local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Lifecycle, events and settings changes. Windows are built in Window.lua,
-- filled in Render.lua; the header menu is Menu.lua and the spell breakdown
-- Breakdown.lua. Nothing here is protected, so windows update in combat too.
-- ModeUI never touches Blizzard's own meter window or its option.
local Events, DM, L = addon.Events, addon.Domain.DamageMeter, addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end
-- Meter events can arrive many times a second; windows redraw at most this
-- often. In combat the fight timer ticks on its own.
M.RENDER_INTERVAL, M.TIMER_INTERVAL = 0.25, 0.5
-- After combat the game turns the numbers public again; redraw a few times
-- so percent and breakdowns appear without waiting for the next event.
M.AFTER_COMBAT = { 1, 3 }

function M:OnInitialize()
    self.Initialize(self.db)
    self.frames, self.movers, self.sessionIds = {}, {}, {}
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() if self.active then self:RenderAll() end end)
    -- SharedMedia fonts and textures can register after login.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

function M:OnEnable()
    self.active = true
    for _, event in ipairs(DM.EVENTS) do Events:On(self, event, function(name) self:OnMeterEvent(name) end) end
    Events:On(self, "GROUP_ROSTER_UPDATE", function() self:UpdateShown() end)
    -- Blizzard's meter loads with the game; this catches it loading later.
    Events:On(self, "ADDON_LOADED", function(_, name) if name == "Blizzard_DamageMeter" then self:SyncBlizzard() end end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    self:Refresh()
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self:CloseMenu(); self:CloseBreakdown()
    self:Refresh()
end

function M:OnCombatStateChanged(inCombat)
    if not self.active then return end
    self:UpdateShown()
    self:UpdateGrips()
    if inCombat then self:StopResize() end
    if not inCombat and self.blizzardPending then self:SyncBlizzard() end
    -- The ticker runs the fight timer.
    if inCombat then self:Ticker():Show(); return end
    self:RequestRender()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs(self.AFTER_COMBAT) do C_Timer.After(delay, function() if self.active then self:RequestRender() end end) end
    end
end

function M:OnMeterEvent(event)
    if event == "DAMAGE_METER_RESET" then
        -- Earlier fights are gone; windows go back to their Fight setting.
        for window in pairs(self.sessionIds) do self.sessionIds[window] = nil end
        self:CloseBreakdown()
    end
    if event ~= "DAMAGE_METER_COMBAT_SESSION_UPDATED" and self.built then
        for _, window in ipairs(self.windows) do self.frames[window].offset = 0 end
    end
    self:RequestRender()
end

-- Redraws on the next tick, at most every RENDER_INTERVAL.
function M:RequestRender()
    self.dirty = true
    self:Ticker():Show()
end

function M:Ticker()
    if self.ticker then return self.ticker end
    local ticker = CreateFrame("Frame")
    local since, clock = math.huge, 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        since, clock = since + elapsed, clock + elapsed
        if self.dirty and since >= self.RENDER_INTERVAL then
            self.dirty, since = false, 0
            self:RenderAll()
        end
        local fighting = addon.InCombat()
        if clock >= self.TIMER_INTERVAL then
            clock = 0
            if fighting then self:RenderHeaders() end
        end
        -- Sleeps until the next event or fight.
        if not self.dirty and not fighting then ticker:Hide() end
    end)
    self.ticker = ticker
    return ticker
end

-- Whether a window shows: switched on, and its Show setting allows it now.
-- Edit Mode and Test on Screen show every window that's on.
function M:ShouldShow(window)
    local style = self:Style(window)
    if not self.active or not style.show then return false end
    if self.editing or self.testing then return true end
    local when = style.visibility
    if when == "combat" then return addon.InCombat() end
    if when == "group" then return IsInGroup and IsInGroup() == true end
    return when == "always"
end

function M:UpdateShown()
    if not self.built then return end
    for _, window in ipairs(self.windows) do
        local frame, show = self.frames[window], self:ShouldShow(window)
        local was = frame:IsShown()
        frame:SetShown(show)
        if show and not was then self:RenderWindow(window) end
    end
    if self.breakdown and self.breakdown:IsShown() and not self.frames[self.breakdown.window]:IsShown() then self:CloseBreakdown() end
end

function M:Refresh()
    self.refreshing = true
    self:ClearStyles()
    -- Windows anchored with Match Width or Match Height follow their anchor first.
    self:MatchAnchored()
    self:SyncBlizzard()
    if self.active then self:Build() end
    -- The breakdown repaints its shell after any settings change.
    self.paintRevision = (self.paintRevision or 0) + 1
    if self.built then
        for _, window in ipairs(self.windows) do self:PaintWindow(window) end
        self:UpdateShown()
        self:RenderMovers()
        self:RenderAll()
        if self.active then self:Ticker():Show() elseif self.ticker then self.ticker:Hide() end
    end
    self.refreshing = false
    if addon.EditMode and addon.EditMode.RefreshElements then addon.EditMode:RefreshElements() end
    if self.page then self.page:Refresh() end
end

-- Position Manager's anchor size listener: a window matched to something
-- that isn't a meter window follows it when that changes size.
function M:AnchorResized()
    if self.active and self.built and not self.refreshing and self:MatchAnchored() then self:Refresh() end
end

function M:SetEditMode(enabled)
    local editing = enabled and self.active or false
    if editing == (self.editing or false) then return end
    self.editing = editing
    self:CloseMenu(); self:CloseBreakdown()
    if self.built then self:Refresh() end
end

-- Test on Screen: every window that's on shows the sample fight.
function M:SetTestDisplay(on)
    if on and not self:CanTestDisplay() then return false end
    self.testing = on == true
    self:Refresh()
    return true
end
function M:CanTestDisplay() return self.active == true and not addon.InCombat() and not addon.editMode end

local function Commit(self, window, style)
    local target = self.db[window]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    self:Refresh()
    if self.page then self.page:Layout() end
    return true
end

-- Values are checked by Initialize on a copy before they're kept. Windows
-- aren't protected, so settings change in combat too. A grouped window's
-- shared settings are saved on the head of its group, so the group changes
-- together.
function M:SetOption(window, key, value)
    local defaults = self.styleDefaults[window]
    if not defaults or defaults[key] == nil then return false end
    local target = self:OwnerOf(window, key)
    local candidate = Copy(self.db)
    candidate[target][key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    if key == "meterType" or key == "session" then
        self.sessionIds[window] = nil
        if self.built then self.frames[window].offset = 0 end
        if self.breakdown and self.breakdown.window == window then self:CloseBreakdown() end
    end
    return Commit(self, target, candidate[target])
end

-- A window's fight: "current", "overall" (saved), or an earlier fight's
-- session ID (kept until the game resets its data or the window changes).
function M:SetSession(window, session)
    if type(session) == "number" then
        self.sessionIds[window] = session
        if self.built then self.frames[window].offset = 0 end
        self:CloseBreakdown()
        self:RenderAll()
        return true
    end
    return self:SetOption(window, "session", session)
end

-- Resets a window's look; for a grouped window, its group's.
function M:ResetWindow(window)
    if not self.styleDefaults[window] then return false end
    window = self:Leader(window)
    local style = Copy(self.styleDefaults[window])
    for key in pairs(self.identityKeys) do style[key] = self.db[window][key] end
    return Commit(self, window, style)
end

-- Copy & Apply: copies one window's look (its group's, when grouped) to the
-- chosen windows (a grouped one takes it on its group's head). scope: "all"
-- (everything but what each window shows and when, its group and matching),
-- "window" (size, frame and header), "bars" or "text" (M.copyScopes).
-- Each copy is checked before it's kept. Returns ok and how many changed.
function M:CopyStyleTo(from, targets, scope)
    scope = scope or "all"
    if not self.styleDefaults[from] or type(targets) ~= "table" or (scope ~= "all" and not self.copyScopes[scope]) then return false end
    from = self:Leader(from)
    local keys = {}
    if scope == "all" then
        for key in pairs(self.styleDefaults[from]) do if not self.identityKeys[key] then keys[#keys + 1] = key end end
    else
        for _, key in ipairs(self.copyScopes[scope]) do keys[#keys + 1] = key end
    end
    local owners, applied = {}, 0
    for _, window in ipairs(self.windows) do
        if targets[window] then owners[self:Leader(window)] = true end
    end
    for _, window in ipairs(self.windows) do
        if owners[window] and window ~= from then
            local candidate = Copy(self.db)
            for _, key in ipairs(keys) do candidate[window][key] = Copy(self.db[from][key]) end
            if pcall(self.Initialize, candidate) then
                local target = self.db[window]
                for key in pairs(target) do target[key] = nil end
                for key, value in pairs(candidate[window]) do target[key] = value end
                applied = applied + 1
            end
        end
    end
    Commit(self, from, Copy(self.db[from]))
    return true, applied
end

function M:CopyStyleToAll(from, scope)
    local all = {}
    for _, window in ipairs(self.windows) do all[window] = true end
    return self:CopyStyleTo(from, all, scope)
end

-- Clears the game's recorded fights (Blizzard's own Reset), for every meter.
function M:ResetData()
    DM.Reset()
    self:OnMeterEvent("DAMAGE_METER_RESET")
    self:RenderAll()
end

-- Owner for the shared font and color widgets: window() names the window
-- being edited and part() the text. The font widget's "font" and
-- "fontMedia", and "partColor", are that text's own keys.
local PART_KEYS = { font = "Font", fontMedia = "FontMedia", partColor = "Color" }
function M:AppearanceOwner(window, part)
    local function Key(key) return PART_KEYS[key] and part and part() .. PART_KEYS[key] or key end
    local appearance = setmetatable({}, { __index = function(_, key) return M:Style(window())[Key(key)] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return true end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(window(), Key(key), value) end
    return owner
end

-- Edit Mode's Open Module Settings opens the page on the selected window.
function M:OpenElementSettings(id)
    for _, window in ipairs(self.windows) do
        if self.elementIds[window] == id and self.page and self.page.SetEditing then self.page.SetEditing(window) end
    end
end

-- The settings page's status line.
function M:Status()
    if not DM.Supported() then return L["The game's damage meter isn't available on this client, so there is nothing to show."] end
    local available, reason = DM.Available()
    if not available then return reason or L["The game's damage meter isn't available right now."] end
    if DM.GameMeterOn() == false then
        return L["The game's own Damage Meter option is off, so fights may not be recorded. Turn it on in the game's options."]
    end
    if not self.active then return L["Off. Turn the module on to show its windows."] end
    return L["On. Move windows with Edit Mode; click a window's header for its meter and fight."]
end
