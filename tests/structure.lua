-- Folder layout and load order rules from docs/ARCHITECTURE.md. Static checks
-- on the files and the TOC/XML load list; nothing here runs the addon.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

-- Files that predate the layout. Each phase of the restructure removes entries;
-- new code may not be added to these.
local LEGACY_DIRECTORIES = {}
local LEGACY_MODULE_FILES = {}
local LINE_BUDGET = 400
local OVER_BUDGET = {}
local CODE_DIRECTORIES = { Libs = true, Shared = true, Modules = true }
local ASSET_DIRECTORIES = { Media = true }

local failures = {}
local function Fail(message) failures[#failures + 1] = message end

-- Every file under an addon folder (ModeUI's by default), relative to it
-- with forward slashes.
local function ListFiles(dir)
    local root = (dir or H.addonDir):gsub("[/\\]$", "")
    -- The first output line is the folder's absolute path; the listing follows.
    local command
    if package.config:sub(1, 1) == "\\" then
        command = 'cd /d "' .. root:gsub("/", "\\") .. '" && cd && dir /s /b /a-d'
    else
        command = "cd '" .. root:gsub("'", "'\\''") .. "' && pwd && find \"$(pwd)\" -type f"
    end
    local pipe = assert(io.popen(command), "cannot list addon files")
    local found, prefix = {}, nil
    for line in pipe:lines() do
        local path = line:gsub("\r$", ""):gsub("\\", "/")
        if not prefix then prefix = #path:gsub("/$", "") + 2
        else found[#found + 1] = path:sub(prefix) end
    end
    pipe:close()
    assert(#found > 0, "no addon files found under " .. root)
    table.sort(found)
    return found
end

local function TopDirectory(path) return path:match("^([^/]+)/") end
local function ModuleOf(path) return path:match("^Modules/([^/]+)/") end
local function CountLines(path, dir)
    local text = H.Read((dir or H.addonDir) .. path)
    local _, count = text:gsub("\n", "")
    if text ~= "" and text:sub(-1) ~= "\n" then count = count + 1 end
    return count
end

local files, loadedBy, xmlFiles = H.Files()
local position = {}
for index, path in ipairs(files) do
    if position[path] then Fail(path .. " is loaded twice (" .. loadedBy[position[path]] .. ", " .. loadedBy[index] .. ")") end
    position[path] = position[path] or index
end

-- Every Lua file is loaded exactly once, and every XML file is reachable.
local _, tocEntries = H.Toc()
local tocLoads = {}
for _, entry in ipairs(tocEntries) do tocLoads[entry:gsub("\\", "/")] = true end

local modules = {}
for _, path in ipairs(ListFiles()) do
    local top = TopDirectory(path)
    local lua, xml = path:match("%.lua$"), path:match("%.xml$")
    if lua or xml then
        if not top then
            Fail(path .. ": code files belong in Libs/, Shared/ or Modules/, not the addon root")
        elseif not CODE_DIRECTORIES[top] and not LEGACY_DIRECTORIES[top] then
            Fail(path .. ": " .. top .. "/ is not a code folder (Libs/, Shared/, Modules/)")
        end
    elseif top and not ASSET_DIRECTORIES[top] and not CODE_DIRECTORIES[top] and not LEGACY_DIRECTORIES[top] then
        Fail(path .. ": unexpected folder " .. top .. "/")
    end
    if lua and not position[path] then Fail(path .. " is never loaded by the TOC or an XML include") end
    if xml and not xmlFiles[path] then Fail(path .. " is never included by the TOC or another XML file") end
    if top == "Modules" then
        local name = ModuleOf(path)
        if name then
            modules[name] = modules[name] or {}
            modules[name][#modules[name] + 1] = path
        elseif not LEGACY_MODULE_FILES[path] then
            Fail(path .. ": each module is a folder, Modules/<Name>/")
        end
    end
    if lua and top ~= "Libs" then
        local lines = CountLines(path)
        if lines > LINE_BUDGET and not OVER_BUDGET[path] then
            Fail(path .. " has " .. lines .. " lines; split it (budget " .. LINE_BUDGET .. ")")
        elseif OVER_BUDGET[path] and lines <= LINE_BUDGET then
            Fail(path .. " is within budget now; remove it from OVER_BUDGET in tests/structure.lua")
        end
    end
end
for path in pairs(OVER_BUDGET) do
    if not position[path] then Fail("OVER_BUDGET lists " .. path .. ", which is not loaded; remove it") end
end
for path in pairs(LEGACY_MODULE_FILES) do
    if not position[path] then Fail("LEGACY_MODULE_FILES lists " .. path .. ", which is not loaded; remove it") end
end

-- Module folders: <Name>.xml loaded by the TOC, Init.lua first, Driver.lua,
-- and every file loaded from inside the module's own folder.
local firstModuleFile
for name, paths in pairs(modules) do
    local folder = "Modules/" .. name .. "/"
    local xml = folder .. name .. ".xml"
    local present = {}
    for _, path in ipairs(paths) do present[path] = true end
    if not present[xml] then Fail(folder .. " needs " .. name .. ".xml")
    elseif not tocLoads[xml] then Fail(xml .. " must be listed in ModeUI.toc") end
    if not present[folder .. "Init.lua"] then Fail(folder .. " needs Init.lua") end
    if not present[folder .. "Driver.lua"] then Fail(folder .. " needs Driver.lua") end
    local first
    for index, path in ipairs(files) do
        if path:sub(1, #folder) == folder then
            first = first or index
            local from = loadedBy[index]
            if from:sub(1, #folder) ~= folder then Fail(path .. " must be loaded by " .. xml .. ", not " .. from) end
        end
    end
    if first and files[first] ~= folder .. "Init.lua" then Fail(folder .. "Init.lua must load before the module's other files") end
    if first and (not firstModuleFile or first < firstModuleFile) then firstModuleFile = first end
end

-- Shared never names a module: no Shared file reaches for the table a
-- module's Init.lua publishes (addon.UnitFrames and the like), and no module
-- reaches for another module's table.
local moduleTables = {}
for name in pairs(modules) do
    local init = H.Read(H.addonDir .. "Modules/" .. name .. "/Init.lua")
    for field in init:gmatch("\naddon%.([%w_]+)%s*=%s*M%f[^%w_]") do moduleTables[field] = name end
end
for _, path in ipairs(files) do
    local owner = ModuleOf(path)
    if TopDirectory(path) == "Shared" or owner then
        local text = H.Read(H.addonDir .. path)
        for field, name in pairs(moduleTables) do
            if name ~= owner and text:find("addon%." .. field .. "%f[^%w_]") then
                Fail(path .. " uses addon." .. field .. " from Modules/" .. name .. "/; talk through addon.Messages or move it to Shared/")
            end
        end
    end
end

-- Layering: Libs first, then Shared, then module folders. Shared/Runtime/Boot.lua
-- starts the addon on ADDON_LOADED, so it loads last.
local lastLib, firstOther = 0, nil
for index, path in ipairs(files) do
    local top = TopDirectory(path)
    if top == "Libs" then lastLib = index elseif not firstOther then firstOther = index end
    if top == "Shared" and path ~= "Shared/Runtime/Boot.lua" and firstModuleFile and index > firstModuleFile then
        Fail(path .. " must load before every module folder")
    end
end
if firstOther and lastLib > firstOther then Fail("Libs/ files must load before everything else") end
if position["Shared/Runtime/Boot.lua"] and position["Shared/Runtime/Boot.lua"] ~= #files then
    Fail("Shared/Runtime/Boot.lua must be the last file loaded")
end

-- Companion addons (docs/ARCHITECTURE.md, "Companion addons"): <Name>.toc
-- needing ModeUI and grouped under it, Core.lua first (ModeUI's addon table
-- from ModeUI-Core) and Start.lua last, module folders like ModeUI's, every
-- file loaded once, the same line budget; ModeUI-Core lists the name.
local api = H.Read(H.addonDir .. "Shared/Runtime/API.lua")
for _, companion in ipairs(H.COMPANIONS) do
    local dir = H.Dir(companion)
    local meta, entries = H.Toc(companion)
    if meta.Dependencies ~= "ModeUI" then Fail(companion .. ".toc must list ## Dependencies: ModeUI") end
    if meta.Group ~= "ModeUI" then Fail(companion .. ".toc must list ## Group: ModeUI (the AddOn list nests it under ModeUI)") end
    if not api:find("%f[%w]" .. companion .. " = true") then Fail("ModeUI-Core's COMPANIONS must list " .. companion) end
    local list, by = H.Files(companion)
    local at = {}
    for index, file in ipairs(list) do
        if at[file] then Fail(companion .. "/" .. file .. " is loaded twice") end
        at[file] = at[file] or index
    end
    if list[1] ~= "Core.lua" then Fail(companion .. "/Core.lua must load first") end
    if list[#list] ~= "Start.lua" then Fail(companion .. "/Start.lua must load last") end
    local tocSet, folders = {}, {}
    for _, entry in ipairs(entries) do tocSet[entry] = true end
    for _, file in ipairs(ListFiles(dir)) do
        local lua = file:match("%.lua$")
        if lua and not at[file] then Fail(companion .. "/" .. file .. " is never loaded by its TOC or an XML include") end
        local name = file:match("^Modules/([^/]+)/")
        if name then folders[name] = true
        elseif lua and file ~= "Core.lua" and file ~= "Start.lua" then Fail(companion .. "/" .. file .. ": code belongs in Modules/<Name>/") end
        if lua and CountLines(file, dir) > LINE_BUDGET then Fail(companion .. "/" .. file .. " is over " .. LINE_BUDGET .. " lines") end
    end
    for name in pairs(folders) do
        local folder = "Modules/" .. name .. "/"
        if not tocSet[folder .. name .. ".xml"] then Fail(companion .. "/" .. folder .. name .. ".xml must be listed in " .. companion .. ".toc") end
        if not at[folder .. "Init.lua"] or not at[folder .. "Driver.lua"] then Fail(companion .. "/" .. folder .. " needs Init.lua and Driver.lua") end
        local first
        for index, file in ipairs(list) do
            if file:sub(1, #folder) == folder then
                first = first or index
                if by[index]:sub(1, #folder) ~= folder then Fail(companion .. "/" .. file .. " must be loaded by its module's XML") end
            end
        end
        if first and list[first] ~= folder .. "Init.lua" then Fail(companion .. "/" .. folder .. "Init.lua must load first") end
    end
end

if #failures > 0 then
    table.sort(failures)
    error("structure: " .. #failures .. " problem(s)\n  " .. table.concat(failures, "\n  "), 0)
end
print("structure: all checks passed (" .. #files .. " Lua files)")
