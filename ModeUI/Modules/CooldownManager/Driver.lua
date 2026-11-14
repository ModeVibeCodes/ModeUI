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

-- Its own start: the settings are checked and the custom bars sorted out
-- with ModeUI's other modules, but its window waits for /mcdm.
function M:OnInitialize()
    self.Initialize(self.db)
    -- Set by the version 4 migration, which can only see this module's table.
    if self.db.movePlaces then self:MovePlaces(); self.db.movePlaces = nil end
    self:RebuildAssignments()
    self:AddBarTargets()
    -- SharedMedia fonts and bar textures can register after login.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
    addon.RegisterMessage(self, addon.Messages.MODULE_TOGGLED, function(_, id)
        if id == self.id and self.window then self:RefreshWindow() end
    end)
    -- Resource bars in Class Color follow the Class Colors module.
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() if self.active then self:RefreshResources() end end)
    SLASH_MODEUICDM1 = self.SLASH
    SlashCmdList.MODEUICDM = function() self:ToggleWindow() end
end

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("cooldownManager")
    self:Build()
    self:SetResourceEvents(true)
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
    -- Custom spells' own icons: charges, picture and usability change with
    -- these; procs light them; learning or losing a spell shows or hides one.
    for _, event in ipairs({ "SPELL_UPDATE_USES", "SPELL_UPDATE_ICON", "SPELL_UPDATE_USABLE" }) do
        Events:On(self, event, function() self:UpdateSpellIcons() end)
    end
    Events:On(self, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellID) self:SpellProc(spellID, true) end)
    Events:On(self, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellID) self:SpellProc(spellID, false) end)
    Events:On(self, "SPELLS_CHANGED", function() self:Refresh() end)
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
    self:SetResourceEvents(false)
    if self.built then
        for _, id in ipairs(self:BarIds()) do self:UpdateAlpha(id) end
        self:RefreshGlows()
        self:RenderMovers()
        self:HideSpellIcons()
        self:RefreshResources()
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
    if self.built then self:RenderMovers(); self:RenderResourceMovers(); self:UpdateFade() end
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
        self:UpdateCooldowns()
        self:RefreshGlows()
    end
    self:RefreshResources()
    if addon.EditMode then addon.EditMode:RefreshElements() end
    if self.page then self.page:Refresh() end
    if self.resourcePage then self.resourcePage:Refresh() end
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
    local defaults = self:Defaults(viewer)
    if not self:CanConfigure() or not defaults or defaults[key] == nil then return false end
    local candidate = Copy(self.db)
    candidate[viewer][key] = Copy(value)
    -- Rows add lines down or up, columns right or left: a new Growth keeps
    -- New Lines if it still fits, else takes the first that does.
    if key == "grow" then
        local lines, current = self.LinesFor(value), candidate[viewer].lineGrowth
        if current ~= lines[1] and current ~= lines[2] then candidate[viewer].lineGrowth = lines[1] end
    end
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
    if not self:CanConfigure() or not self:Defaults(viewer) then return false end
    local style = Copy(self:Defaults(viewer))
    for key in pairs(self.identityKeys) do style[key] = Copy(self.db[viewer][key]) end
    return Commit(self, viewer, style)
end

-- Copies one viewer's look (borders, background, cooldown, text, glows,
-- opacity, bars) to the viewers in `targets` (a set). What each shows,
-- when, its shape and its spells stay its own. Returns how many took it.
function M:CopyStyleTo(from, targets)
    if not self:CanConfigure() or not self:Defaults(from) or type(targets) ~= "table" then return false end
    local applied = 0
    for _, viewer in ipairs(self:BarIds()) do
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
    for _, id in ipairs(self:BarIds()) do all[id] = true end
    return self:CopyStyleTo(from, all)
end

-- Per-spell switches ---------------------------------------------------------

-- Sets one switch ("hide", or a glow: "proc", "active", "ready", "buff") for
-- the spell with cooldown ID `key` ("1234") on a bar; a switch is stored
-- only while it differs from the bar.
function M:SetSpellSwitch(viewer, key, kind, on)
    if not self:Defaults(viewer) or self.spellKinds[kind] == nil or type(key) ~= "string" then return false end
    local spells = Copy(self.db[viewer].spells)
    local entry = spells[key] or {}
    -- hide stores true while on; a glow switched on starts from the bar's
    -- look for it (Glows tab) and keeps its own look from then on.
    if not on then entry[kind] = nil
    elseif kind == "hide" then entry.hide = true
    elseif type(entry[kind]) ~= "table" then entry[kind] = self:GlowDefaults(viewer, kind) end
    spells[key] = next(entry) and entry or nil
    return self:SetOption(viewer, "spells", spells)
end

-- The look a bar gives a glow when a spell switches it on.
function M:GlowDefaults(viewer, kind)
    local style = self.db[viewer]
    local look = { style = style[kind .. "Glow"], color = Copy(style[kind .. "Color"]), pulse = style[kind .. "Pulse"],
        lines = style.glowLines, thickness = style.glowThickness }
    if kind == "ready" then look.mode, look.duration = style.readyMode, style.readyDuration end
    return look
end

-- Changes one part of a spell's glow look (style, color, pulse, lines,
-- thickness; mode and duration for the off-cooldown glow), switching the
-- glow on first if it was off. Checked by Initialize like every setting.
function M:SetSpellGlow(viewer, key, kind, field, value)
    if not self:Defaults(viewer) or self.spellKinds[kind] ~= "glow" or type(key) ~= "string" then return false end
    local spells = Copy(self.db[viewer].spells)
    local entry = spells[key] or {}
    local look = type(entry[kind]) == "table" and entry[kind] or self:GlowDefaults(viewer, kind)
    look[field] = Copy(value)
    entry[kind] = look
    spells[key] = entry
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
-- Every spell on the bar now takes this spell's switches.
function M:ApplySpellToViewer(viewer, key)
    local entry = self.db[viewer].spells[key]
    local spells = Copy(self.db[viewer].spells)
    for _, item in ipairs(self:BarItems(viewer)) do
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

-- Edit Mode's Open Module Settings opens this module's window on the
-- chosen bar (a standalone module has no page in ModeUI's window).
function M:OpenSettings(elementId)
    self:OpenWindow()
    for _, id in ipairs(self:BarIds()) do
        if self.ElementId(id) == elementId then self:SelectBar(id) end
    end
    for _, id in ipairs(self.resources) do
        if self.ResourceElementId(id) == elementId then self:SelectResource(id) end
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
    return L["On. Move bars with Edit Mode; choose spells in Blizzard's Cooldown Manager (Open CDM)."]
end
