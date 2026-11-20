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
local EXPECTED = { "Solid", "Matte", "BG", "Gradient", "Button", "Glass", "Cast", "Panel", "Title", "Shield", "Obsidian", "ObsidianTrack" }
Check(table.concat(bars, ",") == table.concat(EXPECTED, ","), "bar textures in menu order: " .. table.concat(bars, ","))
-- Mode-Obsidian's are "Mode-<Name>" (owner, November 20, 2026).
local LSM_NAMES = { Obsidian = "Mode-Obsidian", ObsidianTrack = "Mode-Obsidian Track" }
for _, key in ipairs(bars) do
    local name = LSM_NAMES[key] or ("Mode " .. key)
    Check(keys[key] and keys[key][7] == name, key .. ": LibSharedMedia name should be " .. name)
end

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
    assert(addon.Style.ApplyAsset(tex, "EdgecutHeavy12s2m"), "border ring art applies")
    assert(addon.Style.ApplyAsset(tex, "NoSuchAsset") == false, "unknown keys are refused")
    assert(addon.Style.AssetPath("Shield"):find("Mode\\Bars\\Shield", 1, true))
    assert(addon.Style.FontPath("semibold"):find("Geist%-SemiBold%.ttf$"))
]])

-- The core: every edge preset lays out on whole pixels with no masks, takes a
-- highlight and a tint; bars swap textures and carry the spark and a shield;
-- names, icons and rings follow the design.
world.run([[
    local Style, Tone = addon.Style, addon.Style.Tone
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(184, 46)
    for preset, def in pairs(Style.EDGE_PRESETS) do
        local edge = Style.Edge(host, preset, { color = Tone.celadon })
        assert(edge.rimTexture and edge.holder, preset .. ": rim and holder")
        assert((edge.shadow ~= nil) == (def.shadow == true), preset .. ": shadow ring matches the preset")
        assert((edge.gap ~= nil) == (def.gap ~= nil), preset .. ": gap matches the preset")
        assert(edge:Layout() == (def.gap == true and 1 or 0) + def.rim, preset .. ": outset in pixels")
        assert(edge.styleId == def.style, preset .. ": the role's own style")
        edge:SetHighlight("accent")
        edge:SetHighlight(nil)
        edge:SetTint(Tone.dispel.Magic)
        edge:SetTint(nil)
        -- Every style keeps the role's reach and rings, so a layout never moves.
        for _, choice in ipairs(Style.EdgeStyleChoices()) do
            edge:SetStyle(choice.id)
            assert(edge.styleId == choice.id and edge:Layout() == (def.gap == true and 1 or 0) + def.rim, preset .. " in " .. choice.id .. ": same reach")
            assert((edge.shadow ~= nil) == (def.shadow == true) and (edge.gap ~= nil) == (def.gap ~= nil), preset .. " in " .. choice.id .. ": same rings")
            for i, ring in ipairs(edge.rings) do
                assert(edge.textures[i].texture == Style.AssetPath("Edge" .. ring.key), preset .. " " .. ring.key .. ": its art")
            end
        end
        edge:SetStyle(nil)
    end
    -- Pieces: each ring as four 1:1 corners and four edges (a sliced texture on
    -- a host shorter than its art is drawn scaled down to specks).
    local thin = CreateFrame("Frame", nil, UIParent)
    thin:SetSize(300, 10)
    local pieced = Style.Edge(thin, "frameThin", { pieces = true, style = "round", metal = "gunmetal" })
    local D = Style.EDGE_DATA
    for i, ring in ipairs(pieced.rings) do
        local parts, spec = pieced.parts[i], D.SHAPES[ring.shape]
        assert(#parts == 8 and parts[1] == pieced.textures[i], ring.key .. ": eight pieces, the first the ring's own")
        for _, part in ipairs(parts) do
            assert(part.texture == Style.AssetPath("Edge" .. ring.key) and part:IsShown() and part.slice == nil, ring.key .. ": unsliced art")
        end
        local tl, top, right = parts[1], parts[2], parts[5]
        assert(tl.width == spec.margin and tl.height == spec.margin and tl.points[1][4] == -ring.out and tl.points[1][5] == ring.out, ring.key .. ": a 1:1 corner")
        assert(tl.texCoord[2] == spec.margin / spec.w and tl.texCoord[4] == spec.margin / spec.h, ring.key .. ": the corner's texels")
        assert(top.height == spec.margin and top.points[1][4] == spec.margin - ring.out and top.points[2][4] == ring.out - spec.margin, ring.key .. ": the top edge between the corners")
        assert(right.width == spec.margin and right.texCoord[3] == spec.margin / spec.h, ring.key .. ": the side stretches the middle rows")
    end
    pieced:SetTint(Tone.celadon)
    for _, part in ipairs(pieced.parts[2]) do assert(part:IsShown() == not pieced.rings[2].profile) end
    assert(#pieced:Regions() == 8 * #pieced.rings, "every piece fades with the border")
    pieced:SetStyle("blizz")
    assert(#pieced.parts[1] == 8 and pieced.parts[1][2].texture == Style.AssetPath("Edge" .. pieced.rings[1].key), "a new style keeps its pieces")
    -- Snapping (Style.SnapEdges): at a UI scale that isn't pixel perfect a host
    -- sits between pixels; a snapped edge's holder moves onto whole pixels.
    local oldPixelUtil = PixelUtil
    PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1440 end }
    local root = CreateFrame("Frame", nil, UIParent)
    local control = CreateFrame("Button", nil, root)
    control:SetSize(191, 24); control.centerX, control.centerY = 300.5, 200.2
    local snapped, plain = Style.Edge(control, "control"), Style.Edge(host, "control")
    Style.SnapEdges(root)
    -- A host inside a frame the game forbids (an aura icon on Blizzard's
    -- containers): its parent can't be read, so the walk stops; no error.
    local walled = CreateFrame("Frame", nil, UIParent)
    walled.GetParent = function() error("Attempt to access forbidden object from code tainted by an AddOn") end
    local aura = CreateFrame("Frame", nil, walled); aura:SetSize(30, 30)
    local auraEdge = Style.Edge(aura, "control")
    assert(pcall(Style.SnapEdges, root) and auraEdge.snap == false, "a forbidden parent ends the walk")
    local hidden = CreateFrame("Frame", nil, UIParent); hidden.IsForbidden = function() return true end
    local inner = CreateFrame("Frame", nil, hidden); inner:SetSize(30, 30)
    local innerEdge = Style.Edge(inner, "control")
    assert(pcall(Style.SnapEdges, root) and innerEdge.snap == false, "so does a forbidden frame")
    Style.SnapEdges(root)
    local k = control:GetEffectiveScale() / (768 / 1440)
    local low, high = snapped.holder.points[1], snapped.holder.points[2]
    assert(low[1] == "BOTTOMLEFT" and high[1] == "TOPRIGHT" and low[2] == control, "corner to corner on the host")
    for _, side in ipairs({ { control:GetLeft(), low[4] }, { control:GetBottom(), low[5] },
        { control:GetLeft() + 191, high[4] }, { control:GetBottom() + 24, high[5] } }) do
        local px = side[1] * k + side[2]
        assert(math.abs(px - math.floor(px + 0.5)) < 1e-6 and math.abs(side[2]) <= 0.5, "each side on a whole pixel, moved under half a pixel")
    end
    assert(math.abs(low[4]) > 1e-6, "the fixture really sits between pixels")
    assert(plain.holder.points[1][1] == "TOPLEFT" and plain.holder.points[1][4] == 0, "an edge outside the root keeps the plain anchor")
    snapped:Layout(); assert(snapped.holder.points[1][1] == "BOTTOMLEFT", "a re-layout keeps the snap")
    PixelUtil = oldPixelUtil
    -- The roles' defaults (owner, November 17, 2026): frames Mode-Blizz in
    -- Silver, windows Mode-Thin in Steel. The reach of every role is what it
    -- was: the heavy roles' black line sits just inside the host.
    assert(Style.EdgeReach("frame") == 3 and Style.EdgeReach("window") == 3 and Style.EdgeReach("frameThin") == 2
        and Style.EdgeReach("group") == 1 and Style.EdgeReach("control") == 2 and Style.EdgeReach("card") == 2, "reach by role")
    assert(Style.EdgeDepth("frame") == 2 and Style.EdgeDepth("frameThin") == 1 and Style.EdgeDepth("card") == 2, "band and outside black line")
    -- Height floors: two slice margins per ring (cut 4/6, round 6/12) less the ring's reach outside the host.
    assert(Style.EdgeMinHeight("frameThin", "blizz") == 6 and Style.EdgeMinHeight("frameThin", "thin") == 6
        and Style.EdgeMinHeight("frameThin", "blizzEmpty") == 6 and Style.EdgeMinHeight("frameThin", "round") == 10, "thin floors")
    assert(Style.EdgeMinHeight("frame", "blizz") == 12 and Style.EdgeMinHeight("frame", "round") == 24, "heavy floors (the inside black line)")
    assert(Style.EdgeMinHeight("frameThin", nil) == 6, "the role's own style")
    local frame = Style.Edge(host, "frame")
    assert(frame.rings[#frame.rings].kind == "gap" and frame.rings[#frame.rings].out == 0, "the black line inside the host's edge")
    assert(frame.styleId == "blizz" and frame:Metal() == Tone.metal.silver, "frames: Mode-Blizz, Silver")
    -- The Specular band: a dark base with mid, light and hi layers, the metal's own tones.
    local layers = {}
    for i, ring in ipairs(frame.rings) do if ring.kind == "band" then layers[#layers + 1] = { ring, frame.textures[i] } end end
    assert(#layers == 4 and layers[1][1].tone == "dark" and layers[4][1].tone == "hi" and layers[4][1].profile == "s2h", "specular layers")
    assert(layers[1][2].vertexColor[1] == Tone.metal.silver.dark[1] and layers[4][2]:IsShown(), "painted in Silver")
    frame:SetTint(Tone.celadon)
    assert(layers[1][2].vertexColor[1] == Tone.celadon[1] and not layers[4][2]:IsShown(), "a tint is one flat color")
    frame:SetTint(nil)
    frame:SetStyle("blizz", "gunmetal")
    assert(frame:Metal() == Tone.metal.gunmetal and layers[1][2].vertexColor[1] == Tone.metal.gunmetal.dark[1], "another metal repaints")
    frame:SetStyle("blizzEmpty")
    assert(#frame.rings == 3 and frame.textures[2].vertexColor[1] == Tone.metal.silver.mid[1] and not frame.textures[4]:IsShown(), "Mode-BlizzEmpty: flat Silver mid, back to the style's metal")
    local window = Style.Edge(host, "window")
    assert(window.styleId == "thin" and window:Metal() == Tone.metal.steel and #window.rings == 8, "windows: Mode-Thin bevel in Steel")
    window:SetStyle("round", "default")
    assert(window.styleId == "round" and window:Metal() == Tone.metal.silver and window.rings[2].key:find("^roundHeavy"), "Mode-Round, Silver")
    assert(Style.EdgeStyleChoices(true)[5].id == "none" and Style.EdgeMetalChoices()[1].id == "default", "picker choices")
    frame:SetStyle(nil)
    frame:SetRim(1)
    assert(frame:Layout() == 1 and #frame.rings == 6 and frame.rings[3].profile == "s1m" and frame.rings[6].kind == "gap",
        "a 1px band: the 1px Specular band, and the shadow and black line stay")
    -- A host whose scale changes after layout (a nameplate aura button made
    -- once) keeps one physical pixel per holder unit: the holder ignores its
    -- parents' scale and takes the pixel factor itself.
    PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1440 end }
    local plateFrame = CreateFrame("Frame", nil, host); plateFrame:SetScale(0.1)
    local aura = CreateFrame("Frame", nil, plateFrame); aura:SetSize(22, 22)
    local auraEdge = Style.Edge(aura, "frameThin")
    plateFrame:SetScale(0.8)
    assert(auraEdge.holder:IsIgnoringParentScale() and math.abs(auraEdge.holder:GetEffectiveScale() - 768 / 1440) < 1e-9, "a holder unit is one physical pixel, whatever the host's scale")
    PixelUtil = nil
    auraEdge:Layout()
    assert(not auraEdge.holder:IsIgnoringParentScale() and auraEdge.holder.scale == 1, "without the factor: the host's pixel size")
    -- Bars: every picker texture applies; unknown keys fall back to Matte.
    local bar = Style.Bar(host, { role = "health" })
    assert(bar.textureKey == "Matte", "health bars default to Mode Matte")
    for _, key in ipairs(Style.BAR_TEXTURES) do bar:SetTextureKey(key); assert(bar.textureKey == key) end
    bar:SetTextureKey("NoSuchTexture"); assert(bar.textureKey == "Matte")
    assert(Style.Bar(host, { role = "power" }).textureKey == "Gradient", "power is Mode Gradient")
    assert(Style.Bar(host, { role = "cast" }).textureKey == "Cast", "cast bars are Mode Cast")
    -- Matte draws its base with the sheen lift; health and power empty parts are see-through.
    assert(bar:SetTextureKey("Matte") == nil and bar.lift:IsShown() and bar.lift.texture == Style.AssetPath("MatteLift"), "Matte has a sheen")
    assert(math.abs(bar.bg.vertexColor[4] - Tone.emptyAlpha) < 1e-9 and Tone.emptyAlpha == 0.6, "see-through health empty part")
    assert(Style.Bar(host, { role = "cast" }).bg.vertexColor[4] == 1, "cast bars stay solid")
    assert(Style.SameColor(Tone.darkFill, Style.Hex("1C1D1C")), "the dark fill")
    -- Module bars (Kit.BarForeground): a Mode texture with a lift draws its base
    -- and the white lift on the sheen, over the fill; others hide the sheen.
    assert(Style.MediaAsset("media:Mode Glass") == Style.ASSETS.Glass and select(2, Style.MediaAsset("media:Mode Matte")) == "Matte")
    assert(Style.MediaAsset("media:Other") == nil and Style.MediaAsset(nil) == nil)
    local kbar = addon.Kit.Bar(host)
    addon.Kit.BarForeground(kbar, "media:Mode Glass", 20, 1)
    assert(kbar.statusBarTexture == Style.AssetPath("GlassBase") and kbar.sheen:IsShown() and kbar.sheen.texture == Style.AssetPath("GlassLift"), "Glass base + lift")
    assert(kbar.sheen.points[1][2] == kbar:GetStatusBarTexture() and kbar.liftKey == "Glass", "the lift covers the fill")
    -- The lift fades with the fill's opacity (a hook on SetStatusBarColor).
    local hooks = {}
    hooksecurefunc = hooksecurefunc or function(t, name, hook)
        local old = t[name]; hooks[#hooks + 1] = name
        t[name] = function(...) old(...); hook(...) end
    end
    local fbar = addon.Kit.Bar(host)
    addon.Kit.BarForeground(fbar, "media:Mode Matte", 20, 1)
    fbar:SetStatusBarColor(0.1, 0.1, 0.1, 0.4)
    assert(fbar.sheen:GetAlpha() == 0.4, "the lift fades with the fill")
    addon.Kit.BarForeground(fbar, "flat", 20, 1)
    assert(fbar.sheen:GetAlpha() == 1, "a texture without a lift resets the sheen")
    addon.Kit.BarForeground(kbar, "media:Mode BG", 20, 1)
    assert(not kbar.sheen:IsShown() and kbar.liftKey == nil, "BG has no lift")
    addon.Kit.BarForeground(kbar, "mode", 20, 1)
    assert(kbar.sheen:IsShown() and kbar.sheen.points[1][2] ~= kbar:GetStatusBarTexture(), "the older Mode Gradient sheen anchors back to the bar")
    bar:SetFill(Tone.reaction.hostile)
    bar:SetSpark(true); assert(bar.head:IsShown() and not bar.endLine:IsShown(), "a spark replaces the end line")
    bar:SetSpark(false); assert(not bar.head:IsShown() and bar.endLine:IsShown())
    local shield = Style.Shield(bar)
    shield:Update(nil, { max = 100, shield = 15, total = 30 })
    shield:Update("player", { max = 100, shield = 0, total = 25 })
    -- The Hairline spans the whole bar (tiled 1:1) and is clipped to the fill, so it never stretches.
    for _, lines in ipairs({ shield.attachedLines, shield.fullLines }) do
        local first = lines.points and lines.points[1]
        assert(first and first[2] == bar, "hairline lines anchor to the bar, not the fill")
    end
    assert(shield.attachedClip.points[1][2] == shield.attached:GetStatusBarTexture(), "and clip to the shield fill")
    -- Names: Gradient is per letter from the color to 50% color + 50% white.
    local text = Style.GradientText("Mode", { 1, 0, 0 })
    assert(text:sub(1, 10) == "|cffff0000" and text:find("|r$"), "gradient starts at the color")
    local finish = Style.GradientEnd({ 1, 0, 0 })
    assert(math.abs(finish[2] - 0.5) < 1e-6, "gradient ends 50% toward white")
    assert(Style.GradientText(nil, { 1, 0, 0 }) == nil)
    -- A shield's look: Mode textures only, opacity 10-200%, nil back to standard.
    local look = Style.Shield(Style.Bar(host))
    assert(look.look.texture == 'Shield' and look.look.opacity == 1 and look.look.color == nil, 'standard look')
    look:SetLook({ texture = 'Nope' }); assert(look.look.texture == 'Shield', 'unknown texture falls back')
    look:SetLook({ texture = 'Glass', opacity = 5, color = Tone.celadon })
    assert(look.look.opacity == 2 and look.attachedLines.texture:find('Glass') and look.attachedLift.vertexColor[4] == 0.84)
    look:SetLook(nil); assert(look.look.texture == 'Shield' and look.look.opacity == 1 and look.look.color == nil)
    -- Icons: wider than tall.
    assert(Style.IconHeight(30) == 26 and Style.IconHeight(40) == 34 and Style.IconHeight(44) == 38 and Style.IconHeight(56) == 50)
    local ring = Style.Ring(host, 66)
    assert(ring.portrait and ring.mask and ring.rim == 3 and ring.shadow, "portrait ring, 3px of metal and a shadow ring")
    assert(ring.line and ring.line.vertexColor[1] == Tone.shadow[1] and ring.line.vertexColor[3] == Tone.shadow[3], "the 1px black line inside the metal")    -- Mode-Blizz's specular layers in Silver by default; a color is Mode-BlizzEmpty.
    local silver = Tone.metal.silver
    assert(#ring.layers == 4 and ring.disc.vertexColor[1] == silver.dark[1] and ring.layers[4].texture.vertexColor[1] == silver.hi[1], "Mode-Blizz, Silver")
    for _, profile in ipairs(Style.EDGE_DATA.RingProfiles()) do assert(Style.ASSETS["Ring" .. profile], "ring art is registered") end
    Style.PaintRing(ring, nil, "steel")
    assert(ring.disc.vertexColor[1] == Tone.metal.steel.dark[1] and ring.layers[2].texture:IsShown(), "another metal")
    Style.PaintRing(ring, Tone.celadon)
    local function Near(a, b) return math.abs(a - b) < 1e-9 end
    local cel = Style.ColorTones(Tone.celadon)
    assert(Near(cel.mid[1], Tone.celadon[1]) and Near(cel.dark[2], Tone.celadon[2] * 0.55) and Near(cel.hi[3], Tone.celadon[3] + (1 - Tone.celadon[3]) * 0.6), "tones made from a color")
    assert(Near(ring.disc.vertexColor[1], cel.dark[1]) and ring.layers[2].texture:IsShown() and Near(ring.layers[2].texture.vertexColor[1], Tone.celadon[1])
        and Near(ring.layers[4].texture.vertexColor[1], cel.hi[1]), "a color: Specular lighting in its own tones")
    assert(ring.line.vertexColor[1] == Tone.shadow[1] and ring.shadow.vertexColor[1] == Tone.shadow[1], "a colored ring keeps its black line and shadow")
    -- Every Mode border style draws on the ring; bevel's inner row sits 1px in.
    for _, choice in ipairs(Style.EdgeStyleChoices()) do
        Style.SetRingStyle(ring, choice.id)
        assert(ring.styleId == choice.id and #ring.layers == #Style.EDGE_DATA.RingLayers(choice.id), choice.id)
    end
    Style.SetRingStyle(ring, "thin"); Style.PaintRing(ring)
    assert(#ring.layers == 6 and ring.disc.vertexColor[1] == Tone.metal.steel.mid[1], "Mode-Thin: Steel bevel")
    Style.SetRingStyle(ring, "blizzEmpty"); Style.PaintRing(ring)
    assert(#ring.layers == 1 and ring.disc.vertexColor[1] == silver.mid[1] and not ring.pool[2]:IsShown(), "Mode-BlizzEmpty: flat Silver")
    Style.SetRingStyle(ring, "bogus")
    assert(ring.styleId == "blizz" and #ring.layers == 4 and ring.pool[4]:IsShown(), "unknown style: Mode-Blizz")
    assert(Style.SameColor(Style.Hex("575757"), Tone.slate), "Slate, a little lighter")
    -- Health text glow: a halo in the text's color, sized from the format and
    -- set on the text's justified side; it follows the color and visibility.
    local hooked = {}
    local oldHook = hooksecurefunc
    hooksecurefunc = function(t, name, hook)
        local old = t[name]; hooked[#hooked + 1] = name
        t[name] = function(...) old(...); hook(...) end
    end
    local text = host:CreateFontString(nil, "OVERLAY")
    text:SetTextColor(0.2, 0.8, 0.4, 1)
    Style.TextGlow(text, { size = 10, chars = Style.GLOW_CHARS.percent, justify = "RIGHT", px = 1 })
    local glow = text.glow
    assert(glow and glow.texture == Style.AssetPath("TextGlow") and glow.blendMode == "ADD" and glow.layer == "OVERLAY", "an added-light halo")
    assert(glow.width == 25 + 10 and glow.height == 10 + 10, "sized from the format: 4 digits x 0.62 x 10, 5px round")
    assert(glow.points[1][1] == "RIGHT" and glow.points[1][2] == text and glow.points[1][4] == 5, "on the justified side")
    assert(glow.vertexColor[2] == 0.8 and glow.vertexColor[4] == Style.TEXT_GLOW_ALPHA and glow:IsShown(), "the text's color")
    text:SetTextColor(0.9, 0.3, 0.3, 1)
    assert(glow.vertexColor[1] == 0.9, "follows a new color")
    text:Hide(); assert(not glow:IsShown(), "hides with the text")
    text:Show(); assert(glow:IsShown())
    Style.TextGlow(text, nil); assert(not glow:IsShown(), "toggled off")
    text:Show(); assert(not glow:IsShown(), "stays off")
    -- Text glow, Halo: 8 copies under the text that take its writes (color
    -- codes left out), its color by mode, and its visibility.
    local word = host:CreateFontString(nil, "OVERLAY")
    word:SetFont("Fonts/x.ttf", 12, "OUTLINE"); word:SetJustifyH("LEFT"); word:SetTextColor(0.2, 0.8, 0.4, 1); word:SetText("87%")
    Style.TextHalo(word, { color = "deep", strength = 0.2, px = 1 })
    local halo = word.halo
    assert(#halo == 8 and halo[1].text == "87%" and halo[1].font[3] == "" and halo[1].shadowColor[4] == 0, "8 copies, no outline or shadow")
    assert(halo[1].alpha == 0.2 and halo[8].alpha == 0.2, "every copy at the strength")
    for _, copy in ipairs(halo) do
        local x, y = copy.points[1][4], copy.points[1][5]
        assert(math.abs(x) <= 1 and math.abs(y) <= 1 and (x ~= 0 or y ~= 0), "1px out, tight to the letters")
    end
    assert(word.shadowColor[4] == 0, "the glow takes the shadow's place")
    local deep = Style.Deep({ 0.2, 0.8, 0.4 })
    assert(math.abs(halo[1].color[2] - deep[2]) < 1e-9 and deep[2] < 0.6 and deep[2] > deep[1], "Deep: the same hue, darker")
    word:SetText("|cffff0000Kae|rlyn"); assert(halo[5].text == "Kaelyn", "color codes stay out of the glow")
    word:SetFormattedText("|cff808080%s|r %s", "60", "Kaelyn"); assert(halo[8].text == "60 Kaelyn")
    Style.TextHalo(word, { color = "ink", strength = 0.2, px = 1 })
    word:SetTextColor(0, 1, 0); assert(halo[1].color[2] == Tone.shadow[2], "Ink stays dark")
    Style.TextHalo(word, { color = "match", strength = 0.2, px = 1 })
    word:SetTextColor(0, 1, 0); assert(halo[1].color[2] == 1, "Match follows the text")
    word:Hide(); assert(not halo[1]:IsShown(), "hides with the text")
    word:Show(); assert(halo[1]:IsShown())
    Style.TextHalo(word, nil); assert(not halo[1]:IsShown(), "toggled off")
    word:Show(); word:SetText("off"); assert(not halo[1]:IsShown() and halo[1].text ~= "off", "stays off and unwritten")
    hooksecurefunc = oldHook
    assert(Style.Accent("specialty") == Tone.rosewood and Style.Accent() == Tone.ivory)
    -- The style sheet builds on demand.
    assert(_G.ModeUIStyleSheet == nil, "no sheet before /modeui style")
    Style.ToggleSheet()
    assert(_G.ModeUIStyleSheet and _G.ModeUIStyleSheet:IsShown(), "sheet opens")
    Style.ToggleSheet()
    assert(not _G.ModeUIStyleSheet:IsShown(), "and closes")
    -- Companions and probes reach the same Style and Domain through ModeUI-Core.
    local Core = LibStub("ModeUI-Core", true)
    assert(Core and Core.Style == Style and Core.Domain == addon.Domain and Core.IsPublic == addon.IsPublic, "ModeUI-Core API")
    assert(Core.Ready() == (addon.initialized == true))
]])

if #failures > 0 then
    table.sort(failures)
    error("style: " .. #failures .. " problem(s)\n  " .. table.concat(failures, "\n  "), 0)
end
print("style: all checks passed (" .. #assets .. " assets)")
