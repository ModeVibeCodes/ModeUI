local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The settings preview: the bar being edited, drawn by the same layout, skin
-- and text code as the real one, with your own tracked spells (their icons
-- and names come from the game's spell data, by cooldown ID). Spells hidden
-- here show faded, so they can be brought back; a custom bar's spell that
-- isn't tracked now shows faded too. Icon bars end with a + slot: on a
-- custom bar, Essential or Utility it lists the spells to add (Picker.lua),
-- on Tracked Buffs it opens Blizzard's Cooldown Manager. With nothing tracked yet,
-- sample icons stand in on a viewer. Clicking a spell opens its menu
-- (SpellMenu.lua); while you edit the Cooldown text a sample cooldown runs
-- on the first icon.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Cooldowns = addon.Domain.Cooldowns
local SAMPLE_COOLDOWN, STATIC_ELAPSED, HINT_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 8, 3, 18, 560, 200
local SAMPLE_ICON, SAMPLE_COUNT = 134400, 6 -- the question mark icon
local FADED = 0.3

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- The bar the page is editing, else Essential.
function M:PreviewViewer()
    local page = self.page
    return page and page.viewerEditing and page.viewerEditing() or "essential"
end

-- What the preview shows: { key, icon, name, faded } per spell in the bar's
-- order, or samples when a viewer tracks nothing yet; and whether they're real.
function M:PreviewEntries(id)
    local entries, tracked = {}, {}
    local function Entry(key, present)
        entries[#entries + 1] = { key = key, icon = self:EntryIcon(key) or SAMPLE_ICON, name = self:SpellLabel(key),
            faded = self:SpellSwitch(id, key, "hide") or not present, missing = not present }
    end
    -- A viewer's own spells first (Blizzard's order), then the bar's own list.
    local list, listed = self:Entries(id), {}
    for _, key in ipairs(list) do listed[key] = true end
    for _, item in ipairs(self:BarItems(id)) do
        local key = self:SpellKey(item)
        if key then
            tracked[key] = true
            if not listed[key] then Entry(key, true) end
        end
    end
    for _, key in ipairs(list) do
        -- A custom spell counts as present while you know it; an item always.
        if self.IsItemEntry(key) then Entry(key, true)
        elseif self.IsSpellEntry(key) then Entry(key, Cooldowns.Known(self:SpellOf(key))) else Entry(key, tracked[key] == true) end
    end
    if not self:IsCustom(id) then self:Ordered(id, entries, function(entry) return entry.key end) end
    if #entries > 0 or self:IsCustom(id) then return entries, true end
    for i = 1, SAMPLE_COUNT do entries[i] = { icon = SAMPLE_ICON, name = string.format(L["Sample %d"], i) } end
    return entries, false
end

-- Icon bars end with the + slot.
function M:HasPlus(id) return not self:IsBar(id) end

local function Count(id, entries) return #entries + (M:HasPlus(id) and 1 or 0) end
local function Scale(style, count)
    local g = M.Geometry(style, count, 1)
    return math.min(1, MAX_WIDTH / g.extent.width, MAX_HEIGHT / g.extent.height), g
end

function M:GetPreviewSize()
    local id = self:PreviewViewer()
    local scale, g = Scale(self.db[id], Count(id, (self:PreviewEntries(id))))
    return math.max(320, g.extent.width * scale), g.extent.height * scale + 8 + HINT_HEIGHT
end

local function Hover(sample)
    sample:EnableMouse(true)
    sample.highlight = W.Fill(sample, T.primary, "OVERLAY", 0, 0.16)
    sample.highlight:Hide()
    sample:SetScript("OnEnter", function() sample.highlight:Show() end)
    sample:SetScript("OnLeave", function() sample.highlight:Hide() end)
end

-- A sample that lights up under the mouse, opens its spell menu, and can
-- be dragged to a new place on the bar (PreviewDrag.lua).
local function Sample(view, index, bar)
    local list = bar and view.bars or view.icons
    local sample = list[index]
    if sample then return sample end
    sample = M:BuildSample(view.holder, bar)
    Hover(sample)
    M:EnableSampleDrag(view, sample)
    sample:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= nil and mouse ~= "LeftButton" then return end
        -- A press that became a drag isn't a click.
        if view.dragged then view.dragged = nil; return end
        M:JumpTo("spells")
        if sample.key then M:OpenSpellMenu(view, sample.key, sample) end
    end)
    list[index] = sample
    return sample
end

-- The + slot: an empty slot with a plus in it.
local function Plus(view)
    if view.plus then return view.plus end
    local plus = M:BuildSample(view.holder, false)
    Hover(plus)
    plus.bars = { plus:CreateTexture(nil, "OVERLAY"), plus:CreateTexture(nil, "OVERLAY") }
    for _, line in ipairs(plus.bars) do line:SetTexture(Kit.FLAT); Kit.Tint(line, T.muted or Kit.palette.muted, 0.9) end
    plus:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= nil and mouse ~= "LeftButton" then return end
        local id = M:PreviewViewer()
        if M:TakesEntries(id) then M:OpenPicker(view, plus) else M:OpenCooldownSettings() end
    end)
    view.plus = plus
    return plus
end

local function PlaceCross(plus, g)
    local arm = math.max(g.px * 6, math.floor(math.min(g.w, g.h) * 0.4 / g.px) * g.px)
    local thick = math.max(g.px, 2 * g.px)
    plus.bars[1]:ClearAllPoints(); plus.bars[1]:SetPoint("CENTER"); plus.bars[1]:SetSize(arm, thick)
    plus.bars[2]:ClearAllPoints(); plus.bars[2]:SetPoint("CENTER"); plus.bars[2]:SetSize(thick, arm)
end

-- Fills one sample: icon, texts, a sample cooldown or bar fill. `focus`:
-- the text whose popout is open on this spell, which shows on it.
local function Fill(sample, entry, index, bar, demo, phase, focus)
    local icon = bar and sample.Icon.Icon or sample.Icon
    icon:SetTexture(entry.icon)
    local count = (index == 1 or focus == "count") and "2" or ""
    if bar then
        sample.Bar:SetValue(index == 1 and 0.65 or math.max(0.15, 1 - index * 0.17))
        sample.Bar.Name:SetText(entry.name)
        sample.Bar.Duration:SetText(string.format("%d", 4 + index * 3))
        sample.Icon.Applications:SetText(count)
        return
    end
    sample.ChargeCount.Current:SetText(count)
    local cooldown = sample.Cooldown
    if (demo and index == 1) or focus == "cooldown" then
        local elapsed = phase and phase % SAMPLE_COOLDOWN or STATIC_ELAPSED
        cooldown:SetCooldown(GetTime() - elapsed, SAMPLE_COOLDOWN); cooldown:Show()
        sample.cooldownText:SetText(string.format("%d", math.ceil(SAMPLE_COOLDOWN - elapsed)))
    else
        cooldown:Hide(); sample.cooldownText:SetText("")
    end
end

-- On the spell whose menu is open: the glow being set up in its popout,
-- else the first glow that's on, as it would show on screen.
local function PreviewGlow(view, sample, id, style)
    local look
    if view.menuKey ~= nil and sample.key == view.menuKey then
        local kinds = view.glowKind and { view.glowKind } or M:Glows(id)
        for _, kind in ipairs(kinds) do look = look or M:SpellGlow(id, sample.key, kind) end
    end
    M:WantGlow(sample, "proc", look)
    M:ResolveGlows(sample)
end

function M:RenderPreview(view)
    local id = self:PreviewViewer()
    local style, bar = self.db[id], self:IsBar(id)
    local entries, real = self:PreviewEntries(id)
    local plus = self:HasPlus(id)
    local count = Count(id, entries)
    local scale = Scale(style, count)
    view.area:SetScale(scale)
    local g = self.Geometry(style, count, self.PixelSize(view.area))
    view.area:SetSize(g.extent.width, g.extent.height)
    view.area:ClearAllPoints(); view.area:SetPoint("TOP", view.frame, "TOP", 0, -2 / scale)
    view.holder:SetSize(g.width, g.height)
    view.holder:ClearAllPoints(); view.holder:SetPoint("TOPLEFT", view.area, "TOPLEFT", g.extent.x, -g.extent.y)
    view.area:SetAlpha(style.show and style.opacity / 100 or 0.4)
    local demo = not bar and self.page ~= nil and self.page.textPart ~= nil and self.page.textPart() == "cooldown"
    local phase = addon.PreviewStates:Sample(self.id)
    for index, entry in ipairs(entries) do
        local sample = Sample(view, index, bar)
        local state = self:Dress(sample)
        state.viewer, state.g = id, g
        self.Place(sample, view.holder, g, index)
        sample.key, sample.index, sample.dragIcon = entry.key, index, entry.icon
        if bar then self:SkinBar(sample, style, g, state) else self:SkinIcon(sample, style, g, state) end
        self:StyleTexts(id, sample, style, g, entry.key or false)
        local focus = view.menuKey ~= nil and entry.key == view.menuKey and view.textPart or nil
        Fill(sample, entry, index, bar, demo, phase, focus)
        if sample.Icon.SetDesaturated then sample.Icon:SetDesaturated(entry.missing == true) end
        PreviewGlow(view, sample, id, style)
        sample:SetAlpha(entry.faded and FADED or 1)
        sample:Show()
    end
    for _, list in ipairs({ view.icons, view.bars }) do
        for index = 1, #list do
            if list ~= (bar and view.bars or view.icons) or index > #entries then list[index]:Hide() end
        end
    end
    if plus then
        local slot = Plus(view)
        local state = self:Dress(slot)
        state.viewer, state.g = id, g
        self.Place(slot, view.holder, g, count)
        self:SkinIcon(slot, style, g, state)
        slot.Icon:SetTexture(nil); slot.Cooldown:Hide(); slot.ChargeCount.Current:SetText(""); slot.cooldownText:SetText("")
        PlaceCross(slot, g)
        slot:Show()
    elseif view.plus then view.plus:Hide() end
    view.caption:SetText(self:PreviewCaption(id, entries, real))
    self:RefreshSpellMenu()
end

function M:PreviewCaption(id, entries, real)
    local label = self:Label(id)
    local caption = self.db[id].show and label or string.format(L["%s is off"], label)
    local missing = 0
    for _, entry in ipairs(entries) do if entry.missing then missing = missing + 1 end end
    if self:IsCustom(id) and #entries == 0 then caption = caption .. " · " .. L["click + to add a spell"]
    elseif not real then caption = caption .. " · " .. L["no spells tracked yet"] end
    if self:HiddenCount(id) > 0 then caption = caption .. " · " .. string.format(L["%d hidden"], self:HiddenCount(id)) end
    if missing > 0 then caption = caption .. " · " .. string.format(L["%d not tracked or known now"], missing) end
    return caption
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, icons = {}, bars = {} }
    self.previewView = view
    view.area = CreateFrame("Frame", nil, frame)
    view.holder = CreateFrame("Frame", nil, view.area)
    view.caption = W.Label(frame, "", nil, 0, 0, 360, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a spell for its switches; drag to move"], nil, 0, 0, 240, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- The tracked spells change with talents and Blizzard's Cooldown Settings;
-- each time Blizzard lays a viewer out again, so does ModeUI, and the open
-- preview follows on the next frame.
function M:QueuePreview(id)
    local view, page = self.previewView, self.page
    if not view or not page or not page:IsShown() or id ~= self:PreviewViewer() or self.previewQueued then return end
    self.previewQueued = true
    local function Run() M.previewQueued = nil; if M.page and M.page:IsShown() then view.Refresh() end end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

-- A preview click: show the settings it belongs to.
function M:JumpTo(target, part)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    if part and page.SetTextPart then page.SetTextPart(part) end
    page:Reveal(page.jumpTargets[target])
    return true
end
