local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The row helpers the resource bar page and the Cast Bar page share, on the
-- shared widgets (Shared/Settings). spec: db() (the settings shown), set(key,
-- value), ranges (the sliders' { low, high, step }) and owner (for the font
-- and color widgets).
function M:PageHelpers(page, spec)
    local ui, db = { db = spec.db, owner = spec.owner }, spec.db
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Set(key) return function(value) spec.set(key, value) end end
    ui.Refresh, ui.Set = Refresh, Set
    -- Rows built inside show only while predicate() holds (and any inner one).
    function ui.When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do
            local row, prior = page.rows[i], page.rows[i].visibleWhen
            row.visibleWhen = prior and function() return predicate() and prior() end or predicate
        end
    end
    function ui.Columns(titles, height)
        local localized = {}
        for i, title in ipairs(titles) do localized[i] = L[title] end
        return page:Columns(localized, height)
    end
    function ui.Slider(host, key, suffix, get, set, range)
        range = range or spec.ranges[key]
        Refresh(W.Slider(host, range[1], range[2], range[3], get or function() return db()[key] or range[1] end,
            set or function(value) spec.set(key, math.floor(value + 0.5)) end, suffix, true))
        return host.slider
    end
    function ui.Select(host, width, choices, key, get, set)
        local button = W.Select(host, width, choices, function()
            local value = get and get() or db()[key]
            for _, choice in ipairs(choices()) do if choice.id == value then return value, L[choice.label] end end
            return value, tostring(value)
        end, set or Set(key))
        Refresh(function() button:Refresh() end)
        return button
    end
    function ui.Pills(title, list, key, width, get, set)
        local choices = {}
        for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width or 110 } end
        local buttons, refresh = W.Exclusive(page:Row(L[title], 48), choices, get or function() return db()[key] end, set or Set(key))
        Refresh(refresh)
        return buttons
    end
    function ui.Toggles(entries)
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = { label = L[entry[1]], get = function() return db()[entry[2]] end, set = Set(entry[2]) }
        end
        return page:ToggleGrid(items, { maxColumns = 3, minimumCellWidth = 150 })
    end
    function ui.Color(host, key, enabled) W.ColorRow(page, spec.owner, host.rowLabel and host.rowLabel:GetText() or key, key, enabled, host) end
    function ui.Note(text, height)
        local host = page:Row("", height or 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local label = W.Label(host, L[text], nil, 0, -6, 440, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end
    function ui.Button(label, width, onClick)
        local host = page:Row("", 40)
        host.rowLabel:Hide(); host:ClearAllPoints(); host:SetAllPoints(host.row)
        local button = W.Button(host, L[label], width, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", onClick)
        return button
    end
    -- A tab; past the first, a note while the bar is off.
    function ui.Tab(title, build)
        page:Section(L[title], nil, false)
        if title ~= "Bar" then
            ui.When(function() return not db().show end, function() W.Tip(ui.Note("This bar is off. Turn on Show Bar on the Bar tab to use it.")) end)
        end
        build()
    end
    -- The Status line, Open Edit Mode and Reset to Defaults rows.
    function ui.Status(text)
        local status = W.Label(page:Row(L["Status"], 48), "", nil, 0, -4, 420, T.muted); status:SetWordWrap(true)
        Refresh(function() status:SetText(text()) end)
        return status
    end
    function ui.EditModeButton()
        local edit = page:Row(L["Edit Mode"], 48)
        local button = W.Button(edit, L["Open Edit Mode"], 160, 30, "secondary")
        button:SetPoint("LEFT"); button:SetScript("OnClick", function() addon:SetEditMode(true) end)
        return button
    end
    return ui
end
