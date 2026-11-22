-- Edit Mode (docs/DESIGN_LANGUAGE.md, "Edit Mode"): /modeui edit, edge
-- snapping, the grid's spacing, Esc twice, undoing a drag, the docked panel
-- with the module page scoped to the element, and Pin; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([[
    local PM, E = addon.PositionManager, addon.EditMode
    -- /modeui edit opens and closes Edit Mode.
    SlashCmdList.MODEUI('edit')
    assert(addon.editMode and addon.editWindow:IsShown(), '/modeui edit opens Edit Mode')

    -- Edge snapping: an element's edge near another's lines up with it.
    local function Box(x, y, w, h)
        local f = CreateFrame('Frame', nil, UIParent); f:SetSize(w, h); f:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x, y)
        return f
    end
    local other = { frame = Box(300, 300, 100, 40), editMode = true, module = { enabled = true } }
    local moving = { frame = Box(300 + 100 + 3, 200, 100, 40) } -- left edge 353, other's right edge 350
    local fake = { elements = { other = other }, FindMoreGuides = PM.FindMoreGuides }
    local found = PM.FindGuides(fake, moving, 500, 500)
    local ox = addon.Positioning:Geometry(other.frame)
    assert(found.x and math.abs(found.x.delta + 3) < 0.01 and found.x.line == ox + 50, 'meets the other element side by side')
    -- Narrower, its left edge 3 px right of the other's left edge (centers apart).
    moving.frame:SetSize(60, 40); moving.frame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', 283, 200)
    found = PM.FindGuides(fake, moving, 500, 500)
    assert(found.x and math.abs(found.x.delta + 3) < 0.01 and found.x.line == ox - 50, 'lines up with its left edge')
    -- An axis the drag didn't move keeps its value.
    moving.dragFrom = { x = 500, y = 120 }
    found = PM.FindGuides(fake, moving, 500, 120)
    assert(found.x == nil, 'x not moved: no snap on x')

    -- The grid's spacing.
    assert(E:SetGridSpacing(48) and PM.GRID_SPACING == 48 and not E:SetGridSpacing(2), 'grid spacing')
    E:SetGrid(true)
    assert(#PM.grid.lines >= 2 * (math.floor(640 / 48) + math.floor(400 / 48)), 'lines every 48')
    E:SetGrid(false); E:SetGridSpacing(32)

    -- Undo a drag (it counts once, when it's dropped).
    local id = 'unitFramesPlayer'
    assert(E:Select(id))
    local element, before = PM:Element(id), PM:GetPosition(id)
    assert(PM:StartDragging(id))
    element.frame.centerX = element.frame.centerX + 40
    assert(not E.history:CanUndo(), 'nothing recorded while dragging')
    assert(PM:StopDragging(id) and PM:GetPosition(id).x ~= before.x and E.history:CanUndo(), 'the drop is recorded')
    assert(E.history:Undo() and PM:GetPosition(id).x == before.x and E.history:CanRedo(), 'undone')
    assert(E.history:Redo() and PM:GetPosition(id).x ~= before.x, 'redone')
    assert(E.history:Undo())

    -- The panel: Unit Frames' page, scoped to the selected frame.
    local panel, strip = addon.editPanel, addon.editWindow
    assert(E:Select('unitFramesTarget') and panel:IsShown())
    local page = addon.configWindow.pages.unitFrames
    assert(page:GetParent() == strip.settingsHost and addon.EditPage.elementId == 'unitFramesTarget', 'the page edits the Target')
    -- Pin keeps it at the screen's right edge.
    strip.pinButton.scripts.OnClick(strip.pinButton)
    local point, relative, relativePoint = panel:GetPoint(1)
    assert(panel.pinned and point == 'TOPRIGHT' and relative == UIParent and relativePoint == 'TOPRIGHT', 'pinned to the right edge')
    strip.pinButton.scripts.OnClick(strip.pinButton)
    assert(not panel.pinned and select(1, panel:GetPoint(1)) == 'TOPLEFT', 'docked beside the element again')

    -- Fit's placer: names clear of each other and of other elements, on screen;
    -- the smallest element chooses first.
    local Labels, Focus = addon.EditLabels, addon.EditFocus
    local crowd = {
        { id = 'big', rect = { x = 40, y = 40, w = 200, h = 60 }, w = 80 },
        { id = 'small', rect = { x = 100, y = 104, w = 30, h = 30 }, w = 70 },
        { id = 'wide', rect = { x = 40, y = 138, w = 200, h = 20 }, w = 90 },
    }
    local spots = Labels.Place(crowd, {}, 400, 300)
    assert(spots.small and spots.small.x == 100 - 70 - 4, 'boxed in above and below, the smallest (placed first) goes left')
    local placed = {}
    for _, item in ipairs(crowd) do
        local s = spots[item.id]
        if s then
            local r = { x = s.x, y = s.y, w = item.w, h = Labels.HEIGHT }
            assert(r.x >= 0 and r.y >= 0 and r.x + r.w <= 400 and r.y + r.h <= 300, item.id .. ' on screen')
            for _, other in ipairs(crowd) do assert(other == item or not Labels.Hit(r, other.rect, 0), item.id .. ' clear of ' .. other.id) end
            for _, p in ipairs(placed) do assert(not Labels.Hit(r, p, 0), item.id .. ' clear of the other names') end
            placed[#placed + 1] = r
        end
    end

    -- Names and Focus: saved for the account, Inside and Strong by default.
    assert(addon.root.editMode.names == 'inside' and E:Names() == 'inside' and E:Focus() == 'strong', 'Inside and Strong by default')
    assert(not E:SetNames('bogus') and not E:SetFocus('bogus'), 'only known choices')
    assert(strip.namesSelect.label:GetText() == 'Names: Inside' and strip.focusSelect.label:GetText() == 'Focus: Strong', 'the top bar shows both')
    -- Strong: the dim surrounds the Target, which lifts above it; the other outlines hide.
    assert(E:Select('unitFramesTarget'))
    local target, player = PM:Element('unitFramesTarget'), PM:Element('unitFramesPlayer')
    assert(Focus.frame and Focus.frame:IsShown() and Focus.frame.strata == 'DIALOG' and Focus.alpha == Focus.STRENGTH.strong, 'the dim is on')
    local tx, ty, tw, th = addon.Positioning:Geometry(target.frame)
    assert(math.abs(Focus.pieces[1].rect[4] - (ty + th / 2 + Focus.PAD)) < 0.01 and math.abs(Focus.pieces[3].rect[3] - (tx - tw / 2 - Focus.PAD)) < 0.01,
        'the opening is the Target')
    local td, pd = target.decoration, player.decoration
    assert(td.frame:IsShown() and td.frame.strata == 'DIALOG' and td.frame:GetFrameLevel() == Focus.LIFT, 'the Target lifts above it')
    assert(td.chip:IsShown() and td.label:GetText() == 'Target Frame' and td.sub:GetText():find('×', 1, true), 'its chip: name and size')
    assert(not pd.frame:IsShown(), 'Strong hides the other outlines')
    assert(pd.tag:IsShown() and pd.tag.text:GetText() == 'Player Frame' and not pd.chip:IsShown(), 'Inside: the name in its corner')
    -- The mouse over the Player: its outline and name come up through the dim.
    -- (Nothing reacts under the panel; the mock screen is smaller than it, so it moves aside.)
    local dockedAt = { panel:GetPoint(1) }
    panel:ClearAllPoints(); panel:SetPoint('TOPLEFT', UIParent, 'TOPRIGHT', 20, 0)
    local px, py = addon.Positioning:Geometry(player.frame)
    local cursor, scale = GetCursorPosition, UIParent:GetEffectiveScale()
    GetCursorPosition = function() return px * scale, py * scale end
    Labels:Tick()
    assert(PM.hovered == 'unitFramesPlayer' and pd.frame:IsShown() and pd.frame.strata == 'DIALOG' and pd.chip:IsShown(), 'hovered: lifted and named')
    GetCursorPosition = function() return -50, -50 end
    Labels:Tick()
    assert(PM.hovered == nil and not pd.frame:IsShown(), 'and back under it')
    GetCursorPosition = cursor
    -- Dim: the other outlines stay, under it; it halves while dragging.
    assert(E:SetFocus('dim') and addon.root.editMode.focus == 'dim' and Focus.alpha == Focus.STRENGTH.dim)
    assert(pd.frame:IsShown() and pd.frame.strata ~= 'DIALOG', 'Dim: the Player stays, under the dim')
    target.dragging = true; Focus:Track()
    assert(math.abs(Focus.alpha - Focus.STRENGTH.dim / 2) < 0.001, 'half while dragging')
    target.dragging = false; Focus:Track()
    -- Fit: every name that fits shows, none over another.
    assert(E:SetNames('fit') and not pd.tag:IsShown())
    local shown = {}
    for _, element in pairs(PM.elements) do
        local d = element.decoration
        if d and d.chip:IsShown() then
            local p = d.chip.points[1]
            local rect = Labels.FrameRect(element.frame)
            shown[#shown + 1] = { x = rect.x + p[4], y = rect.y + p[5], w = d.chip:GetWidth(), h = Labels.HEIGHT }
        end
    end
    assert(#shown >= 2 and Labels.spots.unitFramesPlayer, 'names placed')
    for i = 1, #shown do for j = i + 1, #shown do assert(not Labels.Hit(shown[i], shown[j], 0), 'no name over another') end end
    panel:ClearAllPoints(); panel:SetPoint(unpack(dockedAt))
    -- Off: only the selected element is named; Hide All hides everything.
    assert(E:SetNames('none') and not pd.chip:IsShown() and not pd.tag:IsShown() and td.chip:IsShown(), 'Off')
    strip.namesSelect.menu:Show(); strip.namesSelect:Refresh()
    local hideAll
    for _, row in ipairs(strip.namesSelect.rows or {}) do if row.choice and row.choice.id == 'hidden' then hideAll = row end end
    if hideAll then hideAll.scripts.OnClick(hideAll) else E:SetHighlights(false) end
    assert(not E.highlights and not td.frame:IsShown(), 'Hide All')
    assert(E:SetNames('inside')); E.highlights = true; E:RefreshElements()
    assert(td.frame:IsShown() and E:Names() == 'inside')
    -- Anchor To and Match step the dim away; Focus Off removes it.
    local started = addon.EditAnchor:Start('unitFramesTarget', 'width'); assert(started, 'Match Width starts')
    assert(not Focus.frame:IsShown(), 'no dim while picking')
    addon.EditAnchor:Stop()
    assert(Focus.frame:IsShown() and E:SetFocus('off') and not Focus.frame:IsShown(), 'Focus Off')
    assert(E:SetFocus('strong'))

    -- Esc lets go; a second Esc closes Edit Mode; the page goes back.
    strip.scripts.OnKeyDown(strip, 'ESCAPE')
    assert(addon.editMode and E:Selected() == nil and not panel:IsShown() and addon.EditPage:Page() == nil, 'Esc lets go')
    strip.scripts.OnKeyDown(strip, 'ESCAPE')
    assert(not addon.editMode and not strip:IsShown() and page:GetParent() == addon.configWindow.pageHost, 'second Esc closes')
    assert(not addon.EditFocus.frame:IsShown() and not addon.EditLabels.watcher:IsShown(), 'no dim or watcher after Edit Mode')
    SlashCmdList.MODEUI('edit'); assert(addon.editMode)
    SlashCmdList.MODEUI('edit'); assert(not addon.editMode, '/modeui edit closes it again')
]], 'edit mode')
print('edit mode: edges, grid, Esc, undo, docked panel, names, focus')
