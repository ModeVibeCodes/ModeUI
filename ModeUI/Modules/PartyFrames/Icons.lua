local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The icons on a member, each with its own switch and place: role, leader,
-- raid marker, ready check, and summon, resurrection or another phase. Each
-- reads Domain.Group (or Domain.RaidIcon); an unknown or secret answer
-- hides the icon. Atlases are Blizzard's own party frame art.
local Group, RaidIcon = addon.Domain.Group, addon.Domain.RaidIcon

local function Atlas(icon, atlas)
    if not atlas then icon:Hide(); return end
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAtlas(atlas)
    icon:Show()
end

function M:UpdateIcons(f)
    if not self:Live(f) then return end
    local db, icons, unit = self.db, f.icons, f.unit
    local role = db.roleShow and Group.Role(unit) or nil
    if role == "DAMAGER" and db.hideDamagerRole then role = nil end
    Atlas(icons.role, role and Group.ROLE_ATLAS[role])
    Atlas(icons.leader, db.leaderShow and Group.LeaderAtlas(unit) or nil)
    if db.raidIconShow then RaidIcon.Apply(icons.raidIcon, unit) else icons.raidIcon:Hide() end
    local ready = db.readyCheckShow and not self.readyCheckDone and Group.ReadyCheck(unit) or nil
    Atlas(icons.readyCheck, ready and Group.READY_ATLAS[ready])
    local incoming = db.incomingShow and Group.Incoming(unit) or nil
    Atlas(icons.incoming, incoming and Group.INCOMING_ATLAS[incoming])
end

-- Sample icons for stand-ins and the preview: what each member would show.
M.SAMPLE_ICONS = {
    role = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" },
    ready = { "ready", "ready", "waiting", "notready", "ready" },
}
-- One member shows the ready check and another a summon, so both can be
-- placed; preview states (Samples.lua) show them on every member.
function M:PaintIconSample(f, index, states)
    local db, icons = self.db, f.icons
    states = states or {}
    local role = f.role or self.SAMPLE_ICONS.role[index]
    if role == "DAMAGER" and db.hideDamagerRole then role = nil end
    Atlas(icons.role, db.roleShow and role and Group.ROLE_ATLAS[role] or nil)
    Atlas(icons.leader, db.leaderShow and (index == 1 or states.leader) and Group.LEADER_ATLAS or nil)
    if db.raidIconShow and (index == 2 or states.raidIcon) then RaidIcon.ApplyIndex(icons.raidIcon, 8) else icons.raidIcon:Hide() end
    Atlas(icons.readyCheck, db.readyCheckShow and (index == 3 or states.readyCheck) and Group.READY_ATLAS[self.SAMPLE_ICONS.ready[index]] or nil)
    Atlas(icons.incoming, db.incomingShow and (index == 4 or states.summon) and Group.INCOMING_ATLAS.summonPending or nil)
end
