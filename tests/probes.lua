-- Probe addons (probes/): each loads on top of ModeUI from its own TOC, opens
-- through /mprobe, builds every tab, and runs its updates with live units whose
-- values are secret. Static checks: probes draw only through ModeUI-Core and
-- never touch ModeUI's settings or Blizzard's frames. Not native rendering.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local PROBES = { "ModeUI_ProbeFrames", "ModeUI_ProbePanels" }
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

local before = STUBS .. "\n" .. EXTRA
local world = H.Load({ before = before })
local env = world.env
local function LoadProbe(name)
    local ns = {}
    for _, path in ipairs(ProbeFiles(name)) do
        Check(path)
        local fn = assert(load(H.Read(H.root .. path), "@" .. path, "t", env))
        fn(name, ns)
    end
    return ns
end
for _, name in ipairs(PROBES) do
    local ns = LoadProbe(name)
    assert(ns.Kit and ns.Kit.ok, name .. ": kit ready")
end

world.run([====[
    local reg=assert(ModeUIProbes,'probe registry')
    assert(SlashCmdList.MODEUIPROBE and SLASH_MODEUIPROBE1=='/mprobe','one /mprobe command')
    for _,id in ipairs({'frames','panels'}) do assert(reg.list[id],'registered: '..id) end
    -- /mprobe alone lists the probes.
    local before=#messages;SlashCmdList.MODEUIPROBE('');assert(#messages>before,'lists probes')
    -- Live units: secret health, power and casts reach only widgets that accept them.
    units.player={exists=true,health=Secret('hp'),max=Secret('max'),power=Secret('pw'),powerMax=Secret('pmax'),token='ENERGY',
        name='Fixture',level=60,class='ROGUE',isPlayer=true,connected=true,reaction=5}
    units.party1={exists=true,health=Secret('hp1'),max=Secret('max1'),power=10,powerMax=100,token='MANA',name=Secret('name1'),
        level=60,class='PRIEST',isPlayer=true,connected=true,reaction=5}
    units.target={exists=true,health=Secret('thp'),max=Secret('tmax'),power=0,powerMax=0,token='MANA',name='Defias Thug',
        level=18,reaction=2,cast={name=Secret('cast'),text=Secret('text'),texture=Secret('tex'),startMs=Secret('s'),endMs=Secret('e'),
        notInterruptible=Secret('locked')}}
    for _,id in ipairs(reg.order) do
        SlashCmdList.MODEUIPROBE(id)
        local window=reg.list[id].window()
        assert(window:IsShown(),'opens: '..id)
        for _,tab in ipairs(window.order) do
            SlashCmdList.MODEUIPROBE(id..' '..tab.id)
            assert(window.current==tab.id and window.pages[tab.id]:IsShown(),'tab builds: '..id..' '..tab.id)
            for _=1,8 do Advance(0.11) end
        end
        SlashCmdList.MODEUIPROBE(id);assert(not window:IsShown(),'closes: '..id)
    end
    -- Group Frames: every layout and source, frames 1px apart outside their rims.
    local frames=reg.list.frames.window()
    frames:Select('group');frames:Show()
    local body=frames.pages.group
    local function Buttons(parent,out)
        out=out or {}
        for _,child in ipairs(parent.childList or {}) do
            if child.kind=='Button' and child.id then out[#out+1]=child end
            Buttons(child,out)
        end
        return out
    end
    for _,button in ipairs(Buttons(body)) do button.scripts.OnClick(button);for _=1,6 do Advance(0.21) end end
    for _,id in ipairs({'party','healer','raid','raidhealer','vertical'}) do
        for _,button in ipairs(Buttons(body)) do if button.id==id or button.id=='live' or button.id=='class' then button.scripts.OnClick(button) end end
        for _=1,6 do Advance(0.21) end
        for _,button in ipairs(Buttons(body)) do if button.id=='samples' then button.scripts.OnClick(button) end end
        Advance(0.21)
    end
    -- Live party: the secret health went straight to the health bar.
    local function Click(id) for _,button in ipairs(Buttons(body)) do if button.id==id then button.scripts.OnClick(button) end end end
    Click('party');Click('live');Advance(0.21)
    local function Find(parent,test)
        for _,region in ipairs(parent.regionList or {}) do if test(region) then return region end end
        for _,child in ipairs(parent.childList or {}) do
            if test(child) then return child end
            local found=Find(child,test);if found then return found end
        end
    end
    assert(Find(body,function(f) return f.kind=='StatusBar' and f.value==units.party1.health end),'live party1 health is the secret value')
    assert(Find(body,function(f) return f.kind=='StatusBar' and f.value==units.player.health end),'live player health')
    Click('samples');Advance(0.21)
    assert(Find(body,function(f) return f.kind=='StatusBar' and f.value==27 end),'sample at 27%')
    frames:Hide()
    local function Has(parent,test) return Find(parent,test)~=nil end
    -- Minimap: the game clock; the secret zone only reaches SetText.
    local panels=reg.list.panels.window();panels:Select('minimap');panels:Show();Advance(1.1)
    assert(Has(panels.pages.minimap,function(f) return f.GetText and f:GetText()=='09:05' end),'game clock')
    panels:Hide()
    -- No target: the live plate hides.
    units.target=nil
    local plates=reg.list.frames.window();plates:Select('plates');plates:Show();Advance(0.2);plates:Hide()
]====], "probes")

print("probes: all checks passed (" .. #PROBES .. " probes)")
