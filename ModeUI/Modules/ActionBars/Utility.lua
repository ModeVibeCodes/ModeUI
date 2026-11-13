local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The micro menu and the bag bar (Forever's own: square bag slots and a key
-- ring). Blizzard's buttons move onto plain ModeUI bars and take the Mode
-- skin; the buttons keep Blizzard's code (clicks, tooltips, alerts, bag
-- contents). Neither the buttons nor these bars are secure, so they can be
-- laid out again in combat when Blizzard moves them back.
--
-- What Blizzard keeps doing, and how the look survives it:
--  * Micro buttons: SetPushed/SetNormal re-apply the highlight atlas and
--    re-place the Character portrait on every UpdateMicroButtons; hooks
--    restyle after them. Blizzard's own button background and portrait
--    frame are faded; the glyph (Normal, Pushed, Disabled, Highlight atlases)
--    sits inside the Mode border. Blizzard shows and hides some buttons
--    (Store, Help, Housing); the bar lays out the shown ones.
--  * Bag buttons: UpdateTextures re-applies their frame art and BagsBar:Layout
--    re-anchors them (on picking up an item, among others); hooks restyle and
--    re-place them. The backpack's free-slot count is the bar's Count text.
--  * MicroMenu and BagsBar (empty now, with their frame art and dividers)
--    fade to 0 alpha. ModeUI only calls hooksecurefunc and HookScript on
--    Blizzard's frames; it never writes fields on them or calls their
--    layout code.
local Kit, Public = addon.Kit, addon.IsPublic
M.utilityFrames = { micro = "MicroMenu", bags = "BagsBar" }
-- Bag buttons left to right, as Blizzard shows them (its bar grows left
-- from the backpack). The key ring only shows when the character has one.
M.BAG_BUTTONS = { "KeyRingButton", "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot",
    "CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton" }

local function Shown(frame)
    if not frame or not frame.IsShown then return false end
    local shown = frame:IsShown()
    return Public(shown) and shown == true
end

-- Every button a utility bar can hold, in order. The micro menu's are the
-- ones Blizzard added to it (they carry a layoutIndex), in its order.
function M:CollectUtility(bar)
    local spec, list = self.barSpecs[bar], {}
    if spec.utility == "micro" then
        local menu = _G.MicroMenu
        if type(menu) == "table" and menu.GetChildren then
            for _, child in ipairs({ menu:GetChildren() }) do
                local index = child.layoutIndex
                if Public(index) and type(index) == "number" then list[#list + 1] = child end
            end
            table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
        end
    else
        for _, name in ipairs(self.BAG_BUTTONS) do
            local button = _G[name]
            if type(button) == "table" and button.SetParent then list[#list + 1] = button end
        end
    end
    while #list > spec.count do table.remove(list) end
    return list
end

-- Moving a shown micro button fires its OnShow/OnHide, which re-lays out
-- Blizzard's micro menu; MicroMenuMixin:GetEdgeButton then compares the
-- centers of the lowest and highest layoutIndex buttons still on it. A
-- button hidden since load (Help) was never placed and has no center, so it
-- must never be left first or last: hidden buttons leave first and come back
-- last (moving a hidden button fires nothing).
function M:ShownLast(frames)
    local hidden, shown = {}, {}
    for _, frame in ipairs(frames) do
        local list = Shown(frame) and shown or hidden
        list[#list + 1] = frame
    end
    for _, frame in ipairs(shown) do hidden[#hidden + 1] = frame end
    return hidden
end

-- The buttons laid out now: the ones Blizzard shows.
function M:UtilityButtons(bar)
    local list = {}
    for _, button in ipairs(self.buttons[bar] or {}) do if Shown(button) then list[#list + 1] = button end end
    return list
end

-- Blizzard's empty bars fade out while ModeUI holds their buttons.
function M:FadeUtilityFrames(faded)
    self.utilityAlpha = self.utilityAlpha or {}
    for kind, name in pairs(self.utilityFrames) do
        local frame = _G[name]
        if type(frame) == "table" and frame.SetAlpha then
            if faded then
                if self.utilityAlpha[kind] == nil then self.utilityAlpha[kind] = frame:GetAlpha() end
                frame:SetAlpha(0)
            elseif self.utilityAlpha[kind] ~= nil then
                frame:SetAlpha(Public(self.utilityAlpha[kind]) and self.utilityAlpha[kind] or 1)
                self.utilityAlpha[kind] = nil
            end
        end
    end
end

local function Texture(button, key, getter)
    local texture = button[key]
    if texture == nil and button[getter] then texture = button[getter](button) end
    return texture
end
local function Inset(region, host, inset) if region and region.SetPoint then Kit.Inset(region, host, inset) end end

-- Puts the Mode look back after Blizzard redraws a button.
function M:RestyleUtility(button)
    local state = self.skinState[button]
    if not state or not state.utility then return end
    local inset, Fade, Overlay = state.g.inset, self.Fade, self.Overlay
    if state.utility == "micro" then
        for _, key in ipairs({ "Background", "PushedBackground", "Shadow", "PortraitMask", "PushedShadow", "MainMenuBarPerformanceBar" }) do
            Fade(button[key])
        end
        -- Any of these may be missing, so no ipairs (it would stop at a gap).
        local regions = { Texture(button, "NormalTexture", "GetNormalTexture"), Texture(button, "PushedTexture", "GetPushedTexture"),
            Texture(button, "DisabledTexture", "GetDisabledTexture"), Texture(button, "HighlightTexture", "GetHighlightTexture"),
            button.FlashContent, button.QuickKeybindHighlightTexture, button.Portrait }
        for i = 1, 7 do Inset(regions[i], button, inset) end
        Overlay(button.FlashBorder, button, inset, Kit.palette.accent, 0.35)
    else
        Fade(Texture(button, "NormalTexture", "GetNormalTexture")); Fade(button.IconBorder)
        Overlay(Texture(button, "PushedTexture", "GetPushedTexture"), button, inset, Kit.onyx.inner, 0.45)
        Overlay(Texture(button, "HighlightTexture", "GetHighlightTexture"), button, inset, { 1, 1, 1 }, 0.16)
        -- Lit while that bag is open.
        Overlay(button.SlotHighlightTexture, button, inset, Kit.palette.accent, 0.28)
    end
end

-- Hooks, once per button (shown or not): restyle after Blizzard's redraws; a
-- button Blizzard shows or hides re-lays the bar out.
M.utilityHooked = setmetatable({}, { __mode = "k" })
function M:HookUtility(bar, button)
    local kind = self.barSpecs[bar].utility
    if self.utilityHooked[button] or not hooksecurefunc then return end
    self.utilityHooked[button] = true
    local function Restyle() M:RestyleUtility(button) end
    for _, name in ipairs(kind == "micro" and { "SetPushed", "SetNormal" } or { "UpdateTextures" }) do
        if type(button[name]) == "function" then hooksecurefunc(button, name, Restyle) end
    end
    if button.HookScript then
        button:HookScript("OnShow", function() M:UtilityChanged(bar) end)
        button:HookScript("OnHide", function() M:UtilityChanged(bar) end)
    end
    -- The bag icon's round and square masks would cut the cropped icon.
    local icon = button.icon
    if icon and icon.RemoveMaskTexture then
        for _, key in ipairs({ "SquareMask", "CircleMask", "Mask" }) do
            if button[key] then pcall(icon.RemoveMaskTexture, icon, button[key]) end
        end
    end
end

-- Skins a micro or bag button. Bag buttons are item buttons, so they take
-- the action button skin (icon cropped, texts) plus their extras.
function M:SkinUtility(bar, button, style, g)
    local kind = self.barSpecs[bar].utility
    if kind == "bags" then self:SkinButton(button, style, g) else
        local state = self.skinState[button] or {}
        self.skinState[button] = state
        state.style, state.g = style, g
        button:SetSize(g.w, g.h)
        self.PaintArt(self:Art(button), button, style, g)
    end
    self.skinState[button].utility = kind
    self:HookUtility(bar, button)
    self:RestyleUtility(button)
end

-- Blizzard showed or hid one of the bar's buttons: lay the bar out again
-- (after combat; the next refresh does it).
function M:UtilityChanged(bar)
    if self.applied and self.active then self:Refresh() end
end

-- BagsBar:Layout re-anchors the bag buttons (when an item is picked up, for
-- one); put them back where the bar has them, in combat too. Blizzard's
-- source makes none of them protected; if the client says one is, combat
-- leaves it for the refresh after combat.
function M:PlaceUtility(bar)
    local header = self.headers[bar]
    if not self.applied or not self.active or not header then return end
    local shown, style = self:UtilityButtons(bar), self.db[bar]
    local count = self:ButtonCount(bar)
    local g = self.Geometry(style, math.max(1, count), self.PixelSize(header))
    local combat = addon.InCombat()
    for i, button in ipairs(shown) do
        local protected = combat and button.IsProtected and button:IsProtected()
        if combat and (not Public(protected) or protected) then self:Refresh(); return end
        if i <= count and button:GetParent() == header then self.Place(button, header, g, i) end
    end
end

function M:HookUtilityLayouts()
    if self.layoutsHooked or not hooksecurefunc then return end
    self.layoutsHooked = true
    local bags = _G.BagsBar
    if type(bags) == "table" and type(bags.Layout) == "function" then
        hooksecurefunc(bags, "Layout", function() M:PlaceUtility("bags") end)
    end
end

-- Shown by Show (Always, Mouseover, Hidden), and in Edit Mode and Keybind
-- Mode. Plain frames, so this needs no state driver.
function M:UtilityVisible(bar, count)
    local style = self.db[bar]
    if not style.show or count < 1 then return false end
    if self.editing or self.binding then return true end
    return style.visibility ~= "hidden"
end
