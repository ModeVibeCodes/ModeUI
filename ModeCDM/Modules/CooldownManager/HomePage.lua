local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Home (owner, November 24, 2026): what the window opens on. Whether the
-- Cooldown Manager shows and why not; the Bar Style with its presets and a
-- way to put every bar back on it; how many bars show, are off or have a
-- look of their own; and the module-wide spell choices (Racial Abilities,
-- and where Blizzard's alerts live).
function M:CreateHomePage(parent)
    local page = W.Page(parent, 480); self.homePage = page
    local ui = { page = page }
    function ui.Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Text(title, height)
        local label = W.Label(page:Row(L[title], height or 48), "", nil, 0, -4, 440, T.muted); label:SetWordWrap(true)
        return label
    end
    local function Button(host, label, width, onClick)
        local button = W.Button(host, L[label], width, 30, "secondary")
        button:SetScript("OnClick", onClick)
        return button
    end

    page:Section(L["Home"], nil, false)
    page:Group(L["Cooldown Manager"])
    local status = Text("Now", 56)
    ui.Refresh(function() status:SetText(M:Status()) end)
    page.homeStatus = status

    page:Group(L["Bar Style"])
    local preset = Text("Preset")
    ui.Refresh(function()
        local tag = M:BarStylePreset()
        preset:SetText(tag and L[M.barStylePresets[tag].label] or L["Your own"])
    end)
    local choices = {}
    for _, tag in ipairs(M.barStylePresetOrder) do choices[#choices + 1] = { label = L[M.barStylePresets[tag].label], value = tag, width = 120 } end
    local buttons, refresh = W.Exclusive(page:Row(L["Start From"], 48), choices, function() return M:BarStylePreset() end,
        function(tag) M:ApplyBarStylePreset(tag) end)
    ui.Refresh(refresh); page.homePresetButtons = buttons
    local actions = page:Row("", 40)
    actions.rowLabel:Hide(); actions:ClearAllPoints(); actions:SetAllPoints(actions.row)
    page.homeEditStyle = Button(actions, "Edit Bar Style", 140, function() M:SelectStyle() end)
    page.homeEditStyle:SetPoint("LEFT")
    page.homeUseEverywhere = Button(actions, "Use Bar Style on Every Bar", 210, function() M:UseBarStyleEverywhere() end)
    page.homeUseEverywhere:SetPoint("LEFT", page.homeEditStyle, "RIGHT", 8, 0)

    page:Group(L["Bars"])
    local counts = Text("Your Bars", 56)
    ui.Refresh(function()
        local shown, off, custom = 0, 0, 0
        for _, id in ipairs(M:BarIds()) do
            if M.db[id].show then shown = shown + 1 else off = off + 1 end
            if M:CustomGroups(id) > 0 then custom = custom + 1 end
        end
        counts:SetText(string.format(L["%d bars show, %d are off, %d have a look of their own. Pick one in the list to change it."], shown, off, custom))
        page.homeUseEverywhere:SetEnabled(custom > 0 and M:CanConfigure())
    end)
    page.homeCounts = counts

    page:Group(L["Spells"])
    local racials = page:Columns({ L["Racial Abilities"] })
    page.racialsSelect = W.Select(racials[1], 240, function() return M:RacialChoices() end, function()
        for _, choice in ipairs(M:RacialChoices()) do if choice.id == M.db.racials then return choice.id, choice.label end end
        return M.db.racials, tostring(M.db.racials)
    end, function(value) M:SetRacials(value) end)
    ui.Refresh(function() page.racialsSelect:Refresh() end)
    W.Tip(W.Label(page:Row("", 56), L["Which spells each bar tracks, and sound, spoken or flash alerts on them, are set in Blizzard's Cooldown Settings (Tracked Spells, at the top). Your race's abilities show on the bar picked here."], nil, 0, -4, 440, T.muted))
    local tracked = page:Row("", 40)
    tracked.rowLabel:Hide(); tracked:ClearAllPoints(); tracked:SetAllPoints(tracked.row)
    page.homeTrackedButton = Button(tracked, "Tracked Spells", 140, function() M:OpenCooldownSettings() end)
    page.homeTrackedButton:SetPoint("LEFT")
    ui.Refresh(function() page.homeTrackedButton:SetEnabled(M:CanOpenCooldownSettings()) end)

    page:Finish()
    return page
end
