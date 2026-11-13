-- The micro menu and bag bar in Action Bars: Blizzard's micro and bag buttons
-- on plain ModeUI bars, their skin and the hooks that keep it, Blizzard
-- showing and hiding buttons, BagsBar re-anchoring, Show (Always, Mouseover,
-- Hidden), Edit Mode, the settings page and preview, and switching off.
-- Simulated client (Forever's frame names and regions); not WoW rendering,
-- security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:GetAtlas() return self.atlas end
    -- Children, as the client lists them.
    local frames, create = {}, CreateFrame
    function CreateFrame(...) local f = create(...); frames[#frames + 1] = f; return f end
    function methods:GetChildren()
        local list = {}
        for _, f in ipairs(frames) do if f:GetParent() == self then list[#list + 1] = f end end
        return unpack(list)
    end
    -- Forever's micro menu: the buttons Blizzard added carry a layoutIndex.
    MicroMenu = CreateFrame('Frame', 'MicroMenu', UIParent)
    local function Micro(name, index)
        local b = CreateFrame('Button', name, MicroMenu)
        b.layoutIndex = index; b:SetSize(32, 40); b:SetPoint('LEFT', MicroMenu, 'LEFT', (index - 1) * 27, 0)
        for _, key in ipairs({ 'Background', 'PushedBackground', 'FlashBorder', 'FlashContent', 'QuickKeybindHighlightTexture' }) do
            b[key] = b:CreateTexture(nil, 'BACKGROUND')
        end
        b.normal, b.pushed, b.highlight = b:CreateTexture(nil, 'ARTWORK'), b:CreateTexture(nil, 'ARTWORK'), b:CreateTexture(nil, 'HIGHLIGHT')
        b.normal:SetAtlas('UI-HUD-MicroMenu-' .. name .. '-Up'); b.normal:SetPoint('CENTER')
        function b:GetNormalTexture() return self.normal end
        function b:GetPushedTexture() return self.pushed end
        function b:GetHighlightTexture() return self.highlight end
        -- Blizzard's SetPushed/SetNormal put its own look back.
        function b:SetPushed() self.Background:SetAlpha(1); self.highlight:ClearAllPoints(); self.highlight:SetPoint('CENTER') end
        function b:SetNormal() self.Background:SetAlpha(1); self.highlight:ClearAllPoints(); self.highlight:SetPoint('CENTER') end
        return b
    end
    for index, name in ipairs({ 'CharacterMicroButton', 'SpellbookMicroButton', 'HelpMicroButton', 'StoreMicroButton', 'MainMenuMicroButton' }) do
        Micro(name, index)
    end
    CharacterMicroButton.Portrait = CharacterMicroButton:CreateTexture(nil, 'ARTWORK')
    CharacterMicroButton.Shadow = CharacterMicroButton:CreateTexture(nil, 'BORDER')
    CharacterMicroButton.PortraitMask = CharacterMicroButton:CreateTexture(nil, 'OVERLAY')
    MainMenuMicroButton.MainMenuBarPerformanceBar = MainMenuMicroButton:CreateTexture(nil, 'OVERLAY')
    HelpMicroButton:Hide() -- shown only where the store is off
    CreateFrame('Frame', nil, MicroMenu) -- not a micro button: no layoutIndex
    -- Forever's bag bar: square slots, a key ring, BagsBar:Layout re-anchoring them.
    BagsBar = CreateFrame('Frame', 'BagsBar', UIParent)
    for index, name in ipairs({ 'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot',
        'CharacterBag3Slot', 'CharacterReagentBag0Slot', 'KeyRingButton' }) do
        local b = CreateFrame('Button', name, BagsBar)
        b:SetSize(45, 45); b:SetPoint('RIGHT', BagsBar, 'RIGHT', -(index - 1) * 47, 0)
        b.icon = b:CreateTexture(nil, 'BORDER'); b.icon:SetTexture('Interface/Icons/Bag' .. index)
        b.SquareMask = b:CreateMaskTexture(); b.icon:AddMaskTexture(b.SquareMask)
        b.IconBorder, b.SlotHighlightTexture = b:CreateTexture(nil, 'OVERLAY'), b:CreateTexture(nil, 'OVERLAY')
        b.Count = b:CreateFontString(nil, 'OVERLAY')
        b.normal = b:CreateTexture(nil, 'ARTWORK')
        function b:GetNormalTexture() return self.normal end
        function b:UpdateTextures() self.normal:SetAtlas('ui-hud-actionbar-iconframe-bags'); self.normal:SetAlpha(1) end
        b:UpdateTextures()
    end
    KeyRingButton:Hide() -- no key ring for this character
    MainMenuBarBackpackButton.FreeSlots = MainMenuBarBackpackButton:CreateFontString(nil, 'OVERLAY')
    MainMenuBarBackpackButton.FreeSlots:SetText('(16)')
    function BagsBar:Layout()
        for index, name in ipairs({ 'MainMenuBarBackpackButton', 'CharacterBag0Slot' }) do
            local b = _G[name]; b:ClearAllPoints(); b:SetPoint('RIGHT', self, 'RIGHT', -(index - 1) * 47, 0)
        end
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit = addon.ActionBars, addon.PositionManager, addon.Kit
    assert(M.db.micro.show and M.db.bags.show, 'both bars on by default')
    assert(M.db.micro.width == 32 and M.db.micro.height == 40 and M.db.bags.width == 36 and M.db.bags.height == 36)
    assert(CharacterMicroButton:GetParent() == MicroMenu, 'Blizzard keeps its buttons while Action Bars is off')

    addon:SetModuleEnabled('actionBars', true)
    local micro, bags = ModeUIMicroMenu, ModeUIBagBar
    assert(micro and bags and not micro.secure and not bags.secure, 'plain frames, not secure ones')
    -- Micro menu: Blizzard's order, the buttons it shows; Help (hidden) waits on the bar.
    assert(CharacterMicroButton:GetParent() == micro and HelpMicroButton:GetParent() == micro, 'every micro button moves')
    local shown = M:UtilityButtons('micro')
    assert(#shown == 4 and shown[1] == CharacterMicroButton and shown[2] == SpellbookMicroButton and shown[3] == StoreMicroButton, 'shown ones, in order')
    assert(M:ButtonCount('micro') == 4 and micro:IsShown() and micro.width == 4 * 32 + 3 + 1, 'four 32 by 40 buttons, 1px apart (an even width)')
    assert(CharacterMicroButton.width == 32 and CharacterMicroButton.height == 40)
    assert(MicroMenu:GetAlpha() == 0 and BagsBar:GetAlpha() == 0, "Blizzard's empty bars fade out")
    -- The Mode skin: Blizzard's button background and portrait frame faded, the glyph inside the border.
    assert(SpellbookMicroButton.Background:GetAlpha() == 0 and CharacterMicroButton.PortraitMask:GetAlpha() == 0
        and CharacterMicroButton.Shadow:GetAlpha() == 0 and MainMenuMicroButton.MainMenuBarPerformanceBar:GetAlpha() == 0)
    assert(M.art[SpellbookMicroButton] and M.art[SpellbookMicroButton].edges[1]:IsShown(), 'a Mode border')
    local inset = M.skinState[SpellbookMicroButton].g.inset
    local function Inset(region, host) local p = region.points and region.points[1]; return p and p[1] == 'TOPLEFT' and p[2] == host and p[4] == inset end
    assert(Inset(SpellbookMicroButton.normal, SpellbookMicroButton) and Inset(CharacterMicroButton.Portrait, CharacterMicroButton), 'glyph and portrait inside the border')
    assert(SpellbookMicroButton.normal.atlas == 'UI-HUD-MicroMenu-SpellbookMicroButton-Up', 'the glyph stays Blizzard\'s')
    -- Blizzard's SetPushed puts its look back; the hook restyles.
    SpellbookMicroButton:SetPushed()
    assert(SpellbookMicroButton.Background:GetAlpha() == 0 and Inset(SpellbookMicroButton.highlight, SpellbookMicroButton), 'restyled after SetPushed')
    -- Blizzard shows Help: the bar lays out five.
    HelpMicroButton:Show()
    assert(M:ButtonCount('micro') == 5 and M:UtilityButtons('micro')[3] == HelpMicroButton and micro.width == 5 * 32 + 4, 'a shown button joins in order')
    HelpMicroButton:Hide()
    assert(M:ButtonCount('micro') == 4)

    -- Bag bar: left to right as Blizzard shows it, the key ring left out while hidden.
    local order = M:UtilityButtons('bags')
    assert(#order == 6 and order[1] == CharacterReagentBag0Slot and order[6] == MainMenuBarBackpackButton, 'reagent bag first, backpack last')
    assert(MainMenuBarBackpackButton:GetParent() == bags and KeyRingButton:GetParent() == bags and bags.width == 6 * 36 + 5 + 1)
    assert(MainMenuBarBackpackButton.normal:GetAlpha() == 0 and MainMenuBarBackpackButton.IconBorder:GetAlpha() == 0, 'frame art faded')
    assert(MainMenuBarBackpackButton.icon.mask == nil, 'square mask off, so the icon crops')
    assert(MainMenuBarBackpackButton.SlotHighlightTexture.texture == Kit.FLAT, 'open-bag highlight in the Mode look')
    MainMenuBarBackpackButton:UpdateTextures()
    assert(MainMenuBarBackpackButton.normal:GetAlpha() == 0, 'restyled after UpdateTextures')
    -- Picking up an item: BagsBar:Layout re-anchors; the hook puts them back, in combat too.
    local before = { MainMenuBarBackpackButton:GetPoint(1) }
    testCombat, testLockdown = true, true
    BagsBar:Layout()
    local after = { MainMenuBarBackpackButton:GetPoint(1) }
    assert(after[2] == bags and after[1] == before[1] and after[4] == before[4], 'back on the bag bar')
    testCombat, testLockdown = false, false
    -- Count is the backpack's free slots.
    assert(M.TextRegion(MainMenuBarBackpackButton, 'count') == MainMenuBarBackpackButton.FreeSlots)
    assert(MainMenuBarBackpackButton.FreeSlots.points[1][1] == 'BOTTOMRIGHT', 'placed like a Count text')

    -- Show: Always, Mouseover or Hidden only.
    assert(not M:SetOption('micro', 'visibility', 'combat') and not M:SetOption('bags', 'visibility', 'custom'), 'no conditions')
    assert(M:SetOption('micro', 'visibility', 'hidden') and not micro:IsShown(), 'Hidden')
    assert(addon:SetEditMode(true) and micro:IsShown() and ModeUIMicroMenuMover:IsShown(), 'shown in Edit Mode')
    assert(PM.elements.actionBarsMicro and PM.elements.actionBarsMicro.label == 'Micro Menu' and PM.elements.actionBarsBags.label == 'Bag Bar')
    local p = PM:GetPosition('actionBarsBags')
    assert(p.target == 'actionBarsMicro' and p.point == 'BOTTOMRIGHT' and p.relativePoint == 'TOPRIGHT', 'bags sit on the micro menu, right edges lined up')
    assert(addon:SetEditMode(false) and not micro:IsShown())
    assert(M:SetOption('micro', 'visibility', 'mouseover') and micro:IsShown() and micro:GetAlpha() == 0, 'Mouseover fades it')
    micro.mouseOver = true; M:UpdateFade()
    assert(micro:GetAlpha() == 1, 'and shows it under the mouse')
    micro.mouseOver = false
    assert(M:SetOption('micro', 'visibility', 'always') and micro:GetAlpha() == 1)
    -- Keybind Mode leaves them alone.
    assert(M:SetKeybindMode(true) and not (M.catchers.micro and M.catchers.micro[1] and M.catchers.micro[1]:IsShown()), 'no keybind catchers')
    M:SetKeybindMode(false)

    -- The settings page: no keybinds, paging, glows or cooldowns; the preview shows the glyphs.
    addon:SelectConfigPage('actionBars')
    local page = addon.configWindow.pages.actionBars
    page.SetEditing('micro')
    local view = M.previewView
    assert(view.buttons[2].icon.atlas == 'UI-HUD-MicroMenu-SpellbookMicroButton-Up' and view.buttons[1].icon.texture == 'portrait:player', 'the preview shows the glyphs and your portrait')
    local choices = {}
    page.visibilitySelect.scripts.OnClick(page.visibilitySelect)
    for _, row in ipairs(page.visibilitySelect.rows) do if row:IsShown() then choices[#choices + 1] = row.choice.id end end
    page.visibilitySelect.menu:Hide()
    assert(table.concat(choices, ',') == 'always,mouseover,hidden', 'three Show choices')
    page.SetEditing('bags')
    assert(page.textPart() == 'count' and view.buttons[6].Count:GetText() == '(16)', 'the bag bar edits its free-slot count')
    page.SetEditing('bar1')
    assert(page.textPart() == 'count', 'the text choice stays until changed')

    -- Switching off gives the buttons back and Blizzard's bars their alpha.
    addon:SetModuleEnabled('actionBars', false)
    assert(CharacterMicroButton:GetParent() == MicroMenu and MainMenuBarBackpackButton:GetParent() == BagsBar)
    assert(MicroMenu:GetAlpha() == 1 and BagsBar:GetAlpha() == 1 and not micro:IsShown())
]==], "utility bars")

print("utility bars: all checks passed")
