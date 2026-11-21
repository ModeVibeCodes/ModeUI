local _, addon = ...
local Public, Number = addon.IsPublic, addon.IsNumber

-- What you track in the game's Cooldown Manager (its Cooldown Settings):
-- the cooldown IDs in each of the four viewers' categories, in your order,
-- whether or not the viewer has made frames for them yet. Blizzard's viewers
-- only make their frames while they show, so a viewer that's hidden (its
-- Edit Mode Visibility, In Combat out of combat, the game option off) has
-- none; this reads the setup itself.
--
-- Read only, never rebuilt: Blizzard's data provider rebuilds its cache and
-- writes your layout back when asked for it while it's out of date, which
-- addon code must never cause (the taint would reach Blizzard's viewers and
-- their secret values). So this reads its cache only while it's up to date
-- (IsDirty false), and otherwise works the result out the same way the data
-- provider does (CooldownViewerSettingsDataProvider:CheckBuildDisplayData):
-- the game's category sets, minus those hidden by default, with your active
-- layout's order and category moves when it's for your current spec. Every
-- Blizzard method called here only returns a field.
local CD = addon.Domain.Cooldowns
local Call = addon.Domain.Query.Call

-- The viewers' categories (Enum.CooldownViewerCategory names).
CD.SHOWN = { "Essential", "Utility", "TrackedBuff", "TrackedBar" }
-- Every category the data provider reads, in its order.
local ALL = { "Essential", "Utility", "TrackedBuff", "TrackedBar", "EquipSlotEssential", "EquipSlotTracked",
    "SpecAgnosticEssential", "SpecAgnosticTracked" }
local HIDE_BY_DEFAULT = 2 -- Enum.CooldownSetSpellFlags.HideByDefault
local HIDDEN = -1 -- a category no viewer shows (Blizzard's HiddenActive)

-- obj:name(...) when obj has that method; its first return, or nil.
local function Method(object, name, ...)
    if type(object) ~= "table" then return nil end
    local fn = object[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
end

local function Flag(flags, bit)
    return Number(flags) and math.floor(flags / bit) % 2 == 1
end

-- Blizzard's own cache, while it's up to date: { { id, category, known } }.
local function FromCache(settings)
    local provider = Method(settings, "GetDataProvider")
    if Method(provider, "IsDirty") ~= false then return nil end
    local data = Method(provider, "GetDisplayData")
    if type(data) ~= "table" or type(data.orderedCooldownIDs) ~= "table" or type(data.cooldownInfoByID) ~= "table" then return nil end
    local list = {}
    for _, id in ipairs(data.orderedCooldownIDs) do
        local info = Number(id) and data.cooldownInfoByID[id]
        if type(info) == "table" then list[#list + 1] = { id = id, category = info.category, known = info.isKnown } end
    end
    return list
end

-- Your active layout, when it's for the spec you're in now.
local function ActiveLayout(settings)
    local manager = Method(settings, "GetLayoutManager")
    if not Method(manager, "IsLoaded") then return nil end
    local layout = Method(manager, "GetActiveLayout")
    local util = _G.CooldownViewerUtil
    local ok, tag = Call(type(util) == "table" and util.GetCurrentClassAndSpecTag)
    if type(layout) ~= "table" or not ok or tag == nil or layout.classAndSpecTag ~= tag then return nil end
    return layout
end

-- The same result worked out from the game's data and your layout.
local function Rebuild(settings, enum)
    local api = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
    local flags = type(Enum.CooldownSetSpellFlags) == "table" and Enum.CooldownSetSpellFlags.HideByDefault
    local hide = Number(flags, 1) and flags or HIDE_BY_DEFAULT
    local byID, order = {}, {}
    for _, name in ipairs(ALL) do
        local ok, ids = false, nil
        if Number(enum[name]) then ok, ids = Call(api, enum[name], true) end
        if ok and Public(ids) and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local info = Number(id) and not byID[id] and CD.Info(id)
                if info then
                    local category = Flag(info.flags, hide) and HIDDEN or info.category
                    byID[id] = { id = id, category = category, known = info.isKnown }
                    order[#order + 1] = id
                end
            end
        end
    end
    local layout = ActiveLayout(settings)
    if layout then
        -- Your order: what the game still has, then anything new at the end.
        if type(layout.orderedCooldownIDs) == "table" then
            local mine, placed = {}, {}
            for _, id in ipairs(layout.orderedCooldownIDs) do
                if byID[id] and not placed[id] then placed[id] = true; mine[#mine + 1] = id end
            end
            for _, id in ipairs(order) do if not placed[id] then mine[#mine + 1] = id end end
            order = mine
        end
        -- Your category moves (to another viewer, or Not Displayed).
        local blocks = type(layout.cooldownInfo) == "table" and layout.cooldownInfo or {}
        for id, entry in pairs(byID) do
            local block = blocks[id]
            local moved = type(block) == "table" and tonumber(block.category)
            if moved then entry.category = moved end
        end
    end
    local list = {}
    for _, id in ipairs(order) do list[#list + 1] = byID[id] end
    return list
end

-- Your setup: layout[name] = the cooldown IDs a viewer shows (learned ones,
-- in order) per category name in CD.SHOWN; layout.category[id] = the
-- category name each tracked ID is in, learned or not. Nil when the client
-- has no Cooldown Manager categories.
function CD.Layout()
    local enum = type(Enum) == "table" and Enum.CooldownViewerCategory
    if type(enum) ~= "table" then return nil end
    local settings = _G.CooldownViewerSettings
    local list = (type(settings) == "table" and FromCache(settings)) or Rebuild(settings, enum)
    local names, layout = {}, { category = {} }
    for _, name in ipairs(CD.SHOWN) do
        layout[name] = {}
        if Number(enum[name]) then names[enum[name]] = name end
    end
    for _, entry in ipairs(list) do
        local name = Number(entry.category) and names[entry.category]
        if name then
            layout.category[entry.id] = name
            if not (Public(entry.known) and entry.known == false) then
                local ids = layout[name]
                ids[#ids + 1] = entry.id
            end
        end
    end
    return layout
end
