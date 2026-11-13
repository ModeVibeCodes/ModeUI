local _, addon = ...

-- ModeUI only needs class colors from Play The Game Tools' Global Settings.
-- UI scale, loot and font CVars stay with Play The Game Tools.
local G = {}
addon.GlobalSettings = G
local classDefaults = { WARRIOR = { .78, .61, .43 }, PALADIN = { .96, .55, .73 }, HUNTER = { .67, .83, .45 },
    ROGUE = { 1, .96, .41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, .44, .87 }, MAGE = { .25, .78, .92 },
    WARLOCK = { .53, .53, .93 }, DRUID = { 1, .49, .04 } }
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v, low, high) return Public(v) and type(v) == "number" and v == v and v >= low and v <= high end

function G:GetClassColor(class)
    if not Public(class) or type(class) ~= "string" then return end
    local native
    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, value = pcall(C_ClassColor.GetClassColor, class)
        if ok then native = value end
    end
    native = native or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if Public(native) and type(native) == "table" and Number(native.r, 0, 1) and Number(native.g, 0, 1) and Number(native.b, 0, 1) then
        return native
    end
    local color = classDefaults[class]
    if color then return { r = color[1], g = color[2], b = color[3] } end
end
