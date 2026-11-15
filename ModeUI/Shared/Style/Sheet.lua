local _, addon = ...
-- /modeui style: a sheet that draws every Mode preset in game, for checking the
-- design system against docs/DESIGN_LANGUAGE.md. Built the first time it opens.
local Style = addon.Style
local Tone = Style.Tone

local sheet

local function Label(parent, text, x, y, size, weight, color)
    local label = parent:CreateFontString(nil, "OVERLAY")
    Style.Font(label, size or 11, weight or "medium")
    Style.Shadow(label)
    color = color or Tone.graphite.secondary
    label:SetTextColor(color[1], color[2], color[3])
    label:SetText(text)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return label
end

-- A box with a preset border and a Graphite fill.
local function Box(parent, preset, x, y, w, h, opts)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetSize(w, h)
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    Style.ApplyAsset(fill, "Solid")
    Style.Paint(fill, Tone.mono.raised)
    box.edge = Style.Edge(box, preset, opts)
    return box
end

local function BarIn(parent, x, y, w, h, preset, texture, color, value, opts)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:SetSize(w, h)
    local bar = Style.Bar(holder, { texture = texture, spark = opts and opts.spark })
    bar:SetAllPoints()
    bar:SetFill(color)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(value)
    if preset then holder.edge = Style.Edge(holder, preset) end
    return bar, holder
end

local function Build()
    local frame = CreateFrame("Frame", "ModeUIStyleSheet", UIParent)
    frame:SetSize(980, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    Style.ApplyAsset(bg, "Panel")
    Style.Paint(bg, Tone.graphite.panel)
    frame:SetScript("OnSizeChanged", function(self, w, h) Style.TileCoords(bg, "Panel", w, h, Style.Pixel(self)) end)
    Style.TileCoords(bg, "Panel", 980, 600, Style.Pixel(frame))
    frame.edge = Style.Edge(frame, "window")
    if UISpecialFrames then table.insert(UISpecialFrames, "ModeUIStyleSheet") end

    local title = Label(frame, "MODE  ·  STYLE SHEET", 16, -14, 13, "bold", Tone.ivory)
    title:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(60, 20)
    close:SetPoint("TOPRIGHT", -12, -10)
    local closeText = close:CreateFontString(nil, "OVERLAY")
    Style.Font(closeText, 11, "semibold")
    closeText:SetPoint("RIGHT")
    closeText:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Borders.
    Label(frame, "Borders", 16, -44, 12, "semibold", Tone.graphite.text)
    local presets = { "frame", "frameThin", "group", "window", "control", "line", "empty" }
    for i, preset in ipairs(presets) do
        local x = 16 + (i - 1) * 132
        local box = Box(frame, preset, x + 4, -72, 116, 34, preset == "line" and { color = Tone.dispel.Magic } or preset == "empty" and { color = Tone.celadon } or nil)
        Label(frame, preset, x + 4, -112, 10)
        if preset == "frame" then box.edge:SetHighlight(nil) end
    end
    local target = Box(frame, "frame", 20, -136, 116, 34)
    target.edge:SetHighlight("accent")
    Label(frame, "frame + accent", 20, -176, 10)
    local focus = Box(frame, "frameThin", 152, -136, 116, 34)
    focus.edge:SetHighlight("specialty")
    Label(frame, "frameThin + specialty", 152, -176, 10)
    local ring = Style.Ring(frame, 66)
    ring.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 300, -124)
    addon.Domain.Portrait.Apply(ring.portrait, "player", "portrait")
    Label(frame, "ring 66", 312, -200, 10)
    local icon = Box(frame, "frameThin", 400, -136, 40, Style.IconHeight(40))
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexture([[Interface\Icons\Spell_Fire_FireBolt02]])
    Style.CropIcon(iconTexture, 40, Style.IconHeight(40))
    Label(frame, "icon 40 x " .. Style.IconHeight(40), 396, -180, 10)

    -- Bars and shields.
    Label(frame, "Bars", 16, -216, 12, "semibold", Tone.graphite.text)
    local states = { { 60, 20, 20, "Fits" }, { 85, 15, 30, "Stops at end" }, { 100, 0, 25, "Full health" } }
    for i, state in ipairs(states) do
        local bar = BarIn(frame, 20, -244 - (i - 1) * 46, 184, 34, "frame", "Matte", Tone.darkFill, state[1])
        local shield = Style.Shield(bar)
        shield:Update(nil, { max = 100, shield = state[2], total = state[3] })
        if state[1] >= 100 then shield.full:SetAlpha(1) end
        Label(frame, state[4], 214, -254 - (i - 1) * 46, 10)
    end
    local class = BarIn(frame, 330, -244, 184, 34, "frame", "Gradient", Tone.reaction.friendly, 64)
    Style.Shield(class):Update(nil, { max = 100, shield = 18, total = 18 })
    Label(frame, "class color, Gradient", 524, -254, 10)
    BarIn(frame, 330, -290, 132, 11, "frameThin", "BG", Tone.reaction.hostile, 58)
    Label(frame, "nameplate, BG", 472, -290, 10)
    BarIn(frame, 330, -320, 250, 18, "frame", "Cast", Tone.cast.casting, 72, { spark = true })
    Label(frame, "cast, Comet spark", 590, -322, 10)
    BarIn(frame, 330, -350, 184, 3, "frameThin", "Gradient", Tone.power, 70)
    Label(frame, "power 3px", 524, -348, 10)

    -- Bar textures.
    Label(frame, "Mode textures", 16, -392, 12, "semibold", Tone.graphite.text)
    for i, key in ipairs(Style.BAR_TEXTURES) do
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        local x, y = 20 + col * 186, -420 - row * 42
        BarIn(frame, x, y, 150, 18, "frameThin", key, Tone.reaction.hostile, 70)
        Label(frame, "Mode " .. key, x, y - 22, 10)
    end

    -- Type.
    local name = frame:CreateFontString(nil, "OVERLAY")
    Style.Font(name, 14, "semibold")
    Style.Shadow(name)
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 640, -136)
    local c = addon.Domain.UnitColor.PlayerClass("player")
    local classColor = c and { c.r, c.g, c.b } or Tone.reaction.friendly
    Style.SetName(name, addon.Domain.Name.Get("player"), classColor, "gradient")
    Label(frame, "Geist Regular 0123456789", 640, -160, 12, "regular", Tone.graphite.text)
    Label(frame, "Geist Medium 0123456789", 640, -178, 12, "medium", Tone.graphite.text)
    Label(frame, "Geist SemiBold 0123456789", 640, -196, 12, "semibold", Tone.graphite.text)
    Label(frame, "Geist Bold 0123456789", 640, -214, 12, "bold", Tone.graphite.text)
    return frame
end

function Style.ToggleSheet()
    if addon.InCombat and addon.InCombat() then return end
    if not sheet then
        sheet = Build()
        sheet:Show()
        return
    end
    sheet:SetShown(not sheet:IsShown())
end
