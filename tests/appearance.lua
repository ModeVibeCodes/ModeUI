-- Global > Appearance and suite step 1 (docs/DESIGN_LANGUAGE.md, "Suite
-- defaults"): the suite font and border metal, modules following them, the
-- Customized list with Back to suite, and saved profiles from before; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- A fresh account: the suite font is the Mode typeface; every module follows it.
local world = H.Load({ before = STUBS })
world.run([[
    local A, R = addon.Appearance, addon.ReloadManager
    local g = addon.db.globalMedia
    assert(addon.db.suite == 1 and g.font == 'media:Mode' and g.edgeMetal == 'default', 'suite defaults')
    assert(addon.db.modules.tooltip.fontMedia == '' and addon.db.modules.tooltip.font == 'game', 'module text follows the suite')
    assert(addon.db.modules.damageMeters.window1.nameFontMedia == '', 'a Damage Meters text follows the suite')
    assert(addon.db.modules.cooldownManager.essential.fontMedia == 'Mode', 'the Cooldown Manager keeps its own font')
    assert(#A:Customized() == 0, 'nothing customized')
    -- The suite font is what a following text draws in.
    local path = addon.Kit.FontPath(addon.db.modules.tooltip, 'tooltip')
    assert(path == addon.Media:GetFont('Mode') or path == addon.Style.FontPath('regular'), 'Suite draws the Mode typeface')

    -- The page: Font, Border Metal, the Customized list.
    SlashCmdList.MODEUI()
    addon:SelectConfigPage('appearance')
    local page = addon.configWindow.pages.appearance
    assert(page.fontPicker and page.metalPicker and page.customRows.tooltip, 'Font, Border Metal, a row per module')
    assert(page.metalPicker.label:GetText() == 'Obsidian', 'the suite metal starts as the Mode-Border metal')
    assert(not page.customRows.tooltip.row:IsShown() and page.noneCustomized:GetParent().row:IsShown(), 'every module follows the suite')

    -- A module's own font shows in Customized; Back to suite returns it.
    addon.db.modules.tooltip.fontMedia = 'Friz'
    addon.db.modules.bags.edgeMetal = 'steel'
    page:Refresh()
    local rows = page.customRows
    assert(rows.tooltip.row:IsShown() and rows.tooltip.what:GetText() == 'Font', 'Tooltip customizes its font')
    assert(rows.bags.row:IsShown() and rows.bags.what:GetText() == 'Border Metal', 'Bags customizes its metal')
    rows.tooltip.back:GetScript('OnClick')(rows.tooltip.back)
    assert(addon.db.modules.tooltip.fontMedia == '' and addon.db.modules.tooltip.font == 'game' and R.requests.suite, 'back to the suite, after a reload')
    assert(not rows.tooltip.row:IsShown() and rows.bags.row:IsShown(), 'Bags still customized')
    assert(A:BackToSuite('bags') and addon.db.modules.bags.edgeMetal == 'default')

    -- The suite metal and font.
    R:Clear('suite')
    assert(A:SetMetal('steel') and g.edgeMetal == 'steel' and R.requests.suite, 'the suite metal, after a reload')
    assert(not A:SetMetal('pink') and g.edgeMetal == 'steel', 'only Mode metals')
    assert(A:SetFont('media:Expressway') == false or g.font == 'media:Expressway', 'a known font only')
    assert(A:SetFont('game') and g.font == 'game', 'the game font')
    -- A Suite metal draws in the suite's; an element's own metal wins.
    addon.Style.SetSuiteMetal('gunmetal')
    local host = CreateFrame('Frame', nil, UIParent)
    local own = addon.Style.Edge(host, 'frame', { metal = 'silver' })
    local suite = addon.Style.Edge(CreateFrame('Frame', nil, UIParent), 'frame')
    assert(own:Metal() == addon.Style.Tone.metal.silver and suite:Metal() == addon.Style.Tone.metal.gunmetal, 'Suite follows the suite metal')
    addon.Style.SetSuiteMetal('default')
    assert(suite:Metal() ~= addon.Style.Tone.metal.gunmetal, 'default: the style metal')
]], 'appearance')

-- The suite metal is read back when the profile loads.
local saved = world.saved()
local again = H.Load({ before = STUBS, saved = saved })
again.run([[
    assert(addon.db.globalMedia.edgeMetal == 'steel' and addon.Style.suiteMetal == 'steel', 'the suite metal after a reload')
]], 'appearance reload')

-- A profile from before the suite: the global font at "game", module texts at
-- the Mode typeface, one picked font.
local old = H.Load({ before = STUBS, saved = { schemaVersion = 2, activeProfile = 'Default', profiles = { Default = {
    typeface = 4, look = 1, globalMedia = { font = 'game', texture = 'default', border = 'thin', overrides = {} },
    modules = { tooltip = { fontMedia = 'Mode', font = 'game' }, chat = { fontMedia = 'Friz', font = 'game' } } } } } })
old.run([[
    local g = addon.db.globalMedia
    assert(addon.db.suite == 1 and g.font == 'media:Mode' and g.edgeMetal == 'default', 'the global font becomes the Mode typeface')
    assert(addon.db.modules.tooltip.fontMedia == '', 'a text at the Mode typeface follows the suite')
    assert(addon.db.modules.chat.fontMedia == 'Friz', 'a picked font stays')
    local list = addon.Appearance:Customized()
    assert(#list == 1 and list[1].id == 'chat' and list[1].font == 1, 'Chat listed as customized')
]], 'appearance migration')
print('appearance: suite font and metal, Customized, migration')
