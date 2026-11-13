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
    self.headers, self.slots, self.ghosts, self.buttons = {}, {}, {}, {}
    self.barOf = setmetatable({}, { __mode = "k" })
    -- SharedMedia fonts can register after login; restyle the text with them.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("actionBars")
    -- Learning or losing a stance resizes the stance bar.
    Events:On(self, "UPDATE_SHAPESHIFT_FORMS", function() self:Refresh() end)
    Events:On(self, "ACTIONBAR_SHOWGRID", function() self:SetGridShown(true) end)
    Events:On(self, "ACTIONBAR_HIDEGRID", function() self:SetGridShown(false) end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    self:Refresh()
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self.gridShown = false
    self:Refresh()
end

function M:SetEditMode(enabled)
    self.editing = enabled and self.active or false
    if not self.built then return end
    self:RenderGhosts()
    self:UpdateFade()
end

-- Runs now, or once combat ends: the buttons and bars are protected.
function M:Refresh()
    Defer:Run(REFRESH, function() self:Apply() end)
end

function M:Apply()
    if self.active then
        self:Build()
        self:HideBlizzard()
        for _, bar in ipairs(self.bars) do self:ApplyBar(bar) end
        self:RenderGhosts()
        self.applied = true
    elseif self.applied then
        self.applied = false
        self:Restore()
    end
    if self.built then self:UpdateFade() end
    if addon.EditMode then addon.EditMode:RefreshElements() end
    if self.page then self.page:Refresh() end
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

-- Values are checked by Initialize on a copy before they're kept.
function M:SetOption(bar, key, value)
    local defaults = self.styleDefaults[bar]
    if not self:CanConfigure() or not defaults or defaults[key] == nil then return false end
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

-- Copies one bar's look (size, borders, text, opacity) to every other bar;
-- what each bar shows and when stays its own. The pet and stance bars keep
-- their ten-button limit.
function M:CopyStyleToAll(from)
    if not self:CanConfigure() or not self.styleDefaults[from] then return false end
    for _, bar in ipairs(self.bars) do
        if bar ~= from then
            local style = Copy(self.db[from])
            for key in pairs(self.identityKeys) do style[key] = self.db[bar][key] end
            local candidate = Copy(self.db)
            candidate[bar] = style
            if pcall(self.Initialize, candidate) then
                local target = self.db[bar]
                for key in pairs(target) do target[key] = nil end
                for key, value in pairs(candidate[bar]) do target[key] = value end
            end
        end
    end
    return Commit(self, from, Copy(self.db[from]))
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
