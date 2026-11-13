local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Class Colors: optional custom colors per class for every
-- class-colored ModeUI element. Changes apply right away (no reload); turning
-- the module off, or resetting a class, returns to the game's own color.
-- ModeUI's colors are its own; Play The Game Tools keeps its separate setting.
local M = { title = "Class Colors", category = "global", defaultEnabled = true,
    configDescription = "Custom colors for class-colored ModeUI elements, such as names and health bars." }
addon.ClassColors = M
addon:RegisterModule("classColors", M)

-- WoW Forever's classes, in the order the game lists them.
M.classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local KNOWN = {}
for _, class in ipairs(M.classes) do KNOWN[class] = true end
-- Used only if the client can't report a class color.
local FALLBACK = { WARRIOR = { .78, .61, .43 }, PALADIN = { .96, .55, .73 }, HUNTER = { .67, .83, .45 },
    ROGUE = { 1, .96, .41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, .44, .87 }, MAGE = { .25, .78, .92 },
    WARLOCK = { .53, .53, .93 }, DRUID = { 1, .49, .04 } }

local Public = addon.IsPublic
local function Number(v, low, high) return Public(v) and type(v) == "number" and v == v and v >= low and v <= high end

function M.Initialize(db)
    if db.colors == nil then db.colors = {} end
    assert(type(db.colors) == "table", "Invalid class colors.")
    for class, color in pairs(db.colors) do
        assert(KNOWN[class] and type(color) == "table", "Invalid class color: " .. tostring(class))
        for i = 1, 3 do assert(Number(color[i], 0, 1), "Invalid class color channel: " .. class) end
    end
end

function M:OnInitialize() self.Initialize(self.db) end
-- Lifecycle callbacks run before the saved enabled flag changes; set it first.
function M:OnEnable() self.enabled = true; self.db.enabled = true; self:Changed() end
function M:OnDisable() self.enabled = false; self.db.enabled = false; self:Changed() end

function M:ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = type(names) == "table" and names[class]
    if Public(name) and type(name) == "string" and name ~= "" then return name end
    return class:sub(1, 1) .. class:sub(2):lower()
end

-- The game's color for a class, as { r, g, b } fields.
function M:NativeColor(class)
    if not Public(class) or type(class) ~= "string" then return end
    local native
    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, value = pcall(C_ClassColor.GetClassColor, class)
        if ok and Public(value) then native = value end
    end
    native = native or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class])
    if Public(native) and type(native) == "table" and Number(native.r, 0, 1) and Number(native.g, 0, 1) and Number(native.b, 0, 1) then
        return { r = native.r, g = native.g, b = native.b }
    end
    local color = FALLBACK[class]
    if color then return { r = color[1], g = color[2], b = color[3] } end
end

function M:IsCustom(class) return self.db ~= nil and self.db.colors[class] ~= nil end

-- The color ModeUI uses for a class: the custom one while the module is on.
-- Reads the validated profile directly, so modules that draw before this one
-- initializes (Unit Frames) already get the custom colors at login.
function M:GetColor(class)
    if not Public(class) or type(class) ~= "string" then return end
    local db = addon.db and addon.db.modules and addon.db.modules.classColors
    local custom = type(db) == "table" and db.enabled == true and type(db.colors) == "table" and db.colors[class]
    if custom then return { r = custom[1], g = custom[2], b = custom[3] } end
    return self:NativeColor(class)
end

function M:SetColor(class, color)
    if not KNOWN[class] then return false end
    if color ~= nil then
        if type(color) ~= "table" then return false end
        for i = 1, 3 do if not Number(color[i], 0, 1) then return false end end
        color = { color[1], color[2], color[3] }
    end
    self.db.colors[class] = color
    self:Changed()
    return true
end

function M:ResetAll()
    for class in pairs(self.db.colors) do self.db.colors[class] = nil end
    self:Changed()
    return true
end

-- Class-colored modules redraw at once; colors are plain texture/text tints,
-- so this is safe in combat too.
function M:Changed()
    if not addon.initialized then return end
    addon:SendMessage(addon.Messages.CLASS_COLORS_CHANGED)
    if self.page then self.page:Refresh() end
end
