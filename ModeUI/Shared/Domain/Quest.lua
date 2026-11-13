local _, addon = ...
local Q = addon.Domain.Query

-- Whether a unit is part of one of your active quests: a quest boss, or a
-- creature C_QuestLog.UnitIsRelatedToActiveQuest reports (kill, loot or
-- interact objectives). Players never are. Neither API documents secret
-- returns; anything but a plain true counts as no.
local Quest = {}
addon.Domain.Quest = Quest

function Quest.IsRelated(unit)
    if Q.Plain(UnitIsPlayer, unit) == true then return false end
    if Q.Plain(UnitIsQuestBoss, unit) == true then return true end
    local log = C_QuestLog
    return log ~= nil and Q.Plain(log.UnitIsRelatedToActiveQuest, unit) == true
end
