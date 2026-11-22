local _, addon = ...
local M = addon.Appearance
if not M then return end

-- Reading and changing the suite's font and metal, and finding the modules
-- that customize them. A change applies after a reload: every module draws its
-- text and borders from these at build time.
local Style = addon.Style
local SKIP = addon.Database.SUITE_SKIP

function M:OnInitialize() self.Initialize(self.db) end

local function Global() return addon.db.globalMedia end
-- The suite font as a FontDropdown appearance: { font, fontMedia }.
function M:FontAppearance()
    local key = Global().font
    local name = type(key) == "string" and key:match("^media:(.+)$")
    if name then return { font = "game", fontMedia = name } end
    return { font = key == "chat" and "chat" or "game", fontMedia = "builtin:" .. (key == "chat" and "chat" or "game") }
end
function M:SetFont(key) return addon.Media:SetGlobalStyle("font", key) end
function M:Metal() return Global().edgeMetal end
function M:SetMetal(id)
    if addon.InCombat() then return false end
    if id ~= "default" and not Style.Tone.metal[id] then return false end
    if Global().edgeMetal == id then return true end
    Global().edgeMetal = id
    addon.ReloadManager:Request("suite", "Apply the suite border metal.")
    return true
end

-- Walks a module's settings for its own fonts and metals. visit(node, key,
-- kind) gets each customized one: kind "font" (a fontMedia key, or a Damage
-- Meters <part>FontMedia) or "metal" (an edgeMetal key).
local function Walk(node, depth, visit)
    if type(node) ~= "table" or depth > 12 then return end
    for key, value in pairs(node) do
        if type(value) == "table" then Walk(value, depth + 1, visit)
        elseif type(key) == "string" then
            local base = key == "fontMedia" and "font" or key:match("^(.*)FontMedia$") and key:match("^(.*)FontMedia$") .. "Font"
            if base and node[base] ~= nil and (value ~= "" or node[base] ~= "game") then visit(node, key, "font", base)
            elseif key == "edgeMetal" and value ~= "default" then visit(node, key, "metal") end
        end
    end
end
M.Walk = Walk

-- The modules that customize the suite's look, in sidebar order:
-- { { id, title, font = n, metal = n } }.
function M:Customized()
    local list = {}
    for _, id in ipairs(addon.moduleOrder) do
        local module, db = addon.modules[id], addon.db.modules[id]
        if not SKIP[id] and type(db) == "table" and not module.developer then
            local entry = { id = id, title = module.title, font = 0, metal = 0 }
            Walk(db, 0, function(_, _, kind) entry[kind] = entry[kind] + 1 end)
            if entry.font + entry.metal > 0 then list[#list + 1] = entry end
        end
    end
    return list
end

-- Takes a module back to the suite: every font and metal it set follows
-- Appearance again (after a reload).
function M:BackToSuite(id)
    local db = addon.db.modules[id]
    if addon.InCombat() or SKIP[id] or type(db) ~= "table" then return false end
    local changed = false
    Walk(db, 0, function(node, key, kind, base)
        if kind == "font" then node[key] = ""; node[base] = "game" else node[key] = "default" end
        changed = true
    end)
    if changed then addon.ReloadManager:Request("suite", "Apply the suite's font and border metal.") end
    return changed
end
