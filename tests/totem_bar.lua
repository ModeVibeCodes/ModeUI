-- The totem bar reskin (Modules/ActionBars/Totem.lua): Blizzard's multi-cast
-- bar (MultiCastActionBarFrame, Forever's Blizzard_ActionBar/Shared) in the
-- Mode look, element rims, the picker, and back when Action Bars switch off.
-- A stand-in for Blizzard's frames and functions; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local TOTEMS = [==[
    local methods = getmetatable(UIParent).__index
    function methods:SetID(id) self.id = id end
    function methods:GetID() return self.id or 0 end
    function methods:SetRotation(r) self.rotation = r end
    function methods:GetHighlightTexture() return self.highlightTexture end
    EARTH_TOTEM_SLOT, FIRE_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT = 2, 1, 3, 4
    local function Tex(f) return f:CreateTexture() end
    local bar = CreateFrame('Frame', 'MultiCastActionBarFrame', UIParent); bar:SetSize(230, 38); bar:SetPoint('BOTTOM')
    local order = { EARTH_TOTEM_SLOT, FIRE_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT }
    for i = 1, 4 do
        local slot = CreateFrame('Button', 'MultiCastSlotButton' .. i, bar); slot:SetSize(30, 30); slot:SetPoint('BOTTOMLEFT', 36 + (i - 1) * 38, 3)
        slot.background, slot.overlayTex, slot.highlightTexture = Tex(slot), Tex(slot), Tex(slot)
        slot:SetID(order[i])
    end
    local function Button(name, parent)
        local b = CreateFrame('Button', name, parent or bar); b:SetSize(30, 30); b:SetPoint('CENTER')
        b.icon, b.overlayTex, b.NormalTexture = Tex(b), Tex(b), Tex(b)
        _G[name .. 'Highlight'] = Tex(b)
        return b
    end
    for i = 1, 12 do
        local b = Button('MultiCastActionButton' .. i)
        b.slotButton = _G['MultiCastSlotButton' .. ((i - 1) % 4 + 1)]
    end
    local summon = Button('MultiCastSummonSpellButton'); summon.flyoutButton = CreateFrame('Button', nil, summon); summon.flyoutButton.normalTexture = Tex(summon.flyoutButton)
    Button('MultiCastRecallSpellButton')
    local flyout = CreateFrame('Frame', 'MultiCastFlyoutFrame', bar); flyout:SetSize(32, 90); flyout.top, flyout.middle = Tex(flyout), Tex(flyout)
    flyout.buttons = {}
    for i = 1, 3 do
        local b = CreateFrame('Button', 'MultiCastFlyoutButton' .. i, flyout); b:SetSize(24, 24); b.icon = Tex(b); flyout.buttons[i] = b
    end
    local close = CreateFrame('Button', 'MultiCastFlyoutFrameCloseButton', flyout); close.normalTexture = Tex(close)
    local open = CreateFrame('Button', 'MultiCastFlyoutFrameOpenButton', bar); open.normalTexture = Tex(open)
    -- Blizzard's update functions (the reskin hooks them): they re-set the art's coordinates.
    function MultiCastSlotButton_Update(self, slot) self:SetID(slot); self.overlayTex:SetTexCoord(0, 1, 0, 1); self.background:SetTexCoord(0, 1, 0, 1) end
    function MultiCastActionButton_Update(self, id, index, slot) self.overlayTex:SetTexCoord(0, 1, 0, 1) end
    function MultiCastFlyoutFrame_ToggleFlyout(self, kind, parent) self.top:SetTexCoord(0, 1, 0, 1); self:Show() end
    function MultiCastFlyoutFrameOpenButton_Show(self) self.normalTexture:SetTexCoord(0, 1, 0, 1); self:Show() end
]==]
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua") .. TOTEMS

local world = H.Load({ before = STUBS })
world.run([==[
    local M, S = addon.ActionBars, addon.Style
    local Tone = S.Tone
    addon:SetModuleEnabled('actionBars', true)
    -- The buttons: Mode buttons in Action Bar 1's look at Blizzard's 30 x 30, Blizzard's frame art faded.
    local b1, art = MultiCastActionButton1, M.art[MultiCastActionButton1]
    assert(art and art.edge.preset == 'frame' and art.edge.holder:IsShown() and b1.width == 30 and b1.height == 30, 'a Mode button at 30 x 30')
    assert(art.face.texture == S.AssetPath('FGBase') and b1.overlayTex.alpha == 0 and b1.NormalTexture.alpha == 0, 'the Mode face; Blizzard art faded')
    assert(MultiCastSummonSpellButtonHighlight.alpha == 0 and M.art[MultiCastSummonSpellButton] and M.art[MultiCastRecallSpellButton], 'Call and Recall too')
    -- Each element's rim in its color: button 1 sits on slot 1 (Earth), button 2 on Fire.
    assert(art.edge.tint == Tone.totem.earth and M.art[MultiCastActionButton2].edge.tint == Tone.totem.fire, 'element rims')
    local slot = MultiCastSlotButton3
    assert(slot.background.alpha == 0 and slot.overlayTex.alpha == 0 and slot.highlightTexture.alpha == 0, 'the empty slot faded')
    assert(M.art[slot].edge.tint == Tone.totem.water and M.art[slot].face:IsShown(), 'the empty slot: face and Water rim')
    -- Blizzard updates repaint; the faded art stays faded.
    MultiCastSlotButton_Update(MultiCastSlotButton1, AIR_TOTEM_SLOT)
    assert(M.art[MultiCastSlotButton1].edge.tint == Tone.totem.air and MultiCastSlotButton1.overlayTex.alpha == 0, 'a slot that changes element')
    MultiCastActionButton_Update(b1, 1, 1, AIR_TOTEM_SLOT)
    assert(art.edge.tint == Tone.totem.air and b1.overlayTex.alpha == 0, 'its button follows')
    -- The picker: a Surface panel in Mode-Border, cropped icons, the Mode chevrons.
    MultiCastFlyoutFrame_ToggleFlyout(MultiCastFlyoutFrame, 'slot', b1)
    assert(MultiCastFlyoutFrame.top.alpha == 0 and MultiCastFlyoutFrame.middle.alpha == 0 and M.totemPanel.edge.holder:IsShown(), 'the panel')
    assert(M.totemPanel.face.vertexColor[1] == Tone.graphite.panel[1] and M.totemPanel.edge.styleId == 'obsidian', 'Graphite in Mode-Border')
    assert(MultiCastFlyoutButton1.icon.texCoord[1] == 0.08, 'icons cropped')
    local chevron = M.totemChevrons[MultiCastFlyoutFrameCloseButton]
    assert(chevron and chevron:IsShown() and MultiCastFlyoutFrameCloseButton.normalTexture.alpha == 0 and chevron.vertexColor[1] == Tone.ivory[1], 'the close chevron')
    MultiCastFlyoutFrameOpenButton_Show(MultiCastFlyoutFrameOpenButton)
    assert(M.totemChevrons[MultiCastFlyoutFrameOpenButton].rotation == math.pi and MultiCastFlyoutFrameOpenButton.normalTexture.alpha == 0, 'the open chevron points up')
    -- Switched off: Blizzard's art back, ModeUI's hidden.
    addon:SetModuleEnabled('actionBars', false)
    assert(MultiCastSlotButton3.background.alpha == 1 and b1.overlayTex.alpha == 1 and not M.art[slot].edge.holder:IsShown(), "Blizzard's art back")
    assert(not chevron:IsShown() and MultiCastFlyoutFrameCloseButton.normalTexture.alpha == 1 and not M.totemPanel.face:IsShown(), 'the chevrons and panel gone')
    MultiCastSlotButton_Update(slot, WATER_TOTEM_SLOT)
    assert(slot.background.alpha == 1, 'the hooks leave Blizzard alone while off')
    -- On again: the Mode look returns.
    addon:SetModuleEnabled('actionBars', true)
    assert(slot.background.alpha == 0 and M.art[slot].edge.holder:IsShown() and M.art[slot].face:IsShown(), 'back in the Mode look')
]==], "totem bar")
print("totem bar: all checks passed")
