local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The texts: on icons the cooldown numbers (drawn by the game's cooldown
-- widget) and the count (charges, or an aura's stacks); on bars the spell's
-- name, the time left and the stacks on the icon. Blizzard writes them and
-- shows or hides them (the values can be secret); ModeUI sets the font,
-- size, color and place, and hides one by fading it. Nothing is measured:
-- secret text makes a FontString's sizes secret too.
local Kit = addon.Kit
local PAD = 1 -- pixels between a text and the edge it sits against

-- The FontString for a part on an item (Blizzard's or a sample), and the
-- frame it is placed on, or nil when the item has none.
function M.TextRegion(item, part)
    if part == "cooldown" then
        if item.cooldownText then return item.cooldownText, item end
        local cooldown = item.Cooldown
        if not cooldown or not cooldown.GetCountdownFontString then return end
        local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
        return ok and text or nil, item
    elseif part == "count" then
        if item.ChargeCount and item.ChargeCount.Current then return item.ChargeCount.Current, item end
        if item.Applications and item.Applications.Applications then return item.Applications.Applications, item end
        if item.Icon and type(item.Icon) == "table" and item.Icon.Applications then return item.Icon.Applications, item.Icon end
    elseif item.Bar then
        if part == "name" then return item.Bar.Name, item.Bar end
        if part == "duration" then return item.Bar.Duration, item.Bar end
    end
end

-- Places a text at its anchor on its host, PAD pixels plus the border in
-- from the edge, then by its offset; the text box hugs that side.
local function Place(text, host, anchor, x, y, g, room, width, height)
    local h = anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "CENTER"
    local dx = (h == "LEFT" and room) or (h == "RIGHT" and -room) or 0
    local dy = (anchor:find("^TOP") and -room) or (anchor:find("^BOTTOM") and room) or 0
    local function Snap(v) return math.floor(v / g.px + 0.5) * g.px end
    text:ClearAllPoints()
    text:SetPoint(anchor, host, anchor, dx + Snap(x), dy + Snap(y))
    if width then text:SetSize(width, height) end
    text:SetJustifyH(h)
    if text.SetJustifyV then
        text:SetJustifyV(anchor:find("^TOP") and "TOP" or anchor:find("^BOTTOM") and "BOTTOM" or "MIDDLE")
    end
end

local function StylePart(self, viewer, item, part, style, g)
    local text, host = self.TextRegion(item, part)
    if not text then return end
    local size, shown = style[part .. "Size"], style[part .. "Show"]
    local look = { outline = style.outline, shadow = style.shadow, slug = style.slug, textColor = style[part .. "Color"] }
    Kit.Font(text, look, size, Kit.FontPath(style, self.id), g.px)
    text:SetWordWrap(false)
    -- Icons: the count tucks into the icon's corner. Bars: the name and time
    -- sit inside the bar; the name stops short of the time.
    local room, width = g.inset + PAD * g.px, nil
    if host == item.Bar then
        room = 4 * g.px
        local inner = math.max(g.px, g.w - g.h - 2 * g.inset)
        if part == "name" then
            width = inner - 2 * room - (style.durationShow and 4 * style.durationSize or 0)
        else width = inner - 2 * room end
        width = math.max(g.px, width)
    elseif host ~= item then room = g.inset + PAD * g.px end
    if part ~= "cooldown" and not width then width = math.max(g.px, (host == item and g.w or g.h) - 2 * g.inset) end
    Place(text, host, style[part .. "Anchor"], style[part .. "X"], style[part .. "Y"], g, room, width, width and (size + 1) or nil)
    text:SetAlpha(shown and 1 or 0)
end

function M:StyleTexts(viewer, item, style, g)
    for _, part in ipairs(self:Parts(viewer)) do StylePart(self, viewer, item, part, style, g) end
end
