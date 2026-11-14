local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local InterfaceColor = W.InterfaceColor

-- Without an explicit font object, labels follow the type scale: help text
-- (muted or faint) is small, everything else is body size.
function W.Label(parent, text, font, x, y, width, color)
    color = InterfaceColor(color) or T.text
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x or 0, y or 0)
    label:SetWidth(width or 360)
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(color))
    label:SetText(text)
    W.CrispText(label)
    local size = not font and ((color == T.muted or color == T.faint) and T.fontSize.small or T.fontSize.body) or nil
    addon.Media:BindInterfaceFont(label, _G[font or "GameFontHighlight"], size)
    return label
end

-- Headings carry hierarchy through size and the theme's heading color; the
-- accent is reserved for state and card titles.
function W.Heading(parent, text, size, x, y, width, color)
    color = InterfaceColor(color)
    if color == nil or color == T.primary or color == T.text then color = T.heading end
    local label = W.Label(parent, text, "GameFontNormalLarge", x, y, width, color)
    addon.Media:BindInterfaceFont(label, GameFontNormalLarge, size, nil, "heading")
    return label
end

-- A section tab's underline: 2 px under the visible text, on the button's
-- bottom edge. Native string measurements are local UI data; reject
-- restricted/invalid results. Left-edge selection bars need no alignment.
function W.AlignTextLine(button, line)
    if not line or line.leftEdge then return end
    local width=button.label:GetStringWidth()
    if (issecretvalue and issecretvalue(width)) or type(width)~="number" or width~=width or width<0 or width==math.huge then return end
    width=math.min(width,math.max(8,button:GetWidth()-20))
    local available=button.label:GetWidth()
    if not (issecretvalue and issecretvalue(available)) and type(available)=="number" and available>0 then width=math.min(width,available) end
    line:ClearAllPoints();line:SetSize(math.max(8,width),2)
    local justify=button.label.GetJustifyH and button.label:GetJustifyH() or (button.modeLeftAligned and "LEFT" or "CENTER")
    local drop=-button:GetHeight()/2
    if justify=="LEFT" then line:SetPoint("BOTTOMLEFT",button.label,"LEFT",0,drop)
    elseif justify=="RIGHT" then line:SetPoint("BOTTOMRIGHT",button.label,"RIGHT",0,drop)
    else line:SetPoint("BOTTOM",button,"BOTTOM",0,0) end
end
