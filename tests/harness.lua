-- Loads ModeUI from its TOC into a fresh simulated client per call. Lua syntax,
-- startup, UI construction and settings restoration only; this is not WoW.
-- Runs on any Lua 5.1+ interpreter (5.2+ gets small 5.1 compatibility shims).
local H = {}
local sep = package.config:sub(1, 1)
local here = (debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "")
H.root = here .. ".." .. sep
H.addonDir = H.root .. "ModeUI" .. sep

local function Read(path)
    local file = assert(io.open(path, "rb"), "missing file: " .. path)
    local text = file:read("*a"); file:close()
    return (text:gsub("^\239\187\191", ""))
end
H.Read = Read

function H.Toc()
    local metadata, order = {}, {}
    for line in (Read(H.addonDir .. "ModeUI.toc") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local key, value = line:match("^## ([^:]+):%s*(.-)%s*$")
        if key then metadata[key] = value
        elseif line:match("%S") and not line:match("^#") then order[#order + 1] = line:gsub("\\", "/") end
    end
    return metadata, order
end

-- Expands XML includes the way the client does: <Script file> and <Include file>
-- paths are relative to the XML file's folder. Only those two elements (inside
-- <Ui>) are understood; anything else fails so the harness never silently skips
-- code. Returns Lua paths relative to the addon folder, in load order, and for
-- each one the TOC or XML file that loaded it, and the set of XML files read.
local function Directory(path) return path:match("^(.*/)") or "" end
local function Normalize(path)
    local parts = {}
    for part in path:gsub("\\", "/"):gmatch("[^/]+") do
        if part == ".." then
            assert(#parts > 0, "include path leaves the addon folder: " .. path)
            parts[#parts] = nil
        elseif part ~= "." then parts[#parts + 1] = part end
    end
    return table.concat(parts, "/")
end

function H.Files()
    local _, order = H.Toc()
    local files, loadedBy, visiting, xmlFiles = {}, {}, {}, {}
    local function Add(path, from)
        assert(path:match("%.lua$") or path:match("%.xml$"), "unexpected load entry " .. path .. " in " .. from)
        if path:match("%.lua$") then
            files[#files + 1] = path
            loadedBy[#files] = from
            return
        end
        assert(not visiting[path], "XML include loop at " .. path)
        visiting[path] = true
        xmlFiles[path] = true
        local text = Read(H.addonDir .. path:gsub("/", sep))
        text = text:gsub("<%?xml.-%?>", ""):gsub("<!%-%-.-%-%->", "")
        local base = Directory(path)
        for closing, tag, attributes, selfClosing in text:gmatch("<(/?)([%w_]+)(.-)(/?)>") do
            if tag == "Script" or tag == "Include" then
                assert(closing == "" and selfClosing == "/", path .. ": <" .. tag .. "> must be self-closing")
                local file = attributes:match('file%s*=%s*"([^"]+)"')
                assert(file, path .. ": <" .. tag .. "> needs a file attribute")
                Add(Normalize(base .. file), path)
            elseif tag ~= "Ui" then
                error(path .. ": harness does not support <" .. tag .. ">")
            end
        end
        visiting[path] = nil
    end
    for _, entry in ipairs(order) do Add(Normalize(entry), "ModeUI.toc") end
    return files, loadedBy, xmlFiles
end

local loadChunk = loadstring or load
local function Compile(source, name, env)
    if setfenv then
        local fn, err = loadstring(source, "@" .. name)
        assert(fn, err)
        return setfenv(fn, env)
    end
    local fn, err = load(source, "@" .. name, "t", env)
    assert(fn, err)
    return fn
end

-- options.before: Lua run after the addon files load, before ADDON_LOADED.
-- options.saved: table assigned to ModeUIDB before ADDON_LOADED.
-- options.ptg: table assigned to PTGToolsDB (Play The Game Tools' saved data).
-- options.files: extra Lua files (repo-relative) loaded as addon files after
-- the TOC, before ADDON_LOADED; used to run docs/module-template.
function H.Load(options)
    options = options or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.unpack = unpack or table.unpack
    env.loadstring = function(source, name) return load(source, name, "t", env) end
    env.getfenv = getfenv or function() return env end
    env.math = setmetatable({ pow = function(a, b) return a ^ b end }, { __index = math })
    Compile(Read(H.root .. "tests" .. sep .. "wow_mock.lua"), "wow_mock.lua", env)()
    Compile([[
        WOW_PROJECT_MAINLINE=1; WOW_PROJECT_CAMELOT=18; WOW_PROJECT_ID=18
        messages={}; function print(s) messages[#messages+1]=s end
        C_UI={Reload=function() reloads=(reloads or 0)+1 end}
        function UnitClass() return 'Rogue','ROGUE',4 end
        function UnitGUID() return 'Player-Collaboration-Fixture' end
        function UnitFullName() return 'Fixture','TestRealm' end
    ]], "setup", env)()
    local metadata, order = H.Toc()
    env.metadata = metadata
    env.C_AddOns.GetAddOnMetadata = function(_, key) return metadata[key] end
    local addon = {}
    env.addon = addon
    for _, name in ipairs(H.Files()) do
        Compile(Read(H.addonDir .. name:gsub("/", sep)), name, env)("ModeUI", addon)
    end
    for _, name in ipairs(options.files or {}) do
        Compile(Read(H.root .. name:gsub("/", sep)), name, env)("ModeUI", addon)
    end
    if options.saved then env.ModeUIDB = options.saved end
    if options.ptg then env.PTGToolsDB = options.ptg end
    if options.before then Compile(options.before, "before", env)() end
    Compile("FireEvent('ADDON_LOADED','ModeUI'); FireEvent('PLAYER_LOGIN')", "events", env)()
    local world = { env = env, addon = addon }
    function world.run(source, name) return Compile(source, name or "test", env)() end
    function world.saved() return addon.ProfileCodec.Copy(env.ModeUIDB) end
    return world
end

return H
