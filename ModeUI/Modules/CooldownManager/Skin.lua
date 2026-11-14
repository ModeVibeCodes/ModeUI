local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The icon skin: the Mode slot (Kit.Slot: a hollow border around the
-- background, the icon a pixel inside it, cropped square to the slot) on
-- Blizzard's own item frames. Blizzard's round mask and frame art come off;
-- its out-of-range shade becomes a flat tint inside the border; its swipe
-- becomes a flat one in Swipe Color at Swipe Opacity (Blizzard's gold swipe
-- for an active aura is kept). Ready Flash, Edge, Bling and the debuff border
-- follow their switches. The same code skins the settings preview's samples.
--
-- Nothing is stored on Blizzard's frames: the textures ModeUI adds live in
-- `M.dress`, keyed by the item.
local Kit, Public, Cooldowns = addon.Kit, addon.IsPublic, addon.Domain.Cooldowns
local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local RANGE_COLOR = Kit.palette.hostile
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
    self:HookItem(self.sourceOf[item] or viewer, item)
    local state = self:Dress(item)
    -- Same settings, viewer and size since the last skin: only the alpha
    -- and glows are brought up to date.
    local last = state.g
    if state.revision == self.revision and state.viewer == viewer and last and last.w == g.w and last.h == g.h
        and last.px == g.px then
        self:ApplySpell(viewer, item)
        return
    end
    state.viewer, state.g, state.revision = viewer, g, self.revision
    if self:IsBar(viewer) then self:SkinBar(item, style, g, state) else self:SkinIcon(item, style, g, state) end
    self:StyleTexts(viewer, item, style, g)
    self:ApplySpell(viewer, item)
end

local function Fade(region, shown) if region and region.SetAlpha then region:SetAlpha(shown and 1 or 0) end end
M.FadeRegion = Fade

function M:SkinIcon(item, style, g, state)
    local icon = item.Icon
    if not state.stripped then
        state.stripped = true
        self.StripArt(item, icon)
        state.art = Kit.SlotArt(item)
    end
    item:SetSize(g.w, g.h)
    Kit.PaintSlotArt(state.art, item, style, g)
    if icon and icon.SetTexCoord then
        Kit.Inset(icon, item, g.inset)
        Kit.CropIcon(icon, g)
    end
    local cooldown = item.Cooldown
    if cooldown and cooldown.SetPoint then
        Kit.Inset(cooldown, item, g.inset)
        if not state.swipe and cooldown.SetSwipeTexture then state.swipe = pcall(cooldown.SetSwipeTexture, cooldown, Kit.FLAT) end
    end
    -- Out of range: Blizzard tints the icon and shows its shade; the shade
    -- becomes flat red inside the border, or nothing.
    if item.OutOfRange then
        Kit.SlotOverlay(item.OutOfRange, item, g.inset, RANGE_COLOR, 0.28)
        Fade(item.OutOfRange, style.rangeTint)
    end
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
    local cooling = key and Cooldowns.Cooling(Cooldowns.SpellID(tonumber(key)))
    if cooling ~= nil then icon:SetDesaturated(cooling and not self.AuraUp(item)) end
end

-- The swipe, edge, bling and gray, put back after each Blizzard refresh,
-- and the glows that follow the icon's state. The gold swipe Blizzard draws
-- while a spell's aura is up is left as it is.
function M:StyleCooldown(item)
    local state = self.dress[item]
    local style = state and self.db[state.viewer]
    local cooldown = item.Cooldown
    if not style or not cooldown or not cooldown.SetSwipeColor then return end
    self:StyleDesaturation(item, style)
    if not self.AuraUp(item) then
        local c = style.swipeColor
        cooldown:SetSwipeColor(c[1], c[2], c[3], style.swipeOpacity / 100)
    end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(style.showEdge) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(style.showBling) end
    if self.sourceOf[item] then self:ApplyGlows(item) end
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
