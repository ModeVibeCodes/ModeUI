local _, addon = ...
local Q = addon.Domain.Query

-- Unit portraits: the character portrait, or a class icon for players.
local Portrait = {}
addon.Domain.Portrait = Portrait
Portrait.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function Portrait.SetIcon(icon, path)
    if icon.SetAtlas then icon:SetTexCoord(0, 1, 0, 1) end
    icon:SetTexture(path)
end

-- style "class" shows the class icon when GetClassAtlas exists and its atlas is
-- confirmed by C_Texture.GetAtlasInfo; otherwise SetPortraitTexture, else a
-- question mark.
-- Returns what it drew: "class" (the class icon), "portrait" (the unit's
-- portrait) or "icon" (the unknown icon).
function Portrait.Apply(icon, unit, style)
    if style == "class" and Q.Truthy(UnitIsPlayer, unit) then
        local _, class = Q.Plain(UnitClass, unit)
        local atlas = class and Q.Plain(GetClassAtlas, class)
        if type(atlas) == "string" and icon.SetAtlas and C_Texture and Q.Plain(C_Texture.GetAtlasInfo, atlas)
            and pcall(icon.SetAtlas, icon, atlas) then return "class" end
    end
    icon:SetTexCoord(0, 1, 0, 1)
    if Q.Truthy(UnitExists, unit) and Q.Call(SetPortraitTexture, icon, unit) then return "portrait" end
    Portrait.SetIcon(icon, Portrait.UNKNOWN_ICON)
    return "icon"
end

function Portrait.Exists(unit) return Q.Truthy(UnitExists, unit) end
