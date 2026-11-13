local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The preview's glow menu and glow previews. Clicking a button in the
-- settings preview opens the Bar tab and a menu to the left of the button:
-- that button's switches (Proc Glow, Glow When Ready, Desaturate on
-- Cooldown), Copy, Paste and Apply to Bar for those switches, and the bar's
-- glow styles. It stays open while the page scrolls and closes on a click
-- anywhere else, the close button, or combat. While it's open the button
-- previews its glow; a proc lit on the real bar shows on its preview button.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local WIDTH, HEIGHT, PAD = 304, 334, 14
local INNER = WIDTH - 2 * PAD

-- Turns one switch ("proc", "ready" or "gray") on or off for the button at
-- `index`; switches are stored only while off.
function M:SetButtonGlow(bar, index, kind, on)
    local glows = Copy(self.db[bar].buttonGlows)
    local place = tostring(index)
    local entry = glows[place] or {}
    if on then entry[kind] = nil else entry[kind] = false end
    glows[place] = next(entry) and entry or nil
    return self:SetOption(bar, "buttonGlows", glows)
end

-- Copy, Paste and Apply to Bar move one button's switches to others.
function M:CopyButtonGlows(bar, index)
    self.glowClipboard = Copy(self.db[bar].buttonGlows[tostring(index)] or {})
    return true
end
function M:PasteButtonGlows(bar, index)
    if not self.glowClipboard then return false end
    local glows = Copy(self.db[bar].buttonGlows)
    glows[tostring(index)] = next(self.glowClipboard) and Copy(self.glowClipboard) or nil
    return self:SetOption(bar, "buttonGlows", glows)
end
function M:ApplyButtonGlowsToBar(bar, index)
    local entry = self.db[bar].buttonGlows[tostring(index)]
    local glows = {}
    for i = 1, self.barSpecs[bar].count do glows[tostring(i)] = entry and Copy(entry) or nil end
    return self:SetOption(bar, "buttonGlows", glows)
end

local function Check(menu, y, label, kind)
    local box = W.Button(menu, "", 24, 24, "checkbox")
    box:SetPoint("TOPLEFT", PAD, y)
    box.text = W.Label(menu, label, nil, PAD + 34, y - 4, INNER - 34, T.text)
    box:SetScript("OnClick", function()
        local bar = M:PreviewBar()
        M:SetButtonGlow(bar, menu.index, kind, not M.GlowOn(M.db[bar], menu.index, kind))
        M:RefreshGlowMenu()
    end)
    box.kind = kind
    return box
end

-- Segments sized to their labels, filling the menu's width.
local function Pills(menu, y, list, key, widths)
    local host = CreateFrame("Frame", nil, menu)
    host:SetPoint("TOPLEFT", PAD, y); host:SetSize(INNER, 28)
    local choices = {}
    for i, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = widths[i] } end
    return W.Exclusive(host, choices, function() return M.db[M:PreviewBar()][key] end,
        function(value) M:SetOption(M:PreviewBar(), key, value); M:RefreshGlowMenu() end)
end

local function Action(menu, label, width, x, y, fn)
    local button = W.Button(menu, label, width, 26, "secondary")
    button:SetPoint("TOPLEFT", x, y)
    button:SetScript("OnClick", function() fn(M:PreviewBar(), menu.index); M:RefreshGlowMenu() end)
    return button
end

-- A click anywhere outside the menu (and its button) closes it.
local function OnEvent(menu, event)
    if event == "PLAYER_REGEN_DISABLED" then menu:Hide(); return end
    local over = menu:IsMouseOver() or (menu.button and menu.button:IsMouseOver())
    if not (addon.IsPublic(over) and over) then menu:Hide() end
end

function M:GlowMenu()
    if self.glowMenu then return self.glowMenu end
    local menu = CreateFrame("Frame", "ModeUIActionBarGlowMenu", UIParent)
    menu:SetSize(WIDTH, HEIGHT); menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(200)
    menu:SetClampedToScreen(true); menu:EnableMouse(true); menu:Hide()
    W.Texture(menu, "Window"); W.Texture(menu, "BorderSilver", "BORDER")
    menu.title = W.Label(menu, "", nil, PAD, -12, INNER - 34, T.secondary)
    menu.close = W.Button(menu, "X", 24, 24, "secondary")
    menu.close:SetPoint("TOPRIGHT", -10, -8)
    menu.close:SetScript("OnClick", function() menu:Hide() end)
    W.Label(menu, L["This Button"], nil, PAD, -40, INNER, T.muted)
    menu.procBox = Check(menu, -58, L["Proc Glow"], "proc")
    menu.readyBox = Check(menu, -86, L["Glow When Ready"], "ready")
    menu.grayBox = Check(menu, -114, L["Desaturate on Cooldown"], "gray")
    menu.copy = Action(menu, L["Copy"], 84, PAD, -146, function(bar, index) M:CopyButtonGlows(bar, index) end)
    menu.paste = Action(menu, L["Paste"], 84, PAD + 88, -146, function(bar, index) M:PasteButtonGlows(bar, index) end)
    menu.apply = Action(menu, L["Apply to Bar"], INNER - 176, PAD + 176, -146, function(bar, index) M:ApplyButtonGlowsToBar(bar, index) end)
    W.Label(menu, L["This Bar: Proc Glow"], nil, PAD, -184, INNER, T.muted)
    menu.procButtons, menu.procRefresh = Pills(menu, -202, self.choices.procGlow, "procGlow", { 82, 62, 70, 58 })
    W.Label(menu, L["This Bar: Ready Glow"], nil, PAD, -238, INNER, T.muted)
    menu.readyButtons, menu.readyRefresh = Pills(menu, -256, self.choices.readyStyle, "readyStyle", { 136, 136 })
    menu.more = W.Button(menu, L["All Glow Settings"], INNER, 26, "secondary")
    menu.more:SetPoint("BOTTOMLEFT", PAD, 12)
    menu.more:SetScript("OnClick", function() menu:Hide(); M:JumpTo("glows") end)
    menu:SetScript("OnEvent", OnEvent)
    menu:SetScript("OnShow", function()
        for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED" }) do
            if not menu:IsEventRegistered(event) then menu:RegisterEvent(event) end
        end
    end)
    menu:SetScript("OnHide", function()
        menu:UnregisterAllEvents()
        local view = menu.view
        menu.view, menu.index, menu.button = nil, nil, nil
        if view then view.glowIndex = nil; view.Refresh() end
    end)
    self.glowMenu = menu
    return menu
end

-- To the left of the button, level with it; the screen edge pushes it back
-- in when there's no room.
local function Place(menu, anchor)
    menu:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
end

function M:OpenGlowMenu(view, index, anchor)
    local menu = self:GlowMenu()
    menu.view, menu.index, menu.button = view, index, anchor
    view.glowIndex = index
    Place(menu, anchor)
    menu:Show()
    self:RefreshGlowMenu()
    view.Refresh()
end

function M:RefreshGlowMenu()
    local menu = self.glowMenu
    if not menu or not menu:IsShown() or not menu.index then return end
    local bar = self:PreviewBar()
    local style = self.db[bar]
    menu.title:SetText(string.format(L["%s, button %d"], L[self.barSpecs[bar].label], menu.index))
    for _, box in ipairs({ menu.procBox, menu.readyBox, menu.grayBox }) do box:SetSelected(self.GlowOn(style, menu.index, box.kind)) end
    menu.procRefresh(); menu.readyRefresh()
    -- The bar's own switches gray out what they turn off.
    menu.readyBox:SetEnabled(style.readyGlow)
    menu.grayBox:SetEnabled(style.cooldownDesaturate)
    for _, button in ipairs(menu.readyButtons) do button:SetEnabled(style.readyGlow) end
    menu.paste:SetEnabled(self.glowClipboard ~= nil)
end

-- Blizzard's own proc animation, for the Blizzard style's preview.
local function BlizzardAlert(button)
    local ok, alert = pcall(CreateFrame, "Frame", nil, button, "ActionButtonSpellAlertTemplate")
    if not ok or not alert then return end
    local state = M.skinState[button]
    local g = state and state.g
    if g then alert:SetSize(g.w * 1.4, g.h * 1.4) end
    alert:SetPoint("CENTER", button, "CENTER", 0, 0)
    if alert.ProcLoop and alert.ProcLoop.Play then alert.ProcLoop:Play() end
    alert:Hide()
    return alert
end

local function Want(self, button, kind, on, style, color, pulse)
    local set = self.glows[button]
    if not on and not (set and set[kind]) then return end
    local glow = self:Glow(button, kind)
    if on then self.PaintGlow(glow, button, style, color, pulse) end
    glow.wanted = on
end

-- Glows on one preview button: on the menu's button, and wherever the real
-- button has a proc now; only switches that are on for that place. One glow
-- shows at a time, as on the bars.
function M:PreviewGlows(view, button, index, style, real)
    local chosen = view.glowIndex == index
    local proc = (chosen or (real ~= nil and self.procs[real] == true)) and self.GlowOn(style, index, "proc")
    Want(self, button, "proc", proc and (style.procGlow == "mode" or style.procGlow == "border"), style.procGlow, style.procColor, style.procPulse)
    local ready = chosen and style.readyGlow and self.GlowOn(style, index, "ready")
    Want(self, button, "ready", ready, style.readyStyle, style.readyColor, true)
    self:ResolveGlows(button)
    view.alerts = view.alerts or {}
    local blizzard = proc and style.procGlow == "blizzard"
    if blizzard and not view.alerts[button] then view.alerts[button] = BlizzardAlert(button) end
    if view.alerts[button] then view.alerts[button]:SetShown(blizzard) end
    if self.glows[button] then self.glows[button].blizzard = blizzard; self:ResolveGlows(button) end
end
