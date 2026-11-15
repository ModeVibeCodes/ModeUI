local addonName, ns = ...
-- The probe kit, bundled into every ModeUI probe addon by tools/build_probes.ps1.
-- A probe is a preview of a planned redesign: plain (insecure) frames drawn
-- with ModeUI's own design system through the ModeUI-Core API, never touching
-- ModeUI's modules, Blizzard's frames or any saved settings. `/mprobe` lists
-- every probe that is loaded; `/mprobe <id>` opens or closes one.
local Core = LibStub and LibStub("ModeUI-Core", true)
local Kit = {}
ns.Kit = Kit
if not Core then
    -- ModeUI from before the ModeUI-Core API: say so once, build nothing.
    local warn = CreateFrame("Frame")
    warn:RegisterEvent("PLAYER_LOGIN")
    warn:SetScript("OnEvent", function()
        print("|cffefe6d2" .. addonName .. "|r needs the current ModeUI (with the ModeUI-Core API). Update ModeUI, then reload.")
    end)
    return
end
local S = Core.Style
local T = S.Tone
Kit.Core, Kit.S, Kit.T, Kit.D = Core, S, T, Core.Domain
Kit.IsNumber, Kit.IsPublic = Core.IsNumber, Core.IsPublic
Kit.ok = true

-- A font string in Geist with the Mode shadow.
function Kit.Text(parent, size, weight, color, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    S.Font(text, size or 11, weight or "medium")
    S.Shadow(text)
    color = color or T.graphite.text
    text:SetTextColor(color[1], color[2], color[3])
    return text
end

-- A texture covering `frame`, from a Mode asset, painted with a token.
function Kit.Fill(frame, key, color, layer, sublevel, alpha)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    texture:SetAllPoints()
    S.ApplyAsset(texture, key or "Solid")
    S.Paint(texture, color or T.mono.base, alpha)
    return texture
end

-- A tiled Mode texture (Panel, Title) that keeps its 1:1 tiling as `frame` resizes.
function Kit.Tiled(frame, key, color, layer, sublevel)
    local texture = Kit.Fill(frame, key, color, layer, sublevel)
    local function Tile(w, h) if w and h and w > 0 and h > 0 then S.TileCoords(texture, key, w, h, S.Pixel(frame)) end end
    frame:HookScript("OnSizeChanged", function(_, w, h) Tile(w, h) end)
    Tile(frame:GetWidth(), frame:GetHeight())
    return texture
end

-- A Mode control button: Graphite face in the `control` border, the accent on
-- the outer line while hovered. kind: nil, "primary" (Ivory) or "danger" (Rosewood Deep).
function Kit.Button(parent, label, width, height, kind, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 72, height or 22)
    local face = kind == "primary" and T.ivory or kind == "danger" and T.rosewoodDeep or T.graphite.raised
    button.face = Kit.Fill(button, "Button", face)
    button.edge = S.Edge(button, "control")
    local ink = kind == "primary" and T.graphite.base or kind == "danger" and T.mono.white or T.graphite.text
    button.label = Kit.Text(button, 11, kind and "bold" or "semibold", ink)
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    if kind == "primary" then button.label:SetShadowOffset(0, 0) end
    button:SetScript("OnEnter", function(self) self.edge:SetHighlight("accent") end)
    button:SetScript("OnLeave", function(self) self.edge:SetHighlight(nil) end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

-- Segmented choices: a row of buttons, the chosen one lit (Ivory label and
-- outer line). options: { { id, label } }; get() returns the chosen id; set(id).
function Kit.Choice(parent, options, get, set, width)
    local row = { buttons = {} }
    local function Refresh()
        local chosen = get()
        for _, button in ipairs(row.buttons) do
            local on = button.id == chosen
            local c = on and T.ivory or T.graphite.text
            button.label:SetTextColor(c[1], c[2], c[3])
            button.edge:SetHighlight(on and "accent" or nil)
            button.on = on
        end
    end
    for i, option in ipairs(options) do
        local button = Kit.Button(parent, option.label, width or 84, 20, nil, function() set(option.id); Refresh() end)
        button.id = option.id
        button:SetScript("OnLeave", function(self) if not self.on then self.edge:SetHighlight(nil) end end)
        if i > 1 then button:SetPoint("LEFT", row.buttons[i - 1], "RIGHT", 6, 0) end
        row.buttons[i] = button
    end
    row.first = row.buttons[1]
    row.Refresh = Refresh
    Refresh()
    return row
end

-- A class color as { r, g, b } (Class Colors' custom colors included).
function Kit.ClassColor(class)
    local c = Kit.D.UnitColor.Class(class)
    return c and { c.r, c.g, c.b } or T.reaction.friendly
end

-- An icon (aura, button, cooldown): the art cropped to its shape (wider than
-- tall), a cooldown swipe and a count. preset: a Style.Edge preset, or nil for
-- an icon flush in a frame's corner (the frame's rim is its outer border).
-- Fill it from an aura with Domain.Auras.Apply, or set icon.icon yourself.
function Kit.Icon(parent, width, preset, opts)
    local height = S.IconHeight(width)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(width, height)
    icon.back = Kit.Fill(icon, "Solid", T.mono.void, "BACKGROUND", -1)
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetAllPoints()
    S.CropIcon(icon.icon, width, height)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.icon)
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
    if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(not (opts and opts.numbers)) end
    icon.cooldown:Hide()
    icon.textLayer = CreateFrame("Frame", nil, icon)
    icon.textLayer:SetAllPoints()
    icon.textLayer:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    icon.count = Kit.Text(icon.textLayer, math.max(9, math.floor(width / 3.2)), "bold", T.textBright)
    icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
    if preset then icon.edge = S.Edge(icon, preset, opts and opts.color and { color = opts.color } or nil) end
    return icon
end

-- A caption over a sample: 10px Medium, muted.
function Kit.Caption(parent, text, anchor, x, y)
    local caption = Kit.Text(parent, 10, "medium", T.graphite.muted)
    caption:SetPoint("TOPLEFT", anchor or parent, anchor and "BOTTOMLEFT" or "TOPLEFT", x or 0, y or -6)
    caption:SetText(text)
    return caption
end

-- A section title: 11px uppercase Ivory, like a settings card title.
function Kit.Heading(parent, text, x, y)
    local heading = Kit.Text(parent, 11, "bold", T.ivory)
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    heading:SetText(text:upper())
    return heading
end

-- The color the client's health curve gives at `p` (0-1): Rosewood to 30%,
-- through Ivory at 65%, to Celadon at full. For sample frames, whose health
-- is a plain number; live frames use Style.PaintHealthText.
function Kit.HealthTextColor(p)
    if p <= 0.3 then return T.rosewood end
    if p <= 0.65 then return S.Mix(T.ivory, T.rosewood, (p - 0.3) / 0.35) end
    return S.Mix(T.celadon, T.ivory, (p - 0.65) / 0.35)
end

-- Calls fn(seconds since the last call) every `interval` seconds while
-- `frame` is shown.
function Kit.Every(frame, interval, fn)
    local waited = interval
    frame:HookScript("OnUpdate", function(_, elapsed)
        waited = waited + (elapsed or 0)
        if waited < interval then return end
        local since = waited
        waited = 0
        fn(since)
    end)
end

-- A Mode window: Graphite panel with Mode Panel, a Mode Title bar, the `window`
-- border, a close button, and a tab strip. tabs: { { id, label, build(body) } };
-- each tab's body is built the first time it is chosen.
function Kit.Window(id, title, width, height, tabs)
    local frame = CreateFrame("Frame", "ModeUIProbe" .. id, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Kit.Tiled(frame, "Panel", T.graphite.panel, "BACKGROUND", -7)
    frame.edge = S.Edge(frame, "window")
    if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetHeight(28)
    Kit.Tiled(bar, "Title", T.graphite.raised, "BACKGROUND", -6)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local line = bar:CreateTexture(nil, "BORDER")
    S.ApplyAsset(line, "Solid"); S.Paint(line, T.graphite.line)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    local name = Kit.Text(bar, 12, "bold", T.ivory)
    name:SetPoint("LEFT", 12, 0)
    name:SetText("MODE PROBE  ·  " .. title:upper())
    local close = Kit.Button(bar, "Close", 56, 18, nil, function() frame:Hide() end)
    close:SetPoint("RIGHT", -8, 0)
    frame.titleBar = bar
    -- Tabs: Ivory text and a 2px Ivory line under the chosen one.
    frame.pages, frame.tabs = {}, {}
    local x = 12
    for _, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, frame)
        button.label = Kit.Text(button, 12, "semibold", T.graphite.muted)
        button.label:SetPoint("CENTER")
        button.label:SetText(tab.label)
        local w = math.max(64, math.floor((button.label:GetStringWidth() or 60) + 24))
        button:SetSize(w, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -32)
        x = x + w + 4
        button.mark = button:CreateTexture(nil, "ARTWORK")
        S.ApplyAsset(button.mark, "Solid"); S.Paint(button.mark, T.ivory)
        button.mark:SetPoint("BOTTOMLEFT", 8, 0); button.mark:SetPoint("BOTTOMRIGHT", -8, 0); button.mark:SetHeight(2)
        button:SetScript("OnClick", function() frame:Select(tab.id) end)
        frame.tabs[tab.id] = { button = button, def = tab }
    end
    frame.order = tabs
    function frame:Select(tabID)
        local chosen = self.tabs[tabID] and tabID or self.order[1].id
        for tid, entry in pairs(self.tabs) do
            local on = tid == chosen
            local c = on and T.ivory or T.graphite.muted
            entry.button.label:SetTextColor(c[1], c[2], c[3])
            entry.button.mark:SetShown(on)
            if on and not self.pages[tid] then
                local body = CreateFrame("Frame", nil, self)
                body:SetPoint("TOPLEFT", 12, -66)
                body:SetPoint("BOTTOMRIGHT", -12, 12)
                entry.def.build(body)
                self.pages[tid] = body
            end
            if self.pages[tid] then self.pages[tid]:SetShown(on) end
        end
        self.current = chosen
    end
    frame:Select(tabs[1].id)
    return frame
end

-- Registers a probe for /mprobe. open(tab) shows it (on `tab` if given),
-- returning its window.
ModeUIProbes = ModeUIProbes or { list = {}, order = {} }
local registry = ModeUIProbes
function Kit.Register(id, title, window)
    if not registry.list[id] then registry.order[#registry.order + 1] = id end
    registry.list[id] = { title = title, window = window }
end

if not SlashCmdList.MODEUIPROBE then
    SLASH_MODEUIPROBE1 = "/mprobe"
    SlashCmdList.MODEUIPROBE = function(text)
        local id, tab = (text or ""):lower():match("^%s*(%S*)%s*(%S*)")
        local entry = registry.list[id or ""]
        if not entry then
            print("|cffefe6d2ModeUI probes|r: /mprobe <name> [tab]")
            for _, key in ipairs(registry.order) do print("  " .. key .. "  -  " .. registry.list[key].title) end
            return
        end
        local window = entry.window()
        if tab ~= "" then window:Select(tab); window:Show(); return end
        window:SetShown(not window:IsShown())
    end
end
