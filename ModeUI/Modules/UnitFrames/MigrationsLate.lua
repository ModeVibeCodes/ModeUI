local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- The latest layout-version steps, apart from Migrations.lua (which calls
-- M.MigrateLate from Initialize) so each file stays short. A new default
-- replaces only a value still equal to the old default.
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Style = addon.Style
local Public, Same, Legacy, Tone = addon.IsPublic, Style.SameColor, Style.LEGACY, Style.Tone

function M.MigrateLate(db)
    -- 24 -> 25: the Target's health color takes Class Color.
    if db.layoutVersion == 24 then
        if type(db.target) == "table" and db.target.healthColorMode == "default" then db.target.healthColorMode = "class" end
        db.layoutVersion = 25
    end
    -- 25 -> 26: every Mode cast bar (owner, November 23, 2026). Cast colors
    -- still at the old amber and gray take light blue and orange-red; the
    -- channel color arrives with its default (green).
    if db.layoutVersion == 25 then
        for _, unit in ipairs(M.units) do
            local frame = db[unit]
            local cast = type(frame) == "table" and Public(frame) and frame.castBar
            if type(cast) == "table" and Public(cast) then
                if Same(cast.color, Legacy.palette.neutral) then cast.color = Copy(Tone.cast.casting) end
                if Same(cast.lockedColor, Legacy.palette.tapped) then cast.lockedColor = Copy(Tone.cast.shielded) end
            end
        end
        db.layoutVersion = 26
    end
    -- 26 -> 27: no combat icons (owner, November 23, 2026). The Player's and
    -- Target's combat badge, on by default until now, turns off; the red ring
    -- in combat stays.
    if db.layoutVersion == 26 then
        for _, unit in ipairs({ "player", "target" }) do
            local frame = db[unit]
            local status = type(frame) == "table" and Public(frame) and frame.status
            if type(status) == "table" and Public(status) and status.combatIcon == true then status.combatIcon = false end
        end
        db.layoutVersion = 27
    end
end
