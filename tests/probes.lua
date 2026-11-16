-- The probe kit (probes/Kit/ProbeKit.lua): small preview addons are built on
-- it to try a redesign in game without changing ModeUI. Every redesign so far
-- has been built into ModeUI and its probe retired, so this checks the kit
-- itself: its static rules, and a sample probe (a window with two tabs,
-- drawn only through ModeUI-Core) opened through /mprobe with secret live
-- values. Add a new probe's folder name to PROBES to load and check it too.
-- Simulated client; not native rendering.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local PROBES = {}
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local EXTRA = H.Read(H.root .. "tests/probe_stubs.lua")

-- A probe's files in TOC order; ProbeKit.lua comes from probes/Kit.
local function ProbeFiles(name)
    local files = {}
    local toc = H.Read(H.root .. "probes/" .. name .. "/" .. name .. ".toc")
    assert(toc:find("## Dependencies: ModeUI", 1, true), name .. " depends on ModeUI")
    for line in (toc .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        if line ~= "" and not line:find("^##") then
            files[#files + 1] = line == "ProbeKit.lua" and "probes/Kit/ProbeKit.lua" or ("probes/" .. name .. "/" .. line)
        end
    end
    assert(files[1] == "probes/Kit/ProbeKit.lua", name .. " loads the kit first")
    return files
end

-- Static rules over every probe file and the kit.
local seen = {}
local function Check(path)
    if seen[path] then return end
    seen[path] = true
    local text = H.Read(H.root .. path)
    local _, lines = text:gsub("\n", "")
    assert(lines < 400, path .. " is over 400 lines")
    assert(not text:find("ModeUIDB", 1, true), path .. " reads or writes ModeUIDB")
    assert(not text:find("%f[%w]addon%.") , path .. " reaches into ModeUI's addon table")
    assert(not text:find("Interface\\AddOns\\", 1, true), path .. " uses a texture path (Style.Asset only)")
    assert(not text:find("SetBackdrop", 1, true) and not text:find("AddMaskTexture", 1, true), path .. " draws its own border")
    -- Colors come from Style.Tone: no literal color triples.
    assert(not text:find("SetVertexColor%(%s*[%d%.]+%s*,"), path .. " hard-codes a vertex color")
    assert(not text:find("SetTextColor%(%s*[%d%.]+%s*,"), path .. " hard-codes a text color")
    assert(not text:find("hooksecurefunc", 1, true) and not text:find("SetAttribute", 1, true), path .. " touches secure code")
end

local world = H.Load({ before = STUBS .. "\n" .. EXTRA })
local env = world.env
local function Load(path, name, ns)
    Check(path)
    local fn = assert(load(H.Read(H.root .. path), "@" .. path, "t", env))
    fn(name, ns)
end
for _, name in ipairs(PROBES) do
    local ns = {}
    for _, path in ipairs(ProbeFiles(name)) do Load(path, name, ns) end
    assert(ns.Kit and ns.Kit.ok, name .. ": kit ready")
end

-- The sample probe: the kit, then a window drawn with ModeUI's design system.
local sample = {}
Load("probes/Kit/ProbeKit.lua", "ModeUI_ProbeSample", sample)
assert(sample.Kit and sample.Kit.ok, "the kit is ready on top of ModeUI-Core")
env.probeSample = sample
world.run([====[
    local Kit = probeSample.Kit
    local S, T, D = Kit.S, Kit.T, Kit.D
    local function Panel(body)
        local panel = CreateFrame('Frame', nil, body)
        panel:SetSize(200, 120); panel:SetPoint('TOPLEFT', 6, -6)
        Kit.Fill(panel, 'Panel', T.graphite.panel)
        S.Edge(panel, 'window')
        local holder = CreateFrame('Frame', nil, panel)
        holder:SetPoint('BOTTOMLEFT', 8, 8); holder:SetPoint('BOTTOMRIGHT', -8, 8); holder:SetHeight(6)
        local bar = S.Bar(holder, { role = 'health' }); bar:SetAllPoints()
        local okMax, max, okValue, value = D.Health.Read('player')
        bar:SetMinMaxValues(0, okMax and max or 1); bar:SetValue(okValue and value or 1)
        panel.bar = bar
        Kit.Caption(body, 'A sample panel.', panel, 0, -8)
        return panel
    end
    local built = {}
    Kit.Register('sample', 'Sample', function()
        built.window = built.window or Kit.Window('Sample', 'Sample', 420, 260, {
            { id = 'one', label = 'One', build = function(body) built.one = Panel(body) end },
            { id = 'two', label = 'Two', build = function(body) built.two = Panel(body) end },
        })
        return built.window
    end)
    local reg = assert(ModeUIProbes, 'probe registry')
    assert(SlashCmdList.MODEUIPROBE and SLASH_MODEUIPROBE1 == '/mprobe', 'one /mprobe command')
    local before = #messages; SlashCmdList.MODEUIPROBE(''); assert(#messages > before, '/mprobe alone lists the probes')
    -- A live unit whose health is secret: it reaches only the bar.
    units.player = { exists = true, health = Secret('hp'), max = Secret('max'), power = 0, powerMax = 0, token = 'ENERGY',
        name = 'Fixture', level = 60, class = 'ROGUE', isPlayer = true, connected = true, reaction = 5 }
    SlashCmdList.MODEUIPROBE('sample two')
    local window = reg.list.sample.window()
    assert(window:IsShown() and window.current == 'two' and built.two and built.one, 'opens on a tab (the first builds with the window)')
    assert(built.two.bar.value == units.player.health, 'the secret health went straight to the bar')
    SlashCmdList.MODEUIPROBE('sample one'); assert(window.current == 'one' and window.pages.one:IsShown() and not window.pages.two:IsShown(), 'switches tabs')
    SlashCmdList.MODEUIPROBE('sample'); assert(not window:IsShown(), '/mprobe <name> toggles it')
]====], "probes")
print("probes: all checks passed (kit and sample probe" .. (#PROBES > 0 and (", " .. #PROBES .. " probes") or "") .. ")")
