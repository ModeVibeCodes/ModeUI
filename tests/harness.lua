-- Loads ModeUI from its TOC into a fresh simulated client per call. Lua syntax,
-- startup, UI construction and settings restoration only; this is not WoW.
-- Runs on any Lua 5.1+ interpreter (5.2+ gets small 5.1 compatibility shims).
local H = {}
local sep = package.config:sub(1, 1)
local here = (debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "")
H.root = here .. ".." .. sep
H.addonDir = H.root .. "ModeUI" .. sep
-- Companion addons beside ModeUI (docs/ARCHITECTURE.md, "Companion addons"),
-- each a folder of its own with <Name>.toc, loaded after ModeUI.
H.COMPANIONS = { "ModeCDM" }
-- An addon's folder: ModeUI's, or a companion's.
function H.Dir(name) return (name == nil or name == "ModeUI") and H.addonDir or (H.root .. name .. sep) end

local function Read(path)
    local file = assert(io.open(path, "rb"), "missing file: " .. path)
    local text = file:read("*a"); file:close()
    return (text:gsub("^\239\187\191", ""))
end
H.Read = Read

function H.Toc(name)
    local metadata, order = {}, {}
    for line in (Read(H.Dir(name) .. (name or "ModeUI") .. ".toc") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
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

function H.Files(name)
    local dir, toc = H.Dir(name), (name or "ModeUI") .. ".toc"
    local _, order = H.Toc(name)
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
        local text = Read(dir .. path:gsub("/", sep))
        text = text:gsub("<%?xml.-%?>", ""):gsub("<!%-%-.-%-%->", "")
        local base = Directory(path)
        for closing, tag, attributes, selfClosing in text:gmatch("<(/?)([%w_]+)(.-)(/?)>") do
            if tag == "Script" or tag == "Include" then
                assert(closing == "" and selfClosing == "/", path .. ": <" .. tag .. "> must be self-closing")
                local file = attributes:match('file%s*=%s*"([^"]+)"')
                assert(file, path .. ": <" .. tag .. "> needs a file attribute")
                Add(Normalize(base .. file), path)
            elseif tag ~= "Ui" and tag ~= "Font" then
                -- <Font> declares a font object (Kit/Fonts.xml) and runs no code.
                error(path .. ": harness does not support <" .. tag .. ">")
            end
        end
        visiting[path] = nil
    end
    for _, entry in ipairs(order) do Add(Normalize(entry), toc) end
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
-- options.companions: false loads ModeUI alone; otherwise every companion
-- loads from its TOC after ModeUI, with its own name and namespace.
-- options.lateCompanions: the companions load after ModeUI's ADDON_LOADED
-- (the client may run a dependent addon's files then).
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
    local metadata = H.Toc()
    env.metadata = metadata
    local companionMetadata = {}
    for _, name in ipairs(H.COMPANIONS) do companionMetadata[name] = H.Toc(name) end
    env.C_AddOns.GetAddOnMetadata = function(name, key) return (companionMetadata[name] or metadata)[key] end
    local addon = {}
    env.addon = addon
    for _, name in ipairs(H.Files()) do
        Compile(Read(H.addonDir .. name:gsub("/", sep)), name, env)("ModeUI", addon)
    end
    for _, name in ipairs(options.files or {}) do
        Compile(Read(H.root .. name:gsub("/", sep)), name, env)("ModeUI", addon)
    end
    local namespaces = {}
    local function LoadCompanions()
        if options.companions == false then return end
        for _, companion in ipairs(H.COMPANIONS) do
            local ns = {}
            namespaces[companion] = ns
            for _, name in ipairs(H.Files(companion)) do
                Compile(Read(H.Dir(companion) .. name:gsub("/", sep)), companion .. "/" .. name, env)(companion, ns)
            end
        end
    end
    if not options.lateCompanions then LoadCompanions() end
    if options.saved then env.ModeUIDB = options.saved end
    if options.ptg then env.PTGToolsDB = options.ptg end
    if options.before then Compile(options.before, "before", env)() end
    Compile("FireEvent('ADDON_LOADED','ModeUI')", "events", env)()
    if options.lateCompanions then LoadCompanions() end
    for _, companion in ipairs(options.companions == false and {} or H.COMPANIONS) do
        env.FireEvent("ADDON_LOADED", companion)
    end
    Compile("FireEvent('PLAYER_LOGIN')", "events", env)()
    local world = { env = env, addon = addon, namespaces = namespaces }
    function world.run(source, name) return Compile(source, name or "test", env)() end
    -- What the client would write to SavedVariables: a plain deep copy of the
    -- whole database. Not ProfileCodec.Copy, whose size cap is for one profile
    -- (import/export); the database holds every profile.
    function world.saved()
        local function Copy(value)
            if type(value) ~= "table" then return value end
            local result = {}
            for k, v in pairs(value) do result[k] = Copy(v) end
            return result
        end
        return Copy(env.ModeUIDB)
    end
    return world
end

return H
