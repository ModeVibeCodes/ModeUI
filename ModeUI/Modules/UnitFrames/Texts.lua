local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Text slots on a frame face (TextSlots.lua defines them): one text and its
-- lift per slot, placed from the slot's settings and filled from unit data.
-- Unit values may be secret: they go only to SetText/SetFormattedText.
local Kit, Domain = addon.Kit, addon.Domain
local Write, Font, LayoutLift = Kit.Write, Kit.Font, Kit.LayoutLift
local Health, Power, Name, Level = Domain.Health, Domain.Power, Domain.Name, Domain.Level
local FLIP = { LEFT = "RIGHT", RIGHT = "LEFT" }
local VALUE_MODE = { healthPercent = "percent", healthCurrent = "current", healthBoth = "both", powerPercent = "percent",
    powerCurrent = "current", powerBoth = "both" }
local MUTED = M.palette.muted
-- Level and Name in the Default color: the level muted, the name after it.
local LEVEL_NAME = string.format("|cff%02x%02x%02x%%s|r %%s", math.floor(MUTED[1] * 255 + 0.5),
    math.floor(MUTED[2] * 255 + 0.5), math.floor(MUTED[3] * 255 + 0.5))

function M:BuildTexts(f)
    f.texts, f.textKinds = {}, { name = {}, health = {}, power = {} }
    for _, slot in ipairs(self.textSlots) do
        local text = Kit.Text(f.textLayer)
        text.lift = Kit.Text(f.textLayer, "ARTWORK")
        text.slot = slot
        f.texts[slot] = text
    end
end

-- A slot's settings, X offset and border alignment. A mirrored Target shows
-- the Player's slot from the other side, its X offset and alignment flipped.
function M:SlotSettings(fdb, slot)
    if fdb.mirrored ~= true then
        local s = fdb.texts[slot]
        return s, s.x, s.align
    end
    local s = fdb.texts[self.slotMirror[slot] or slot]
    return s, -s.x, FLIP[s.align] or s.align
end

-- Where the bottom of border text sits, up from the health bar's top: its
-- baseline on the middle of the top rim, so the letters sit on the border and
-- their descenders (a quarter of the font size) dip over it.
function M:BorderBottom(g, size, y)
    local px = g.px
    local descent = math.floor(size * 0.25 / px + 0.5) * px
    return g.pad - g.border / 2 - descent + math.floor(y / px + 0.5) * px
end

-- Text never reaches the portrait (owner, November 13, 2026). A text on the
-- portrait side stops 2px before the ring's outer edge across its own line
-- (its font's band at `mid`, moved by its Y offset), rounded out to whole
-- pixels; its X offset moves it away from the portrait freely but never past
-- that line. Returns how far in from the bars' portrait-side edge it may start.
local function Clearance(g, mid, size, dy, minimum)
    minimum = minimum or 4
    local R, px = g.portrait / 2, g.px
    if R <= 0 then return minimum end
    local half = math.ceil((size + 2) / 2 / px) * px
    local c = mid - dy - g.height / 2
    local d = (c - half <= 0 and c + half >= 0) and 0 or math.min(math.abs(c - half), math.abs(c + half))
    if d >= R then return minimum end
    local edge = R + math.sqrt(R * R - d * d) + 2 * px - g.inset
    return math.max(minimum, math.ceil(edge / px - 1e-6) * px)
end
local function Clamped(sign, clear, dx) return sign * math.max(clear, clear + sign * dx) end

-- Places one bar slot: its bar's point (TOPLEFT, RIGHT, BOTTOM...), 4 units in
-- from the bar's side and 1px in from its top or bottom edge.
local function PlaceInBar(f, g, place, text, s, dx, near, sign)
    local px, power = g.px, place.bar == "power"
    local bar = power and f.power or f.health
    local top = power and g.barsTop + g.healthHeight + g.gap or g.barsTop
    local height = power and g.powerHeight or g.healthHeight
    local line = math.ceil((s.size + 2) / px) * px
    local mid, y = top + height / 2, s.y
    if place.v == "TOP" then mid, y = top + px + line / 2, s.y - px
    elseif place.v == "BOTTOM" then mid, y = top + height - px - line / 2, s.y + px end
    local x = (place.h == "LEFT" and 4 or place.h == "RIGHT" and -4 or 0) + dx
    if place.h == near then x = Clamped(sign, Clearance(g, mid, s.size, s.y), dx) end
    local point = place.v == "CENTER" and place.h or place.h == "CENTER" and place.v or place.v .. place.h
    text:SetPoint(point, bar, point, x, y)
end

-- On the border: across the health bar's span, clear of the ring at the
-- text's own height (the ring curves away above the block, so it can sit closer).
function M:PlaceOnBorder(f, g, text, s, dx, near, sign)
    local line = math.ceil((s.size + 2) / g.px) * g.px
    local bottom = self:BorderBottom(g, s.size, s.y)
    local nearX = Clamped(sign, Clearance(g, g.barsTop - bottom - line / 2, s.size, 0, 0), dx)
    text:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", near == "LEFT" and nearX or dx, bottom)
    text:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", near == "RIGHT" and nearX or dx, bottom)
end

-- Lays out every slot and sorts the shown ones by the data they follow, so
-- unit events refresh only their own texts.
function M:LayoutTexts(f, unit)
    local fdb, g = self:FrameDB(unit), f.geometry
    local near = fdb.portraitSide == "right" and "RIGHT" or "LEFT"
    local sign = near == "LEFT" and 1 or -1
    local path = self:FontPath(fdb)
    f.textUnitColored = f.textUnitColored or {}
    for _, list in pairs(f.textKinds) do for i = #list, 1, -1 do list[i] = nil end end
    for i = #f.textUnitColored, 1, -1 do f.textUnitColored[i] = nil end
    for _, slot in ipairs(self.textSlots) do
        local text, place = f.texts[slot], self.slotPlaces[slot]
        local s, dx, align = self:SlotSettings(fdb, slot)
        local shown = s.content ~= "none" and (place.bar ~= "power" or fdb.showPower)
        local justify = place.h or align
        text:ClearAllPoints()
        if shown then
            -- Names in the font's SemiBold when it is Geist (docs/DESIGN_LANGUAGE.md, "Text").
            local named = self.contentKind[s.content] == "name" and s.content ~= "level"
            Font(text, fdb, s.size, named and addon.Style.Weighted(path, "semibold") or path, g.px)
            if place.bar == "border" then self:PlaceOnBorder(f, g, text, s, dx, near, sign)
            else
                PlaceInBar(f, g, place, text, s, dx, near, sign)
                -- Names stop at 60% of the bar, so a long one never runs over the other side.
                text:SetWidth(self.contentKind[s.content] == "name" and s.content ~= "level" and fdb.barWidth * 0.6 or 0)
            end
            text:SetJustifyH(justify)
            -- A unit color that doesn't suit this text (Level Difficulty on a name) shows the default.
            local mode = self.TextColorModeFits(s.content, s.colorMode) and s.colorMode or "default"
            if mode == "custom" then text:SetTextColor(s.color[1], s.color[2], s.color[3], 1)
            elseif s.content == "level" then text:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1) end
            local kind = f.textKinds[self.contentKind[s.content]]
            local entry = { text = text, content = s.content, mode = mode, custom = mode ~= "default" }
            kind[#kind + 1] = entry
            if mode ~= "default" and mode ~= "custom" then f.textUnitColored[#f.textUnitColored + 1] = entry end
        else
            Write(text, "")
        end
        text:SetShown(shown)
        LayoutLift(text, fdb, s.size, path, g.px, shown, justify)
    end
end

-- Names and levels. `name` and `level` may be secret.
function M:WriteNames(f, unit, name, level, identity)
    local color
    local gradient = self:FrameDB(unit).nameColorMode == "gradient"
    for _, entry in ipairs(f.textKinds.name) do
        local text, content = entry.text, entry.content
        if not entry.custom and content ~= "level" then
            color = color or self:NameColor(unit, identity)
            text:SetTextColor(color[1], color[2], color[3], 1)
        end
        -- Gradient names run from the color toward white, letter by letter
        -- (Style.GradientText); a secret name keeps the plain color.
        local styled = gradient and not entry.custom and content == "name" and addon.Style.GradientText(name, color)
        if styled then
            local white = addon.Style.Tone.mono.white
            text:SetTextColor(white[1], white[2], white[3], 1); Write(text, styled)
            -- The lift is a black copy: color codes would show through it.
            if text.lift then text.lift:SetText(name) end
        elseif content == "name" then Write(text, name)
        elseif content == "level" then Write(text, level)
        elseif level == "" then Write(text, name)
        else Kit.Formatted(text, entry.custom and "%s %s" or LEVEL_NAME, level, name) end
    end
end

-- A unit color for a text: Reaction, Class Color or Level Difficulty, else
-- nil (unknown). Stand-ins show the Player friendly (its class) and the other
-- frames as an enemy at level 60.
local P = M.palette
function M:UnitTextColor(f, unit, mode)
    local fdb = self:FrameDB(unit)
    if f.ghost then
        if mode == "difficulty" then return Level.DifficultyColor(60) or P.hostile end
        if mode == "class" then return self:SampleIdentity(unit, fdb) end
        return self:Soften(unit == "player" and P.green or P.hostile, fdb)
    end
    if mode == "reaction" then return self:IdentityColor(unit, true, fdb) end
    if mode == "class" then return self:IdentityColor(unit, false, fdb) end
    if mode == "difficulty" then
        local level = Level.Number(unit)
        if level == -1 then return P.hostile end -- a skull: far above you
        return Level.DifficultyColor(level)
    end
end
-- Paints the texts colored by the unit; an unknown color shows the default.
function M:PaintUnitColoredTexts(f, unit)
    for _, entry in ipairs(f.textUnitColored or {}) do
        local color = self:UnitTextColor(f, unit, entry.mode)
        if not color then
            local fdb = self:FrameDB(unit)
            color = entry.content == "level" and MUTED or self.contentKind[entry.content] == "name" and self:NameColor(unit)
                or fdb.textColor
        end
        entry.text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

function M:UpdateNameTexts(f, unit)
    self:PaintUnitColoredTexts(f, unit)
    if #f.textKinds.name == 0 then return end
    self:WriteNames(f, unit, Name.Get(unit), Level.Text(unit))
end

-- Health texts; okValue/value from Health.Read (value may be secret).
function M:UpdateHealthTexts(f, unit, okValue, value)
    local list = f.textKinds.health
    if #list == 0 then return end
    -- Objects (pickups, interactables) have no health to show.
    local object = Health.IsObject(unit)
    local state = not object and Health.State(unit)
    for _, entry in ipairs(list) do
        local text = entry.text
        if object then Write(text, "")
        elseif state then Write(text, state)
        elseif entry.content == "healthDeficit" then
            local ok, deficit = Health.Deficit(unit)
            Write(text, ok and deficit or "")
        else Kit.ValueText(text, VALUE_MODE[entry.content], Health.Percent, unit, okValue, value) end
    end
end

function M:UpdatePowerTexts(f, unit, powerType, okValue, value)
    for _, entry in ipairs(f.textKinds.power) do
        Kit.ValueText(entry.text, VALUE_MODE[entry.content], function(u, curve) return Power.Percent(u, powerType, curve) end,
            unit, okValue, value)
    end
end

-- Stand-ins: level 60 and fixed sample numbers. The settings sample names its
-- frame; an Edit Mode stand-in, whose handle already does, shows a name the
-- way the frame would: your own on the Player, "Name" on the others.
local SAMPLE = { healthPercent = "75%", healthCurrent = "3,450", healthBoth = "3,450 · 75%", healthDeficit = "-1150",
    powerPercent = "60%", powerCurrent = "1,200", powerBoth = "1,200 · 60%" }
function M:PaintTextSample(g, unit, identity)
    local L = addon.L
    local name = g.sample and L[self.titles[unit]] or unit == "player" and Name.Get("player") or L["Name"]
    self:WriteNames(g, unit, name, "60", identity)
    self:PaintUnitColoredTexts(g, unit)
    for _, kind in ipairs({ "health", "power" }) do
        for _, entry in ipairs(g.textKinds[kind]) do Write(entry.text, SAMPLE[entry.content]) end
    end
end
