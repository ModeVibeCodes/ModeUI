local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The window's list (owner, November 24, 2026: "by kind"): Home and Bar
-- Style first; then Cooldowns (Essential, Utility and your Cooldown Bars)
-- and Buffs (Tracked Buffs, Tracked Bars and your Buff Bars), each heading
-- with a + that adds a bar of its kind and each of your bars with a - that
-- deletes it after asking; then Player Bars (the resource bars and the Cast
-- Bar). Each row says what matters: Off, Custom (a look of its own), or how
-- many spells it shows. A long list packs its rows closer.
local ROW = 32

local function Caption(window, text)
    local label = W.Label(window.list, text:upper(), nil, 0, 0, M.WINDOW_LIST_WIDTH - 24, T.faint or T.muted)
    addon.Media:BindInterfaceFont(label, GameFontHighlight, T.fontSize.group, nil, "heading")
    return label
end

function M:BuildWindowList(window)
    local list = CreateFrame("Frame", nil, window)
    list:SetPoint("TOPLEFT", 16, -self.WINDOW_HEADER_HEIGHT - 6); list:SetPoint("BOTTOMLEFT", 16, 16)
    list:SetWidth(self.WINDOW_LIST_WIDTH - 24)
    window.list, window.rows = list, {}
    window.cooldownCaption, window.buffCaption = Caption(window, L["Cooldowns"]), Caption(window, L["Buffs"])
    window.resourceCaption = Caption(window, L["Player Bars"])
    -- + on the right of Cooldowns and Buffs adds a bar of that kind.
    local function Add(caption, kind)
        local button = W.Button(list, "+", 22, 20, "quiet")
        button:SetPoint("RIGHT", caption, "RIGHT", 0, 0)
        button:SetScript("OnClick", function() local id = M:AddCustomBar(kind); if id then M:SelectBar(id) end end)
        return button
    end
    window.addCooldown, window.addBuff = Add(window.cooldownCaption, "cooldown"), Add(window.buffCaption, "buff")
end

-- A row's status: Off, Custom, or how many spells show on it.
function M:ListStatus(kind, id)
    if kind == "home" or kind == "style" then return "" end
    local style = (kind == "cast" and self.db.castBar) or (kind == "resource" and self.db.resources[id]) or self.db[id]
    if not style.show then return L["Off"] end
    if kind == "bar" then
        if self:CustomGroups(id) > 0 then return L["Custom"] end
        local count = self.placedCount and self.placedCount[id]
        if type(count) == "number" and count > 0 then return tostring(count) end
        return ""
    end
    for _, group in ipairs(self.playerStyleGroups) do
        if not self:PlayerFollows(kind == "cast" and "cast" or id, group) then return L["Custom"] end
    end
    return ""
end

function M:RefreshList()
    local window = self.window
    if not window then return end
    local list, rows, y = window.list, window.rows, 0
    local room = #self.db.customBars < self.MAX_CUSTOM
    local count = 2 + #self.viewers + #self.resources + #self.db.customBars + 1
    local fixed = 3 * 24 + 3 * 12
    -- 22 at the least: fifteen custom bars (MAX_CUSTOM) still fit the list.
    local step = math.max(22, math.min(ROW, math.floor((self.WINDOW_HEIGHT - self.WINDOW_HEADER_HEIGHT - 22 - fixed) / count)))
    local which = self:SelectedPage()
    local function Row(index, kind, id)
        local row = rows[index]
        if not row then
            row = W.Button(list, "", self.WINDOW_LIST_WIDTH - 24, 30, "tab")
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 10, 0); row.label:SetPoint("RIGHT", -70, 0)
            row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
            row.status = W.Label(row, "", nil, 0, 0, 56, T.muted)
            row.status:SetJustifyH("RIGHT")
            row:SetScript("OnClick", function()
                if row.kind == "home" then M:SelectHome()
                elseif row.kind == "style" then M:SelectStyle()
                elseif row.kind == "cast" then M:SelectCast()
                elseif row.kind == "resource" then M:SelectResource(row.barId) else M:SelectBar(row.barId) end
            end)
            -- - deletes a custom bar, after asking.
            row.delete = W.Button(row, "-", 22, 20, "quiet")
            row.delete:SetPoint("RIGHT", -4, 0)
            row.delete:SetScript("OnClick", function() M:ConfirmDelete(row.barId) end)
            rows[index] = row
        end
        row.barId, row.kind = id, kind
        -- Kept for older callers: true for a resource bar, "cast" for the Cast Bar.
        row.resource = (kind == "cast" and "cast") or (kind == "resource" and true) or nil
        local custom = kind == "bar" and self:IsCustom(id)
        local label = (kind == "home" and L["Home"]) or (kind == "style" and L["Bar Style"]) or (kind == "cast" and L[self.CAST_LABEL])
            or (kind == "resource" and self:ResourceLabel(id)) or self:Label(id)
        row.label:SetText(label)
        row.status:SetText(self:ListStatus(kind, id))
        row.status:ClearAllPoints(); row.status:SetPoint("RIGHT", custom and -30 or -10, 0)
        row.delete:SetShown(custom); row.delete:SetEnabled(self:CanConfigure())
        local selected = (kind == which) and (kind ~= "bar" or id == self.selectedBar) and (kind ~= "resource" or id == self.selectedResource)
        row:SetSelected(selected and true or false)
        row:SetHeight(step - 2)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:Show()
        y = y + step
    end
    local function Place(region, height)
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", 0, -y); region:Show()
        y = y + height
    end
    local index = 1
    Row(index, "home"); index = index + 1
    Row(index, "style")
    for _, kind in ipairs({ "cooldown", "buff" }) do
        y = y + 12
        Place(kind == "cooldown" and window.cooldownCaption or window.buffCaption, 24)
        local viewers = kind == "cooldown" and { "essential", "utility" } or { "buffIcon", "buffBar" }
        for _, viewer in ipairs(viewers) do index = index + 1; Row(index, "bar", viewer) end
        for _, bar in ipairs(self.db.customBars) do
            if bar.kind == kind then index = index + 1; Row(index, "bar", bar.id) end
        end
    end
    y = y + 12
    Place(window.resourceCaption, 24)
    for _, id in ipairs(self.resources) do index = index + 1; Row(index, "resource", id) end
    index = index + 1; Row(index, "cast", "cast")
    for i = index + 1, #rows do rows[i]:Hide() end
    local add = room and self:CanConfigure()
    window.addCooldown:SetEnabled(add); window.addBuff:SetEnabled(add)
end
