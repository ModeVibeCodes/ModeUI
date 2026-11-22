local _, addon = ...
local M = addon.Media
-- The bundled texture registry: Mode theme and unit frame artwork, with
-- slicing metadata, applied to textures by key.

-- Source originals and runtime cutouts share one bundled asset registry.
M.textureBase = addon.Style.TEXTURE_ROOT
M.Textures = {
    -- The settings scroll bar's thumb.
    ModeScrollThumb = { file = "Mode/ScrollThumb.tga", rounded = true },
    -- Unit Frames Satin Matte (tools/build_unit_frame_textures.py): neutral
    -- luminance tinted in-game; slices cover each corner radius.
    UnitFrameCircle = { file = "UnitFrames/Circle.tga", rounded = true },
    -- Status badge icons (tools/build_shape_textures.lua), white, tinted in game.
    UnitFrameRested = { file = "UnitFrames/Rested.tga", transparent = true },
    UnitFrameCombat = { file = "UnitFrames/Combat.tga", transparent = true },
    -- Procedural shapes from tools/build_shape_textures.lua. ModeFlat rounds
    -- settings controls (4 px corners) and ModeCard the cards (6 px); the
    -- switch track and slider track are stadiums sliced only left and right
    -- ({ left, top, right, bottom }). The nameplate rims use small corner
    -- radii so health and cast boxes round alike.
    ModeFlat = { file = "Mode/Flat.tga", slice = 5, rounded = true },
    ModeChevron = { file = "Mode/Chevron.tga", transparent = true },
    -- 4x4 tile for Mode Slate Hatch (Kit.BarBackground tiles it per pixel).
    ModeSlateHatch = { file = "Mode/SlateHatch.tga" },
    NameplateGlow = { file = "Nameplates/Glow.tga", slice = 12, rounded = true },
    AuraGlow = { file = "Nameplates/AuraGlow.tga", slice = 6, rounded = true },
    NameplateArrow = { file = "Nameplates/Arrow.tga", transparent = true },
    NameplateStripes = { file = "Nameplates/Stripes.tga", transparent = true },
    -- Skins (Shared/Skin): the close button's cross.
    ModeClose = { file = "Mode/Close.tga", transparent = true },
    -- Window shrink and expand glyphs.
    ModeMinimize = { file = "Mode/Minimize.tga", transparent = true },
    ModeMaximize = { file = "Mode/Maximize.tga", transparent = true },
    -- Chat compartment glyphs: the chat menu's speech bubble and Channels' "#".
    ChatMenu = { file = "Chat/Menu.tga", transparent = true },
    ChatChannels = { file = "Chat/Channels.tga", transparent = true },
    ChatFriends = { file = "Chat/Friends.tga", transparent = true },
    -- Damage meter header glyphs and the resize grip, tinted in game.
    DamageMeterReset = { file = "DamageMeters/Reset.tga", transparent = true },
    DamageMeterLock = { file = "DamageMeters/Lock.tga", transparent = true },
    DamageMeterUnlock = { file = "DamageMeters/Unlock.tga", transparent = true },
    DamageMeterGrip = { file = "DamageMeters/Grip.tga", transparent = true },
    -- The same grip on Edit Mode's panel (Shared/Settings/EditPanel.lua).
    ResizeGrip = { file = "DamageMeters/Grip.tga", transparent = true },
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
