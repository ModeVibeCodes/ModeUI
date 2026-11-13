local _,addon=...
local W,T=addon.ConfigWidgets,addon.InterfaceTheme

local function Measure(label)
    local width=label:GetStringWidth()
    if (issecretvalue and issecretvalue(width)) or type(width)~="number" or width~=width or width<0 or width==math.huge then width=#(label:GetText() or "")*11 end
    return math.max(1,math.ceil(width))
end

-- Each module may declare a presentation plan as module.modeLayout (never a
-- saved setting). With { decorateOnly = true } the page keeps its own sections
-- and the Mode layer only restyles headings and color rows.

function W.ModeHeadingRule(parent,heading)
    local line=parent:CreateTexture(nil,"ARTWORK");line.modeAsset="ModeHeaderLine";W.Paint(line,T.line,0.7)
    line:SetHeight(1)
    local function Align()
        local width=math.min(heading:GetWidth(),Measure(heading))
        line:ClearAllPoints();line:SetPoint("TOPLEFT",heading,"BOTTOMLEFT",0,-4);line:SetWidth(width)
    end
    Align();return line,Align
end

local function CompactColors(page)
    for _,color in ipairs(page.settingsColors or {}) do
        color.hex:Hide();if color.apply then color.apply:Hide() end
        color.pick:SetWidth(80)
    end
end

-- Existing rows, controls, callbacks, search entries and visibility predicates
-- remain the owners of their behavior. This layer only restyles them.
function W.ApplyModeModuleLayout(page,id)
    if T.id~="mode" or page.modeLayout then return end
    local module=addon.modules[id]
    local plan=module and module.modeLayout
    if not plan then return end
    page.modeFooterLayout=true
    CompactColors(page)
    page.modeLayout={plan=plan}
    for _,row in ipairs(page.rows) do
        local heading=row.subsectionHeading or (row.sectionHeader and row.heading)
        if heading then
            addon.Media:BindInterfaceFont(heading,GameFontNormalLarge,20,nil,"heading")
            local _,align=W.ModeHeadingRule(row,heading);row:HookScript("OnSizeChanged",align)
        end
    end
end
