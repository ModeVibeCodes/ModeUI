local _, addon = ...
local Q, Public = addon.Domain.Query, addon.IsPublic

-- What a unit is casting or channeling. Cast values are secret while the
-- game restricts spell casts (SecretWhenUnitSpellCastRestricted): the name,
-- icon, times and interruptibility may then be secret. They go only to
-- FontString SetText, Texture SetTexture, StatusBar SetMinMaxValues and
-- SetVertexColorFromBoolean, all of which accept secrets from addon code.
local Cast = {}
addon.Domain.Cast = Cast

-- A secret name always means a cast; a public one is present or nil.
local function Active(name) return not Public(name) or name ~= nil end

-- nil when idle, else { channel, text, texture, startMs, endMs, notInterruptible }.
function Cast.Read(unit)
    local ok, name, text, texture, startMs, endMs, _, _, notInterruptible = Q.Call(UnitCastingInfo, unit)
    if ok and Active(name) then
        return { channel = false, text = text, texture = texture, startMs = startMs, endMs = endMs, notInterruptible = notInterruptible }
    end
    local okChannel, channelName, channelText, channelTexture, channelStart, channelEnd, _, channelLocked = Q.Call(UnitChannelInfo, unit)
    if okChannel and Active(channelName) then
        return { channel = true, text = channelText, texture = channelTexture, startMs = channelStart, endMs = channelEnd,
            notInterruptible = channelLocked }
    end
end

-- The bar's current value in the same unit as startMs/endMs.
function Cast.Now() return GetTime() * 1000 end
