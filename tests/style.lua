-- The Mode design system (Shared/Style, docs/DESIGN_LANGUAGE.md): every asset
-- key points at a real power-of-two TGA, the fonts ship with their license,
-- and the bar textures and fonts register with LibSharedMedia; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local failures = {}
local function Check(ok, message) if not ok then failures[#failures + 1] = message end end

local function TgaSize(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local header = file:read(18)
    file:close()
    if not header or #header < 18 then return nil end
    local w = header:byte(13) + header:byte(14) * 256
    local h = header:byte(15) + header:byte(16) * 256
    return w, h, header:byte(17), header:byte(3)
end
local function PowerOfTwo(n) return n > 0 and (n & (n - 1)) == 0 end

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS })
local assets = world.run([[
    local list = {}
    for key, asset in pairs(addon.Style.ASSETS) do list[#list + 1] = { key, asset.file, asset.slice or 0, asset.tile and true or false, asset.fill, asset.lift, asset.lsm } end
    return list
]])

-- Every asset: a 32-bit power-of-two TGA, slice margins under half its size.
local keys = {}
for _, entry in ipairs(assets) do
    local key, file, slice, tile, fill, lift = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6]
    keys[key] = entry
    local path = H.addonDir .. "Media/Textures/Mode/" .. file:gsub("\\", "/") .. ".tga"
    local w, h, depth, kind = TgaSize(path)
    Check(w, key .. ": missing file " .. path)
    if w then
        Check(PowerOfTwo(w) and PowerOfTwo(h), key .. ": " .. w .. "x" .. h .. " is not a power of two")
        Check(depth == 32 and kind == 2, key .. ": must be an uncompressed 32-bit TGA")
        Check(slice * 2 < math.min(w, h), key .. ": slice margin " .. slice .. " too large for " .. w .. "x" .. h)
    end
    if fill then Check(fill == "Solid" or fill:match("Base$"), key .. ": fill should be Solid or a Base texture") end
end
for _, entry in ipairs(assets) do
    if entry[5] then Check(keys[entry[5]], entry[1] .. ": fill " .. entry[5] .. " is not an asset") end
    if entry[6] then Check(keys[entry[6]], entry[1] .. ": lift " .. entry[6] .. " is not an asset") end
end

-- The picker's bar textures: each has a LibSharedMedia name, and the names are the design's.
local bars = world.run([[ return addon.Style.BAR_TEXTURES ]])
local EXPECTED = { "Solid", "Matte", "BG", "Gradient", "Button", "Glass", "Cast", "Panel", "Title", "Shield" }
Check(table.concat(bars, ",") == table.concat(EXPECTED, ","), "bar textures in menu order: " .. table.concat(bars, ","))
for _, key in ipairs(bars) do Check(keys[key] and keys[key][7] == "Mode " .. key, key .. ": LibSharedMedia name should be Mode " .. key) end

-- Fonts: the four static Geist weights and the OFL beside them.
for _, weight in ipairs({ "Regular", "Medium", "SemiBold", "Bold" }) do
    local file = io.open(H.addonDir .. "Media/Fonts/Geist/Geist-" .. weight .. ".ttf", "rb")
    Check(file, "missing Geist-" .. weight .. ".ttf")
    if file then
        local magic = file:read(4); file:close()
        Check(magic == "\0\1\0\0", "Geist-" .. weight .. ".ttf is not a TrueType file")
    end
end
Check(io.open(H.addonDir .. "Media/Fonts/Geist/OFL.txt", "rb"), "Geist needs its OFL.txt beside the fonts")

-- LibSharedMedia: every bar texture as statusbar and background, every Geist weight as a font.
local registered = world.run([[
    local lsm = LibStub("LibSharedMedia-3.0")
    local out = {}
    for _, key in ipairs(addon.Style.BAR_TEXTURES) do
        local name = addon.Style.ASSETS[key].lsm
        out[#out + 1] = { name, lsm:IsValid("statusbar", name), lsm:IsValid("background", name) }
    end
    for _, name in pairs(addon.Style.FONT_NAMES) do out[#out + 1] = { name, lsm:IsValid("font", name), true } end
    return out
]])
for _, entry in ipairs(registered) do Check(entry[2] and entry[3], entry[1] .. " is not registered with LibSharedMedia") end

-- Applying an asset sets its path, wrap and slice margins; an unknown key does nothing.
world.run([[
    local tex = CreateFrame("Frame"):CreateTexture()
    assert(addon.Style.ApplyAsset(tex, "Rim1"), "Rim1 applies")
    assert(addon.Style.ApplyAsset(tex, "NoSuchAsset") == false, "unknown keys are refused")
    assert(addon.Style.AssetPath("Shield"):find("Mode\\Bars\\Shield", 1, true))
    assert(addon.Style.FontPath("semibold"):find("Geist%-SemiBold%.ttf$"))
]])

if #failures > 0 then
    table.sort(failures)
    error("style: " .. #failures .. " problem(s)\n  " .. table.concat(failures, "\n  "), 0)
end
print("style: all checks passed (" .. #assets .. " assets)")
