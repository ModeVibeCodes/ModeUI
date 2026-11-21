local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- The totem timers (owner, November 20, 2026): Blizzard's TotemFrame (the
-- round icons with a time under them that Blizzard hangs below its Player
-- frame; Forever's Blizzard_UnitFrame/Mainline/TotemFrame) in the Mode look
-- while the ModeUI Player frame is on. A reskin only: Blizzard keeps the
-- frame, its pool of buttons, their places, clicks (right-click dismisses)
-- and tooltips; ModeUI paints over them.
--   * the icon a Mode icon: 24 x 20, cropped, never round (Blizzard's circle
--     mask taken off), in the `frameThin` edge, its rim the element's color
--     for a Shaman's totems (Tone.totem; other summons keep the edge's metal);
--   * Blizzard's gold ring faded; the swipe flat, not round;
--   * the time in the Mode typeface, Bold 10, Text bright.
-- Blizzard re-sets the time's color every frame (AuraButtonMixin.UpdateDuration),
-- so a hook paints it back.
local Style, Kit = addon.Style, addon.Kit
local Tone = Style.Tone
local WIDTH = 24
M.totemArt = setmetatable({}, { __mode = "k" })

local function Element(slot)
    if slot == _G.EARTH_TOTEM_SLOT then return Tone.totem.earth end
    if slot == _G.FIRE_TOTEM_SLOT then return Tone.totem.fire end
    if slot == _G.WATER_TOTEM_SLOT then return Tone.totem.water end
    if slot == _G.AIR_TOTEM_SLOT then return Tone.totem.air end
end
local function Shaman()
    local ok, _, class = pcall(UnitClass, "player")
    return ok and addon.IsPublic(class) and class == "SHAMAN"
end
function M:TotemsOn() return self.active == true and self:FrameOn("player") end

-- The time's color, put back after Blizzard's (a guard keeps the hook from
-- answering its own call).
local painting = false
local function PaintTime(text)
    if painting or not M:TotemsOn() then return end
    painting = true
    local c = Tone.textBright
    text:SetVertexColor(c[1], c[2], c[3])
    painting = false
end

function M:SkinTotem(button)
    local icon = button and button.Icon
    if not (icon and icon.Texture) then return end
    local art = self.totemArt[button]
    if not art then
        art = { edge = Style.Edge(icon, "frameThin", { pieces = true }) }
        self.totemArt[button] = art
        if button.Duration and hooksecurefunc then hooksecurefunc(button.Duration, "SetVertexColor", PaintTime) end
    end
    local height = Style.IconHeight(WIDTH)
    icon:SetSize(WIDTH, height)
    local texture = icon.Texture
    if icon.TextureMask and texture.RemoveMaskTexture and not art.unmasked then
        art.unmasked = pcall(texture.RemoveMaskTexture, texture, icon.TextureMask)
    end
    texture:ClearAllPoints(); texture:SetAllPoints(icon)
    Kit.CropIcon(texture, { px = Kit.PixelSize(icon), w = WIDTH, h = height, inset = 0 })
    if button.Border then button.Border:SetAlpha(0) end
    local cooldown = icon.Cooldown
    if cooldown and cooldown.SetSwipeTexture then
        cooldown:SetSwipeTexture(Kit.FLAT)
        if cooldown.SetTexCoordRange then cooldown:SetTexCoordRange({ x = 0, y = 0 }, { x = 1, y = 1 }) end
        local shadow = Tone.shadow
        if cooldown.SetSwipeColor then cooldown:SetSwipeColor(shadow[1], shadow[2], shadow[3], 0.65) end
    end
    art.edge:SetShown(true)
    art.edge:SetTint(Shaman() and Element(button.slot) or nil)
    art.edge:Layout()
    if button.Duration then
        Style.Font(button.Duration, 10, "bold")
        button.Duration:SetShadowColor(Tone.shadow[1], Tone.shadow[2], Tone.shadow[3], 0.95)
        button.Duration:SetShadowOffset(1, -1)
        PaintTime(button.Duration)
    end
end

local function Buttons(frame)
    local list = {}
    if frame.totemPool and frame.totemPool.EnumerateActive then
        for button in frame.totemPool:EnumerateActive() do list[#list + 1] = button end
    else
        for _, child in ipairs({ frame:GetChildren() }) do if child.Icon then list[#list + 1] = child end end
    end
    return list
end

-- Every timer showing now, and each time Blizzard updates them.
function M:SkinTotems()
    local frame = _G.TotemFrame
    if type(frame) ~= "table" then return end
    if not self.totemHooked and hooksecurefunc and type(frame.Update) == "function" then
        self.totemHooked = true
        hooksecurefunc(frame, "Update", function(f) if M:TotemsOn() then M:SkinTotems() end end)
    end
    if not self:TotemsOn() then self:RestoreTotems(); return end
    for _, button in ipairs(Buttons(frame)) do self:SkinTotem(button) end
end

-- ModeUI's Player frame off: Blizzard's own look back on every timer.
function M:RestoreTotems()
    for button, art in pairs(self.totemArt) do
        art.edge:SetShown(false)
        local icon = button.Icon
        if icon and icon.TextureMask and art.unmasked and icon.Texture.AddMaskTexture then
            pcall(icon.Texture.AddMaskTexture, icon.Texture, icon.TextureMask); art.unmasked = false
        end
        if icon then icon:SetSize(22, 22); icon.Texture:SetTexCoord(0, 1, 0, 1) end
        if button.Border then button.Border:SetAlpha(1) end
        if button.Duration and _G.GameFontNormalSmall then button.Duration:SetFontObject(_G.GameFontNormalSmall) end
        -- The round swipe, as TotemButtonMixin:OnLoad sets it.
        local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("CircleMask")
        local cooldown = icon and icon.Cooldown
        if atlas and cooldown and cooldown.SetTexCoordRange then
            cooldown:SetSwipeTexture(atlas.file or atlas.filename)
            cooldown:SetTexCoordRange({ x = atlas.leftTexCoord, y = atlas.topTexCoord }, { x = atlas.rightTexCoord, y = atlas.bottomTexCoord })
        end
    end
end
