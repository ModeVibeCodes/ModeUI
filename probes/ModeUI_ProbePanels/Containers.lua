local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Minimap probe (Phase 7; the Windows, Chat, Damage Meters, Tooltip and Bags
-- tabs retired once ModeUI's modules were built and confirmed): the frame
-- around the game's map (200 x 184, the map itself stays the game's).
local S, T, D = Kit.S, Kit.T, Kit.D

function ns.BuildMinimap(body)
    local map = CreateFrame("Frame", nil, body)
    map:SetSize(200, 184)
    map:SetPoint("TOPLEFT", 10, -10)
    Kit.Fill(map, "Matte", T.mono.track)
    S.Edge(map, "frame")
    local hint = Kit.Text(map, 10, "medium", T.graphite.muted)
    hint:SetPoint("CENTER", 0, 14)
    hint:SetText("the game's map")
    local clock = Kit.Text(map, 12, "bold", T.textBright)
    clock:SetPoint("BOTTOM", 0, 22)
    local zone = Kit.Text(map, 11, "semibold", T.graphite.text)
    zone:SetPoint("BOTTOM", 0, 8)
    zone:SetWidth(186); zone:SetWordWrap(false)
    -- The button container under the map: tiles in the `group` edge, 1px apart.
    local tray = CreateFrame("Frame", nil, body)
    tray:SetSize(200, 26)
    tray:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 0, -8)
    local px = S.Pixel(tray)
    for i, name in ipairs({ "Bags", "Chat", "Tooltip", "Windows", "Profiles" }) do
        local tile = CreateFrame("Frame", nil, tray)
        tile:SetSize(26, S.IconHeight(26))
        tile:SetPoint("LEFT", tray, "LEFT", (i - 1) * (26 + 3 * px), 0)
        Kit.Fill(tile, "Button", T.mono.raised)
        S.Edge(tile, "group")
        local glyph = tile:CreateTexture(nil, "ARTWORK")
        S.ApplyAsset(glyph, "Icon" .. name); S.Paint(glyph, T.graphite.secondary)
        glyph:SetSize(14, 14); glyph:SetPoint("CENTER")
    end
    local function Refresh()
        local hour, minute = D.Query.Plain(GetGameTime)
        clock:SetText((Kit.IsNumber(hour) and Kit.IsNumber(minute)) and string.format("%02d:%02d", hour, minute)
            or (date and date("%H:%M")) or "")
        -- The zone name may be secret: straight to SetText.
        local ok, text = D.Location.ZoneText()
        if not (ok and pcall(zone.SetText, zone, text)) then zone:SetText("") end
    end
    Refresh()
    Kit.Every(map, 1, Refresh)
    Kit.Caption(body, "Frame: 200 x 184, frame edge; clock above zone at the bottom (live); addon buttons in a tray under the map. A layout preview: your real minimap is not moved.", tray, 0, -12):SetWidth(600)
end
