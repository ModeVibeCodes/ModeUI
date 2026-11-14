local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Lifecycle, events and settings changes. Blizzard's viewers are hooked in
-- Blizzard.lua, laid out in Layout.lua, skinned in Skin.lua, Bars.lua and
-- Text.lua, lit in Glow.lua and faded in Visibility.lua. None of Blizzard's
-- Cooldown Manager frames is protected, so changes apply in combat too;
-- settings still change only outside combat, like every ModeUI page.
local Events, L, Cooldowns = addon.Events, addon.L, addon.Domain.Cooldowns
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:OnInitialize()
    self.Initialize(self.db)
    -- SharedMedia fonts and bar textures can register after login.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("cooldownManager")
    self:Build()
    self:HookProcs()
    -- Blizzard's Cooldown Manager loads with the game, normally before
    -- ModeUI; if not yet, its viewers are hooked when it does.
    if not self:HookViewers() then
        Events:On(self, "ADDON_LOADED", function(_, name)
            if name ~= Cooldowns.ADDON then return end
            if self:HookViewers() then Events:Off(self, "ADDON_LOADED") end
            self:Refresh()
        end)
    end
    Events:On(self, "SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    Events:On(self, "PLAYER_TARGET_CHANGED", function() self:UpdateFade() end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    self:Refresh()
end

-- Blizzard's look comes back with a reload: its item frames keep ModeUI's
-- textures until then, and re-laying them out from here would mean calling
-- into Blizzard's code. Placement, glows and fading stop now.
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    if self.built then
        for _, viewer in ipairs(self.viewers) do self:UpdateAlpha(viewer) end
        self:RefreshGlows()
        self:RenderMovers()
        addon.ReloadManager:Request("cooldownManager", L["Cooldown Manager: reload to give Blizzard's cooldowns back their own look and place."])
    end
    if self.fader then self.fader:Hide() end
    if self.page then self.page:Refresh() end
end

function M:OnCombatStateChanged() if self.active then self:UpdateFade() end end

function M:SetEditMode(enabled)
    local editing = enabled and self.active or false
    if editing == (self.editing or false) then return end
    self.editing = editing
    if self.built then self:RenderMovers(); self:UpdateFade() end
end

-- Lays every viewer out and skins it again. The revision tells a later
-- layout (an aura coming or going) that the skin is still current.
M.revision = 0
function M:Refresh()
    self.revision = self.revision + 1
    if self.active then
        self:LayoutAll()
        self:RenderMovers()
        self:UpdateFade()
        self:RefreshGlows()
    end
    if addon.EditMode then addon.EditMode:RefreshElements() end
    if self.page then self.page:Refresh() end
end

function M:CanConfigure() return not addon.InCombat() end

local function Commit(self, viewer, style)
    local target = self.db[viewer]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    self:Refresh()
    if self.page then self.page:Layout() end
    return true
end

-- Opacity only changes alpha: a slider drag sets it without a relayout.
M.alphaKeys = { opacity = true, fadeOpacity = true }

-- Values are checked by Initialize on a copy before they're kept.
function M:SetOption(viewer, key, value)
    local defaults = self.styleDefaults[viewer]
    if not self:CanConfigure() or not defaults or defaults[key] == nil then return false end
    local candidate = Copy(self.db)
    candidate[viewer][key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    if self.alphaKeys[key] then
        self.db[viewer][key] = candidate[viewer][key]
        if self.active then self:UpdateFade() end
        if self.page then self.page:Refresh() end
        return true
    end
    return Commit(self, viewer, candidate[viewer])
end

function M:ResetViewer(viewer)
    if not self:CanConfigure() or not self.styleDefaults[viewer] then return false end
    local style = Copy(self.styleDefaults[viewer])
    for key in pairs(self.identityKeys) do style[key] = Copy(self.db[viewer][key]) end
    return Commit(self, viewer, style)
end

-- Copies one viewer's look (borders, background, cooldown, text, glows,
-- opacity, bars) to the viewers in `targets` (a set). What each shows,
-- when, its shape and its spells stay its own. Returns how many took it.
function M:CopyStyleTo(from, targets)
    if not self:CanConfigure() or not self.styleDefaults[from] or type(targets) ~= "table" then return false end
    local applied = 0
    for _, viewer in ipairs(self.viewers) do
        if viewer ~= from and targets[viewer] then
            local style = Copy(self.db[from])
            for key in pairs(self.identityKeys) do style[key] = Copy(self.db[viewer][key]) end
            local candidate = Copy(self.db)
            candidate[viewer] = style
            if pcall(self.Initialize, candidate) then
                local target = self.db[viewer]
                for key in pairs(target) do target[key] = nil end
                for key, value in pairs(candidate[viewer]) do target[key] = value end
                applied = applied + 1
            end
        end
    end
    Commit(self, from, Copy(self.db[from]))
    return true, applied
end

function M:CopyStyleToAll(from)
    local all = {}
    for _, viewer in ipairs(self.viewers) do all[viewer] = true end
    return self:CopyStyleTo(from, all)
end

-- Per-spell switches ---------------------------------------------------------

-- Sets one switch ("hide", "proc" or "ready") for the spell with cooldown
-- ID `key` ("1234"); a switch is stored only while it differs from the viewer.
function M:SetSpellSwitch(viewer, key, kind, on)
    if not self.styleDefaults[viewer] or self.spellKinds[kind] == nil or type(key) ~= "string" then return false end
    local spells = Copy(self.db[viewer].spells)
    local entry = spells[key] or {}
    local stored = self.spellKinds[kind]
    -- hide stores true while on; proc and ready store false while off.
    if (kind == "hide") == (on == true) then entry[kind] = stored else entry[kind] = nil end
    spells[key] = next(entry) and entry or nil
    return self:SetOption(viewer, "spells", spells)
end

-- Copy, Paste and Apply to Viewer move one spell's switches to others.
function M:CopySpell(viewer, key)
    self.spellClipboard = Copy(self.db[viewer].spells[key] or {})
    return true
end
function M:PasteSpell(viewer, key)
    if not self.spellClipboard then return false end
    local spells = Copy(self.db[viewer].spells)
    spells[key] = next(self.spellClipboard) and Copy(self.spellClipboard) or nil
    return self:SetOption(viewer, "spells", spells)
end
-- Every spell tracked in the viewer now takes this spell's switches.
function M:ApplySpellToViewer(viewer, key)
    local entry = self.db[viewer].spells[key]
    local spells = Copy(self.db[viewer].spells)
    for _, item in ipairs(self:Items(viewer)) do
        local other = self:SpellKey(item)
        if other then spells[other] = entry and Copy(entry) or nil end
    end
    return self:SetOption(viewer, "spells", spells)
end
-- Clears every spell's switches in a viewer.
function M:ResetSpells(viewer) return self:SetOption(viewer, "spells", {}) end

-- How many spells a viewer hides, for the settings page.
function M:HiddenCount(viewer)
    local count = 0
    for _, entry in pairs(self.db[viewer].spells) do if entry.hide then count = count + 1 end end
    return count
end

-- Owner for the shared font and color widgets. viewer() names the viewer
-- being edited and part() the text; "partColor" is that text's color.
function M:AppearanceOwner(viewer, part)
    local function Key(key) return key == "partColor" and part() .. "Color" or key end
    local appearance = setmetatable({}, { __index = function(_, key) return M.db[viewer()][Key(key)] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(viewer(), Key(key), value) end
    return owner
end

-- Edit Mode's Open Module Settings opens the page on the chosen viewer.
function M:OpenElementSettings(id)
    for _, viewer in ipairs(self.viewers) do
        if self.elementIds[viewer] == id and self.page and self.page.SetEditing then self.page.SetEditing(viewer) end
    end
end

function M:Status()
    if not self.active then return L["Off. Blizzard's Cooldown Manager keeps its own look."] end
    local state = self:GameState()
    if state == "missing" then return L["Blizzard's Cooldown Manager isn't loaded on this character."] end
    if state == "unavailable" then return L["The game doesn't offer the Cooldown Manager here yet."] end
    if state == "off" then
        -- The checkbox and its category in the game's own words (Forever's
        -- settings put it in the ADVANCED_OPTIONS_LABEL category).
        local option, category = _G.ENABLE_COOLDOWN_VIEWER, _G.ADVANCED_OPTIONS_LABEL
        if type(option) == "string" and type(category) == "string" then
            return string.format(L["Turn on \"%s\" in the game's Options (%s) to see it."], option, category)
        end
        return L["Turn on the game's Cooldown Manager in its Options to see it."]
    end
    return L["On. Move viewers with Edit Mode; choose spells in Blizzard's Cooldown Settings."]
end
