local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- What stands in for the real bars: Edit Mode's movable stand-ins (empty
-- slots in the bar's shape, with its name) and the settings preview (the bar
-- being edited, with sample spells, keybinds, counts, a macro name and a
-- cooldown). Both are drawn by the same layout and skin code as the real
-- bars, so they match the settings. Clicking a part of the preview jumps to
-- its settings. Static shows the cooldown part-way; Animated runs it.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local COOLDOWN, STATIC_ELAPSED, HINT_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 8, 3, 18, 560, 200
local ICONS = "Interface\\Icons\\"
M.sampleIcons = { "Spell_Holy_HolyBolt", "Ability_Warrior_Charge", "Spell_Fire_Fireball02", "Spell_Frost_FrostBolt02",
    "Spell_Nature_Lightning", "Spell_Shadow_ShadowWordPain", "Ability_Rogue_Sprint", "Spell_Holy_FlashHeal",
    "INV_Potion_54", "Spell_Nature_Rejuvenation", "Ability_Hunter_SniperShot", "Spell_Arcane_Blink" }
M.sampleKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
-- Which sample button shows a count, the macro name and the cooldown.
local COUNTS, MACRO, COOLING = { [3] = "3", [7] = "12" }, 5, 2

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- Edit Mode stand-in: the bar's empty slots, a faint accent fill and its name.
function M:LayoutGhost(bar)
    local ghost = self.ghosts[bar]
    if not ghost then return end
    local style, count = self.db[bar], self:SampleCount(bar)
    local g = self.Geometry(style, count, self.PixelSize(ghost))
    ghost:SetSize(g.width, g.height)
    for i = 1, count do
        local slot = ghost.slots[i] or self:BuildSlot(ghost)
        ghost.slots[i] = slot
        self.Place(slot, ghost, g, i)
        self:PaintSlot(slot, style, g)
        slot:Show()
    end
    for i = count + 1, #ghost.slots do ghost.slots[i]:Hide() end
    ghost.fill:SetAllPoints(ghost)
    ghost.fill:SetTexture(Kit.FLAT); Kit.Tint(ghost.fill, Kit.palette.accent, 0.12)
    Kit.Font(ghost.label, { outline = true, shadow = true, textColor = Kit.palette.accent }, 11, Kit.FontPath(style, self.id), g.px)
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

local function FitText(hit, text)
    local width = math.max(8, math.min(text:GetWidth(), text:GetStringWidth() + 4))
    local justify = text:GetJustifyH()
    local point = justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER"
    hit:ClearAllPoints()
    hit:SetPoint(point, text, point, 0, 0)
    hit:SetSize(width, math.max(8, text:GetStringHeight() + 2))
    hit:SetShown(text:GetAlpha() > 0)
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
    local elapsed = phase and phase % COOLDOWN or STATIC_ELAPSED
    for i = 1, count do
        local button = Sample(view, i)
        self.Place(button, view.bar, g, i)
        button.icon:SetTexture(ICONS .. self.sampleIcons[i])
        self:SkinButton(button, style, g, true)
        local prefix = bar == "bar1" and "" or (bar == "pet" and "P" or bar == "stance" and "T" or "S")
        Kit.Write(button.HotKey, prefix .. self.sampleKeys[i])
        Kit.Write(button.Count, COUNTS[i] or "")
        Kit.Write(button.Name, i == MACRO and L["Macro"] or "")
        Kit.Write(button.cooldownText, i == COOLING and tostring(math.ceil(COOLDOWN - elapsed)) or "")
        if i == COOLING then button.cooldown:SetCooldown(GetTime() - elapsed, COOLDOWN); button.cooldown:Show()
        else button.cooldown:Hide() end
        for part, hit in pairs(button.hits) do
            if part ~= "button" then FitText(hit, self.TextRegion(button, part)) end
        end
        button:Show()
    end
    for i = count + 1, #view.buttons do view.buttons[i]:Hide() end
    local spec = self.barSpecs[bar]
    view.caption:SetText(style.show and L[spec.label] or L[spec.label .. " is hidden"])
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, buttons = {} }
    view.bar = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 200, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end
