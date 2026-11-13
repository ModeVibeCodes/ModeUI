local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The texts on a button: keybind, count, macro name and cooldown numbers.
-- Blizzard writes them (the values can be secret); ModeUI sets their font,
-- size, color and place, and hides one by fading it, since Blizzard shows
-- and hides them itself. Blizzard re-places the keybind when bindings change
-- and tints it red out of range; hooks put ModeUI's place and color back,
-- leaving the out-of-range red alone.
--
-- Lifted shadows need a copy of each text: hooks on SetText, Show and Hide
-- keep the copy in step. The cooldown numbers are drawn by the game, not
-- written from Lua, so they get the crisp shadow only.
local Kit, Public = addon.Kit, addon.IsPublic
local KEYS = { hotkey = "HotKey", count = "Count", macro = "Name" }
local PAD = 1 -- pixels between a text and the icon's edge
M.lifts = setmetatable({}, { __mode = "k" })
M.textState = setmetatable({}, { __mode = "k" })

-- The FontString for a part, or nil when the button has none.
function M.TextRegion(button, part)
    if part ~= "cooldown" then return button[KEYS[part]] end
    if button.cooldownText then return button.cooldownText end
    local cooldown = button.cooldown
    if not cooldown or not cooldown.GetCountdownFontString then return end
    local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
    return ok and text or nil
end

local function Red(r, g, b)
    local red = RED_FONT_COLOR
    if red and red.GetRGB then
        local rr, rg, rb = red:GetRGB()
        return math.abs(r - rr) < 0.01 and math.abs(g - rg) < 0.01 and math.abs(b - rb) < 0.01
    end
    return r > 0.9 and g < 0.2 and b < 0.2
end

local guard = false
local function KeepColor(text, r, g, b)
    local state = M.textState[text]
    if guard or not state or not (Public(r) and Public(g) and Public(b)) or Red(r, g, b) then return end
    local c = state.color
    guard = true; text:SetVertexColor(c[1], c[2], c[3], 1); guard = false
end

local function SyncLift(text)
    local lift, state = M.lifts[text], M.textState[text]
    if lift then lift:SetShown(text:IsShown() and state ~= nil and state.lifted == true) end
end

-- A lift for a Blizzard text, kept in step with it from now on.
function M:Lift(text)
    local lift = self.lifts[text]
    if lift then return lift end
    lift = text:GetParent():CreateFontString(nil, "ARTWORK")
    lift:SetWordWrap(false)
    self.lifts[text] = lift
    lift:SetText(text:GetText())
    if hooksecurefunc then
        hooksecurefunc(text, "SetText", function(source, value) local copy = M.lifts[source]; if copy then copy:SetText(value) end end)
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(text, method, SyncLift) end
    end
    return lift
end

-- Places a text at its anchor on the button, PAD pixels in from the icon's
-- edge, then by its offset. The text box hugs the letters (justified to the
-- anchor's side, top or bottom), so a corner keybind sits right in the corner.
local function Place(text, button, anchor, x, y, g, width, height)
    local h = anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "CENTER"
    local room = g.inset + PAD * g.px
    local dx = (h == "LEFT" and room) or (h == "RIGHT" and -room) or 0
    local dy = (anchor:find("^TOP") and -room) or (anchor:find("^BOTTOM") and room) or 0
    text:ClearAllPoints()
    text:SetPoint(anchor, button, anchor, dx + math.floor(x / g.px + 0.5) * g.px, dy + math.floor(y / g.px + 0.5) * g.px)
    if width then text:SetSize(width, height) end
    text:SetJustifyH(h)
    if text.SetJustifyV then
        text:SetJustifyV(anchor:find("^TOP") and "TOP" or anchor:find("^BOTTOM") and "BOTTOM" or "MIDDLE")
    end
    return h
end

local function StylePart(self, button, part, style, g, sample)
    local text = M.TextRegion(button, part)
    if not text then return end
    local size, color, shown = style[part .. "Size"], style[part .. "Color"], style[part .. "Show"]
    -- The keybind's color is set with the vertex color Blizzard tints, over white text.
    local hotkey = part == "hotkey" and not sample
    local look = { outline = style.outline, shadow = style.shadow, liftedShadow = style.liftedShadow, slug = style.slug,
        textColor = hotkey and { 1, 1, 1 } or color }
    local path = Kit.FontPath(style, self.id)
    Kit.Font(text, look, size, path, g.px)
    local state = self.textState[text] or {}
    self.textState[text] = state
    state.color, state.lifted = color, shown and style.shadow and style.liftedShadow
    if hotkey then
        guard = true; text:SetVertexColor(color[1], color[2], color[3], 1); guard = false
        if not state.hooked and hooksecurefunc then state.hooked = true; hooksecurefunc(text, "SetVertexColor", KeepColor) end
    end
    local width = part ~= "cooldown" and math.max(g.px, g.w - 2 * g.inset) or nil
    local justify = Place(text, button, style[part .. "Anchor"], style[part .. "X"], style[part .. "Y"], g, width, size + 1)
    if part ~= "macro" then text:SetWordWrap(false) end
    text:SetAlpha(shown and 1 or 0)
    -- Samples carry their own lift; Blizzard's texts get one on first use.
    local lift = sample and text.lift or (state.lifted and part ~= "cooldown" and self:Lift(text)) or self.lifts[text]
    if lift then
        Kit.LayoutLift(text, look, size, path, g.px, state.lifted and text:IsShown(), justify, lift)
        lift:SetAlpha(shown and 1 or 0)
    end
end

function M:StyleTexts(button, style, g, sample)
    for _, part in ipairs(self.textParts) do StylePart(self, button, part, style, g, sample) end
    -- Blizzard re-places the keybind when bindings change.
    local state = self.skinState[button]
    if state and not sample and not state.hotkeyHooked and hooksecurefunc then
        for _, method in ipairs({ "UpdateHotkeys", "SetHotkeys" }) do
            if type(button[method]) == "function" then
                state.hotkeyHooked = true
                hooksecurefunc(button, method, function(hooked)
                    local current = M.skinState[hooked]
                    if not current then return end
                    -- Re-placing waits for the refresh after combat.
                    if addon.InCombat() then M:Refresh(); return end
                    StylePart(M, hooked, "hotkey", current.style, current.g)
                end)
            end
        end
    end
end
