local _,addon=...
local W,T=addon.ConfigWidgets,addon.InterfaceTheme

-- Single-line text field in the Mode look, with a placeholder. Enter runs
-- box.onEnter when set; Escape just leaves the field.
function W.TextInput(parent,width,placeholder,maxLetters)
    local box=CreateFrame("EditBox",nil,parent);box:SetSize(width,28);box:SetPoint("LEFT")
    box:SetAutoFocus(false);box:SetMaxLetters(maxLetters or 48)
    box:SetFontObject(GameFontHighlight);box:SetTextInsets(8,8,0,0);box:SetText("")
    addon.Media:BindInterfaceFont(box,GameFontHighlight);W.Texture(box,"InputField")
    local hint=W.Label(box,placeholder or "",nil,8,0,width-16,T.muted)
    hint:ClearAllPoints();hint:SetPoint("LEFT",8,0);hint:SetWordWrap(false)
    box:HookScript("OnTextChanged",function() hint:SetShown(box:GetText()=="") end)
    box:SetScript("OnEscapePressed",function() box:ClearFocus() end)
    box:SetScript("OnEnterPressed",function() box:ClearFocus();if box.onEnter then box.onEnter(box:GetText()) end end)
    box.hint=hint
    return box
end
