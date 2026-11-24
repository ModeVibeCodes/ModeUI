local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The bar page's spell list (owner, November 24, 2026): every spell on the
-- bar in its order, as a row with its icon and name, Show, and a switch per
-- glow the bar has. Clicking the name opens the same menu as clicking the
-- spell in the preview (SpellMenu.lua). Spells hidden here show faded.
local LINE, ICON, MAX_LINES = 26, 20, 40
local GLOW_SHORT = { proc = "Proc", active = "Active", ready = "Ready", buff = "Buff" }

local function Line(host, index)
    local line = host.lines[index]
    if line then return line end
    line = CreateFrame("Frame", nil, host)
    line:SetHeight(LINE - 2)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(ICON, ICON); line.icon:SetPoint("LEFT", 0, 0)
    line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    line.name = W.Button(line, "", 200, LINE - 4, "quiet")
    line.name:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
    line.name.label:ClearAllPoints(); line.name.label:SetPoint("LEFT", 2, 0); line.name.label:SetJustifyH("LEFT")
    line.show = W.Button(line, L["Show"], 64, LINE - 6, "choice")
    line.glows = {}
    for i, kind in ipairs({ "proc", "active", "ready", "buff" }) do
        local button = W.Button(line, L[GLOW_SHORT[kind]], 62, LINE - 6, "choice")
        button.kind = kind
        line.glows[i] = button
    end
    host.lines[index] = line
    return line
end

function M:BuildSpellList(ui)
    local page = ui.page
    local host = page:Row("", LINE)
    host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
    host.lines = {}
    page.spellList = host
    local row = page.rows[#page.rows]
    local function Draw()
        local id = ui.Viewer()
        local entries = M:PreviewEntries(id)
        local count = math.min(#entries, MAX_LINES)
        local kinds = M:Glows(id)
        for index = 1, count do
            local entry, line = entries[index], Line(host, index)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(index - 1) * LINE)
            line:SetPoint("RIGHT", host, "RIGHT", 0, 0)
            line.key = entry.key
            line.icon:SetTexture(entry.icon)
            if line.icon.SetDesaturated then line.icon:SetDesaturated(entry.missing == true) end
            line.name.label:SetText(entry.name or "")
            line.name:SetScript("OnClick", function() if M.previewView then M:OpenSpellMenu(M.previewView, entry.key, line.name) end end)
            local shown = not M:SpellSwitch(id, entry.key, "hide")
            line.show:SetSelected(shown)
            line.show:SetScript("OnClick", function() M:SetSpellSwitch(id, entry.key, "hide", shown) end)
            -- Right to left: the glows, then Show.
            local x = 0
            for i = #line.glows, 1, -1 do
                local button = line.glows[i]
                local has = false
                for _, kind in ipairs(kinds) do if kind == button.kind then has = true end end
                button:SetShown(has and entry.key ~= nil)
                if has then
                    button:ClearAllPoints(); button:SetPoint("RIGHT", line, "RIGHT", -x, 0); x = x + 66
                    local on = M:SpellSwitch(id, entry.key, button.kind)
                    button:SetSelected(on)
                    button:SetScript("OnClick", function() M:SetSpellSwitch(id, entry.key, button.kind, not on) end)
                end
            end
            line.show:ClearAllPoints(); line.show:SetPoint("RIGHT", line, "RIGHT", -x, 0)
            line.show:SetShown(entry.key ~= nil)
            line:SetAlpha(entry.faded and 0.45 or 1)
            line:Show()
        end
        for index = count + 1, #host.lines do host.lines[index]:Hide() end
        row:SetHeight(math.max(1, count) * LINE + 4)
        host.empty = host.empty or W.Label(host, "", nil, 0, -4, 420, T.muted)
        host.empty:SetText(count == 0 and L["No spells on this bar yet. Click + in the preview to add one."] or "")
        host.count = count
    end
    ui.Refresh(Draw)
    return host
end
