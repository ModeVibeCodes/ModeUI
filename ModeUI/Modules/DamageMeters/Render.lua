local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Fills the windows from the game's meter. In combat the game makes amounts
-- and names secret: they go only to the bar (SetMinMaxValues/SetValue, so the
-- top source fills its bar and the rest scale to it), to AbbreviateNumbers,
-- and to SetText/SetFormattedText. The game's order is the ranking; nothing
-- here sorts, compares or adds amounts while they're secret. Percent shows
-- only while the amounts are public (out of combat).
local Kit, L = addon.Kit, addon.L
local DM, UnitColor = addon.Domain.DamageMeter, addon.Domain.UnitColor
local Public, Number = addon.IsPublic, addon.IsNumber

-- An amount for the bar: a public non-number (nil) counts as 0; a secret
-- one passes through untouched.
local function Amount(value)
    if Public(value) and type(value) ~= "number" then return 0 end
    return value
end
M.Amount = Amount
-- ok, text: abbreviated text for an amount ("12.3K", Decimals places); ok is
-- false when there is none. The text is secret when the amount is, so only
-- ok is tested.
local function Abbreviate(value, decimals)
    if Public(value) and type(value) ~= "number" then return false end
    return Kit.ShortNumber(value, decimals)
end

-- The source's class (never secret), or "" for anything without one.
local function ClassOf(source)
    local class = source.classFilename
    if not Public(class) or type(class) ~= "string" then return "" end
    return class
end

-- The bar color for a source: its class (or Class Colors' custom one), the
-- window's Custom color, or Other Color for anything without a class.
function M.BarColor(style, class)
    if style.barColorMode == "custom" then return style.barColor end
    local color = class ~= "" and UnitColor.Class(class)
    if color then return { color.r, color.g, color.b } end
    return style.otherColor
end

-- Joins the amount, the other amount and the share with the Separator:
-- "5K (179, 61%)" in parentheses, else "5K / 179 / 61%". The amounts may be
-- secret strings; they only go to SetFormattedText.
local function Join(text, style, main, hasExtra, extra, share)
    local sep = M.separators[style.separator]
    if sep == true then
        if hasExtra and share then Kit.Formatted(text, "%s (%s, %d%%)", main, extra, share)
        elseif hasExtra then Kit.Formatted(text, "%s (%s)", main, extra)
        elseif share then Kit.Formatted(text, "%s (%d%%)", main, share)
        else Kit.Write(text, main) end
        return
    end
    if hasExtra and share then Kit.Formatted(text, "%s" .. sep .. "%s" .. sep .. "%d%%", main, extra, share)
    elseif hasExtra then Kit.Formatted(text, "%s" .. sep .. "%s", main, extra)
    elseif share then Kit.Formatted(text, "%s" .. sep .. "%d%%", main, share)
    else Kit.Write(text, main) end
end

-- Value text: the amount (per second first for DPS and HPS), the other with
-- Amount and Per Second, and the share of the total while public, joined by
-- the Separator. Deaths show when the death happened, while known.
function M.WriteValue(text, source, total, style, info)
    if info.deaths then Kit.Write(text, DM.Clock(source.deathTimeSeconds)); return end
    -- Swapped by the public type flag only: and/or would test a secret amount.
    local amount, first, second = source.totalAmount, source.totalAmount, source.amountPerSecond
    if info.perSecond then first, second = source.amountPerSecond, source.totalAmount end
    -- Counts (interrupts, dispels) are always whole numbers.
    local decimals = info.count and 0 or style.decimals
    local hasMain, main = Abbreviate(first, decimals)
    local hasExtra, extra = false, nil
    if not info.count and style.numbers == "both" then hasExtra, extra = Abbreviate(second, decimals) end
    local share
    if style.showPercent and Number(amount, 0) and Number(total) and total > 0 then
        share = math.floor(amount / total * 100 + 0.5)
    end
    if not hasMain then Kit.Write(text, "") else Join(text, style, main, hasExtra, extra, share) end
end

-- A text's color: its class color with Class (names and values), else its own.
function M.PaintColor(text, style, part, class)
    local classColor = style[part .. "ColorMode"] == "class" and class ~= "" and UnitColor.Class(class)
    if classColor then text:SetTextColor(classColor.r, classColor.g, classColor.b, 1); return end
    local c = style[part .. "Color"]
    text:SetTextColor(c[1], c[2], c[3], 1)
end

local function SetIcon(row, style, info, class)
    if style.icon == "none" then return end
    local atlas = not info.noIcon and DM.ClassAtlas(class)
    if atlas and pcall(row.icon.SetAtlas, row.icon, atlas) then row.icon:Show() else row.icon:Hide() end
end

function M:FillRow(row, source, rank, data, style, info)
    row.source, row.rank = source, rank
    local class = ClassOf(source)
    local color = self.BarColor(style, class)
    row.bar:SetStatusBarColor(color[1], color[2], color[3], style.barOpacity / 100)
    if info.deaths then
        row.bar:SetMinMaxValues(0, 1); row.bar:SetValue(1)
    else
        row.bar:SetMinMaxValues(0, Amount(data.max)); row.bar:SetValue(Amount(source.totalAmount))
    end
    SetIcon(row, style, info, class)
    local name = source.name
    if Public(name) and type(name) ~= "string" then name = "" end
    if style.showRank then Kit.Formatted(row.name, "%d. %s", rank, name) else Kit.Write(row.name, name) end
    self.PaintColor(row.name, style, "name", class)
    self.PaintColor(row.value, style, "value", class)
    self.WriteValue(row.value, source, data.total, style, info)
end

-- "Current", "Overall" or an earlier fight's name.
function M:SessionLabel(session)
    if session == "current" then return L["Current"] end
    if session == "overall" then return L["Overall"] end
    for _, item in ipairs(DM.Sessions()) do
        if item.id == session then return item.name or string.format(L["Fight %d"], item.id) end
    end
    return string.format(L["Fight %d"], session)
end

-- The session a window shows: an earlier fight picked from its menu, else
-- its Fight setting.
function M:SessionOf(window) return self.sessionIds[window] or self.db[window].session end

-- The data a window shows: the sample in Edit Mode and Test on Screen, else
-- the game's.
function M:WindowData(window)
    local style = self:Style(window)
    if self.editing or self.testing then return self:SampleData(style.meterType) end
    return DM.Session(self:SessionOf(window), style.meterType)
end

function M:RenderHeader(frame, style, info, session, data)
    if not style.header then return end
    if frame.buttons then frame.buttons.session.text:SetText(self:SessionShort(session)) end
    local title = L[info.label]
    if style.titleUpper then title = title:upper() end
    Kit.Write(frame.header.title, title)
    local parts = {}
    if style.showSession then parts[#parts + 1] = self:SessionLabel(session) end
    if style.showTimer then
        local seconds = data and data.sample and data.duration or DM.Duration(session)
        local clock = DM.Clock(seconds)
        if clock ~= "" then parts[#parts + 1] = clock end
    end
    Kit.Write(frame.header.info, table.concat(parts, " · "))
end

-- Why a window has no rows.
function M:EmptyText(info)
    if not DM.Supported() then return L["The game's damage meter isn't available on this client."] end
    local available, reason = DM.Available()
    if not available then return reason or L["The game's damage meter isn't available right now."] end
    if DM.GameMeterOn() == false then return L["Turn on the game's Damage Meter option to record fights."] end
    if info.id == "avoidable" then return L["No avoidable damage taken."] end
    return L["No data yet."]
end

-- The rows: the game's ranking from the scroll offset. With Always Show Me,
-- your own row takes the first or last row when you'd be scrolled out of view.
function M:FillRows(frame, style, info, data)
    local sources = data and data.sources or {}
    local count, rows = #sources, frame.g.rows
    frame.offset = math.max(0, math.min(frame.offset or 0, count - rows))
    local me
    if style.alwaysShowMe and not info.deaths then
        for index, source in ipairs(sources) do
            local mine = source.isLocalPlayer
            if Public(mine) and mine == true then me = index; break end
        end
    end
    for i = 1, rows do
        local row, index = frame.rows[i], frame.offset + i
        if me and i == rows and me > frame.offset + rows then index = me end
        if me and i == 1 and me <= frame.offset then index = me end
        local source = sources[index]
        if source then
            self:FillRow(row, source, index, data, style, info)
            row:Show()
        else
            row.source = nil
            row:Hide()
        end
    end
    frame.empty:SetText(count == 0 and self:EmptyText(info) or "")
    frame.empty:SetShown(count == 0)
end

function M:RenderWindow(window)
    local frame = self.frames[window]
    if not frame or not frame:IsShown() or not frame.g then return end
    local style = self:Style(window)
    local info = DM.typeById[style.meterType]
    local data = self:WindowData(window)
    self:RenderHeader(frame, style, info, self:SessionOf(window), data)
    self:FillRows(frame, style, info, data)
end

function M:RenderAll()
    if not self.built then return end
    for _, window in ipairs(self.windows) do self:RenderWindow(window) end
    self:RenderBreakdown()
end

-- Only the header, for the fight timer while a fight runs.
function M:RenderHeaders()
    if not self.built then return end
    for _, window in ipairs(self.windows) do
        local frame = self.frames[window]
        if frame:IsShown() and frame.g then
            local style = self:Style(window)
            self:RenderHeader(frame, style, DM.typeById[style.meterType], self:SessionOf(window), nil)
        end
    end
end

-- The mouse wheel moves the rows through the ranking.
function M:Scroll(window, step)
    local frame = self.frames[window]
    if not frame then return end
    frame.offset = math.max(0, (frame.offset or 0) + step)
    self:RenderWindow(window)
end
