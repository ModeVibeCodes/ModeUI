-- Bags: one Mode window for every bag, fed by a stubbed C_Container, that
-- follows Blizzard's bag frames (stubbed with Forever's names and toggles):
-- capture and release of Blizzard's frames, sections, Blizzard's item button
-- template on bag holders, slot looks (quality, quest, new, junk, item
-- level), search, the view order, Clean Up, the footer, moving by the
-- header, Edit Mode, settings, validation, the page and persistence.
-- Simulated client; not WoW rendering, mouse, taint or secure execution.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/skin_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:GetTop() local _, y = self:GetCenter(); return y + self:GetHeight() / 2 end
    function methods:GetRight() local x = self:GetCenter(); return x + self:GetWidth() / 2 end
    function methods:SetToplevel(value) self.toplevel = value end
    function methods:SetUserPlaced(value) self.userPlaced = value end
    function methods:SetDesaturated(value) assert(type(value) == 'boolean'); self.desaturated = value end
    -- Blizzard's ContainerFrameItemButtonTemplate, as far as ModeUI touches it:
    -- the icon, count, art and cooldown, and its own click handler, which finds
    -- the bag through the button's parent (ContainerFrameItemButtonMixin).
    used, picked = {}, {}
    local createFrame = CreateFrame
    function CreateFrame(kind, name, parent, template)
        if kind ~= 'ItemButton' then return createFrame(kind, name, parent, template) end
        assert(template == 'ContainerFrameItemButtonTemplate', 'Blizzard\'s bag item button template')
        assert(type(name) == 'string' and name:find('^ModeUI'), 'named, so the template\'s children are too')
        local b = createFrame('Button', name, parent)
        b.kind, b.template = 'ItemButton', template
        b.icon = b:CreateTexture(nil, 'BORDER')
        b.Count = b:CreateFontString()
        for _, key in ipairs({ 'IconBorder', 'IconOverlay', 'searchOverlay', 'NewItemTexture', 'JunkIcon', 'IconQuestTexture' }) do
            b[key] = b:CreateTexture(nil, 'OVERLAY')
        end
        b.NormalTexture, b.PushedTexture, b.HighlightTexture = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
        function b:GetNormalTexture() return self.NormalTexture end
        b.Cooldown = createFrame('Cooldown', name .. 'Cooldown', b)
        b.Cooldown.countdown = b.Cooldown:CreateFontString()
        function b.Cooldown:GetCountdownFontString() return self.countdown end
        function b:GetBagID() return self.bagID or self:GetParent():GetID() end
        b:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then used[#used + 1] = { self:GetBagID(), self:GetID() }
            else picked[#picked + 1] = { self:GetBagID(), self:GetID() } end
        end)
        b:Hide()
        return b
    end
    -- The bags: a 16-slot backpack, two 8-slot bags, an empty bag slot, the
    -- reagent bag (4) and the keyring (4).
    bags = { [0] = 16, [1] = 8, [2] = 8, [3] = 0, [4] = 0, [5] = 4, [-2] = 4 }
    items = {
        [0] = { [1] = { iconFileID = 101, stackCount = 5, quality = 1, itemID = 1, itemName = 'Potion', hyperlink = 'item:1' },
            [2] = { iconFileID = 102, stackCount = 1, quality = 2, itemID = 2, itemName = 'Boots', hyperlink = 'item:2' },
            [3] = { iconFileID = 103, stackCount = 1, quality = 0, itemID = 3, itemName = 'Broken Fang', hyperlink = 'item:3' },
            [4] = { iconFileID = 104, stackCount = 1, quality = 4, itemID = 4, itemName = 'Axe', hyperlink = 'item:4' },
            [5] = { iconFileID = 105, stackCount = 1, quality = 1, itemID = 5, itemName = 'Letter', hyperlink = 'item:5' } },
        [1] = { [8] = { iconFileID = 106, stackCount = 20, quality = 1, itemID = 6, itemName = 'Linen', hyperlink = 'item:6' } },
        [5] = { [1] = { iconFileID = 107, stackCount = 3, quality = 1, itemID = 7, itemName = 'Herb', hyperlink = 'item:7' } },
        [-2] = { [1] = { iconFileID = 108, stackCount = 1, quality = 1, itemID = 8, itemName = 'Key', hyperlink = 'item:8' } },
    }
    classes = { [1] = 0, [2] = 4, [3] = 15, [4] = 2, [5] = 12, [6] = 7, [7] = 7, [8] = 13 }
    newItems, quests, sorts, search = {}, { ['0:5'] = true }, 0, ''
    Constants = { InventoryConstants = { NumBagSlots = 4, NumReagentBagSlots = 1 } }
    C_ActionBar = { ShouldShowKeyring = function() return true end }
    function GetKeyRingSize() return bags[-2] end
    function GetMoney() return 123456 end
    local function Item(bag, slot) return items[bag] and items[bag][slot] end
    C_Container = {
        GetContainerNumSlots = function(bag) return bags[bag] or 0 end,
        GetContainerNumFreeSlots = function(bag)
            local free = bags[bag] or 0
            for slot = 1, bags[bag] or 0 do if Item(bag, slot) then free = free - 1 end end
            return free
        end,
        GetContainerItemInfo = function(bag, slot)
            local item = Item(bag, slot)
            if not item then return nil end
            local copy = {}
            for k, v in pairs(item) do copy[k] = v end
            copy.isFiltered = search ~= '' and not item.itemName:lower():find(search:lower(), 1, true)
            return copy
        end,
        GetContainerItemQuestInfo = function(bag, slot) return { isQuestItem = quests[bag .. ':' .. slot] == true, isActive = false } end,
        GetContainerItemCooldown = function(bag, slot) if bag == 0 and slot == 1 then return 100, 30, 1 end return 0, 0, 1 end,
        SetItemSearch = function(text) search = text end,
        SortBags = function() sorts = sorts + 1 end,
    }
    C_Container.ContainerIDToInventoryID = function(bag) return 30 + bag end
    -- Equipped bags: 1 and 2 (8 slots each), 3 and 4 empty, the reagent bag (5).
    bagIcons, bagQualities, equipped, pickedBags, cursor = { [31] = 201, [32] = 202, [35] = 205 }, { [32] = 3 }, {}, {}, nil
    function GetInventoryItemTexture(unit, slot) return bagIcons[slot] end
    function GetInventoryItemQuality(unit, slot) return bagQualities[slot] or (bagIcons[slot] and 1) or nil end
    function CursorHasItem() return cursor ~= nil end
    function PutItemInBag(slot) equipped[#equipped + 1] = slot end
    function PickupBagFromSlot(slot) pickedBags[#pickedBags + 1] = slot end
    C_NewItems = { IsNewItem = function(bag, slot) return newItems[bag .. ':' .. slot] == true end }
    C_Item = {
        GetItemInfoInstant = function(link)
            local id = tonumber(link:match('item:(%d+)'))
            return id, nil, nil, (classes[id] == 2 or classes[id] == 4) and 'INVTYPE_FEET' or '', nil, classes[id], 0
        end,
        GetDetailedItemLevelInfo = function(link) return link == 'item:2' and 27 or link == 'item:4' and 60 or nil end,
        GetItemQualityColor = function(q) return ({ [0] = 0.62, 1, 0.12, 0, 0.64 })[q], 0.5, 0.5, '' end,
    }
    -- Blizzard's bag frames and its toggles (combined bags): opening shows
    -- the combined frame, closing hides every bag frame.
    ContainerFrameCombinedBags = CreateFrame('Frame', nil, UIParent); ContainerFrameCombinedBags:Hide()
    for i = 1, 7 do local f = CreateFrame('Frame', 'ContainerFrame' .. i, UIParent); f:SetID(i - 1); f:Hide() end
    ContainerFrame7:SetID(6) -- a bank bag frame
    function OpenAllBags() ContainerFrameCombinedBags:Show() end
    function CloseAllBags()
        ContainerFrameCombinedBags:Hide()
        for i = 1, 7 do _G['ContainerFrame' .. i]:Hide() end
    end
    function ToggleAllBags() if ContainerFrameCombinedBags:IsShown() then CloseAllBags() else OpenAllBags() end end
    fullscreen = CreateFrame('Frame', nil, UIParent)
    function ContainerFrame_SetFullScreenFrame(frame) ContainerFrameCombinedBags:SetParent(frame) end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Kit, Skin = addon.Bags, addon.Kit, addon.Skin
    local Tone = addon.Style.Tone
    local G = Tone.graphite
    assert(M and addon.modules.bags == M and not M.enabled and M.category == 'interface', 'registered under Interface, off by default')
    assert(M.db.columns == 12 and M.db.slotSize == 36 and M.db.spacing == 3 and M.db.sortMode == 'bags' and M.db.growFrom == 'BOTTOMRIGHT')
    assert(M.db.backgroundColor[1] == G.panel[1] and M.db.headerColor[1] == G.raised[1] and M.db.slotColor[1] == Tone.mono.panel[1], 'the Mode window colors')
    assert(M.db.borderColor == nil and M.db.corner == nil and M.db.slotBorderSize == nil and M.db.fontMedia == '', 'Mode edges, the Mode typeface')
    assert(M.frame == nil and _G.ModeUIBagsFrame == nil, 'nothing built while off')
    OpenAllBags()
    assert(ContainerFrameCombinedBags:GetParent() == UIParent, 'Blizzard\'s bags untouched while off')
    CloseAllBags()

    addon:SetModuleEnabled('bags', true)
    local frame = M.frame
    assert(frame and not frame:IsShown() and frame.toplevel and frame.clamped, 'window built, closed')
    assert(ContainerFrameCombinedBags:GetParent() == M.hider and not M.hider:IsShown(), 'Blizzard\'s combined bags wait under a hidden frame')
    assert(ContainerFrame1:GetParent() == M.hider and ContainerFrame7:GetParent() == UIParent, 'held bags captured, the bank bag frame left alone')
    -- Every slot's button is made as the module starts, out of combat (one
    -- made in combat taints Blizzard's item use), none of them drawn yet.
    assert(#M.slots == 40 and M:HasButton(-2, 4) and M:HasButton(5, 4) and not M.buttons[0][1]:IsShown() and M:HasUndrawn(),
        'every slot made at start')
    assert(frame.width == 2 * (M.g.border + M.g.pad) + 12 * 36 + 11 * 3 and M.mover.width == frame.width, 'sized for Edit Mode')
    -- A loading screen draws them once behind it, then the window closes.
    FireEvent('PLAYER_ENTERING_WORLD')
    assert(not M:HasUndrawn() and M.buttons[0][1]:IsShown() and not frame:IsShown() and not M.open, 'drawn once, closed again')
    FireEvent('PLAYER_ENTERING_WORLD')
    assert(not frame:IsShown() and not M.open, 'nothing new: stays closed')

    -- Blizzard opens its bags (the B key): the window follows.
    OpenAllBags()
    assert(frame:IsShown() and M.open, 'opens with Blizzard\'s bags')
    assert(not ContainerFrameCombinedBags:IsVisible(), 'Blizzard\'s own frame never draws')
    -- 16 + 8 + 8 held slots, 4 reagent and 4 keyring slots.
    local shown = 0
    for _, b in ipairs(M.slots) do if b:IsShown() then shown = shown + 1 end end
    assert(shown == 40, 'every slot of every bag: ' .. shown)
    assert(frame.labels[1].text:GetText() == 'Reagents' and frame.labels[2].text:GetText() == 'Keyring', 'reagent and keyring sections')

    -- Slots are Blizzard's item buttons on a holder carrying the bag's ID.
    local potion, boots, fang, axe, letter = M.buttons[0][1], M.buttons[0][2], M.buttons[0][3], M.buttons[0][4], M.buttons[0][5]
    assert(potion.template == 'ContainerFrameItemButtonTemplate' and potion:GetID() == 1 and potion:GetParent():GetID() == 0)
    assert(potion.bagID == nil and potion.attributes == nil, 'nothing written to Blizzard\'s button')
    assert(M.buttons[-2][1]:GetParent():GetID() == -2 and M.buttons[5][1]:GetParent():GetID() == 5, 'keyring and reagent holders')
    potion:GetScript('OnClick')(potion, 'RightButton')
    assert(used[1][1] == 0 and used[1][2] == 1, 'Blizzard\'s click uses the right bag and slot')
    M.buttons[1][8]:GetScript('OnClick')(M.buttons[1][8], 'LeftButton')
    assert(picked[1][1] == 1 and picked[1][2] == 8)

    -- The look: icon, count, rims by quality, quest and new, junk, item level.
    local art = M.art
    assert(potion.icon.texture == 101 and art[potion].count:GetText() == '5' and art[boots].count:GetText() == '', 'icon and count')
    assert(potion.Count.alpha == 0 and potion.IconBorder.alpha == 0 and potion.NormalTexture.alpha == 0, 'Blizzard\'s art faded')
    -- A Mode slot: 36 x 30, a face in Mono panel, the `group` edge outside it.
    local box = art[potion].box
    assert(potion.width == 36 and potion.height == 30, 'wider than tall')
    assert(box.faceKey == 'Solid' and box.face.vertexColor[1] == Tone.mono.panel[1] and box.face.vertexColor[4] == 1, 'a Mono panel face')
    assert(box.modeEdge.preset == 'group' and box.modeEdge.holder:IsShown() and Point(box.edgeFrame)[4] == 0, 'the group edge just outside')
    local function Rim(button) return art[button].box.modeEdge.tint end
    assert(Rim(potion) == nil, 'common: the edge\'s own Gunmetal')
    assert(Rim(boots)[1] == 0.12 and Rim(axe)[1] == 0.64, 'uncommon and epic in quality colors')
    assert(Rim(letter)[1] == M.db.questColor[1], 'quest item in Quest Color')
    assert(art[fang].junk:IsShown() and fang.icon.desaturated, 'junk: coin and faded')
    assert(art[boots].level:IsShown() and art[boots].level:GetText() == '27' and not art[potion].level:IsShown(), 'item level on armor only')
    assert(potion.Cooldown.cooldownStart == 100 and potion.Cooldown.cooldownDuration == 30, 'cooldown swipe')
    newItems['0:1'] = true; FireEvent('BAG_NEW_ITEMS_UPDATED')
    assert(Rim(potion)[1] == Tone.ivory[1], 'new items in Ivory')
    newItems['0:1'] = nil; potion.scripts.OnEnter(potion)
    assert(Rim(potion) == nil, 'pointing at it clears the mark')
    -- Quest items: a small quest mark in the corner.
    assert(art[letter].quest:IsShown() and art[letter].quest.texture:find('Icons\\Quest', 1, true) and art[letter].quest.vertexColor[1] == M.db.questColor[1], 'a quest mark')
    assert(Point(art[letter].quest)[1] == 'TOPRIGHT' and not art[potion].quest:IsShown(), 'top right, quest items only')
    -- Cooldown numbers: the Mode typeface's Bold at Count Size, cooldown color, centered.
    local countdown = potion.Cooldown.countdown
    assert(countdown.font[1] == addon.Style.Weighted(Kit.FontPath(M.db, 'bags'), 'bold') and countdown.font[2] == 12, 'Bold at Count Size')
    assert(countdown.color[1] == Tone.cooldown[1] and Point(countdown)[1] == 'CENTER', 'cooldown color, centered')
    -- Clean Up: the broom glyph, the close cross's size.
    local clean = frame.header.clean
    assert(clean.icon and clean.icon.texture:find('CleanUp', 1, true) and clean.text == nil and clean.width == frame.header.close.width, 'a broom')
    assert(Point(clean)[2] == frame.header.close and Point(frame.header.sort)[2] == clean, 'between Sort and close')
    -- The window: a Mode window with a Mode Title header and a Mode field.
    local wp = Skin.parts[frame]
    assert(wp.faceKey == 'Surface' and wp.face.vertexColor[1] == G.panel[1] and wp.face.vertexColor[4] == 0.95, 'Mode Surface at 95%')
    assert(wp.modeEdge.preset == 'window' and Point(wp.edgeFrame)[4] == 3 and not wp.modeEdge.below:IsShown(), 'the window edge inside; no drop')
    assert(Skin.parts[frame.header].faceKey == 'FG' and Skin.parts[frame.header].face.vertexColor[1] == G.raised[1], 'a Mode-FG header')
    assert(frame.divider.vertexColor[1] == G.line[1] and frame.header.title.color[1] == G.white[1], 'a Graphite line; the title in Graphite white')
    local field = Skin.parts[frame.search]
    assert(field.faceKey == 'Solid' and field.face.vertexColor[1] == G.base[1] and field.modeEdge.preset == 'control', 'search: a Mode field')
    frame.search:SetFocus(); frame.search.scripts.OnEditFocusGained(frame.search)
    assert(field.modeEdge.highlight[1] == Tone.ivory[1], 'Ivory while typing')
    frame.search:ClearFocus(); frame.search.scripts.OnEditFocusLost(frame.search)
    assert(field.modeEdge.highlight == nil)

    -- Geometry: whole pixels, Columns wide.
    local g = M.g
    assert(g.border == 3 and frame.width == 2 * (g.border + g.pad) + 12 * 36 + 11 * 3, 'width from the settings')
    assert(potion.points[1][1] == 'TOPLEFT' and potion.points[1][4] == g.left and potion.points[1][5] == -g.gridTop, 'first slot top left')
    assert(M.buttons[0][13].points[1][5] == -(g.gridTop + 30 + 3), 'the 13th slot starts row two (30 high, 3 apart)')
    assert(frame.points[1][1] == 'BOTTOMRIGHT' and frame.points[1][2] == M.mover, 'hangs from its stand-in at Grow From')

    -- Footer: the Bag Bar (equipped bag slots with their free slots), the
    -- free count over a capacity bar, and the money.
    local bb = frame.bagButtons
    assert(bb[1]:IsShown() and bb[5]:IsShown() and bb[0] == nil and bb[-2] == nil, 'the four bag slots and the reagent bag')
    assert(bb[1].icon.texture == 201 and bb[1].free:GetText() == '7' and bb[2].free:GetText() == '8', 'icons and free slots')
    assert(not bb[3].icon:IsShown() and bb[3].empty:IsShown() and bb[3].free:GetText() == '', 'an empty bag slot: the bag glyph')
    assert(bb[2].box.modeEdge.tint[1] == 0 and bb[1].box.modeEdge.tint == nil, 'a rare bag in its quality')
    assert(bb[1].width == 26 and bb[1].height == 22 and Point(bb[2])[4] == Point(bb[1])[4] + 26 + 3, 'small Mode slots, 3px apart')
    bb[3].scripts.OnReceiveDrag(bb[3]); assert(equipped[1] == 33, 'a bag dropped on a slot goes on')
    bb[1].scripts.OnClick(bb[1], 'LeftButton'); assert(#equipped == 1, 'a click without a bag does nothing')
    cursor = 'bag'; bb[4].scripts.OnClick(bb[4], 'LeftButton'); cursor = nil
    assert(equipped[2] == 34, 'a click with a bag on the cursor puts it on')
    bb[1].scripts.OnDragStart(bb[1]); assert(pickedBags[1] == 31, 'dragging a bag off picks it up')
    bb[1].scripts.OnEnter(bb[1])
    assert(potion.alpha == 0.25 and M.buttons[1][8].alpha == 1, 'pointing at a bag lights its slots')
    bb[1].scripts.OnLeave(bb[1]); assert(potion.alpha == 1, 'and back')
    assert(frame.freeCount:GetText() == '29' and frame.freeLabel:GetText() == 'free', frame.freeCount:GetText())
    assert(frame.freeCount.color[1] == Tone.celadon[1], 'Celadon with room')
    assert(frame.freeMeter.value == 7 and select(2, frame.freeMeter:GetMinMaxValues()) == 36, 'the capacity bar fills as the bags fill')
    assert(M.FullnessColor(3, 36)[1] == Tone.ivory[1] and M.FullnessColor(0, 36)[1] == Tone.rosewood[1], 'Ivory near full, Rosewood full')
    assert(frame.moneyText:GetText():find('^12|T') and frame.moneyText:GetText():find('34|T') and frame.moneyText:GetText():find('56|T'), 'gold, silver, copper')

    -- Search: the game's own bag search; others fade.
    frame.search:SetText('pot'); frame.search:GetScript('OnTextChanged')(frame.search)
    assert(search == 'pot' and potion.alpha == 1 and boots.alpha == 0.25 and M.buttons[0][9].alpha == 0.25, 'matches stay, the rest fade')
    -- View order: Quality puts the epic axe first, empty slots last.
    assert(M:SetOption('sortMode', 'quality'))
    assert(axe.points[1][4] == g.left and axe.points[1][5] == -g.gridTop, 'best quality first')
    assert(frame.header.sort.text:GetText() == 'Quality', 'the Sort button names the order')
    -- The header's Sort dropdown: a menu of the orders under the button.
    local sort, menu = frame.header.sort, frame.sortMenu
    assert(sort.chevron and not menu:IsShown(), 'a chevron; the menu starts closed')
    sort:GetScript('OnClick')(sort)
    assert(menu:IsShown() and #menu.rows == 4 and menu.events.GLOBAL_MOUSE_DOWN, 'the menu opens')
    assert(menu.rows[2].chosen and not menu.rows[1].chosen and menu.rows[2].text:GetText() == 'Quality', 'the chosen order is marked')
    assert(menu.points[1][1] == 'TOPRIGHT' and menu.points[1][2] == sort and menu.width >= sort.width, 'hangs under the button')
    menu.rows[3]:GetScript('OnClick')(menu.rows[3])
    assert(M.db.sortMode == 'type' and not menu:IsShown() and sort.text:GetText() == 'Type', 'picking an order sets Sort, closes the menu')
    sort:GetScript('OnClick')(sort); sort.mouseOver = true; FireEvent('GLOBAL_MOUSE_DOWN')
    assert(menu:IsShown(), 'a click on the button is its own toggle')
    sort.mouseOver = false; FireEvent('GLOBAL_MOUSE_DOWN')
    assert(not menu:IsShown() and not menu.events.GLOBAL_MOUSE_DOWN, 'a click elsewhere closes it')
    sort:GetScript('OnClick')(sort); sort:GetScript('OnClick')(sort); assert(not menu:IsShown(), 'the button toggles it')
    assert(M:SetOption('sortMode', 'bags') and potion.points[1][5] == -g.gridTop)
    sort:GetScript('OnClick')(sort)
    -- Clean Up: the game's sort, never in combat.
    frame.header.clean:GetScript('OnClick')(frame.header.clean)
    assert(sorts == 1, 'Clean Up sorts the bags')
    testCombat = true; assert(not M:CleanUp() and sorts == 1, 'not in combat'); testCombat = false

    -- Closing: Blizzard closes, the window follows and the search clears.
    CloseAllBags()
    assert(not frame:IsShown() and search == '' and frame.search:GetText() == '', 'closes with Blizzard\'s bags, search cleared')
    assert(not menu:IsShown(), 'the Sort menu closes with the window')
    ToggleAllBags(); assert(frame:IsShown(), 'toggles open')
    frame.header.close:GetScript('OnClick')(frame.header.close)
    assert(not frame:IsShown() and not ContainerFrameCombinedBags:IsShown(), 'the close button closes Blizzard\'s bags too')
    -- A frame Blizzard reuses for a bank bag stays Blizzard's.
    ContainerFrame7:Show()
    assert(ContainerFrame7:GetParent() == UIParent and not frame:IsShown(), 'bank bags aren\'t ModeUI\'s')
    ContainerFrame7:Hide()
    -- Blizzard moves its bags under a fullscreen frame; ModeUI takes them back.
    ContainerFrame_SetFullScreenFrame(fullscreen)
    assert(ContainerFrameCombinedBags:GetParent() == M.hider, 'taken back after the fullscreen move')
    -- Bag contents change while closed: redrawn as it opens.
    items[1][1] = { iconFileID = 109, stackCount = 2, quality = 3, itemID = 9, itemName = 'Gem', hyperlink = 'item:9' }
    FireEvent('BAG_UPDATE_DELAYED')
    assert(M.stale, 'marked stale while closed')
    OpenAllBags()
    assert(M.buttons[1][1].icon.texture == 109 and not M.stale, 'redrawn as it opens')
    -- A bag grows during combat lockdown: its new slots get no button until
    -- combat ends. Just before combat (PLAYER_REGEN_DISABLED, before the
    -- lockdown) and after it, every slot gets one.
    testCombat, testLockdown = true, true
    bags[2] = 10; FireEvent('BAG_CONTAINER_UPDATE')
    assert(not M:HasButton(2, 9) and M.layoutPending and M.buttons[2][8]:IsShown(), 'no button made in combat; the rest drawn')
    testCombat, testLockdown = false, false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(M.buttons[2][9]:IsShown() and M.buttons[2][10]:IsShown() and not M.layoutPending, 'made and placed after combat')
    bags[2] = 12; testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    assert(M:HasButton(2, 12), 'made just before the lockdown')
    testCombat, bags[2] = false, 8; FireEvent('BAG_CONTAINER_UPDATE')
    assert(not M.buttons[2][9]:IsShown() and M.buttons[2][8]:IsShown(), 'back to 8 slots')

    -- Settings: live, validated.
    assert(M:SetOption('columns', 8) and frame.width == 2 * (g.border + g.pad) + 8 * 36 + 7 * 3, 'Columns')
    assert(not M:SetOption('columns', 40) and not M:SetOption('growFrom', 'CENTER') and not M:SetOption('slotColor', { 2, 0, 0 }), 'bad values refused')
    -- Border Style and Border Metal (owner, November 17, 2026): the window and
    -- its Sort menu in Mode-Border in its own metal by default; slots keep
    -- theirs; any style keeps the window's size.
    local edge, menuEdge, slotEdge = wp.modeEdge, menu.parts.modeEdge, art[axe].box.modeEdge
    assert(M.db.edgeStyle == 'obsidian' and M.db.edgeMetal == 'default' and edge.styleId == 'obsidian' and edge:Metal() == Tone.metal.obsidian, 'Mode-Border in its own metal')
    local width, height, slotStyle = frame.width, frame.height, slotEdge.styleId
    assert(M:SetOption('edgeStyle', 'obsidianEmpty') and edge.styleId == 'obsidianEmpty' and menuEdge.styleId == 'obsidianEmpty', 'Mode-Empty: window and Sort menu')
    assert(frame.width == width and frame.height == height and slotEdge.styleId == slotStyle, 'same size; slots keep their edge')
    assert(M:SetOption('edgeMetal', 'gunmetal') and edge:Metal() == Tone.metal.gunmetal and menuEdge:Metal() == Tone.metal.gunmetal, 'Gunmetal')
    assert(not M:SetOption('edgeStyle', 'nope') and not M:SetOption('edgeMetal', 'gold') and M.db.edgeStyle == 'obsidianEmpty', 'unknown styles are refused')
    assert(M:SetOption('edgeStyle', 'obsidian') and M:SetOption('edgeMetal', 'default') and edge:Metal() == Tone.metal.obsidian)
    assert(M:SetOption('reagentSection', false) and M:SetOption('keyring', false))
    assert(not frame.labels[1].text:IsShown() and not frame.labels[2].text:IsShown(), 'sections off')
    assert(M.buttons[5][1]:IsShown() and not M.buttons[-2][1]:IsShown(), 'reagents join the bags; no keyring')
    assert(M:SetOption('splitBags', true))
    assert(M.buttons[1][1].points[1][5] < M.buttons[0][16].points[1][5] - 30, 'each bag its own block')
    assert(M:SetOption('showSearch', false) and not frame.search:IsShown() and M.g.gridTop < g.gridTop, 'no search box')
    assert(M:SetOption('qualityBorders', false) and Rim(axe) == nil, 'quality borders off')
    assert(M:SetOption('scale', 150) and frame.scale == 1.5 and M.mover.width == frame.width * 1.5, 'scale; the stand-in covers it')
    assert(M:SetOption('growFrom', 'TOPLEFT') and frame.points[1][1] == 'TOPLEFT')

    -- Moving by the header, unlocked and out of combat.
    frame.header:GetScript('OnDragStart')(frame.header)
    assert(frame.moving, 'drags')
    frame:ClearAllPoints(); frame:SetPoint('CENTER', UIParent, 'CENTER', 100, 50)
    frame.header:GetScript('OnDragStop')(frame.header)
    local position = ModeUIDB.profiles.Default.positions.modeBags
    assert(position.point == 'TOPLEFT' and position.relativePoint == 'TOPLEFT' and position.target == 'screen', 'saved at its Grow From corner')
    assert(frame.points[1][2] == M.mover, 'hangs from the stand-in again')
    M:SetOption('locked', true)
    frame.moving = false; frame.header:GetScript('OnDragStart')(frame.header)
    assert(not frame.moving, 'locked: no dragging')

    -- Edit Mode shows the stand-in.
    M:SetEditMode(true); assert(M.mover:IsShown() and M.mover.label:GetText() == 'Bags')
    M:SetEditMode(false); assert(not M.mover:IsShown())

    -- The page: built on demand, on the standard tabs; Reset… in the footer
    -- instead of an in-page button.
    SlashCmdList.MODEUI(); addon:SelectConfigPage('bags')
    local page = M.page
    assert(page and page.columnsSlider and page.sortSelect and page.growPills and not page.resetButton, 'page controls')
    assert(page.borderStyle and page.borderMetal, 'Border and Border Metal')
    local tabs = {}
    for i, section in ipairs(page.sectionTabs.sections) do tabs[i] = section.title end
    assert(table.concat(tabs, ',') == 'General,Fill,Border,Text', table.concat(tabs, ','))
    local function TabOf(title)
        for _, row in ipairs(page.rows) do if row.settingsTitle == title then return row.section.title end end
    end
    assert(TabOf('Minimum Quality') == 'Border' and TabOf('Grow From') == 'General' and TabOf('Color') == 'Text',
        'slot quality rims on Border, Position on General, the item level color in its text card')
    local resets = addon:ConfigActionItems('reset', M)
    assert(#resets == 1 and resets[1].label == 'All of Bags' and #addon:ConfigActionItems('copy', M) == 0, 'Reset… resets all of Bags')
    -- Sort on the page is a dropdown of the same orders.
    local select = page.sortSelect
    assert(select.label:GetText() == 'Bag Order', select.label:GetText())
    select:GetScript('OnClick')(select)
    assert(select.menu:IsShown() and select.rows[4] and select.rows[4].label:GetText() == 'Name', 'the dropdown lists the orders')
    select.rows[2]:GetScript('OnClick')(select.rows[2])
    assert(M.db.sortMode == 'quality' and not select.menu:IsShown() and select.label:GetText() == 'Quality', 'picked from the dropdown')
    assert(frame.header.sort.text:GetText() == 'Quality', 'the header follows')
    assert(page.statusLabel:GetText():find('slots used', 1, true), page.statusLabel:GetText())
    assert(M:ResetToDefaults() and M.db.columns == 12 and M.db.growFrom == 'BOTTOMRIGHT' and not M.db.locked, 'reset')

    -- Off: Blizzard's frames go home (open bags show there) and the window hides.
    addon:SetModuleEnabled('bags', false)
    assert(not frame:IsShown() and ContainerFrameCombinedBags:GetParent() == fullscreen and ContainerFrameCombinedBags:IsShown(),
        'Blizzard\'s bags back where Blizzard put them, still open')
    assert(ContainerFrame1:GetParent() == UIParent)
    print('bags: all checks passed')
]==])

-- Settings persist, and bad saved data is refused, never reset.
local saved = world.saved()
saved.profiles.Default.modules.bags.columns = 10
saved.profiles.Default.modules.bags.sortMode = 'name'
local again = H.Load({ saved = saved, before = STUBS })
again.run([==[
    local M = addon.Bags
    assert(M.db.columns == 10 and M.db.sortMode == 'name' and M.db.version == 3, 'kept across reloads')
]==])
-- Version 1 -> 2: a window or title bar still at the old health color (#1C1E21) takes #131212; a picked one stays.
local v1 = world.saved()
local one = v1.profiles.Default.modules.bags
one.version, one.backgroundColor, one.headerColor = 1, { 28 / 255, 30 / 255, 33 / 255 }, { 1, 0, 0 }
H.Load({ saved = v1, before = STUBS }).run([==[
    local M, Kit = addon.Bags, addon.Kit
    assert(M.db.version == 3 and M.db.backgroundColor[1] == addon.Style.Tone.graphite.panel[1], 'the old health color follows (on to Graphite)')
    assert(M.db.headerColor[1] == 1, 'a picked title bar color stays')
]==])
-- Version 2 -> 3 (Phase 7): the edges' settings go; values still at
-- version 2's defaults take the Mode ones; picked values stay.
local v2 = world.saved()
local two = v2.profiles.Default.modules.bags
two.version, two.borderColor, two.corner, two.slotBorderColor, two.slotBorderSize = 2, { 1, 0, 0 }, 9, { 0, 1, 0 }, 3
two.backgroundColor, two.headerColor = { 19 / 255, 18 / 255, 18 / 255 }, { 19 / 255, 18 / 255, 18 / 255 }
two.slotColor, two.slotOpacity, two.slotSize, two.spacing, two.fontMedia = { 4 / 255, 4 / 255, 4 / 255 }, 75, 38, 6, 'Expressway'
H.Load({ saved = v2, before = STUBS }).run([==[
    local M, Tone = addon.Bags, addon.Style.Tone
    local db = M.db
    assert(db.version == 3 and db.borderColor == nil and db.corner == nil and db.slotBorderColor == nil and db.slotBorderSize == nil, 'edge settings gone')
    assert(db.backgroundColor[1] == Tone.graphite.panel[1] and db.headerColor[1] == Tone.graphite.raised[1], 'Graphite window and header')
    assert(db.slotColor[1] == Tone.mono.panel[1] and db.slotOpacity == 100 and db.slotSize == 36 and db.fontMedia == 'Mode', 'Mode slots')
    assert(db.spacing == 6, 'a picked spacing stays')
    assert(db.edgeStyle == 'obsidian' and db.edgeMetal == 'default', 'saved settings take the border defaults')
]==])
local bad = world.saved()
bad.profiles.Default.modules.bags.columns = 'many'
local ok = pcall(H.Load, { saved = bad, before = STUBS })
assert(not ok or bad.profiles.Default.modules.bags.columns == 'many', 'bad saved data is never replaced')
print('bags: persistence checks passed')
