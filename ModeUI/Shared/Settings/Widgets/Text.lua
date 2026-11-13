local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local InterfaceColor = W.InterfaceColor

function W.Label(parent, text, font, x, y, width, color)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x or 0, y or 0)
    label:SetWidth(width or 360)
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(InterfaceColor(color) or T.text))
    label:SetText(text)
    W.CrispText(label)
    addon.Media:BindInterfaceFont(label, _G[font or "GameFontHighlight"])
    return label
end

-- Headings carry hierarchy through size and the theme's heading color (the
-- text color in Modern, gold in Blizzard); the accent is reserved for state.
function W.Heading(parent, text, size, x, y, width, color)
    color = InterfaceColor(color)
    if color == nil or color == T.primary or color == T.text then color = T.heading end
    local label = W.Label(parent, text, "GameFontNormalLarge", x, y, width, color)
    addon.Media:BindInterfaceFont(label, GameFontNormalLarge, size, nil, "heading")
    return label
end

-- The line follows visible text, not the width of its clickable row. Native
-- string measurements are local UI data; reject restricted/invalid results.
function W.AlignTextLine(button, line)
    local width=button.label:GetStringWidth()
    if (issecretvalue and issecretvalue(width)) or type(width)~="number" or width~=width or width<0 or width==math.huge then return end
    width=math.min(width,math.max(8,button:GetWidth()-20))
    local available=button.label:GetWidth()
    if not (issecretvalue and issecretvalue(available)) and type(available)=="number" and available>0 then width=math.min(width,available) end
    line:ClearAllPoints();line:SetSize(math.max(8,width),2)
    local justify=button.label.GetJustifyH and button.label:GetJustifyH() or (button.modeLeftAligned and "LEFT" or "CENTER")
    if justify=="LEFT" then line:SetPoint("TOPLEFT",button.label,"BOTTOMLEFT",0,-2)
    elseif justify=="RIGHT" then line:SetPoint("TOPRIGHT",button.label,"BOTTOMRIGHT",0,-2)
    else line:SetPoint("TOP",button.label,"BOTTOM",0,-2) end
end
