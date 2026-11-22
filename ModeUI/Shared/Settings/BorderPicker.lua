local _, addon = ...
local W, L = addon.ConfigWidgets, addon.L
local Style = addon.Style

-- Border and Border Metal (docs/DESIGN_LANGUAGE.md, "Choosing a border"): two
-- dropdowns on one line of a settings page. style and metal: { get, set }
-- (get returns the saved id: a style id or "none"; a metal id or "default").
-- opts.none offers None (modules that could already hide their borders);
-- opts.labels names the two fields (default Border, Border Metal: the
-- glossary in docs/DESIGN_LANGUAGE.md, "Standard tabs"); Default metal reads
-- "Suite": the metal Global > Appearance sets;
-- opts.finishes adds choices after the metals ({ id, label }: the portrait
-- ring's Class Color and Custom). Returns the two fields.
function W.BorderPickers(page, style, metal, opts)
    local labels = opts and opts.labels or { "Border", "Border Metal" }
    local cells = page:Columns({ L[labels[1]], L[labels[2]] })
    local function Localized(list)
        for _, choice in ipairs(list) do choice.label = L[choice.label] end
        return list
    end
    local function Picker(host, list, get, set)
        local button = W.Select(host, nil, function() return list end, function()
            local value = get()
            for _, choice in ipairs(list) do if choice.id == value then return value, choice.label end end
            return value, list[1].label
        end, set)
        page.refreshers[#page.refreshers + 1] = function() button:Refresh() end
        return button
    end
    local styles = Localized(Style.EdgeStyleChoices(opts and opts.none, true))
    local metals = Style.EdgeMetalChoices()
    metals[1].label = "Suite"
    for _, choice in ipairs(opts and opts.finishes or {}) do metals[#metals + 1] = { id = choice.id, label = choice.label } end
    metals = Localized(metals)
    -- A saved style shows as the style it draws as in the theme in use
    -- (Mode-Obsidian: every Mode metal style is Mode-Obsidian).
    local function StyleGet() return Style.ThemeStyle(style.get()) end
    return Picker(cells[1], styles, StyleGet, style.set), Picker(cells[2], metals, metal.get, metal.set)
end
