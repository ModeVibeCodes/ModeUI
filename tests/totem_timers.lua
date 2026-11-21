-- The totem timers reskin (Modules/UnitFrames/Totems.lua): Blizzard's
-- TotemFrame (Forever's Blizzard_UnitFrame/Mainline/TotemFrame) in the Mode
-- look while the ModeUI Player frame is on, and back when it is off. A
-- stand-in for Blizzard's frame, pool and buttons; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local TIMERS = [==[
    local methods = getmetatable(UIParent).__index
    function methods:SetSwipeTexture(t) self.swipeTexture = t end
    function methods:SetTexCoordRange(a, b) self.texCoordRange = { a, b } end
    function methods:SetSwipeColor(r, g, b, a) self.swipeColor = { r, g, b, a } end
    function methods:SetFontObject(o) self.fontObject = o end
    function methods:RemoveMaskTexture(m) self.removedMask = m end
    function methods:AddMaskTexture(m) self.addedMask = m end
    GameFontNormalSmall = {}
    C_Texture = C_Texture or {}
    C_Texture.GetAtlasInfo = function() return { file = 'circle', leftTexCoord = 0, topTexCoord = 0, rightTexCoord = 1, bottomTexCoord = 1 } end
    EARTH_TOTEM_SLOT, FIRE_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT = 2, 1, 3, 4
    local frame = CreateFrame('Frame', 'TotemFrame', UIParent); frame:SetSize(100, 37); frame:SetPoint('CENTER')
    local active = {}
    frame.totemPool = { EnumerateActive = function() local i = 0; return function() i = i + 1; return active[i] end end }
    local function Button(slot)
        local b = CreateFrame('Button', nil, frame); b:SetSize(37, 37); b:SetPoint('LEFT')
        b.slot = slot
        b.Duration = b:CreateFontString(); b.Border = b:CreateTexture()
        b.Icon = CreateFrame('Frame', nil, b); b.Icon:SetSize(22, 22); b.Icon:SetPoint('CENTER')
        b.Icon.Texture = b.Icon:CreateTexture(); b.Icon.TextureMask = b.Icon:CreateTexture()
        b.Icon.Cooldown = CreateFrame('Cooldown', nil, b.Icon)
        return b
    end
    active[1], active[2] = Button(EARTH_TOTEM_SLOT), Button(AIR_TOTEM_SLOT)
    -- Blizzard's update: the totem pool laid out again; each frame the time recolored gold.
    function frame:Update() for _, b in ipairs(active) do b.Duration:SetVertexColor(1, 0.82, 0) end end
    UnitClass = function() return 'Shaman', 'SHAMAN' end
    -- Blizzard's Player frame bottom container (ManagedFrameSystem).
    local container = { removed = 0, added = 0 }
    function container:RemoveManagedFrame(f) self.removed = self.removed + 1 end
    function container:AddManagedFrame(f) self.added = self.added + 1 end
    function GetPlayerBottomManagedFrameContainer() return container end
    totemContainer = container
    active[1].layoutIndex, active[2].layoutIndex = 2, 4
]==]
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. TIMERS

local world = H.Load({ before = STUBS })
world.run([==[
    local M, S = addon.UnitFrames, addon.Style
    local Tone = S.Tone
    if not M.enabled then addon:SetModuleEnabled('unitFrames', true) end
    assert(M:TotemsOn(), 'the Player frame is on')
    local buttons = {}
    for b in TotemFrame.totemPool:EnumerateActive() do buttons[#buttons + 1] = b end
    local earth, air = buttons[1], buttons[2]
    local art = M.totemArt[earth]
    -- A Mode icon: 24 x 20, unmasked, cropped, in the frameThin edge in the element's color.
    assert(art and art.edge.preset == 'frameThin' and art.edge.holder:IsShown(), 'the Mode edge')
    assert(earth.Icon.width == 24 and earth.Icon.height == 20 and earth.Icon.Texture.removedMask == earth.Icon.TextureMask, 'a Mode icon, not round')
    assert(earth.Icon.Texture.texCoord[1] == 0.08, 'cropped')
    assert(art.edge.tint == Tone.totem.earth and M.totemArt[air].edge.tint == Tone.totem.air, 'element rims for a Shaman')
    assert(earth.Border.alpha == 0, "Blizzard's gold ring faded")
    assert(earth.Icon.Cooldown.swipeTexture == addon.Kit.FLAT and earth.Icon.Cooldown.swipeColor[4] == 0.65, 'a flat swipe')
    -- The time: Bold 10 in Text bright, also after Blizzard recolors it each frame.
    assert(earth.Duration.font[2] == 10 and earth.Duration.font[1]:find('Urbanist%-Bold'), 'the Mode typeface, Bold 10')
    TotemFrame:Update()
    assert(math.abs(earth.Duration.vertexColor[1] - Tone.textBright[1]) < 1e-9 and math.abs(earth.Duration.vertexColor[3] - Tone.textBright[3]) < 1e-9, 'the time stays Text bright')
    -- Attached (Below, the default): taken from Blizzard's layout, hung from
    -- the Player frame's bar block, 1px outside its bottom right, growing left.
    local bars = _G[M.BarsFrameName('player')]
    local p = Point(TotemFrame)
    assert(TotemFrame.ignoreFramePositionManager == true and totemContainer.removed == 1 and TotemFrame.parent == UIParent, "out of Blizzard's layout")
    assert(p[1] == 'TOPRIGHT' and p[2] == bars and p[3] == 'BOTTOMRIGHT' and p[4] == 1 and p[5] == -2, 'under the bar block, 1px outside')
    local reach = S.EdgeReach('frameThin')
    assert(earth.width == 24 + 2 * reach and earth.height == 20 + 2 * reach, 'each button holds its icon and edge')
    local first, second = Point(earth), Point(air)
    assert(first[1] == 'TOPRIGHT' and first[4] == 0 and second[4] == -(24 + 2 * reach - 1), 'from the right, growing left, one shared shadow pixel')
    assert(TotemFrame.width == 2 * (24 + 2 * reach) - 1, 'the row as wide as its timers')
    assert(Point(earth.Duration)[1] == 'TOP' and Point(earth.Duration)[3] == 'BOTTOM', 'the time under the icon')
    -- Above (the Healer layout): over its top right, smaller icons, the time on the icon.
    M.db.totems.attach, M.db.totems.size = 'above', 18
    TotemFrame:Update()
    p = Point(TotemFrame)
    assert(p[1] == 'BOTTOMRIGHT' and p[3] == 'TOPRIGHT' and p[4] == 1 and p[5] == 2 and earth.Icon.width == 18 and earth.Icon.height == 14, 'over the top right, 18 x 14')
    assert(Point(earth.Duration)[1] == 'CENTER' and earth.Duration.font[2] == 9, 'the time on the icon, 9')
    -- Blizzard's Place: given back to Blizzard's layout.
    M.db.totems.attach = 'blizzard'
    TotemFrame:Update()
    assert(TotemFrame.ignoreFramePositionManager == nil and totemContainer.added == 1 and earth.width == 37, "back in Blizzard's layout")
    M.db.totems.attach, M.db.totems.size = 'below', 24
    TotemFrame:Update()
    assert(TotemFrame.ignoreFramePositionManager == true and totemContainer.removed == 2, 'taken again')
    -- Another class's summons keep the edge's own metal.
    UnitClass = function() return 'Druid', 'DRUID' end
    TotemFrame:Update()
    assert(art.edge.tint == nil, 'no element rim off a Shaman')
    UnitClass = function() return 'Shaman', 'SHAMAN' end
    -- The Player frame off: Blizzard's look back.
    assert(M:SetFrameOption('player', 'enabled', false))
    assert(not M:TotemsOn() and not art.edge.holder:IsShown() and earth.Border.alpha == 1, "Blizzard's ring back")
    assert(TotemFrame.ignoreFramePositionManager == nil and totemContainer.added == 2, "back in Blizzard's layout with the frame off")
    assert(earth.Icon.width == 22 and earth.Icon.Texture.addedMask == earth.Icon.TextureMask and earth.Duration.fontObject == GameFontNormalSmall, 'round again')
    assert(earth.Icon.Cooldown.swipeTexture == 'circle', 'the round swipe')
    TotemFrame:Update()
    assert(earth.Duration.vertexColor[2] == 0.82, "Blizzard's colors while off")
    assert(M:SetFrameOption('player', 'enabled', true) and art.edge.holder:IsShown() and earth.Border.alpha == 0, 'back in the Mode look')
]==], "totem timers")
print("totem timers: all checks passed")
