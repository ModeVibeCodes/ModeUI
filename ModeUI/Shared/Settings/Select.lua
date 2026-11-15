local _,addon=...
local W,T=addon.ConfigWidgets,addon.InterfaceTheme

-- Shared compact chooser: a 28 px field with the chosen label at the left, a
-- chevron at the right, and a bounded menu.
-- options.multi: a pick list. Each choice carries `selected`; a click calls
-- setter(id) and leaves the menu open, and each row shows a check box. The
-- menu closes on a click outside it or its field, or when combat starts.
local function CheckBox(row)
    local box=row:CreateTexture(nil,"ARTWORK",nil,1);box:SetSize(14,14);box:SetPoint("RIGHT",-10,0)
    box:SetColorTexture(T.rim[1],T.rim[2],T.rim[3],1)
    local field=row:CreateTexture(nil,"ARTWORK",nil,2);field:SetPoint("TOPLEFT",box,"TOPLEFT",1,-1);field:SetPoint("BOTTOMRIGHT",box,"BOTTOMRIGHT",-1,1)
    field:SetColorTexture(T.field[1],T.field[2],T.field[3],1)
    local mark=row:CreateTexture(nil,"ARTWORK",nil,3);mark:SetPoint("TOPLEFT",box,"TOPLEFT",3,-3);mark:SetPoint("BOTTOMRIGHT",box,"BOTTOMRIGHT",-3,3)
    mark:SetColorTexture(T.primary[1],T.primary[2],T.primary[3],1)
    row.checkBox,row.checkMark=box,mark
end

local function CloseOutside(menu,event)
    if event=="PLAYER_REGEN_DISABLED" then menu:Hide();return end
    local over=menu:IsMouseOver() or menu.field:IsMouseOver()
    if not (addon.IsPublic(over) and over) then menu:Hide() end
end

function W.Select(parent,width,choices,getter,setter,options)
    local multi=options and options.multi
    local button=W.Button(parent,"",width or 260,24,"dropdown")
    button:SetPoint("LEFT");W.DropdownLabel(button)
    -- In a stacked row (Pages.lua) the field spans the row and may share its line.
    local row=parent.row
    if row and row.stacked and parent.valueAnchor then button:SetPoint("RIGHT");row.pairable=true end
    local menu=W.Popup(button,width or 260,240)
    W.Texture(menu,"Window")
    local scroll=CreateFrame("ScrollFrame",nil,menu);scroll:SetPoint("TOPLEFT",6,-6);scroll:SetPoint("BOTTOMRIGHT",-6,6);scroll:EnableMouseWheel(true)
    local content=CreateFrame("Frame",nil,scroll);content:SetSize((width or 260)-12,1);scroll:SetScrollChild(content)
    local rows,offset={},0
    function button:Refresh()
        local value,label=getter();self.label:SetText(label or tostring(value or ""))
        if not menu:IsShown() then return end
        local actualWidth=button:GetWidth()
        local items=choices();menu:SetSize(actualWidth,math.min(240,12+#items*30));content:SetSize(actualWidth-12,#items*30)
        W.PlacePopup(menu,button)
        local max=math.max(0,#items*30-228);offset=math.min(offset,max);scroll:SetVerticalScroll(offset)
        scroll:SetScript("OnMouseWheel",function(_,delta) offset=math.max(0,math.min(max,offset-delta*30));scroll:SetVerticalScroll(offset) end)
        for i,item in ipairs(items) do
            if not rows[i] then
                local row=W.Button(content,"",(width or 260)-12,28,"tab");rows[i]=row;row:SetPoint("TOPLEFT",0,-(i-1)*30)
                row.label:ClearAllPoints();row.label:SetPoint("LEFT",10,0);row.label:SetJustifyH("LEFT")
                if multi then CheckBox(row) end
                row:SetScript("OnClick",function()
                    if not multi then menu:Hide() end
                    setter(row.choice.id);button:Refresh()
                end)
            end
            local row=rows[i];row:SetWidth(actualWidth-12);row.label:SetWidth(actualWidth-(multi and 52 or 28))
            row.choice=item;row.label:SetText(item.label);row:Show()
            if multi then
                row:SetSelected(item.selected==true);row.checkMark:SetShown(item.selected==true)
                row:SetEnabled(item.disabled~=true);row:SetAlpha(item.disabled and 0.45 or 1)
            else row:SetSelected(item.id==value) end
        end
        for i=#items+1,#rows do rows[i]:Hide() end
    end
    button:SetScript("OnClick",function()
        if InCombatLockdown() or UnitAffectingCombat("player") or not button:IsEnabled() then return end
        local shown=menu:IsShown();if addon.CloseFontDropdown then addon:CloseFontDropdown() end
        menu:SetShown(not shown);offset=0;button:Refresh()
    end)
    button:SetScript("OnHide",function() menu:Hide() end)
    if multi then
        menu.field=button
        menu:SetScript("OnEvent",CloseOutside)
        menu:SetScript("OnShow",function() menu:RegisterEvent("GLOBAL_MOUSE_DOWN");menu:RegisterEvent("PLAYER_REGEN_DISABLED") end)
        menu:SetScript("OnHide",function() menu:UnregisterEvent("GLOBAL_MOUSE_DOWN");menu:UnregisterEvent("PLAYER_REGEN_DISABLED") end)
    end
    addon.fontDropdownMenus=addon.fontDropdownMenus or {};addon.fontDropdownMenus[menu]=true
    button.menu,button.rows=menu,rows
    return button
end
