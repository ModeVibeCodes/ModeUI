local _, addon = ...
local T = addon.InterfaceTheme
local W = {}
addon.ConfigWidgets = W

-- Popups escape settings ScrollFrame clipping; anchors still follow the owned button.
function W.PlacePopup(menu,button)
    local ratio=button:GetEffectiveScale()/UIParent:GetEffectiveScale()
    menu:SetScale(ratio)
    local bottom=button.GetBottom and button:GetBottom()
    local below=not (issecretvalue and issecretvalue(bottom)) and type(bottom)=="number" and bottom*ratio or 0
    menu:ClearAllPoints()
    if below<menu:GetHeight()*ratio+8 then menu:SetPoint("BOTTOMLEFT",button,"TOPLEFT",0,4)
    else menu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-4) end
    -- A popup belongs to UIParent, not the settings window: it snaps its own borders.
    addon.Style.QueueSnapEdges(menu)
end
function W.Popup(button,width,height)
    local menu=CreateFrame("Frame",nil,UIParent)
    menu.modeMediaScope=addon.Media:FrameScope(button)
    menu:Hide();menu:SetSize(width,height);menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(200);menu:SetClampedToScreen(true);menu:EnableMouse(true)
    W.PlacePopup(menu,button)
    return menu
end

local function InterfaceColor(color)
    for key, original in pairs(addon.Theme) do
        if color == original then return T[key] or color end
    end
    return color
end
W.InterfaceColor = InterfaceColor

function W.StateColor(enabled)
    return enabled and T.enabled or T.off
end

function W.CrispText(region)
    -- Supported native pixel rounding; no global UI scale or font engine changes.
    if region.SetRoundLayoutToNearestPixel then region:SetRoundLayoutToNearestPixel(true) end
    if T.blizzardArt then
        -- Stock interface text carries a soft drop shadow; it keeps gold and
        -- parchment legible on the textured stone without raising contrast.
        region:SetShadowColor(0, 0, 0, 0.85)
        region:SetShadowOffset(1, -1)
    else
        region:SetShadowOffset(0, 0)
    end
end

-- A fully transparent texture (missing art must never show as a rectangle).
local function Clear(texture)
    local shadow = addon.Style.Tone.shadow
    texture:SetColorTexture(shadow[1], shadow[2], shadow[3], 0)
end
local function Paint(texture, color, alpha)
    if texture.modeAsset then
        local usable=texture.appliedModeAsset==texture.modeAsset or addon.Media:ApplyTexture(texture,texture.modeAsset,color)
        if usable then
            texture.appliedModeAsset=texture.modeAsset
            texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
            return
        end
        if texture.modeAsset=="ModePillSurface" then
            if addon.Media:ApplyTexture(texture,"ModeToggleSurface",color) then
                texture:SetVertexColor(color[1],color[2],color[3],alpha or color[4] or 1)
            else Clear(texture) end
            return
        end
        if texture.modeAsset=="ModeCheckSurface" or texture.modeAsset=="ModeCheckMark" or texture.modeAsset=="ModeToggleSurface" then
            -- The already bundled circular thumb remains a rounded fallback
            -- while a new small-control file is unavailable to this client.
            if addon.Media:ApplyTexture(texture,"ModeThumb",color) then
                texture:SetVertexColor(color[1],color[2],color[3],alpha or color[4] or 1)
            else Clear(texture) end
            return
        end
        -- Missing borders must never become opaque rectangles over controls.
        if texture.modeAsset:find("Border",1,true) then Clear(texture);return end
    end
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end
W.Paint = Paint

-- Static neutral sheen over the large Figma material, below all controls/text.
-- Reuses the gradient API already used by the Forever map renderer.
function W.ModeSheen(frame,inset)
    local texture=frame:CreateTexture(nil,"BACKGROUND",nil,2)
    inset=inset or 0
    texture:SetPoint("TOPLEFT",inset,-inset);texture:SetPoint("BOTTOMRIGHT",-inset,inset)
    texture.modeAsset="ModeSurface";Paint(texture,{1,1,1,1})
    local white = addon.Style.Tone.mono.white
    if not addon.Kit.Gradient(texture, { white[1], white[2], white[3], 0 }, { white[1], white[2], white[3], 0.018 }) then
        texture:SetAlpha(0.008)
    end
    return texture
end

-- Fixed abstract material below page controls and the existing sheen. Missing
-- artwork stays transparent so the darker base remains usable after /reload.
function W.ModePageDetail(frame,inset)
    local texture=frame:CreateTexture(nil,"BACKGROUND",nil,1)
    inset=inset or 0
    texture:SetPoint("TOPLEFT",inset,-inset);texture:SetPoint("BOTTOMRIGHT",-inset,inset)
    texture.modeAsset="ModePageDetail"
    if addon.Media:ApplyTexture(texture,"ModePageDetail") then
        local white = addon.Style.Tone.mono.white
        texture:SetVertexColor(white[1], white[2], white[3], 0.18)
    else Clear(texture) end
    return texture
end

-- A flat surface or line in a theme color: Mode Solid tinted (Global Texture
-- belongs to module displays, never the settings window or popups).
function W.Fill(frame, color, layer, inset, alpha)
    color = InterfaceColor(color)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    inset = inset or 0
    texture:SetPoint("TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", -inset, inset)
    if T.id == "mode" and addon.Style.ApplyAsset(texture, "Solid") then
        texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
    else Paint(texture, color, alpha) end
    return texture
end

-- Four 1px edges. Vertical edges stop short of the corners so translucent
-- outlines never double up.
function W.Outline(frame, color, layer, inset, alpha, scope)
    scope=scope or addon.Media:FrameScope(frame)
    inset = inset or 0
    local style=addon.Media:GlobalStyle("border",scope) or "thin"
    if T.id == "mode" and not frame.modeSquareOutline then
        -- Mode: a Mode Line border (flat 1px rim in the color, 1px shadow).
        local edge = addon.Style.Edge(frame, "line", { color = InterfaceColor(color) })
        local outline = { edges = {}, shown = true, kind = "thin", edge = edge }
        function outline:SetShown(shown) self.shown = shown; edge:SetShown(shown) end
        function outline:SetColor(value, opacity)
            edge:SetTint(InterfaceColor(value))
            edge.holder:SetAlpha(opacity or 1)
            self:SetShown(self.shown)
        end
        outline:SetColor(color, alpha)
        return outline
    end
    local edges = {}
    local function Edge(a, ax, ay, b, bx, by, horizontal)
        local edge = frame:CreateTexture(nil, layer or "BORDER")
        edge:SetPoint(a, ax, ay); edge:SetPoint(b, bx, by)
        if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[#edges + 1] = edge
        return edge
    end
    Edge("TOPLEFT", inset, -inset, "TOPRIGHT", -inset, -inset, true)
    Edge("BOTTOMLEFT", inset, inset, "BOTTOMRIGHT", -inset, inset, true)
    Edge("TOPLEFT", inset, -inset - 1, "BOTTOMLEFT", inset, inset + 1)
    Edge("TOPRIGHT", -inset, -inset - 1, "BOTTOMRIGHT", -inset, inset + 1)
    local outline = { edges = edges, shown = true }
    function outline:SetColor(value, opacity)
        for _, edge in ipairs(self.edges) do Paint(edge, InterfaceColor(value), opacity) end
        local style=addon.Media:GlobalStyle("border",scope) or "thin"
        self.kind=style=="none" and "none" or "thin"
        self:SetShown(self.shown)
    end
    function outline:SetShown(shown)
        self.shown=shown
        for _,edge in ipairs(self.edges) do edge:SetShown(shown and self.kind=="thin") end
    end
    outline:SetColor(color, alpha)
    return outline
end
