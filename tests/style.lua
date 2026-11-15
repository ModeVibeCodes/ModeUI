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
        assert((edge.gap ~= nil) == (def.gap == true), preset .. ": gap matches the preset")
        assert(edge:Layout() == (def.gap and 1 or 0) + def.rim, preset .. ": outset in pixels")
        edge:SetHighlight("accent")
        edge:SetHighlight(nil)
        edge:SetTint(Tone.dispel.Magic)
        edge:SetTint(nil)
    end
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
