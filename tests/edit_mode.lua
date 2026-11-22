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

    -- Esc lets go; a second Esc closes Edit Mode; the page goes back.
    strip.scripts.OnKeyDown(strip, 'ESCAPE')
    assert(addon.editMode and E:Selected() == nil and not panel:IsShown() and addon.EditPage:Page() == nil, 'Esc lets go')
    strip.scripts.OnKeyDown(strip, 'ESCAPE')
    assert(not addon.editMode and not strip:IsShown() and page:GetParent() == addon.configWindow.pageHost, 'second Esc closes')
    SlashCmdList.MODEUI('edit'); assert(addon.editMode)
    SlashCmdList.MODEUI('edit'); assert(not addon.editMode, '/modeui edit closes it again')
]], 'edit mode')
print('edit mode: edges, grid, Esc, undo, docked panel')
