local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Cast Bar (owner, November 17 and 18, 2026): the player's cast bar, on its
-- own in ModeCDM, in the resource bars' look: a status bar in the Mode edge
-- (Mode-Round, Gunmetal, drawn in pieces and on whole pixels), Dark mode by
-- default (the fill in darkFill, the Comet head alone, the text in your
-- class color), the spell icon in its own bordered box (Hidden by default),
-- and Show Interrupted (1s in the Interrupted color, then a 0.3s fade). It
-- sits above Essential Cooldowns. Only the player's: Target, Focus and
-- nameplate cast bars stay where they are. While it is on, Unit Frames'
-- Player cast bar steps aside and Blizzard's stays faded (Kit.PlayerCast,
-- Kit.NativeFade). Saved in db.castBar; added without a version step (a
-- profile from before it takes the defaults). CastBar.lua builds and runs
-- it, CastPreview.lua and CastSettings.lua are its page.
local L = addon.L
local Public, Number = addon.IsPublic, addon.IsNumber
local Tone = addon.Style.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.CAST_LABEL = "Cast Bar"
M.CAST_ELEMENT = "cooldownManagerCastBar"
M.CAST_FRAME = "ModeUICastBar"

-- An Edit Mode element like the others: it attaches to any ModeUI element,
-- and the viewers, custom bars and resource bars can attach to it.
addon.Positioning:AddTarget(M.CAST_ELEMENT, L[M.CAST_LABEL], M.CAST_FRAME)

-- Above Essential Cooldowns; Buff Icons, which sat there, now hang above it
-- (a saved place still at the old default moves once: Migrations.lua, v8).
M.castPosition = { target = M.ElementId("essential"), placement = "above", x = 0, y = 0 }
M.OLD_BUFF_ICON_POSITION = M.defaultPositions.buffIcon
M.defaultPositions.buffIcon = { target = M.CAST_ELEMENT, placement = "above", x = 0, y = 0 }

M.castDefaults = {
    show = true, width = 300, height = 18, matchWidth = true,
    -- The resource bars' border: Mode-Round in Gunmetal, Rim Color.
    border = "mode", edgeStyle = "obsidian", edgeMetal = "default", rimColor = "metal", rimCustom = Copy(Tone.ivory), edgeSize = 1,
    -- Bar Mode Color (the default since version 10, owner, November 20,
    -- 2026): the fill in your class color, or in Bar Color when Bar Color is
    -- Custom. Dark: the fill in darkFill, the Comet head alone, the text in
    -- your class color. Not Interruptible and Interrupted have their own.
    barMode = "color", barColorMode = "class", barTexture = "media:Mode-FG", barColor = Copy(Tone.cast.casting),
    lockedColor = Copy(Tone.cast.shielded), interruptedColor = Copy(Tone.cast.interrupted),
    barBackground = "media:Mode-BG", barBackgroundOpacity = M.RESOURCE_EMPTY, spark = true,
    darkText = "class", darkTextColor = Copy(Tone.textBright),
    -- The spell icon: Hidden, Left or Right, in its own border, Icon Gap
    -- from the bar's border.
    icon = "none", iconGap = 2,
    showInterrupted = true,
    -- Spell Name and Timer, each with its switch, anchor and offsets.
    nameShow = true, nameAnchor = "LEFT", nameX = 0, nameY = 0,
    timerShow = true, timerAnchor = "RIGHT", timerX = 0, timerY = 0,
    textSize = 11, textColor = Copy(Tone.textBright),
    font = "game", fontMedia = addon.Style.FONT_DEFAULT, outline = false, shadow = true, slug = true,
    opacity = 100,
    -- Show When and the show rules, like the other bars (owner, November 24, 2026).
    visibility = "always", fadeOpacity = 0,
    hideMounted = false, hideVehicle = false, onlyInGroup = false, onlyInInstance = false, dim = false,
}
M.castRanges = { fadeOpacity = { 0, 100, 5 }, width = { 40, 600, 1 }, height = { 6, 40, 1 }, iconGap = { 0, 12, 1 }, edgeSize = { 1, 2, 1 },
    barBackgroundOpacity = { 0, 100, 5 }, textSize = { 6, 32, 1 },
    nameX = { -60, 60, 1 }, nameY = { -40, 40, 1 }, timerX = { -60, 60, 1 }, timerY = { -40, 40, 1 },
    opacity = { 10, 100, 5 } }
M.castColorKeys = { rimCustom = true, barColor = true, lockedColor = true, interruptedColor = true,
    darkTextColor = true, textColor = true }
M.castIdentityKeys = { show = true, width = true, height = true, matchWidth = true }
local ANCHORS = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } }
M.castChoices = {
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" }, { id = "noCombat", label = "Out of Combat" },
        { id = "target", label = "In Combat or With a Target" }, { id = "hidden", label = "Hidden" } },
    border = M.resourceChoices.border, edgeStyle = M.resourceChoices.edgeStyle, edgeMetal = M.resourceChoices.edgeMetal,
    rimColor = M.resourceChoices.rimColor, barMode = M.resourceChoices.barMode,
    barColorMode = { { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    darkText = { { id = "class", label = "Class Color" }, { id = "bar", label = "Bar Color" }, { id = "custom", label = "Custom" } },
    icon = { { id = "none", label = "Hidden" }, { id = "left", label = "Left" }, { id = "right", label = "Right" } },
    nameAnchor = ANCHORS, timerAnchor = ANCHORS,
}

-- Rim Color in one picker, as on the resource bars.
function M:CastRim()
    local style = self.db.castBar
    return style.rimColor == "metal" and style.edgeMetal or style.rimColor
end
function M:SetCastRim(choice)
    if choice == "bar" or choice == "custom" then return self:SetCastOption("rimColor", choice) end
    return self:SetCastOption("edgeMetal", choice) and self:SetCastOption("rimColor", "metal")
end

-- Version 10 -> 11 (Migrations.lua): every Mode cast bar's colors (owner,
-- November 23, 2026). A Bar Color or Not Interruptible color still at the old
-- default takes the light blue or orange-red; a picked color stays.
function M.MigrateCastColors(db)
    local cast, Same, Legacy = db.castBar, addon.Style.SameColor, addon.Style.LEGACY
    if type(cast) ~= "table" or not Public(cast) then return end
    if Same(cast.barColor, Legacy.castCasting) then cast.barColor = Copy(Tone.cast.casting) end
    if Same(cast.lockedColor, Legacy.castShielded) then cast.lockedColor = Copy(Tone.cast.shielded) end
end

-- Validation ------------------------------------------------------------------

local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end

-- Fills in and checks db.castBar (called by Initialize). Bad data stops with
-- an error; nothing is reset.
function M.ValidateCast(db)
    if db.castBar == nil then db.castBar = Copy(M.castDefaults) end
    local style = db.castBar
    assert(Public(style) and type(style) == "table", "Invalid cast bar settings")
    for key, default in pairs(M.castDefaults) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid cast bar setting: " .. key)
        if M.castColorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid cast bar color: " .. key) end
        end
    end
    for key, range in pairs(M.castRanges) do assert(Whole(style[key], range), "Invalid cast bar range: " .. key) end
    for key, list in pairs(M.castChoices) do
        local ok = false
        for _, item in ipairs(list) do if item.id == style[key] then ok = true end end
        assert(ok, "Invalid cast bar choice: " .. key)
    end
    assert(addon.Kit.ValidBarTexture(style.barTexture, true), "Invalid cast bar texture")
    assert(addon.Kit.ValidBarTexture(style.barBackground, false), "Invalid cast bar background")
end
