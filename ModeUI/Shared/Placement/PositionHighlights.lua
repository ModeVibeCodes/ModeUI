local _, addon = ...
local PM = addon.PositionManager
local Combat = addon.InCombat

-- Decoration is attached to actual owned bounds, including module icon/layout bounds.
-- Only the visible handle intercepts input; no invisible full-frame input overlay.
function PM:UpdateEditDecoration(element, selected, show)
    local active = show and element.draggable and not Combat()
    if not element.decoration and active then
        local frame = CreateFrame("Frame", nil, element.frame)
        frame:SetAllPoints(element.frame); frame:EnableMouse(false)
        frame:SetFrameLevel(element.frame:GetFrameLevel()+15)
        local edges = {}
        for i,points in ipairs({{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
            local texture=frame:CreateTexture(nil,"OVERLAY")
            texture:SetPoint(points[1]);texture:SetPoint(points[2])
            if i<=2 then texture:SetHeight(1) else texture:SetWidth(1) end
            edges[i]=texture
        end
        local handle=CreateFrame("Button",nil,frame)
        handle:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",0,3)
        handle:SetSize(math.min(200,math.max(88,#(element.label or element.module.title)*6+18)),20)
        handle:EnableMouse(true);handle:RegisterForClicks("LeftButtonUp");handle:RegisterForDrag("LeftButton")
        local background=handle:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(0.08,0.1,0.12,0.94)
        local label=handle:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        label:SetPoint("CENTER");label:SetText(element.label or element.module.title)
        addon.Media:BindInterfaceFont(label,GameFontHighlight,10)
        handle:SetScript("OnMouseDown",function() if self:CanDrag(element) then self:SelectElement(element.id) end end)
        handle:SetScript("OnDragStart",function() self:StartDragging(element.id) end)
        handle:SetScript("OnDragStop",function() self:StopDragging(element.id) end)
        element.decoration={frame=frame,handle=handle,label=label,edges=edges,nudges=self:NudgeButtons(frame,handle,element)}
    end
    local d=element.decoration
    if not d then return end
    local color=selected and addon.Theme.primary or addon.Theme.muted
    for _,edge in ipairs(d.edges) do edge:SetColorTexture(color[1],color[2],color[3],selected and 0.9 or 0.5) end
    d.label:SetTextColor(color[1],color[2],color[3])
    d.handle:EnableMouse(active and self:CanDrag(element) or false)
    local nudging=selected and active and self:CanDrag(element) or false
    for _,button in ipairs(d.nudges) do button:SetShown(nudging);button:EnableMouse(nudging) end
    d.frame:SetShown(active and true or false)
end

-- Four arrow buttons beside the selected element's name: each click moves it
-- one physical pixel. The arrows are the dropdown chevron, turned.
local NUDGES={{-1,0,-math.pi/2},{0,1,math.pi},{0,-1,0},{1,0,math.pi/2}}
function PM:NudgeButtons(frame,handle,element)
    local buttons={}
    for i,nudge in ipairs(NUDGES) do
        local button=CreateFrame("Button",nil,frame)
        button:SetSize(20,20);button:SetPoint("LEFT",handle,"RIGHT",4+(i-1)*22,0)
        button:RegisterForClicks("LeftButtonUp")
        local background=button:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(0.08,0.1,0.12,0.94)
        local arrow=button:CreateTexture(nil,"ARTWORK");arrow:SetPoint("CENTER");arrow:SetSize(16,16)
        addon.Media:ApplyTexture(arrow,"ModeChevron");arrow:SetVertexColor(unpack(addon.Theme.text))
        if arrow.SetRotation then arrow:SetRotation(nudge[3]) end
        local hover=button:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(1,1,1,0.12)
        button:SetScript("OnClick",function() self:Nudge(element.id,nudge[1],nudge[2]) end)
        button.nudge=nudge
        buttons[i]=button
    end
    return buttons
end

function PM:ReleaseEditDecoration(element)
    local d=element.decoration
    if not d then return end
    d.frame:Hide();d.frame:ClearAllPoints();d.handle:EnableMouse(false)
    for _,name in ipairs({"OnMouseDown","OnDragStart","OnDragStop"}) do d.handle:SetScript(name,nil) end
    for _,button in ipairs(d.nudges or {}) do button:Hide();button:SetScript("OnClick",nil) end
    addon.Media:UnbindInterfaceFont(d.label)
    element.decoration=nil
end
