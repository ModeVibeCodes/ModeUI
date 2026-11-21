-- The Mode design standard (docs/DESIGN_LANGUAGE.md), checked on the source.
-- Colors, borders, masks, bar textures, texture paths and font files belong in
-- Shared/Style/ only. Code that predates the standard is listed with its counts
-- in tests/design_legacy.lua; a count may only go down, and an entry is removed
-- when its file is clean. New code gets no allowance.
--   lua tests/design.lua             check
--   lua tests/design.lua --baseline  print the current counts (for the legacy list)
local here = (debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "")
local H = dofile(here .. "harness.lua")
local LEGACY = dofile(here .. "design_legacy.lua")

local RULES = {
    { id = "color", why = "colors come from Style.Tone",
      patterns = { "%f[%w]RGB%(", "SetColorTexture%(%s*[%d%.]", "SetVertexColor%(%s*[%d%.]", "SetTextColor%(%s*[%d%.]",
                   "SetStatusBarColor%(%s*[%d%.]", "SetGradient%(", "|c[fF][fF]%x%x%x%x%x%x" } },
    { id = "border", why = "borders come from Style.Edge presets",
      patterns = { "Kit%.Rim%(", "Kit%.PlaceRim%(", "ModeBorder%(", "ModeBoxBorder%(", "SetBackdrop%(" } },
    { id = "mask", why = "borders need no masks; circles use the ring preset",
      patterns = { "CreateMaskTexture%(", "AddMaskTexture%(", "SetMaskTexture%(" } },
    { id = "bar", why = "bars come from Style.Bar",
      patterns = { "SetStatusBarTexture%(" } },
    { id = "path", why = "textures come from Style.Asset keys",
      patterns = { "Interface[\\/]+[Aa]dd[Oo]ns[\\/]+ModeUI" } },
    { id = "font", why = "fonts come from Style.Font",
      patterns = { "%.[Tt][Tt][Ff]%f[^%w]", "%.[Oo][Tt][Ff]%f[^%w]" } },
}

local function Exempt(path)
    return path:match("^Libs/") or path:match("^Shared/Style/")
end
local function Count(text, rule)
    local total = 0
    for _, pattern in ipairs(rule.patterns) do
        for _ in text:gmatch(pattern) do total = total + 1 end
    end
    return total
end

-- ModeUI's files, then each companion's as "<Companion>/<path>".
local files, source = H.Files(), {}
for _, companion in ipairs(H.COMPANIONS) do
    for _, path in ipairs(H.Files(companion)) do
        files[#files + 1] = companion .. "/" .. path
        source[companion .. "/" .. path] = H.Dir(companion) .. path
    end
end
local found = {}
for _, path in ipairs(files) do
    if not Exempt(path) then
        local text = H.Read(source[path] or (H.addonDir .. path))
        for _, rule in ipairs(RULES) do
            local n = Count(text, rule)
            if n > 0 then found[path] = found[path] or {}; found[path][rule.id] = n end
        end
    end
end

if arg and arg[1] == "--baseline" then
    local paths = {}
    for path in pairs(found) do paths[#paths + 1] = path end
    table.sort(paths)
    print("return {")
    for _, path in ipairs(paths) do
        local parts = {}
        for _, rule in ipairs(RULES) do
            if found[path][rule.id] then parts[#parts + 1] = rule.id .. " = " .. found[path][rule.id] end
        end
        print('    ["' .. path .. '"] = { ' .. table.concat(parts, ", ") .. " },")
    end
    print("}")
    return
end

-- The retired Mode-Blizz look (November 20, 2026; archive/mode-blizz/):
-- no code names its textures, border style ids, asset keys or Geist. Only
-- a module's Migrations.lua and Theme.lua (its history) and the code that maps old saved
-- values (Shared/Style, Shared/Runtime/DB.lua) may.
local RETIRED = {
    "media:Mode BG", "media:Mode Matte", "media:Mode Gradient", "media:Mode Button", "media:Mode Glass", "media:Mode Cast",
    "media:Mode Panel", "media:Mode Title", "media:Mode%-Obsidian\"", "Mode%-Obsidian Track", "Mode%-ObsidianEmpty",
    "[Ss]tyle%s*=%s*\"blizz\"", "[Ss]tyle%s*=%s*\"blizzEmpty\"", "[Ss]tyle%s*=%s*\"thin\"", "[Ss]tyle%s*=%s*\"round\"",
    "ApplyAsset%([^,]+,%s*\"Matte", "ApplyAsset%([^,]+,%s*\"Gradient\"", "ApplyAsset%([^,]+,%s*\"Button\"",
    "ApplyAsset%([^,]+,%s*\"Glass", "ApplyAsset%([^,]+,%s*\"Cast", "ApplyAsset%([^,]+,%s*\"Panel\"", "ApplyAsset%([^,]+,%s*\"Title\"",
    "PaintBox%([^\n]-\"Matte\"", "PaintBox%([^\n]-\"Panel\"", "PaintBox%([^\n]-\"Title\"", "PaintBox%([^\n]-\"Glass\"",
    "PaintBox%([^\n]-\"Button\"", "PaintBox%([^\n]-\"Gradient\"", "Geist", "Mode%-Blizz",
}
local retired = {}
for _, path in ipairs(files) do
    -- A module's Theme.lua moves old profiles from the Mode-Blizz defaults, so it may say so.
    if not (Exempt(path) or path:match("Migrations%.lua$") or path:match("Modules/[^/]+/Theme%.lua$")
        or path == "Shared/Runtime/DB.lua" or path == "Shared/Runtime/Themes.lua") then
        local text = H.Read(source[path] or (H.addonDir .. path))
        for _, pattern in ipairs(RETIRED) do
            if text:find(pattern) then retired[#retired + 1] = path .. ": names the retired look (" .. pattern .. ")" end
        end
    end
end

local failures = {}
for _, line in ipairs(retired) do failures[#failures + 1] = line end
local loaded = {}
for _, path in ipairs(files) do loaded[path] = true end
for path, counts in pairs(found) do
    for _, rule in ipairs(RULES) do
        local n, allowed = counts[rule.id] or 0, (LEGACY[path] or {})[rule.id] or 0
        if n > allowed then
            failures[#failures + 1] = path .. ": " .. n .. " " .. rule.id .. " use(s), " .. allowed .. " allowed; " .. rule.why
        end
    end
end
for path, counts in pairs(LEGACY) do
    if not loaded[path] then
        failures[#failures + 1] = "design_legacy.lua lists " .. path .. ", which is not loaded; remove it"
    else
        for id, allowed in pairs(counts) do
            local n = (found[path] or {})[id] or 0
            if n < allowed then
                failures[#failures + 1] = path .. ": " .. id .. " is down to " .. n .. "; lower its allowance in tests/design_legacy.lua (was " .. allowed .. ")"
            end
        end
    end
end

if #failures > 0 then
    table.sort(failures)
    error("design: " .. #failures .. " problem(s)\n  " .. table.concat(failures, "\n  "), 0)
end
local legacyFiles = 0
for _ in pairs(LEGACY) do legacyFiles = legacyFiles + 1 end
print("design: all checks passed (" .. legacyFiles .. " legacy file(s) still to migrate)")
