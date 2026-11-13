local _, addon = ...
local M, W = addon.UnitFrames, addon.ConfigWidgets
if not M then return end

-- The Text tab: what each text slot shows (TextSlots.lua), one picker per
-- spot like EllesmereUI's text elements, then the style of one slot at a
-- time (font size, color, offsets), the name color and the font. Built by
-- CreateConfigPage (Settings.lua) with its helpers in `ui`.
function M:BuildTextTab(ui)
    local page, When = ui.page, ui.When
    -- The slot the Slot Style controls edit; picking what a slot shows, or
    -- clicking a text in the preview, switches to it.
    local styling = "right"
    local function Slots() return ui.db().texts end
    local function S() return Slots()[styling] end
    function page.SetTextSlot(slot)
        if M.slotPlaces[slot] then styling = slot; page:Refresh(); page:Layout() end
    end
    page.unitFrameTextSlot = function() return styling end
    local n = M.NestedControls(ui, S, function(key, value) M:SetTextOption(ui.Editing(), styling, key, value) end)
    local contents = M.choices.textContent
    local labels = {}
    for _, choice in ipairs(contents) do labels[choice.id] = choice.label end
    page.unitFrameTextSelects = {}
    local function SlotSelect(slot)
        page.unitFrameTextSelects[slot] = ui.Select(M.textSlotLabels[slot], function() return contents end,
            function() return Slots()[slot].content end, function(v)
                if M:SetTextOption(ui.Editing(), slot, "content", v) and v ~= "none" then page.SetTextSlot(slot) end
            end)
    end
    -- Style Slot lists every slot with what it shows.
    local function StyleChoices()
        local list = {}
        for _, slot in ipairs(M.textSlots) do
            list[#list + 1] = { id = slot, label = M.textSlotLabels[slot] .. " · " .. labels[Slots()[slot].content] }
        end
        return list
    end

    ui.Tab("Text", function()
        page:Group("Health Bar")
        for _, slot in ipairs(M.healthSlots) do SlotSelect(slot) end
        page:Group("Border")
        SlotSelect("border")
        When(function() return Slots().border.content ~= "none" end, function()
            ui.Select("Border Alignment", function() return M.choices.textAlign end, function() return Slots().border.align end,
                function(v) M:SetTextOption(ui.Editing(), "border", "align", v) end)
        end)
        When(function() return ui.db().showPower end, function()
            page:Group("Power Bar")
            for _, slot in ipairs(M.powerSlots) do SlotSelect(slot) end
        end)
        page:Group("Slot Style")
        page.unitFrameStyleSlot = ui.Select("Style Slot", StyleChoices, function() return styling end, page.SetTextSlot)
        ui.Mark("text")
        local size = page:Columns({ "Font Size" })
        page.unitFrameTextSize = n.Slider(size[1], M.textRanges.size, "size")
        local offsets = page:Columns({ "Offset X", "Offset Y" })
        page.unitFrameTextX = n.Slider(offsets[1], M.textRanges.x, "x", "px")
        page.unitFrameTextY = n.Slider(offsets[2], M.textRanges.y, "y", "px")
        page.unitFrameTextColor = n.Select("Color", M.choices.textColorMode, "colorMode")
        When(function() return S().colorMode == "custom" end, function() n.Color("Custom Color", "color") end)
        page:Group("Names")
        -- Plain text: Sky by default, or Champagne, Lilac, Frost, class or custom.
        ui.Choice("Name Color", "nameColorMode")
        When(function() return ui.db().nameColorMode == "custom" end, function() ui.Color("Custom Name Color", "nameColor") end)
        -- Pastel: class-colored names, class health and the class gradient ring all use it.
        ui.Slider("Class Color Softness", "classSoftness", "%")
        page:Group("Font")
        local _, refresh = W.FontDropdown(page:Row("Font", 42), ui.owner); page.refreshers[#page.refreshers + 1] = refresh
        ui.Toggles({ { "Text Outline", "outline" } })
        -- One choice for both shadows: None, Crisp (1px) or Lifted (1px plus a lighter one under it).
        local choices = {}
        for _, choice in ipairs(addon.Kit.SHADOW_CHOICES) do choices[#choices + 1] = { label = choice.label, value = choice.id, width = 96 } end
        local _, shadow = W.Exclusive(page:Row("Text Shadow", 48), choices, function() return addon.Kit.ShadowMode(ui.db()) end,
            function(mode)
                local on, lifted = addon.Kit.ShadowKeys(mode)
                M:SetFrameOption(ui.Editing(), "shadow", on); M:SetFrameOption(ui.Editing(), "liftedShadow", lifted)
            end)
        page.refreshers[#page.refreshers + 1] = shadow
        -- Default for numbers; names keep the Name Color and the level stays muted.
        ui.Color("Text Color", "textColor")
    end)
end
