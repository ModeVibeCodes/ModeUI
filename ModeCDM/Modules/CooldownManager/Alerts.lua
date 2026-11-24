local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Spell alerts (owner, November 24, 2026). Spells Blizzard's Cooldown Manager
-- tracks take Blizzard's own alerts (a sound, the name spoken, or a flash),
-- set in its Cooldown Settings: a spell's menu opens them (Tracked Spells;
-- Forever has the editor, M.caps.cdmAlerts). The spells ModeUI tracks itself
-- (spells by ID, items, racials) can play a Ready Sound when their cooldown
-- ends: ModeUI's sound list (Shared/Media: Blizzard Warning and your
-- SharedMedia sounds). Saved per bar as `alerts = { [key] = sound }` (added
-- without a version step; Parts.lua checks it).
local L = addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local MAX_ALERTS = 200

function M:AlertSoundChoices()
    local list = { { id = "none", label = L["No Sound"] } }
    for _, choice in ipairs(addon.Media:GetSounds()) do list[#list + 1] = { id = choice.key, label = choice.label } end
    return list
end
function M:SpellAlert(id, key)
    local style = self.db[id]
    return style and type(style.alerts) == "table" and style.alerts[key] or nil
end
-- Whether a spell can have a Ready Sound of ModeUI's own: one ModeUI tracks itself.
function M:TakesReadySound(key) return type(key) == "string" and self.IsOwnEntry(key) end

function M:SetSpellAlert(id, key, sound)
    if not self:CanConfigure() or not self:HasBar(id) or not self:TakesReadySound(key) then return false end
    local candidate = Copy(self.db)
    local alerts = type(candidate[id].alerts) == "table" and candidate[id].alerts or {}
    alerts[key] = sound ~= "none" and sound or nil
    candidate[id].alerts = next(alerts) and alerts or nil
    if not pcall(self.Initialize, candidate) then return false end
    self.db[id].alerts = candidate[id].alerts
    if sound ~= "none" then self:PlayAlertSound(sound) end
    return true
end

function M:PlayAlertSound(sound)
    local value = addon.Media:GetSound(sound)
    if type(value) == "number" and type(PlaySound) == "function" then return pcall(PlaySound, value, "Master") end
    if type(value) == "string" and type(PlaySoundFile) == "function" then return pcall(PlaySoundFile, value, "Master") end
    return false
end
-- A cooldown ended (Glow.lua, UpdateCooldowns): its sound, if it has one.
function M:SpellReady(id, key)
    local sound = self:TakesReadySound(key) and self:SpellAlert(id, key)
    if sound then self:PlayAlertSound(sound) end
end

-- Validation (Parts.lua): each bar's alerts, a spell or item of ModeUI's own
-- to "default" or a SharedMedia sound.
function M.ValidateAlerts(db)
    local ids = {}
    for _, viewer in ipairs(M.viewers) do ids[#ids + 1] = viewer end
    for _, bar in ipairs(db.customBars) do ids[#ids + 1] = bar.id end
    for _, id in ipairs(ids) do
        local alerts = type(db[id]) == "table" and db[id].alerts
        if alerts ~= nil and alerts ~= false then
            assert(addon.IsPublic(alerts) and type(alerts) == "table", "Invalid cooldown manager alerts: " .. id)
            local count = 0
            for key, sound in pairs(alerts) do
                count = count + 1
                assert(type(key) == "string" and (key:match("^[si]%d+$") or key:match("^t1[34]$")) and type(sound) == "string"
                    and (sound == "default" or sound:match("^media:.+")), "Invalid cooldown manager alert: " .. id)
            end
            assert(count <= MAX_ALERTS, "Too many cooldown manager alerts: " .. id)
        end
    end
end

-- Own Bar (owner, November 24, 2026): a one-icon bar for a spell from its
-- menu, named after it, its spell moved there, ready to place in Edit Mode.
-- Not for a racial (it shows on the bar Racial Abilities picks).
function M:CanOwnBar(id, key)
    if type(key) ~= "string" or #self.db.customBars >= self.MAX_CUSTOM or self:IsRacialHere(id, key) then return false end
    return self:IsBuff(id) and key:match("^%d+$") ~= nil or not self:IsBuff(id)
end
function M:AddSingleBar(id, key)
    if not self:CanOwnBar(id, key) then return nil end
    local new = self:AddCustomBar(self:IsBuff(id) and "buff" or "cooldown")
    if not new then return nil end
    if not self:AddEntry(new, key) then self:DeleteCustomBar(new); return nil end
    local name = tostring(self:SpellLabel(key) or ""):gsub("[|\r\n]", "")
    if name ~= "" then self:RenameCustomBar(new, name:sub(1, self.MAX_NAME)) end
    self:SetOption(new, "perLine", 1)
    return new
end
