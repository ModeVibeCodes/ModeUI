local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- What stands in for the real bars. In Edit Mode, a cyan highlight with the
-- bar's name sits over each bar (with empty slots only when the bar has no
-- buttons to show, like a stance bar without stances). On the settings page,
-- the preview is your own bar: the spells, keybinds, counts, macro names and
-- cooldowns on its buttons now, drawn by the same layout and skin code as the
-- bar itself. While you edit the Cooldown text, a sample cooldown shows if
-- none is running. Clicking a part of the preview jumps to its settings.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Public, Number = addon.IsPublic, addon.IsNumber
local SAMPLE_COOLDOWN, STATIC_ELAPSED, HINT_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 8, 3, 18, 560, 200
-- Events after which the bar's buttons may show something new.
local UPDATES = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_BINDINGS",
    "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN" }

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- Edit Mode stand-in: a cyan highlight, the bar's name, and empty slots only
-- when the bar itself has nothing to show.
function M:LayoutGhost(bar)
    local ghost = self.ghosts[bar]
    if not ghost then return end
    local style, count = self.db[bar], self:SampleCount(bar)
    local g = self.Geometry(style, count, self.PixelSize(ghost))
    ghost:SetSize(g.width, g.height)
    local empty = self:ButtonCount(bar) < 1
    for i = 1, count do
        local slot = ghost.slots[i] or self:BuildSlot(ghost)
        ghost.slots[i] = slot
        self.Place(slot, ghost, g, i)
        self:PaintSlot(slot, style, g)
        slot:SetShown(empty)
    end
    for i = count + 1, #ghost.slots do ghost.slots[i]:Hide() end
    ghost.fill:SetAllPoints(ghost)
    ghost.fill:SetTexture(Kit.FLAT); Kit.Tint(ghost.fill, Kit.palette.accent, 0.18)
    Kit.Font(ghost.label, { outline = true, shadow = true, textColor = { 1, 1, 1 } }, 12, Kit.FontPath(style, self.id), g.px)
    ghost.label:SetText(L[self.barSpecs[bar].label])
end

-- A ModeUI-made button with the parts the skin and text code look for.
function M:BuildSampleButton(parent)
    local button = CreateFrame("Frame", nil, parent)
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.cooldown = CreateFrame("Cooldown", nil, button)
    if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(false) end
    if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(true) end
    button.textLayer = CreateFrame("Frame", nil, button)
    button.textLayer:SetAllPoints()
    for _, key in ipairs({ "HotKey", "Count", "Name", "cooldownText" }) do
        button[key] = Kit.Text(button.textLayer)
        button[key].lift = Kit.Text(button.textLayer, "ARTWORK")
    end
    return button
end

-- The bar the page is editing, else Action Bar 1.
function M:PreviewBar()
    local page = self.page
    return page and page.barEditing and page.barEditing() or "bar1"
end

-- What one of Blizzard's buttons shows now. Values may be secret: they only
-- go to SetTexture and SetText.
local function Real(bar, index) local list = M.buttons[bar]; return list and list[index] or _G[M.barSpecs[bar].prefix .. index] end
local function Shown(region)
    if not region or not region.IsShown then return false end
    local shown = region:IsShown()
    return Public(shown) and shown == true
end
local function Icon(real)
    if not real or not Shown(real.icon) then return nil end
    return real.icon:GetTexture()
end
local function TextOf(region, hiddenToo)
    if not region or (not hiddenToo and not Shown(region)) then return "" end
    local text = region:GetText()
    if Public(text) and (text == nil or text == RANGE_INDICATOR) then return "" end
    return text
end
-- A running cooldown's start and duration in seconds, while they're public.
local function Cooldown(real)
    local cooldown = real and real.cooldown
    if not cooldown or not cooldown.GetCooldownTimes then return end
    local ok, start, duration = pcall(cooldown.GetCooldownTimes, cooldown)
    if not ok or not Number(start) or not Number(duration) or duration <= 1500 then return end
    start, duration = start / 1000, duration / 1000
    if start + duration > GetTime() then return start, duration end
end

-- A sample part that jumps to its settings when clicked and lights up under
-- the mouse; text gets a frame laid over the written text.
local function Clickable(region, target, part, host)
    local hit = region
    if host then
        hit = CreateFrame("Frame", nil, host)
        hit:SetFrameLevel(host:GetFrameLevel() + 2)
    end
    hit:EnableMouse(true)
    hit.jumpHighlight = W.Fill(hit, T.primary, "OVERLAY", 0, 0.16)
    hit.jumpHighlight:Hide()
    hit:SetScript("OnEnter", function() hit.jumpHighlight:Show() end)
    hit:SetScript("OnLeave", function() hit.jumpHighlight:Hide() end)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == nil or button == "LeftButton" then M:JumpTo(target, part) end
    end)
    hit.jump = { target = target, part = part }
    return hit
end

-- The click area for a text, sized from its settings, never by measuring:
-- the preview copies the real buttons' texts, which can be secret, and the
-- game then makes that text's measurements secret too. A corner text gets
-- the half of the button on its side; a centered one the middle.
local function FitText(hit, text, written, style, part, g)
    local anchor = style[part .. "Anchor"]
    local point = anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or "CENTER"
    local inner = math.max(8, g.w - 2 * g.inset)
    hit:ClearAllPoints()
    hit:SetPoint(point, text, point, 0, 0)
    hit:SetSize(point == "CENTER" and inner * 0.6 or inner / 2, math.max(8, style[part .. "Size"] + 2))
    hit:SetShown(written == true and style[part .. "Show"] == true)
end

local function Scale(style, count)
    local g = M.Geometry(style, count, 1)
    return math.min(1, MAX_WIDTH / g.width, MAX_HEIGHT / g.height), g
end

function M:GetPreviewSize()
    local bar = self:PreviewBar()
    local scale, g = Scale(self.db[bar], self:SampleCount(bar))
    return math.max(320, g.width * scale), g.height * scale + 8 + HINT_HEIGHT
end

local function Sample(view, index)
    local button = view.buttons[index]
    if button then return button end
    button = M:BuildSampleButton(view.bar)
    button.hits = { button = Clickable(button, "buttons") }
    for _, part in ipairs(M.textParts) do button.hits[part] = Clickable(M.TextRegion(button, part), "text", part, button.textLayer) end
    view.buttons[index] = button
    return button
end

-- Fills one preview button from the real one; returns whether it has a spell.
local function Fill(button, real)
    local icon = Icon(real)
    local filled = not Public(icon) or icon ~= nil
    button.icon:SetTexture(icon)
    button.icon:SetShown(filled)
    Kit.Write(button.HotKey, filled and TextOf(real.HotKey) or "")
    Kit.Write(button.Count, filled and TextOf(real.Count, true) or "")
    Kit.Write(button.Name, filled and TextOf(real.Name, true) or "")
    return filled
end

function M:RenderPreview(view)
    local bar = self:PreviewBar()
    local style, count = self.db[bar], self:SampleCount(bar)
    local scale = Scale(style, count)
    view.bar:SetScale(scale)
    local g = self.Geometry(style, count, self.PixelSize(view.bar))
    view.bar:SetSize(g.width, g.height)
    view.bar:ClearAllPoints(); view.bar:SetPoint("TOP", view.frame, "TOP", 0, -2 / scale)
    view.bar:SetAlpha(style.show and style.opacity / 100 or 0.4)
    local phase = addon.PreviewStates:Sample(self.id)
    local demo = self.page ~= nil and self.page.textPart ~= nil and self.page.textPart() == "cooldown"
    local filledCount = 0
    for i = 1, count do
        local button, real = Sample(view, i), Real(bar, i)
        self.Place(button, view.bar, g, i)
        self:SkinButton(button, style, g, true)
        local filled = Fill(button, real)
        local start, duration = Cooldown(real)
        if filled and not start and demo then
            -- The sample cooldown, on the first button with a spell.
            demo = false
            local elapsed = phase and phase % SAMPLE_COOLDOWN or STATIC_ELAPSED
            start, duration = GetTime() - elapsed, SAMPLE_COOLDOWN
        end
        local cooling = filled and start ~= nil
        if cooling then
            button.cooldown:SetCooldown(start, duration); button.cooldown:Show()
            Kit.Write(button.cooldownText, tostring(math.ceil(start + duration - GetTime())))
        else
            button.cooldown:Hide(); Kit.Write(button.cooldownText, "")
        end
        for part, hit in pairs(button.hits) do
            if part ~= "button" then
                FitText(hit, self.TextRegion(button, part), filled and (part ~= "cooldown" or cooling), style, part, g)
            end
        end
        filledCount = filledCount + (filled and 1 or 0)
        button:SetShown(filled or style.showEmpty)
    end
    for i = count + 1, #view.buttons do view.buttons[i]:Hide() end
    local spec = self.barSpecs[bar]
    local caption = style.show and L[spec.label] or L[spec.label .. " is hidden"]
    if filledCount == 0 then caption = caption .. " · " .. L["no spells on this bar yet"] end
    view.caption:SetText(caption)
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, buttons = {} }
    view.bar = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 300, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    -- Blizzard updates its buttons on these events; redraw just after it.
    for _, event in ipairs(UPDATES) do
        addon.Events:On(view, event, function()
            if M.page and M.page:IsShown() then C_Timer.After(0, view.Refresh) end
        end)
    end
    return view
end
