local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- Settings tabs for the parts kept in nested tables: combo points (the
-- Target's, in M.db.comboPoints), and each frame's cast bar and auras. Built
-- by CreateConfigPage (Settings.lua) with its helpers in `ui`.

-- Controls bound to one nested table: `get()` returns the table and
-- `set(key, value)` changes it through M:SetNestedOption.
local function Nested(ui, get, set)
    local page, n = ui.page, {}
    function n.Toggle(label, key) return { label = label, get = function() return get()[key] end, set = function(v) set(key, v) end } end
    function n.Toggles(entries) return page:ToggleGrid(entries, { maxColumns = 2, minimumCellWidth = 210 }) end
    function n.Select(label, list, key)
        return ui.Select(label, function() return list end, function() return get()[key] end, function(v) set(key, v) end)
    end
    function n.SelectIn(host, list, key)
        return ui.SelectIn(host, 200, function() return list end, function() return get()[key] end, function(v) set(key, v) end)
    end
    -- One slider in a Columns cell; `range` is { low, high, step }.
    function n.Slider(host, range, key, suffix)
        page.refreshers[#page.refreshers + 1] = W.Slider(host, range[1], range[2], range[3], function() return get()[key] end,
            function(v) set(key, math.floor(v + 0.5)) end, suffix, true)
        return host.slider
    end
    -- The shared color row reads and writes through an appearance owner.
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return get()[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.SetAppearance(_, key, value) return set(key, value) end
    function n.Color(label, key, enabled) W.ColorRow(page, owner, label, key, enabled) end
    return n
end
M.NestedControls = Nested

function M:BuildComboTab(ui)
    local page, When = ui.page, ui.When
    page:Section("Combo Points", nil, false)
    local function C() return M.db.comboPoints end
    local n = Nested(ui, C, function(key, value) M:SetComboOption(key, value) end)
    page.unitFrameComboToggles = n.Toggles({ n.Toggle("Show Combo Points", "enabled"), n.Toggle("Hide Blizzard Combo Points", "hideBlizzard") })
    When(function() return C().enabled end, function()
        page:Group("Placement")
        page.unitFrameComboArc = n.Select("Arc Position", M.choices.comboArc, "arc")
        local sizes = page:Columns({ "Point Size", "Spacing", "Distance" })
        page.unitFrameComboSize = n.Slider(sizes[1], M.comboRanges.size, "size", "px")
        n.Slider(sizes[2], M.comboRanges.spacing, "spacing", "px")
        n.Slider(sizes[3], M.comboRanges.distance, "distance", "px")
        page:Group("Colors")
        n.Color("Lit Point Color", "activeColor"); n.Color("Empty Point Color", "emptyColor")
    end)
    ui.Note("About Combo Points", "Combo points ring the Target frame's portrait while you are a Rogue or a Druid in Cat Form, one socket per point. Without a portrait they line up under the bars. Hide Blizzard Combo Points fades the game's own points, which sit where Blizzard's Target frame was.", 64)
end

-- A tab of the frame's own (a matched Target edits its own cast bar).
function M:BuildCastTab(ui)
    local page, When = ui.page, ui.When
    local function C() return ui.db().castBar end
    local n = Nested(ui, C, function(key, value) M:SetCastOption(ui.Editing(), key, value) end)
    ui.Tab("Cast Bar", function()
        page.unitFrameCastToggles = n.Toggles({ n.Toggle("Show Cast Bar", "enabled") })
        -- Only the Player, Target and Focus have a Blizzard cast bar to hide.
        When(function() return C().enabled and M.nativeCast[ui.Editing()] ~= nil end, function()
            n.Toggles({ n.Toggle("Hide Blizzard Cast Bar", "hideBlizzard") })
        end)
        When(function() return C().enabled end, function()
            page:Group("Placement")
            page.unitFrameCastPosition = n.Select("Position", M.choices.castPosition, "position")
            local size = page:Columns({ "Bar Height", "Gap" })
            page.unitFrameCastHeight = n.Slider(size[1], M.castRanges.height, "height", "px")
            n.Slider(size[2], M.castRanges.gap, "gap", "px")
            page:Group("Icon and Text")
            page.unitFrameCastIcon = n.Select("Spell Icon", M.choices.castIcon, "icon")
            n.Toggles({ n.Toggle("Spell Name", "showText"), n.Toggle("Timer", "showTimer") })
            local font = page:Columns({ "Font Size" })
            n.Slider(font[1], M.castRanges.fontSize, "fontSize")
            page:Group("Colors")
            n.Color("Cast Color", "color"); n.Color("Uninterruptible Color", "lockedColor")
        end)
    end, true)
end
