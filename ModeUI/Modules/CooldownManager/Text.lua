local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The texts: on icons the cooldown numbers (drawn by the game's cooldown
-- widget) and the count (charges, or an aura's stacks); on bars the spell's
-- name, the time left and the stacks on the icon. Blizzard writes them and
-- shows or hides them (the values can be secret); ModeUI sets the font,
-- size, color and place, and hides one by fading it. Nothing is measured:
-- secret text makes a FontString's sizes secret too.
-- A spell can have its own look for each text (its menu's Text rows open
-- TextPopout.lua): saved in the bar's spells as
--   spells["1234"].text = { cooldown = { show, size, anchor, x, y, color,
--       font, fontMedia, outline ("none", "outline", "thick"), shadow } }
-- starting from the bar's look (the Text tab) when first changed.
-- Every text is Geist Bold in the chosen face (docs/DESIGN_LANGUAGE.md,
-- "Cooldown icons"); a font from SharedMedia keeps its own file.
local Kit = addon.Kit
local PAD = 2 -- pixels between a text and the edge it sits against
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The bar's look for a text, in a spell's own look's shape.
local function BarLook(style, part)
    return { show = style[part .. "Show"], size = style[part .. "Size"], anchor = style[part .. "Anchor"],
        x = style[part .. "X"], y = style[part .. "Y"], color = style[part .. "Color"], font = style.font,
        fontMedia = style.fontMedia, outline = style.outline and "outline" or "none", shadow = style.shadow }
end

-- A spell's own look for a text on a bar, else nil.
function M:SpellText(viewer, key, part)
    local style = self.db[viewer]
    local entry = key and style and style.spells[key]
    return entry and entry.text and entry.text[part]
end
-- The look a text starts from when a spell gets its own: the bar's.
function M:TextDefaults(viewer, part) return Copy(BarLook(self.db[viewer], part)) end

-- Changes one field of a spell's own look for a text (starting from the
-- bar's look). Checked by Initialize like every setting.
function M:SetSpellText(viewer, key, part, field, value)
    local parts = {}
    for _, p in ipairs(self:Parts(viewer)) do parts[p] = true end
    if not self:Defaults(viewer) or type(key) ~= "string" or not parts[part] or not self.textFields[field] then return false end
    local spells = Copy(self.db[viewer].spells)
    local entry = spells[key] or {}
    entry.text = entry.text or {}
    local look = entry.text[part] or self:TextDefaults(viewer, part)
    look[field] = Copy(value)
    entry.text[part] = look
    spells[key] = entry
    return self:SetOption(viewer, "spells", spells)
end

-- The text goes back to the bar's look.
function M:ResetSpellText(viewer, key, part)
    if not self:Defaults(viewer) or not self:SpellText(viewer, key, part) then return false end
    local spells = Copy(self.db[viewer].spells)
    local entry = spells[key]
    entry.text[part] = nil
    if next(entry.text) == nil then entry.text = nil end
    spells[key] = next(entry) and entry or nil
    return self:SetOption(viewer, "spells", spells)
end

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

local function StylePart(self, viewer, item, part, style, g, own)
    local text, host = self.TextRegion(item, part)
    if not text then return end
    local look = own and own[part] or BarLook(style, part)
    local size = look.size
    Kit.Font(text, { outline = look.outline, shadow = look.shadow, slug = style.slug, textColor = look.color },
        size, addon.Style.Weighted(Kit.FontPath(look, self.id), "bold"), g.px)
    text:SetWordWrap(false)
    -- Icons: the count tucks into the icon's corner. Bars: the name and time
    -- sit inside the bar; the name stops short of the time.
    local room, width = g.inset + PAD * g.px, nil
    if host == item.Bar then
        room = 4 * g.px
        local inner = math.max(g.px, g.w - M.BarIconWidth(g.h, g.px) - 2 * (g.reach or 0) - 2 * g.px)
        if part == "name" then
            local duration = own and own.duration or BarLook(style, "duration")
            width = inner - 2 * room - (duration.show and 4 * duration.size or 0)
        else width = inner - 2 * room end
        width = math.max(g.px, width)
    elseif host ~= item then room = g.inset + PAD * g.px end
    if part ~= "cooldown" and not width then width = math.max(g.px, (host == item and g.w or g.h) - 2 * g.inset) end
    Place(text, host, look.anchor, look.x, look.y, g, room, width, width and (size + 1) or nil)
    text:SetAlpha(look.show and 1 or 0)
end

-- `key`: the spell the item shows (its own texts; false for none), else
-- the item's own.
function M:StyleTexts(viewer, item, style, g, key)
    if key == nil then key = self:SpellKey(item) end
    local entry = key and style.spells[key]
    local own = entry and entry.text
    for _, part in ipairs(self:Parts(viewer)) do StylePart(self, viewer, item, part, style, g, own) end
end
