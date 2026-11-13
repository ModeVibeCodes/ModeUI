local _, addon = ...
local M = addon.Media
-- The bundled texture registry: Mode theme and unit frame artwork, with
-- slicing metadata, applied to textures by key.

-- Source originals and runtime cutouts share one bundled asset registry.
M.textureBase = "Interface\\AddOns\\ModeUI\\Media\\Textures\\"
M.Textures = {
    ModeSurface = { file = "Mode/Surface.tga", slice = 12, rounded = true },
    ModePageDetail = { file = "Mode/PageAbstract.tga", transparent = true },
    ModePillSurface = { file = "Mode/PillSurface.tga", rounded = true },
    ModeHeaderLine = { file = "Mode/HeaderLine.tga", transparent = true },
    ModeBorder = { file = "Mode/Border.tga", slice = 12, transparent = true },
    ModeSelection = { file = "Mode/Selection.tga", transparent = true },
    ModeControlSurface = { file = "Mode/ControlSurface.tga", slice = 10, rounded = true },
    ModeControlBorder = { file = "Mode/ControlBorder.tga", slice = 10, transparent = true },
    -- Fixed-size controls use full sprites: no slice margins can flatten their
    -- small alpha corners. Fresh paths avoid reusing previously cached images.
    ModeCheckSurface = { file = "Mode/CheckSurfaceRound.tga", rounded = true },
    ModeCheckBorder = { file = "Mode/CheckBorderRound.tga", transparent = true },
    ModeCheckMark = { file = "Mode/CheckSurfaceRound.tga", rounded = true },
    ModeToggleSurface = { file = "Mode/ToggleSurfacePill.tga", rounded = true },
    ModeToggleBorder = { file = "Mode/ToggleBorderPill.tga", transparent = true },
    ModeThumb = { file = "Mode/Thumb.tga", rounded = true },
    ModeSliderThumb = { file = "Mode/CheckSurfaceRound.tga", rounded = true },
    ModeScrollThumb = { file = "Mode/ScrollThumb.tga", rounded = true },
    ModeDivider = { file = "Mode/Divider.tga", transparent = true },
    ModeLogo = { file = "Mode/Logo.tga", transparent = true },
    -- Unit Frames Satin Matte (tools/build_unit_frame_textures.py): neutral
    -- luminance tinted in-game; slices cover each corner radius.
    UnitFrameFrame = { file = "UnitFrames/FrameFill.tga", slice = 6, rounded = true },
    UnitFrameFrameInner = { file = "UnitFrames/FrameInner.tga", slice = 4, rounded = true },
    UnitFrameCircle = { file = "UnitFrames/Circle.tga", rounded = true },
    UnitFrameBar = { file = "UnitFrames/BarSatin.tga" },
    -- Status badge icons (tools/build_shape_textures.lua), white, tinted in game.
    UnitFrameRested = { file = "UnitFrames/Rested.tga", transparent = true },
    UnitFrameCombat = { file = "UnitFrames/Combat.tga", transparent = true },
    -- Procedural shapes from tools/build_shape_textures.lua. ModeFlat rounds
    -- settings controls (4 px corners) and ModeCard the cards (6 px); the
    -- switch track and slider track are stadiums sliced only left and right
    -- ({ left, top, right, bottom }). The nameplate rims use small corner
    -- radii so health and cast boxes round alike.
    ModeFlat = { file = "Mode/Flat.tga", slice = 5, rounded = true },
    ModeCard = { file = "Mode/Card.tga", slice = 7, rounded = true },
    ModeCircle = { file = "Mode/Circle.tga", rounded = true },
    ModeSwitch = { file = "Mode/Switch.tga", slice = { 8, 0, 8, 0 }, rounded = true },
    ModeTrack = { file = "Mode/Track.tga", slice = { 2, 0, 2, 0 }, rounded = true },
    ModeChevron = { file = "Mode/Chevron.tga", transparent = true },
    -- 4x4 tile for Mode Slate Hatch (Kit.BarBackground tiles it per pixel).
    ModeSlateHatch = { file = "Mode/SlateHatch.tga" },
    -- Half-oval box ends and their hole masks (Kit.CapRing, Kit.EndMask).
    ModeCapRight = { file = "Mode/CapRight.tga", rounded = true },
    ModeCapLeft = { file = "Mode/CapLeft.tga", rounded = true },
    ModeCapHoleRight = { file = "Mode/CapHoleRight.tga", transparent = true },
    ModeCapHoleLeft = { file = "Mode/CapHoleLeft.tga", transparent = true },
    NameplateRim = { file = "Nameplates/Rim.tga", slice = 4, rounded = true },
    NameplateGap = { file = "Nameplates/Gap.tga", slice = 3, rounded = true },
    NameplateGlow = { file = "Nameplates/Glow.tga", slice = 12, rounded = true },
    AuraGlow = { file = "Nameplates/AuraGlow.tga", slice = 6, rounded = true },
    NameplateArrow = { file = "Nameplates/Arrow.tga", transparent = true },
    -- The action slot background (in color, not tinted), stretched to the slot.
    ActionBarSlot = { file = "ActionBars/Slot.tga" },
    NameplateStripes = { file = "Nameplates/Stripes.tga", transparent = true },
    -- Skins (Shared/Skin): the frosted chat tab, feathered at its sides and
    -- top, and the close button's cross.
    ModeGlass = { file = "Mode/Glass.tga", slice = 6, rounded = true },
    ModeClose = { file = "Mode/Close.tga", transparent = true },
    -- Window shrink and expand glyphs, and the glass tabs' diagonal glint.
    ModeMinimize = { file = "Mode/Minimize.tga", transparent = true },
    ModeMaximize = { file = "Mode/Maximize.tga", transparent = true },
    ModeSheen = { file = "Mode/Sheen.tga", transparent = true },
    -- Chat compartment glyphs: the chat menu's speech bubble and Channels' "#".
    ChatMenu = { file = "Chat/Menu.tga", transparent = true },
    ChatChannels = { file = "Chat/Channels.tga", transparent = true },
    -- Damage meter header glyphs and the resize grip, tinted in game.
    DamageMeterReset = { file = "DamageMeters/Reset.tga", transparent = true },
    DamageMeterLock = { file = "DamageMeters/Lock.tga", transparent = true },
    DamageMeterUnlock = { file = "DamageMeters/Unlock.tga", transparent = true },
    DamageMeterGrip = { file = "DamageMeters/Grip.tga", transparent = true },
}


-- Return path and read-only rendering metadata; unknown names return nil.
function M:GetTexture(name)
    local asset = self.Textures[name]
    if asset then return self.textureBase .. asset.file, asset end
end

function M:ApplyTexture(texture, key, fallback)
    local asset = assert(self.Textures[key], "ModeUI: unknown texture " .. tostring(key))
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexCoord(0, 1, 0, 1)
    local usable = (not asset.slice or texture.SetTextureSliceMargins ~= nil)
        and texture:SetTexture(self.textureBase .. asset.file, "CLAMP", "CLAMP")
    if usable then
        local slice = asset.slice
        if type(slice) == "table" then texture:SetTextureSliceMargins(slice[1], slice[2], slice[3], slice[4])
        elseif slice then texture:SetTextureSliceMargins(slice, slice, slice, slice) end
        if asset.crop then texture:SetTexCoord(unpack(asset.crop)) end
    else
        local color = fallback or { 0, 0, 0, 1 }
        -- A solid rectangular fallback would reintroduce protruding corners.
        texture:SetColorTexture(color[1], color[2], color[3], (asset.transparent or asset.rounded) and 0 or (color[4] or 1))
        if not self.textureFailures[key] then
            self.textureFailures[key] = true
            print("ModeUI: texture unavailable (" .. key .. "); using a plain fallback.")
        end
    end
    return usable
end
