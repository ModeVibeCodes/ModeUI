local _, addon = ...
local Q, Public, Number = addon.Domain.Query, addon.IsPublic, addon.IsNumber

-- Raid target markers. GetRaidTargetIndex always returns a secret, which only
-- Texture:SetSpriteSheetCell may receive; a missing marker is a plain nil.
local RaidIcon = {}
addon.Domain.RaidIcon = RaidIcon
RaidIcon.TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local ROWS, COLUMNS = 4, 4

-- Shows the unit's marker on `texture`, or hides it. Returns true if shown.
function RaidIcon.Apply(texture, unit)
    local ok, index = Q.Call(GetRaidTargetIndex, unit)
    if not ok or (Public(index) and index == nil) then texture:Hide(); return false end
    texture:SetTexture(RaidIcon.TEXTURE)
    local placed = texture.SetSpriteSheetCell and pcall(texture.SetSpriteSheetCell, texture, index, ROWS, COLUMNS)
    if not placed then
        -- Clients without SetSpriteSheetCell: only a public index can be cropped.
        if not Number(index, 1, ROWS * COLUMNS) then texture:Hide(); return false end
        local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
        texture:SetTexCoord(column / COLUMNS, (column + 1) / COLUMNS, row / ROWS, (row + 1) / ROWS)
    end
    texture:Show()
    return true
end
