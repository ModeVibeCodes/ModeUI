local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Each specialization keeps its own setup (owner, November 26, 2026: bars
-- and spell order reset after a spec change). A spec's setup is which spells
-- sit on which bar (the custom bars' lists, what Essential and Utility
-- took), the viewers' spell order, and where every ModeCDM bar sits in Edit
-- Mode (cooldown, buff and custom bars, Resource Bars, Cast Bar, Swing
-- Timer). Looks, sizes, the bar list, each spell's own switches and the
-- racials' bar stay shared.
--
-- The live setup stays where it always was (db.customBars[i].entries,
-- db.extras, db.order and ModeUI's saved positions), so the rest of the
-- module reads it as before; it is the setup of db.activeSpec. When the spec
-- changes, the live setup is put away under db.specs[<old spec ID>] and the
-- new spec's comes back from there. A spec with nothing put away yet starts
-- from the live setup (so does a bar a spec's setup doesn't name yet).
--   db.specs = { ["62"] = { entries = { custom1 = { "1234" } },
--       extras = { essential = {}, utility = {} }, order = { essential = { "1234" } },
--       positions = { cooldownManagerEssential = { target, placement, x, y, ... } } } }
local Events, Number = addon.Events, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local FIELDS = { "target", "placement", "x", "y", "point", "relativePoint", "fallbackX", "fallbackY" }
local PARTS = { entries = true, extras = true, order = true, positions = true }
local MAX_SPECS = 40

-- Validation (Parts.lua, at load and on every change): well formed only. A
-- setup coming back is checked again with the bars as they are then.
local function KeyList(list, label)
    assert(type(list) == "table" and #list <= M.MAX_ORDER, "Invalid cooldown manager spec setup: " .. label)
    for i, key in pairs(list) do
        assert(type(i) == "number" and i >= 1 and i <= #list and type(key) == "string" and #key <= 12, "Invalid cooldown manager spec setup: " .. label)
    end
end
function M.ValidateSpecSetups(db)
    if db.specs == nil then db.specs = {} end
    assert(addon.IsPublic(db.specs) and type(db.specs) == "table", "Invalid cooldown manager spec setups")
    assert(db.activeSpec == nil or (Number(db.activeSpec, 1) and db.activeSpec == math.floor(db.activeSpec)), "Invalid cooldown manager spec")
    local count = 0
    for spec, setup in pairs(db.specs) do
        count = count + 1
        local label = tostring(spec)
        assert(type(spec) == "string" and spec:match("^%d+$") and #spec <= 10 and type(setup) == "table", "Invalid cooldown manager spec setup: " .. label)
        for part, value in pairs(setup) do assert(PARTS[part] and type(value) == "table", "Invalid cooldown manager spec setup: " .. label) end
        for id, list in pairs(setup.entries or {}) do
            assert(M:IsCustom(id), "Invalid cooldown manager spec setup: " .. label); KeyList(list, label)
        end
        for viewer, list in pairs(setup.extras or {}) do
            assert(M.entryViewers[viewer], "Invalid cooldown manager spec setup: " .. label); KeyList(list, label)
        end
        for viewer, list in pairs(setup.order or {}) do
            assert(M.viewerSpecs[viewer], "Invalid cooldown manager spec setup: " .. label); KeyList(list, label)
        end
        for eid, place in pairs(setup.positions or {}) do
            assert(type(eid) == "string" and eid:match("^cooldownManager") and addon.PositionManager:ValidatePosition(place, true),
                "Invalid cooldown manager spec position: " .. label)
        end
    end
    assert(count <= MAX_SPECS, "Too many cooldown manager spec setups")
end

-- The spec you play now (its ID), or nil while the game can't tell.
function M.CurrentSpec()
    local info = C_SpecializationInfo
    local index = info and info.GetSpecialization and select(2, pcall(info.GetSpecialization))
    if not Number(index, 1, 10) then return nil end
    local read = GetSpecializationInfo or (info and info.GetSpecializationInfo)
    local ok, id = pcall(read, index)
    if ok and Number(id, 1) and id == math.floor(id) then return id end
end

-- Every Edit Mode element of this module, by ID.
function M:SpecElementIds()
    local list = {}
    for _, id in ipairs(self:BarIds()) do list[#list + 1] = self.ElementId(id) end
    for _, id in ipairs(self.resources) do list[#list + 1] = self.ResourceElementId(id) end
    list[#list + 1] = self.CAST_ELEMENT
    list[#list + 1] = self.SWING_ELEMENT
    return list
end

-- The live setup, as one spec's.
function M:CaptureSetup(db)
    local setup = { entries = {}, extras = Copy(db.extras), order = Copy(db.order), positions = {} }
    for _, bar in ipairs(db.customBars) do setup.entries[bar.id] = Copy(bar.entries) end
    local store = addon.db and addon.db.positions
    for _, eid in ipairs(self:SpecElementIds()) do
        local place = type(store) == "table" and store[eid]
        if type(place) == "table" then
            local copy = {}
            for _, key in ipairs(FIELDS) do copy[key] = place[key] end
            setup.positions[eid] = copy
        end
    end
    return setup
end

-- A spec's spells into `candidate` (a copy of the settings): what it names.
local function TakeSpells(candidate, setup)
    for _, bar in ipairs(candidate.customBars) do
        local list = setup.entries and setup.entries[bar.id]
        if list then bar.entries = Copy(list) end
    end
    if setup.extras then
        for viewer in pairs(M.entryViewers) do candidate.extras[viewer] = Copy(setup.extras[viewer] or {}) end
    end
    if setup.order then candidate.order = Copy(setup.order) end
end

-- A spec's places, written into the saved positions in place (Edit Mode's
-- elements hold those very tables), then placed. One that would hang from
-- itself through another element keeps its live place.
function M:PlaceSetup(positions)
    local PM, live = addon.PositionManager, {}
    if not addon.db then return end
    addon.db.positions = addon.db.positions or {}
    local store = addon.db.positions
    for _, eid in ipairs(self:SpecElementIds()) do
        local place = positions[eid]
        if type(place) == "table" and PM:ValidatePosition(place, true) then
            local current = store[eid]
            if type(current) ~= "table" then current = {}; store[eid] = current end
            live[eid] = Copy(current)
            for _, key in ipairs(FIELDS) do current[key] = place[key] end
        end
    end
    for eid, previous in pairs(live) do
        local current = store[eid]
        if current.target ~= "screen" and PM.WouldLoop and PM:Element(eid) and PM:WouldLoop(eid, current.target) then
            for _, key in ipairs(FIELDS) do current[key] = previous[key] end
        end
    end
    for eid in pairs(live) do
        local element = PM:Element(eid)
        if element and element.subject then element.subject.appliedAnchor = nil end
    end
    PM:Refresh()
end

-- Puts the live setup away and brings back the current spec's. Returns
-- whether the setup changed. Nothing moves in combat (a spec can't change
-- there either); it runs again when combat ends.
function M:SyncSpec()
    if not self.active or not self.built or addon.InCombat() then return false end
    local spec = self.CurrentSpec()
    local db = self.db
    if not spec or db.activeSpec == spec then return false end
    local old, setup = db.activeSpec, db.specs[tostring(spec)]
    -- The first spec seen keeps the live setup as its own.
    if not old and not setup then db.activeSpec = spec; return false end
    local candidate = Copy(db)
    if old then candidate.specs[tostring(old)] = self:CaptureSetup(db) end
    candidate.specs[tostring(spec)] = nil
    candidate.activeSpec = spec
    if setup then
        local spells = Copy(candidate)
        TakeSpells(spells, setup)
        -- A setup that no longer fits the bars keeps the live spells.
        if pcall(self.Initialize, Copy(spells)) then candidate = spells end
    end
    -- The bars take their spells first (their sizes follow), then their places.
    if not self.CommitBars(self, candidate) then return false end
    if setup and setup.positions then self:PlaceSetup(setup.positions) end
    -- Edit Mode's Undo starts over: the old spec's places aren't a change.
    local history = addon.EditMode and addon.EditMode.history
    if addon.editMode and history then history:Begin() end
    return setup ~= nil
end

-- A deleted custom bar leaves every spec's setup.
function M.ForgetSpecBar(db, id)
    for _, setup in pairs(type(db.specs) == "table" and db.specs or {}) do
        if setup.entries then setup.entries[id] = nil end
        if setup.positions then setup.positions[M.ElementId(id)] = nil end
    end
end

-- The spec is checked on entering the world, when it changes and after
-- combat. Its own owner, so the module's own handlers for these stay.
M.specWatcher = {}
function M:SetSpecEvents(on)
    local owner = self.specWatcher
    if not on then Events:OffAll(owner); return end
    local function Sync() self.Safe(function() self:SyncSpec() end) end
    Events:On(owner, "PLAYER_ENTERING_WORLD", Sync)
    Events:On(owner, "PLAYER_REGEN_ENABLED", Sync)
    Events:On(owner, "PLAYER_SPECIALIZATION_CHANGED", function(_, unit) if unit == nil or unit == "player" then Sync() end end)
    pcall(Events.On, Events, owner, "ACTIVE_TALENT_GROUP_CHANGED", Sync)
    Sync()
end
