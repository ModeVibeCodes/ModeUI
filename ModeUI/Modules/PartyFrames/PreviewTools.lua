local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The preview's tools: the header's sample buttons (One, Party, Raid 10/20/40)
-- and its Show list of preview states (Samples.lua), and on the Auras tab a
-- quick list beside the sample: Buffs or Debuffs, then each group of that
-- kind (click to edit it; a dimmed one is off), with + on the Tracked Buffs
-- groups to add buffs to them (Picker.lua).
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local ROW, GAP = 20, 2

function M:PreviewSampleButtons(page)
    local buttons = {}
    for _, item in ipairs(self.previewSamples) do
        local button = W.Button(page.previewArea or page, L[item.label], 64, 24, "choice")
        button:SetScript("OnClick", function() M:SetPreviewSample(item.id) end)
        button.sampleId = item.id
        buttons[#buttons + 1] = button
    end
    -- Show: states the samples rarely show on their own, any number at once.
    local states = W.Select(page.previewArea or page, 150, function()
        local list = {}
        for _, item in ipairs(M.previewStateList) do
            list[#list + 1] = { id = item.id, label = L[item.label], selected = M.previewStates[item.id] == true }
        end
        return list
    end, function()
        local n = 0
        for _ in pairs(M.previewStates) do n = n + 1 end
        return nil, n > 0 and string.format(L["Show: %d"], n) or L["Show States"]
    end, function(id) M:TogglePreviewState(id) end, { multi = true })
    buttons[#buttons + 1] = states
    page.previewStateSelect = states
    page.refreshers[#page.refreshers + 1] = function()
        local aura = M:PreviewAuraGroup() ~= nil
        for _, button in ipairs(buttons) do
            if button.sampleId then button:SetSelected(button.sampleId == M.previewSample); button:SetEnabled(not aura) end
        end
        states:Refresh()
    end
    return buttons
end

-- The aura groups of the kind being edited.
function M:AuraKindGroups(kind) return kind == "debuffs" and self.debuffGroups or self.buffGroups end
function M:AuraKind(group) return self.HELPFUL[group] and "buffs" or "debuffs" end

function M:QuickListHeight()
    local most = math.max(#self.buffGroups, #self.debuffGroups)
    return (most + 1) * (ROW + GAP) + 6
end

local function Row(view, index)
    view.quickRows = view.quickRows or {}
    local row = view.quickRows[index]
    if row then return row end
    row = W.Button(view.quick, "", M.QUICK_WIDTH, ROW, "tab")
    row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 8, 0); row.label:SetJustifyH("LEFT")
    row:SetScript("OnClick", function() if M.page then M.page.SetAuraGroup(row.group) end end)
    row.add = W.Button(row, "+", ROW, ROW, "secondary")
    row.add:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.add:SetScript("OnClick", function() M:OpenPicker(row.group, row.add) end)
    view.quickRows[index] = row
    return row
end

-- Lays the quick list out down the right of the preview (Auras tab only).
function M:LayoutQuickList(view, group)
    if not view.quick then
        view.quick = CreateFrame("Frame", nil, view.frame)
        view.kinds = {}
        for i, kind in ipairs({ "buffs", "debuffs" }) do
            local button = W.Button(view.quick, L[kind == "buffs" and "Buffs" or "Debuffs"], M.QUICK_WIDTH / 2 - 1, ROW, "choice")
            button:SetPoint("TOPLEFT", view.quick, "TOPLEFT", (i - 1) * (M.QUICK_WIDTH / 2 + 1), 0)
            button:SetScript("OnClick", function() if M.page then M.page.SetAuraKind(kind) end end)
            button.kind = kind
            view.kinds[i] = button
        end
    end
    local quick = view.quick
    quick:SetShown(group ~= nil)
    if not group then return end
    quick:ClearAllPoints()
    quick:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", 0, -4)
    quick:SetSize(self.QUICK_WIDTH, self:QuickListHeight())
    local kind = self:AuraKind(group)
    for _, button in ipairs(view.kinds) do button:SetSelected(button.kind == kind) end
    local groups = self:AuraKindGroups(kind)
    for i, id in ipairs(groups) do
        local row = Row(view, i)
        row.group = id
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -i * (ROW + GAP))
        row.label:SetText(L[self.auraGroupLabels[id]])
        row:SetSelected(id == group)
        local on = self.db.auras[id].show and (not self.TRACKED[id] or #self.db.auras[id].spells > 0)
        row.label:SetAlpha(on and 1 or 0.45)
        row.add:SetShown(self.TRACKED[id] == true)
        row.label:SetWidth(self.QUICK_WIDTH - (self.TRACKED[id] and ROW + 12 or 12))
        row:Show()
    end
    for i = #groups + 1, #(view.quickRows or {}) do view.quickRows[i]:Hide() end
end
