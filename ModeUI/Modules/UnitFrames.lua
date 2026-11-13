local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface suite: secure Player and Target frames in the locked Onyx skin
-- (round portrait capping a rounded bar block inside a slate rim).
-- Forever runs the mainline client, so unit values can be secret. They are only
-- handed to widgets/formatters Blizzard documents as accepting secret values;
-- never compared, tested or used in arithmetic here. See docs/UNIT_FRAMES.md.
local M = { title = "Unit Frames", category = "interface", defaultEnabled = true,
    configDescription = "Player and Target frames in the Onyx look. Configure outside combat." }
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)

M.units = { "player", "target" }
M.labels = { player = "Player", target = "Target" }
M.elementIds = { player = "unitFramesPlayer", target = "unitFramesTarget" }
M.defaultPositions = {
    player = { target = "screen", placement = "center", x = -280, y = -200 },
    target = { target = "screen", placement = "center", x = 280, y = -200 },
}
M.LAYOUT_VERSION = 11

local function RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
-- Mode text plus Mode-toned gameplay colors.
M.palette = {
    text = RGB(212, 212, 212), accent = RGB(0, 240, 255), green = RGB(127, 219, 151), hostile = RGB(224, 102, 102),
    neutral = RGB(232, 176, 75), tapped = RGB(140, 140, 140), mana = RGB(64, 150, 255), muted = RGB(185, 185, 185),
}
-- The Onyx skin, locked for every frame: default health fill, empty bar, the
-- 2px slate rim and the 2px black gap inside it (owner, layout version 9).
M.onyx = { health = RGB(28, 30, 33), track = RGB(10, 11, 12), border = RGB(106, 115, 125), inner = RGB(0, 0, 0) }
-- Plain-text name colors that contrast the cool Onyx/slate skin (owner's
-- picks). Sky, the owner's own color (layout version 11), is the default.
M.nameAccents = { sky = RGB(145, 198, 255), champagne = RGB(242, 223, 184), lilac = RGB(201, 187, 255),
    frost = RGB(234, 241, 248) }
M.ACCENT = M.nameAccents.sky

M.choices = {
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "both", label = "Current and Percent" }, { id = "none", label = "None" } },
    powerText = { { id = "none", label = "None" }, { id = "percent", label = "Percent" },
        { id = "current", label = "Current Power" }, { id = "both", label = "Current and Percent" } },
    position = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    side = { { id = "left", label = "Left" }, { id = "right", label = "Right" } },
    portraitStyle = { { id = "portrait", label = "Character Portrait" }, { id = "class", label = "Class Icon" } },
    ring = { { id = "class", label = "Class Gradient" }, { id = "border", label = "Default" }, { id = "custom", label = "Custom" } },
    namePosition = { { id = "above", label = "Above Frame" }, { id = "bar", label = "On Health Bar" } },
    nameColor = { { id = "sky", label = "Sky" }, { id = "champagne", label = "Champagne" }, { id = "lilac", label = "Lilac" },
        { id = "frost", label = "Frost" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    level = { { id = "badge", label = "Shown" }, { id = "none", label = "Hidden" } },
    healthColor = { { id = "default", label = "Default" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    powerColor = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
}
local ALLOWED = {}
for key, list in pairs(M.choices) do
    ALLOWED[key] = {}
    for _, item in ipairs(list) do ALLOWED[key][item.id] = true end
end
-- Setting key -> choice list.
M.choiceKeys = { healthText = "healthText", powerText = "powerText", healthTextPosition = "position",
    powerTextPosition = "position", nameAlign = "position", portraitSide = "side", portraitStyle = "portraitStyle",
    portraitRing = "ring", namePosition = "namePosition", nameColorMode = "nameColor", levelStyle = "level",
    healthColorMode = "healthColor", powerColorMode = "powerColor" }

local function Copy(value) return addon.ProfileCodec.Copy(value) end
M.Public = addon.IsPublic
function M.Number(v, low, high)
    return M.Public(v) and type(v) == "number" and v == v and v >= low and v <= high
end
local Public, Number = M.Public, M.Number

local function Frame(side)
    return { enabled = true, hideBlizzard = true, scale = 100, barWidth = 180, healthHeight = 26,
        -- Target only: mirror the Player frame's look (side and visibility stay its own).
        matchPlayer = side == "right",
        -- Target only, while matched: mirror the Player's text alignment and
        -- horizontal offsets to the other side (off: same layout as the Player).
        mirrorText = false,
        showPower = true, powerHeight = 10,
        showPortrait = true, portraitStyle = "portrait", portraitSide = side,
        portraitScale = 150, -- portrait diameter as a % of the bar block
        portraitRing = "class", portraitRingColor = Copy(M.ACCENT),
        showName = true, namePosition = "above", nameAlign = "RIGHT", nameFontSize = 12,
        nameColorMode = "sky", nameColor = Copy(M.ACCENT), nameOffsetX = 0, nameOffsetY = 0,
        -- Class/reaction colors are blended this far toward white (pastel).
        classSoftness = 40,
        levelStyle = "badge", levelFontSize = 11, levelColor = Copy(M.palette.muted), levelOffsetX = 0, levelOffsetY = 0,
        healthColorMode = "default", healthColor = Copy(M.palette.green),
        healthText = "percent", healthTextPosition = "RIGHT", healthFontSize = 11, healthTextOffsetX = 0, healthTextOffsetY = 0,
        powerColorMode = "type", powerColor = Copy(M.palette.mana),
        powerText = "none", powerTextPosition = "CENTER", powerFontSize = 9, powerTextOffsetX = 0, powerTextOffsetY = 0,
        texture = "satin", font = "game", fontMedia = "Expressway", outline = false, shadow = true,
        -- The suite's text style: every text gets a crisp opaque 1px shadow plus
        -- a lighter second shadow 2px out (owner, layout version 11).
        liftedShadow = true, textColor = Copy(M.palette.text) }
end
M.frameDefaults = { player = Frame("left"), target = Frame("right") }
M.frameRanges = { scale = { 50, 200, 1 }, barWidth = { 100, 400, 1 }, healthHeight = { 10, 60, 1 },
    powerHeight = { 2, 30, 1 }, nameFontSize = { 8, 24, 1 }, healthFontSize = { 8, 24, 1 }, powerFontSize = { 6, 20, 1 },
    portraitScale = { 100, 200, 5 }, classSoftness = { 0, 100, 5 }, levelFontSize = { 6, 24, 1 },
    nameOffsetX = { -100, 100, 1 }, nameOffsetY = { -100, 100, 1 }, levelOffsetX = { -100, 100, 1 }, levelOffsetY = { -100, 100, 1 },
    healthTextOffsetX = { -100, 100, 1 }, healthTextOffsetY = { -100, 100, 1 },
    powerTextOffsetX = { -100, 100, 1 }, powerTextOffsetY = { -100, 100, 1 } }
-- Keys that describe placement/identity rather than style; Copy Style skips them.
M.identityKeys = { enabled = true, hideBlizzard = true, portraitSide = true, matchPlayer = true, mirrorText = true }
M.defaults = { player = Copy(M.frameDefaults.player), target = Copy(M.frameDefaults.target), layoutVersion = M.LAYOUT_VERSION }

local function Fill(target, defaults, label)
    for key, default in pairs(defaults) do
        if target[key] == nil then target[key] = Copy(default) end
        local v = target[key]
        assert(Public(v) and type(v) == type(default), "Invalid unit frame setting: " .. label .. key)
        if type(default) == "table" then
            for i = 1, 3 do assert(Number(v[i], 0, 1), "Invalid unit frame color: " .. label .. key) end
        end
    end
end
local function Ranged(v, r) return Number(v, r[1], r[2]) and v == math.floor(v) end

-- Phase-1 (layout version 1) frames: values a user changed from the phase-1
-- defaults carry into both frames once; everything else adopts the defaults.
local V1_FRAME = { width = 220, height = 36, powerHeight = 8 }
local function MigrateV1(db)
    for _, unit in ipairs(M.units) do
        local old = db[unit]
        if type(old) == "table" then
            local new = Copy(M.frameDefaults[unit])
            for _, key in ipairs({ "enabled", "hideBlizzard", "showPower", "showName", "healthText" }) do
                if type(old[key]) == type(new[key]) then new[key] = old[key] end
            end
            if old.showLevel == false then new.levelStyle = "none" end
            if Number(old.powerHeight, 2, 30) and old.powerHeight ~= V1_FRAME.powerHeight then new.powerHeight = math.floor(old.powerHeight) end
            if Number(old.width, 100, 400) and old.width ~= V1_FRAME.width then new.barWidth = math.floor(old.width) end
            if Number(old.height, 18, 80) and old.height ~= V1_FRAME.height then
                local power = new.showPower and new.powerHeight + 2 or 0
                new.healthHeight = math.max(10, math.min(60, math.floor(old.height - power - 8)))
            end
            if Number(db.scale, 50, 200) and db.scale ~= 100 then new.scale = math.floor(db.scale) end
            if db.classColor == false then new.healthColorMode = "custom" end
            local c = db.healthColor
            if type(c) == "table" and Number(c[1], 0, 1) and Number(c[2], 0, 1) and Number(c[3], 0, 1)
                and not (math.abs(c[1] - 52 / 255) < 1e-6 and math.abs(c[2] - 168 / 255) < 1e-6 and math.abs(c[3] - 83 / 255) < 1e-6) then
                new.healthColor = Copy(c); new.healthColorMode = "custom"
            end
            if Number(db.fontSize, 8, 24) and db.fontSize ~= 12 then
                new.nameFontSize = math.floor(db.fontSize); new.healthFontSize = math.floor(db.fontSize)
            end
            if type(db.fontMedia) == "string" and db.fontMedia ~= "" then new.font, new.fontMedia = db.font, db.fontMedia end
            if type(db.outline) == "boolean" then new.outline = db.outline end
            if type(db.shadow) == "boolean" then new.shadow = db.shadow end
            db[unit] = new
        end
    end
end

-- Layout versions 2-7 only changed keys that are either still used (name
-- alignment, the 22 -> 26 health bar, Expressway, the level's own size) or
-- retired by version 9; each step keeps its effect on the keys that remain.
local function MigrateV2toV7(db, from)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if from <= 5 then
                frame.nameAlign = "RIGHT"
                if frame.healthHeight == 22 then frame.healthHeight = 26 end
            end
            if from <= 6 and frame.fontMedia == "PTG Lato" then frame.fontMedia = "Expressway" end
            if from <= 7 and frame.levelFontSize == nil and Number(frame.healthFontSize, 6, 24) then
                frame.levelFontSize = math.floor(frame.healthFontSize)
            end
        end
    end
end

-- Layout version 8 -> 9, per the owner: one locked Onyx skin. Palettes, border
-- styles, background/border colors and thickness, and the name sheen are
-- retired; health uses Default (#1C1E21), Class Color or Custom; names use the
-- Mist accent; the portrait ring becomes the class gradient unless Custom.
local RETIRED = { "palette", "paletteHealth", "paletteTrack", "paletteBorder", "paletteInner", "rimThickness",
    "gapThickness", "hairlineThickness", "nameSheen", "nameSheenStrength", "borderStyle", "borderColor", "borderOpacity",
    "backgroundColor", "backgroundOpacity", "trimColor", "showFrameEdge", "barBorderColor", "barBorderOpacity", "portraitSize" }
M.retiredKeys = RETIRED
local HEALTH_MODE = { custom = "custom", class = "class", reaction = "class" }
local function MigrateV8(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            frame.healthColorMode = HEALTH_MODE[frame.healthColorMode] or "default"
            frame.nameColorMode = "accent"
            if frame.portraitRing ~= "custom" then frame.portraitRing = "class" end
            if frame.namePosition ~= "bar" then frame.namePosition = "above" end
            if frame.levelStyle ~= "none" then frame.levelStyle = "badge" end
            for _, key in ipairs(RETIRED) do frame[key] = nil end
        end
    end
end

-- Layout version 9 -> 10, per the owner: the Mist accent and its glow are
-- replaced by Champagne/Lilac/Frost names with a crisp lifted shadow.
local RETIRED_V10 = { "nameGlow", "nameGlowStrength" }
for _, key in ipairs(RETIRED_V10) do RETIRED[#RETIRED + 1] = key end
local function MigrateV9(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if frame.nameColorMode ~= "class" and frame.nameColorMode ~= "custom" then frame.nameColorMode = "champagne" end
            for _, key in ipairs(RETIRED_V10) do frame[key] = nil end
        end
    end
end

-- Layout version 10 -> 11, per the owner: Sky (#91C6FF) names to try, the
-- lifted shadow on every text instead of just the name, and a matched Target
-- that copies the Player's text layout rather than mirroring it.
local PRESET_NAME = { champagne = true, lilac = true, frost = true }
RETIRED[#RETIRED + 1] = "nameLift"
local function MigrateV10(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if PRESET_NAME[frame.nameColorMode] then frame.nameColorMode = "sky" end
            if type(frame.nameLift) == "boolean" then frame.liftedShadow = frame.nameLift end
            frame.nameLift = nil
        end
    end
end

-- Pure defaults, one-time migration and validation; profile validation runs
-- this on detached copies. Retired phase-1 top-level keys are left in place.
function M.Initialize(db)
    if db.layoutVersion == nil and type(db.player) == "table" and db.player.width ~= nil then MigrateV1(db)
    else
        local from = db.layoutVersion
        if Number(from, 2, 7) then MigrateV2toV7(db, from); db.layoutVersion = 8 end
        if db.layoutVersion == 8 then MigrateV8(db); db.layoutVersion = 9 end
        if db.layoutVersion == 9 then MigrateV9(db); db.layoutVersion = 10 end
        if db.layoutVersion == 10 then MigrateV10(db); db.layoutVersion = M.LAYOUT_VERSION end
    end
    db.layoutVersion = db.layoutVersion or M.LAYOUT_VERSION
    assert(db.layoutVersion == M.LAYOUT_VERSION, "Invalid unit frame layout version")
    for _, unit in ipairs(M.units) do
        if db[unit] == nil then db[unit] = Copy(M.frameDefaults[unit]) end
        local frame = db[unit]
        assert(Public(frame) and type(frame) == "table", "Invalid unit frame settings: " .. unit)
        Fill(frame, M.frameDefaults[unit], unit .. ".")
        for key, r in pairs(M.frameRanges) do assert(Ranged(frame[key], r), "Invalid unit frame range: " .. unit .. "." .. key) end
        for key, list in pairs(M.choiceKeys) do assert(ALLOWED[list][frame[key]], "Invalid unit frame choice: " .. unit .. "." .. key) end
        local texture = frame.texture
        assert(texture == "satin" or texture == "mode" or texture == "default" or texture == "flat" or texture:sub(1, 6) == "media:",
            "Invalid unit frame texture: " .. unit)
    end
end

function M:CanConfigure() return not InCombatLockdown() and not UnitAffectingCombat("player") end
function M:GetFonts() return addon.Media:GetFonts() end
function M:GetTextureChoices()
    local choices = { { id = "satin", label = "Satin" }, { id = "mode", label = "Mode" }, { id = "flat", label = "Flat" },
        { id = "default", label = "Use Global Setting" } }
    for _, item in ipairs(addon.Media:GetStatusBars()) do
        if item.key ~= "default" then choices[#choices + 1] = { id = item.key, label = item.label } end
    end
    return choices
end

-- Values are written in place so config widgets keep their table references.
local function Commit(self, unit, frame)
    local copy = Copy(self.db); copy[unit] = frame
    if not pcall(self.Initialize, copy) then return false end
    local target = self.db[unit]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(copy[unit]) do target[key] = value end
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end
function M:SetFrameOption(unit, key, value)
    if not self:CanConfigure() or not self.labels[unit] or self.frameDefaults[unit][key] == nil then return false end
    local frame = Copy(self.db[unit]); frame[key] = Copy(value)
    return Commit(self, unit, frame)
end
function M:ResetFrame(unit)
    if not self:CanConfigure() or not self.labels[unit] then return false end
    local frame = Copy(self.frameDefaults[unit])
    for key in pairs(self.identityKeys) do frame[key] = self.db[unit][key] end
    return Commit(self, unit, frame)
end
function M:CopyStyle(from, to)
    if not self:CanConfigure() or not self.labels[from] or not self.labels[to] or from == to then return false end
    local frame = Copy(self.db[from])
    for key in pairs(self.identityKeys) do frame[key] = self.db[to][key] end
    return Commit(self, to, frame)
end
-- Per-frame appearance owner for the shared font/color widgets. `unit` may be
-- a function so one settings page can switch which frame it edits.
function M:AppearanceOwner(unit)
    local function Unit() return type(unit) == "function" and unit() or unit end
    local appearance = setmetatable({}, { __index = function(_, key) return M.db[Unit()][key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return M:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetFrameOption(Unit(), key, value) end
    return owner
end

function M:OnInitialize()
    self.Initialize(self.db)
    self.frames, self.ghosts, self.watched = {}, {}, {}
    self.nativeHidden, self.nativeAlpha, self.nativeHooks = {}, {}, {}
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, unit) self:OnEvent(event, unit) end)
    self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() self:OnClassColorsChanged() end)
end
function M:OnEnable()
    self.active = true
    self:Refresh()
end
function M:OnDisable()
    self.active = false
    self:Refresh()
end
function M:SetEditMode(enabled) self.editing = enabled and self.active or false; self:RenderGhosts() end
function M:SetPreviewMode(enabled) self.previewing = enabled and self.active or false; self:RenderGhosts() end
-- Global > Class Colors changed: recolor names, health and portrait rings now.
function M:OnClassColorsChanged()
    if not self.frames then return end
    self:UpdateAll()
    -- Preview stand-ins are re-laid out only outside combat, as everywhere else.
    if not InCombatLockdown() then self:RenderGhosts() end
end

function M:FrameOn(unit) return self.active == true and self.db[unit].enabled == true end

-- Settings a frame renders with. A Target set to Match Player Frame reads the
-- Player's look and text layout, keeping its own identity keys (side,
-- visibility, the toggles); one cached proxy, so per-event updates allocate
-- nothing. With Mirror Player Text on and the portrait on the other side, text
-- alignment and horizontal offsets mirror, and `mirrored` tells the layout to
-- read the grouped level/health text in mirror order.
local FLIP = { LEFT = "RIGHT", RIGHT = "LEFT" }
M.mirrorAlign = { nameAlign = true, healthTextPosition = true, powerTextPosition = true }
M.mirrorOffset = { nameOffsetX = true, levelOffsetX = true, healthTextOffsetX = true, powerTextOffsetX = true }
function M:FrameDB(unit)
    local fdb = self.db[unit]
    if unit ~= "target" or not fdb.matchPlayer then return fdb end
    if not self.matchedTarget then
        local identity, align, offset = self.identityKeys, self.mirrorAlign, self.mirrorOffset
        self.matchedTarget = setmetatable({}, { __index = function(_, key)
            local target, player = self.db.target, self.db.player
            if identity[key] then return target[key] end
            local mirror = target.mirrorText == true and target.portraitSide ~= player.portraitSide
            if key == "mirrored" then return mirror end
            local value = player[key]
            if mirror then
                if align[key] then return FLIP[value] or value end
                if offset[key] then return -value end
            end
            return value
        end })
    end
    return self.matchedTarget
end

-- Native frames keep running so pets, class resources, target auras and cast
-- bars still work; only their main art/bars are faded and their clicks released.
local NATIVE = {
    player = { frame = "PlayerFrame", parts = { "PlayerFrameContainer", "PlayerFrameContent" } },
    target = { frame = "TargetFrame", parts = { "TargetFrameContainer", "TargetFrameContent" } },
}
function M:SetNativeHidden(unit, hidden)
    local spec = NATIVE[unit]
    local native = _G[spec.frame]
    if type(native) ~= "table" or (not hidden and not self.nativeHidden[unit]) then return end
    self.nativeHidden[unit] = hidden or nil
    for _, key in ipairs(spec.parts) do
        local part = native[key]
        if type(part) == "table" and part.SetAlpha and part.GetAlpha then
            if hidden then
                local alpha = part:GetAlpha()
                if self.nativeAlpha[part] == nil then self.nativeAlpha[part] = Number(alpha, 0, 1) and alpha or 1 end
                if not self.nativeHooks[part] and hooksecurefunc then
                    self.nativeHooks[part] = true
                    -- Blizzard may restore alpha later; keep the part faded while hidden.
                    hooksecurefunc(part, "SetAlpha", function(region)
                        if self.nativeHidden[unit] and not self.fading then
                            self.fading = true; region:SetAlpha(0); self.fading = false
                        end
                    end)
                end
                self.fading = true; part:SetAlpha(0); self.fading = false
            else
                part:SetAlpha(self.nativeAlpha[part] or 1); self.nativeAlpha[part] = nil
            end
        end
    end
    if native.EnableMouse then native:EnableMouse(not hidden) end
end

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" }
function M:SetEvents(on)
    if (self.eventsOn or false) == on then return end
    self.eventsOn = on
    local f = self.events
    for _, event in ipairs(UNIT_EVENTS) do
        if on then f:RegisterUnitEvent(event, "player", "target") else f:UnregisterEvent(event) end
    end
    -- Scale/resolution changes re-snap the pixel-perfect borders (registered by
    -- Blizzard's own Forever UI in SharedUIPanelTemplates.lua).
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PORTRAITS_UPDATED",
        "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        if on then f:RegisterEvent(event) else f:UnregisterEvent(event) end
    end
end

-- Secure frames can only be shown, hidden, moved or resized outside combat;
-- requests made in combat are kept and applied when combat ends.
function M:Refresh()
    if not self.frames then return end
    if InCombatLockdown() then self.pending = true; self:UpdateAll(); return end
    self.pending = false
    -- Secure buttons are created on first enable, never in combat.
    if self.active then self:CreateDisplay() end
    local any = false
    for _, unit in ipairs(self.units) do
        local on = self:FrameOn(unit)
        any = any or on
        local f = self.frames[unit]
        if self.ghosts[unit] then self:ApplyLayout(self.ghosts[unit], unit) end
        if f then
            self:ApplyLayout(f, unit)
            self:SyncPosition(unit)
            if on and not self.watched[unit] then RegisterUnitWatch(f); self.watched[unit] = true
            elseif not on and self.watched[unit] then UnregisterUnitWatch(f); self.watched[unit] = nil; f:Hide() end
        end
        self:SetNativeHidden(unit, on and self.db[unit].hideBlizzard)
    end
    self:SetEvents(any)
    self:RenderGhosts()
    self:UpdateAll()
    if addon.EditMode then addon.EditMode:RefreshElements() end
end

function M:OnEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pending then self:Refresh() end
    elseif event == "PLAYER_TARGET_CHANGED" then self:Update("target")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PORTRAITS_UPDATED" then self:UpdateAll()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then self:Refresh()
    elseif unit == "player" or unit == "target" then
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then self:UpdateHealth(unit)
        elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then self:UpdatePower(unit)
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then self:UpdatePortrait(unit)
        else self:Update(unit) end
    end
end

function M:Status()
    if not self.active then return "Disabled. Blizzard's frames are restored outside combat." end
    if self.pending then return "Changes are waiting until you leave combat." end
    return "Active. Use Edit Mode to move the frames; left-click targets, right-click opens the unit menu."
end
