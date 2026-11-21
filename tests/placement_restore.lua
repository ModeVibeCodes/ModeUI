-- Shared/Placement/PositionRestore.lua: the profile's places win over the
-- client's layout cache. The client puts every named frame moved with
-- StartMoving back where it was at the last logout, after ModeUI placed it
-- (owner, November 20, 2026: Cooldown Manager bars at the old profile's places
-- until Edit Mode; the Player and Target frames away from their stand-ins).
-- Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    local PM, UF = addon.PositionManager, addon.UnitFrames
    local function Anchor(frame)
        local p, to, rp, x, y = frame:GetPoint(1)
        return string.format('%s %s %s %.1f %.1f', tostring(p), to == UIParent and 'UIParent' or tostring(to), tostring(rp), x or 0, y or 0)
    end
    local ghost, button = UF.ghosts.player, UF.frames.player
    local want = Anchor(ghost)
    assert(Anchor(button) == want, 'the button copies its stand-in: ' .. Anchor(button) .. ' vs ' .. want)

    -- Every element is kept out of the client's layout cache.
    local saved, placed = {}, {}
    for _, element in pairs(PM.elements) do
        local frame = element.frame
        frame.SetDontSavePosition = function(self, value) saved[self] = value end
        frame.SetUserPlaced = function(self, value) placed[self] = value end
        frame.IsMovable = function() return true end
    end
    PM:KeepOutOfLayoutCache(ghost)
    assert(saved[ghost] == true and placed[ghost] == false, 'never saved by the client')

    -- The client restores old places after ModeUI placed them: the stand-in
    -- (BOTTOM anchor, its old spot) and, through an old copy, the button.
    ghost:ClearAllPoints(); ghost:SetPoint('BOTTOM', UIParent, 'BOTTOM', -256, 361)
    button:ClearAllPoints(); button:SetPoint('BOTTOM', UIParent, 'BOTTOM', -256, 361)
    local essential = PM.elements.cooldownManagerEssential
    local mover, before
    if essential then
        mover = essential.frame
        before = Anchor(mover)
        mover:ClearAllPoints(); mover:SetPoint('CENTER', UIParent, 'CENTER', 0, -271)
    end

    -- A plain re-apply notices the frame moved (the remembered anchor no longer holds).
    PM:ApplyPosition(UF.elementIds.player)
    assert(Anchor(ghost) == want, 'a moved stand-in is placed again: ' .. Anchor(ghost))

    -- Once the client is done (PLAYER_ENTERING_WORLD, a frame later), every
    -- element is placed again and its module told, so the button follows.
    ghost:ClearAllPoints(); ghost:SetPoint('BOTTOM', UIParent, 'BOTTOM', -256, 361)
    FireEvent('PLAYER_ENTERING_WORLD')
    assert(Anchor(ghost) == want and Anchor(button) == want, 'the profile wins: ' .. Anchor(ghost) .. ' / ' .. Anchor(button))
    if mover then assert(Anchor(mover) == before, 'the Cooldown Manager bar is back at its place: ' .. Anchor(mover)) end
    for _, element in pairs(PM.elements) do
        assert(saved[element.frame] == true, element.id .. ': kept out of the layout cache')
    end
]==], "restore")

print("placement restore: all checks passed")
