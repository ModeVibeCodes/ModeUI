local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- Lifecycle, events and settings changes. Bars are built and laid out in
-- Bars.lua and Layout.lua, skinned in Skin.lua and Text.lua, shown and faded
-- in Visibility.lua. Everything that touches Blizzard's buttons or the secure
-- bars waits for the end of combat through Defer.
local Defer, Events, L = addon.Defer, addon.Events, addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local REFRESH = "actionBars:refresh"

function M:OnInitialize()
    self.Initialize(self.db)
    -- Set by the version 2 migration, which can only see this module's table.
    if self.db.movePlaces then self:MigratePositions(); self.db.movePlaces = nil end
    self.headers, self.slots, self.ghosts, self.buttons = {}, {}, {}, {}
    self.barOf = setmetatable({}, { __mode = "k" })
    self.indexOf = setmetatable({}, { __mode = "k" })
    -- SharedMedia fonts can register after login; restyle the text with them.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
    -- /kb opens Keybind Mode (Keybind.lua).
    SLASH_MODEUIKEYBIND1 = "/kb"
    SlashCmdList.MODEUIKEYBIND = function() self:ToggleKeybindMode() end
end

-- Version 2 stacks bars on each other by default; saved places still at
-- version 1's defaults move to the new ones. Places live in the profile's
-- positions, which this module owns for its bars.
local function SamePlace(a, b)
    return type(a) == "table" and a.target == b.target and a.point == b.point and a.relativePoint == b.relativePoint
        and a.x == b.x and a.y == b.y
end
function M:MigratePositions()
    local positions = addon.db and addon.db.positions
    if type(positions) ~= "table" then return end
    for bar, old in pairs(self.oldDefaultPositions) do
        local id = self.elementIds[bar]
        if SamePlace(positions[id], old) then positions[id] = Copy(self.defaultPositions[bar]) end
    end
end

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("actionBars")
    -- Learning or losing a stance resizes the stance bar.
    Events:On(self, "UPDATE_SHAPESHIFT_FORMS", function() self:Refresh() end)
    Events:On(self, "ACTIONBAR_SHOWGRID", function() self:SetGridShown(true) end)
    Events:On(self, "ACTIONBAR_HIDEGRID", function() self:SetGridShown(false) end)
    -- Cooldown starts and ends (Glow.lua).
    Events:On(self, "SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    self:Refresh()
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self.gridShown = false
    if self.binding then self:SetKeybindMode(false) end
    self:Refresh()
end

function M:SetEditMode(enabled)
    local editing = enabled and self.active or false
    if editing == (self.editing or false) then return end
    self.editing = editing
    -- Every bar and slot shows while editing; the bars re-lay out for it.
    if self.built then self:Refresh() end
end

-- Runs now, or once combat ends: the buttons and bars are protected.
function M:Refresh()
    Defer:Run(REFRESH, function() self:Apply() end)
end

function M:Apply()
    if self.active then
        self:Build()
        self:HideBlizzard()
        self:HookProcs()
        for _, bar in ipairs(self.bars) do self:ApplyBar(bar) end
        self:ApplyTotemBar()
        self:RenderGhosts()
        self.applied = true
    elseif self.applied then
        self.applied = false
        self:Restore()
        self:RestoreTotemBar()
    end
    if self.built then self:UpdateFade(); self:RefreshGlows() end
    if addon.EditMode then addon.EditMode:RefreshElements() end
    if self.page then self.page:Refresh() end
    self:RenderBarTags()
end

function M:CanConfigure() return not addon.InCombat() end

local function Commit(self, bar, style)
    local target = self.db[bar]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end

-- Opacity only changes alpha. A slider drag sets it straight on the bars and
-- the preview: rebuilding every bar and the page on each step stuttered.
M.alphaKeys = { opacity = true, fadeOpacity = true }
local function SetAlpha(self, bar, key, value)
    local r = self.ranges[key]
    if not addon.IsPublic(value) or type(value) ~= "number" or value ~= math.floor(value) or value < r[1] or value > r[2] then
        return false
    end
    self.db[bar][key] = value
    if self.built then self:UpdateFade() end
    self:PaintPreviewAlpha()
    return true
end

-- Values are checked by Initialize on a copy before they're kept.
function M:SetOption(bar, key, value)
    local defaults = self.styleDefaults[bar]
    if not self:CanConfigure() or not defaults or defaults[key] == nil then return false end
    if self.alphaKeys[key] then return SetAlpha(self, bar, key, value) end
    -- The micro menu and bag bar show Always, on Mouseover or Hidden.
    if key == "visibility" and self:IsUtility(bar) and not self.utilityVisibility[value] then return false end
    local candidate = Copy(self.db)
    candidate[bar][key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    return Commit(self, bar, candidate[bar])
end

function M:ResetBar(bar)
    if not self:CanConfigure() or not self.styleDefaults[bar] then return false end
    local style = Copy(self.styleDefaults[bar])
    for key in pairs(self.identityKeys) do style[key] = self.db[bar][key] end
    return Commit(self, bar, style)
end

-- Copies one bar's look (size, borders, background, text, glows, opacity) to
-- the bars in `targets` (a set: { bar2 = true }); what each bar shows and when
-- stays its own. The pet and stance bars keep their ten-button limit.
-- Returns how many bars took the style.
function M:CopyStyleTo(from, targets)
    if not self:CanConfigure() or not self.styleDefaults[from] or type(targets) ~= "table" then return false end
    local applied = 0
    for _, bar in ipairs(self.bars) do
        if bar ~= from and targets[bar] then
            local style = Copy(self.db[from])
            for key in pairs(self.identityKeys) do style[key] = self.db[bar][key] end
            local candidate = Copy(self.db)
            candidate[bar] = style
            if pcall(self.Initialize, candidate) then
                local target = self.db[bar]
                for key in pairs(target) do target[key] = nil end
                for key, value in pairs(candidate[bar]) do target[key] = value end
                applied = applied + 1
            end
        end
    end
    Commit(self, from, Copy(self.db[from]))
    return true, applied
end

function M:CopyStyleToAll(from)
    local all = {}
    for _, bar in ipairs(self.bars) do all[bar] = true end
    return self:CopyStyleTo(from, all)
end

-- Switches a bar on for good: Show Bar on, and Show back to Always if it was
-- Hidden (the Editing header's Turn On).
function M:TurnOnBar(bar)
    if not self:CanConfigure() or not self.styleDefaults[bar] then return false end
    if self.db[bar].visibility == "hidden" and not self:SetOption(bar, "visibility", "always") then return false end
    return self.db[bar].show or self:SetOption(bar, "show", true)
end

-- How a bar stands, for the Editing list: "off" (Show Bar off), "hidden"
-- (Show set to Hidden) or nil when it shows.
function M:BarState(bar)
    local style = self.db[bar]
    if not style.show then return "off" end
    if style.visibility == "hidden" then return "hidden" end
end

-- Owner for the shared font and color widgets. bar() names the bar being
-- edited and part() the text; "partColor" is that text's color.
function M:AppearanceOwner(bar, part)
    local function Key(key) return key == "partColor" and part() .. "Color" or key end
    local appearance = setmetatable({}, { __index = function(_, key) return M.db[bar()][Key(key)] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(bar(), Key(key), value) end
    return owner
end

-- Edit Mode's Open Module Settings opens the page on the selected bar.
function M:OpenElementSettings(id)
    for _, bar in ipairs(self.bars) do
        if self.elementIds[bar] == id and self.page and self.page.SetEditing then self.page.SetEditing(bar) end
    end
end

function M:Status()
    if not self.active then return L["Off. Blizzard's action bars are in use."] end
    if Defer:IsQueued(REFRESH) then return L["Changes are waiting until you leave combat."] end
    return L["On. Move bars with Edit Mode; your keybinds and actions stay as they are."]
end
