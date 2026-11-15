local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The icon skin on Blizzard's own item frames: the Mode Button face, the
-- icon filling the item (cropped, never stretched) and the `frameThin` edge
-- outside it. Blizzard's round mask, frame art and
-- out-of-range shade come off (its red out-of-range tint stays, unless Out
-- of Range Tint is off); its swipe becomes a flat one in Swipe Color at
-- Swipe Opacity (Blizzard's gold swipe for an active aura is kept). Ready Flash, Edge, Bling and the debuff border
-- follow their switches. The same code skins the settings preview's samples.
--
-- Nothing is stored on Blizzard's frames: the textures ModeUI adds live in
-- `M.dress`, keyed by the item.
local Kit, Style, Public, Cooldowns = addon.Kit, addon.Style, addon.IsPublic, addon.Domain.Cooldowns
local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
M.dress = setmetatable({}, { __mode = "k" })

-- Blizzard's mask comes off the icon and its frame art fades; once per frame.
-- A region's atlas the game won't tell is left alone.
function M.StripArt(frame, icon)
    if not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        local kind = region.GetObjectType and region:GetObjectType()
        if kind == "MaskTexture" and icon and icon.RemoveMaskTexture then
            pcall(icon.RemoveMaskTexture, icon, region)
        elseif kind == "Texture" and region ~= icon and region.GetAtlas then
            local atlas = region:GetAtlas()
            if Public(atlas) and atlas == OVERLAY_ATLAS then region:SetAlpha(0) end
        end
    end
end

-- The state ModeUI keeps for one item: its art, glows and last geometry.
function M:Dress(item)
    local state = self.dress[item]
    if state then return state end
    state = {}
    self.dress[item] = state
    return state
end

-- Skins an item for the settings of the bar it shows on (`viewer`: a
-- viewer or a custom bar). `g` is the bar's geometry when called from a
-- layout; a new item takes one sized from the settings.
function M:DressItem(viewer, item, g)
    if not viewer or not self.db[viewer] then return end
    local style = self.db[viewer]
    g = g or self.Geometry(style, 1, self.PixelSize(item))
    -- Items Blizzard made before ModeUI was switched on get their hooks now.
    if not self:IsOwnIcon(item) then self:HookItem(self.sourceOf[item] or viewer, item) end
    local state = self:Dress(item)
    -- Same settings, viewer, spell (its own texts) and size since the last
    -- skin: only the alpha and glows are brought up to date.
    local last, key = state.g, self:SpellKey(item)
    if state.revision == self.revision and state.viewer == viewer and state.key == key and last and last.w == g.w
        and last.h == g.h and last.px == g.px then
        self:ApplySpell(viewer, item)
        return
    end
    state.viewer, state.g, state.revision, state.key = viewer, g, self.revision, key
    if self:IsBar(viewer) then self:SkinBar(item, style, g, state) else self:SkinIcon(item, style, g, state) end
    self:StyleTexts(viewer, item, style, g, key)
    self:ApplySpell(viewer, item)
end

local function Fade(region, shown) if region and region.SetAlpha then region:SetAlpha(shown and 1 or 0) end end
M.FadeRegion = Fade

-- The Mode icon art (docs/DESIGN_LANGUAGE.md, "Cooldown icons"): a Mode
-- Button face in Background Color behind the icon, and the `frameThin` edge
-- outside the host (1px Gunmetal, edge-lit, with its shadow ring; the layout
-- leaves room for it). The rim covers its own corners: no mask goes on
-- Blizzard's textures. Border None hides the edge.
function M.IconArt(host)
    local art = { face = host:CreateTexture(nil, "BACKGROUND", nil, -7), edge = Style.Edge(host, M.EDGE) }
    Style.ApplyAsset(art.face, "Button")
    return art
end
function M.PaintIconArt(art, host, style)
    art.face:ClearAllPoints(); art.face:SetAllPoints(host)
    Style.Paint(art.face, style.backgroundColor, style.backgroundOpacity / 100)
    art.edge:SetShown(style.border ~= "none")
    art.edge:Layout()
end

function M:SkinIcon(item, style, g, state)
    local icon = item.Icon
    if not state.stripped then
        state.stripped = true
        self.StripArt(item, icon)
        state.art = self.IconArt(item)
    end
    item:SetSize(g.w, g.h)
    self.PaintIconArt(state.art, item, style)
    if icon and icon.SetTexCoord then
        Kit.Inset(icon, item, 0)
        Kit.CropIcon(icon, g)
    end
    local cooldown = item.Cooldown
    if cooldown and cooldown.SetPoint then
        Kit.Inset(cooldown, item, 0)
        if not state.swipe and cooldown.SetSwipeTexture then state.swipe = pcall(cooldown.SetSwipeTexture, cooldown, Kit.FLAT) end
    end
    -- Out of range, Blizzard tints the icon red (Out of Range Tint) and shows
    -- its shade, a soft shadow cut to its round mask. The shade stays faded:
    -- on square icons it was a block, and Blizzard leaves it shown on an
    -- icon that has no spell yet (RefreshIconColor returns before hiding it).
    Fade(item.OutOfRange, false)
    self:StyleRange(item, style)
    Fade(item.CooldownFlash, style.showFlash)
    Fade(item.DebuffBorder, style.debuffBorder)
    -- Counts sit above the swipe; glows go above them.
    local level = item:GetFrameLevel()
    for _, key in ipairs({ "ChargeCount", "Applications" }) do
        local frame = item[key]
        if frame and frame.SetFrameLevel then frame:SetFrameLevel(level + 4) end
    end
    self:StyleCooldown(item)
end

-- Out of range (Blizzard's spellOutOfRange, read only when public), the icon
-- takes the Mode Rosewood tint instead of Blizzard's red, as on the action
-- bars; with Out of Range Tint off it keeps its color. Blizzard's other tints
-- (unusable, no mana) stay.
function M:StyleRange(item, style)
    local icon = item.Icon
    if not icon or not icon.SetVertexColor then return end
    local out = item.spellOutOfRange
    if Public(out) and out == true then Style.Paint(icon, style.rangeTint and Style.Tone.rosewood or Style.Tone.mono.white) end
end

-- Whether Blizzard shows a spell's effect as up on its icon: it swaps the
-- swipe to its gold aura color (a table it shares, compared by reference;
-- never a secret).
function M.AuraUp(item)
    local constants = _G.CooldownViewerConstants
    return constants ~= nil and constants.ITEM_AURA_COLOR ~= nil and rawequal(item.cooldownSwipeColor, constants.ITEM_AURA_COLOR)
end

-- Desaturate on Cooldown: the icon is gray while its spell is on a real
-- cooldown (not the global cooldown, nor while its effect is up), from
-- C_Spell's never-secret isActive and isOnGCD. Off, icons keep full color.
-- When the game can't say (an item, say), Blizzard's own gray stays.
function M:StyleDesaturation(item, style)
    local icon = item.Icon
    if not icon or not icon.SetDesaturated or self:IsBuff(self.sourceOf[item]) then return end
    if not style.desaturate then icon:SetDesaturated(false); return end
    local key = self:SpellKey(item)
    local cooling = key and Cooldowns.Cooling(self:CooldownSpell(key))
    -- With Show Aura Time on, the icon keeps Blizzard's full color while the
    -- effect's time shows; off, it's gray for as long as the spell cools.
    if cooling ~= nil then icon:SetDesaturated(cooling and not (style.auraSwipe and self.AuraUp(item))) end
    -- Gray until the cooldown ends, which no event reports (Glow.lua).
    if cooling == true then self:WatchCooling(item, true) end
end

-- Show Aura Time off: while the spell's effect is up, the icon shows the
-- spell's cooldown (or recharge) instead of Blizzard's gold effect swipe.
-- The time comes as a duration object straight to the Cooldown, and the
-- aura display time Blizzard switched on goes off again; Blizzard puts its
-- own back on its next refresh, and this runs after each one.
function M:ShowSpellCooldown(item)
    local cooldown, key = item.Cooldown, self:SpellKey(item)
    local spell = key and self:CooldownSpell(key)
    if not spell or not cooldown.SetCooldownFromDurationObject then return end
    local _, max, recharging = Cooldowns.Charges(spell)
    local duration
    if max and recharging and Cooldowns.Cooling(spell) ~= true then duration = Cooldowns.ChargeDuration(spell)
    else duration = Cooldowns.CooldownDuration(spell) end
    if not duration then return end
    if cooldown.SetUseAuraDisplayTime then pcall(cooldown.SetUseAuraDisplayTime, cooldown, false) end
    pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
end

-- The swipe, edge, bling and gray, put back after each Blizzard refresh,
-- and the glows that follow the icon's state. The gold swipe Blizzard draws
-- while a spell's aura is up is left as it is.
function M:StyleCooldown(item)
    local state = self.dress[item]
    local style = state and self.db[state.viewer]
    local cooldown = item.Cooldown
    if not style or not cooldown or not cooldown.SetSwipeColor then return end
    local aura = self.AuraUp(item) and not self:IsBuff(self.sourceOf[item])
    if aura and not style.auraSwipe then self:ShowSpellCooldown(item) end
    self:StyleDesaturation(item, style)
    if not (aura and style.auraSwipe) then
        local c = style.swipeColor
        cooldown:SetSwipeColor(c[1], c[2], c[3], style.swipeOpacity / 100)
    end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(style.showEdge) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(style.showBling) end
    if self:IsLive(item) then self:ApplyGlows(item) end
end

-- A ModeUI-made icon with the parts the skin and text code look for, for the
-- settings preview.
function M:BuildSample(parent, bar)
    local item = CreateFrame("Frame", nil, parent)
    if bar then
        item.Icon = CreateFrame("Frame", nil, item)
        item.Icon.Icon = item.Icon:CreateTexture(nil, "ARTWORK")
        item.Icon.Icon:SetAllPoints()
        item.Bar = CreateFrame("StatusBar", nil, item)
        item.Bar:SetMinMaxValues(0, 1)
        item.Bar.Name = item.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.Bar.Duration = item.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.Icon.Applications = item.Icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    else
        item.Icon = item:CreateTexture(nil, "ARTWORK")
        item.Cooldown = CreateFrame("Cooldown", nil, item)
        if item.Cooldown.SetHideCountdownNumbers then item.Cooldown:SetHideCountdownNumbers(true) end
        item.ChargeCount = CreateFrame("Frame", nil, item)
        item.ChargeCount:SetAllPoints()
        item.ChargeCount.Current = item.ChargeCount:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.cooldownText = item.ChargeCount:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    return item
end
