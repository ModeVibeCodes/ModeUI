local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The preview's glow menu and glow previews. Clicking a button in the
-- settings preview opens the Bar tab and a small menu beside the button:
-- switches for that button's proc glow and ready glow, and the bar's glow
-- styles. While the menu is open the button shows its glows; a proc lit on the
-- real bar shows on its preview button too.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local WIDTH, HEIGHT = 268, 236

-- Turns one glow kind on or off for the button at `index` (stored only when off).
function M:SetButtonGlow(bar, index, kind, on)
    local glows = addon.ProfileCodec.Copy(self.db[bar].buttonGlows)
    local place = tostring(index)
    local entry = glows[place] or {}
    if on then entry[kind] = nil else entry[kind] = false end
    glows[place] = next(entry) and entry or nil
    return self:SetOption(bar, "buttonGlows", glows)
end

local function Check(menu, y, label, kind)
    local box = W.Button(menu, "", 24, 24, "checkbox")
    box:SetPoint("TOPLEFT", 14, y)
    W.Label(menu, label, nil, 46, y - 4, WIDTH - 60, T.text)
    box:SetScript("OnClick", function()
        local bar = M:PreviewBar()
        M:SetButtonGlow(bar, menu.index, kind, not M.GlowOn(M.db[bar], menu.index, kind))
        M:RefreshGlowMenu()
    end)
    box.kind = kind
    return box
end

local function Pills(menu, y, list, key, width)
    local host = CreateFrame("Frame", nil, menu)
    host:SetPoint("TOPLEFT", 14, y); host:SetSize(WIDTH - 28, 28)
    local choices = {}
    for _, item in ipairs(list) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width } end
    return W.Exclusive(host, choices, function() return M.db[M:PreviewBar()][key] end,
        function(value) M:SetOption(M:PreviewBar(), key, value); M:RefreshGlowMenu() end)
end

function M:GlowMenu()
    if self.glowMenu then return self.glowMenu end
    local menu = CreateFrame("Frame", "ModeUIActionBarGlowMenu", UIParent)
    menu:SetSize(WIDTH, HEIGHT); menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(200)
    menu:SetClampedToScreen(true); menu:EnableMouse(true); menu:Hide()
    W.Texture(menu, "Window"); W.Texture(menu, "BorderSilver", "BORDER")
    menu.title = W.Label(menu, "", nil, 14, -12, WIDTH - 28, T.secondary)
    menu.procBox = Check(menu, -38, L["Proc Glow on This Button"], "proc")
    menu.readyBox = Check(menu, -66, L["Glow When Ready on This Button"], "ready")
    W.Label(menu, L["Proc Glow"], nil, 14, -100, WIDTH - 28, T.muted)
    menu.procButtons, menu.procRefresh = Pills(menu, -118, self.choices.procGlow, "procGlow", 60)
    W.Label(menu, L["Ready Glow"], nil, 14, -152, WIDTH - 28, T.muted)
    menu.readyButtons, menu.readyRefresh = Pills(menu, -170, self.choices.readyStyle, "readyStyle", 80)
    menu.more = W.Button(menu, L["All Glow Settings"], WIDTH - 28, 26, "secondary")
    menu.more:SetPoint("BOTTOMLEFT", 14, 12)
    menu.more:SetScript("OnClick", function() menu:Hide(); M:JumpTo("glows") end)
    menu:SetScript("OnHide", function()
        local view = menu.view
        menu.view, menu.index = nil, nil
        if view then view.glowIndex = nil; view.Refresh() end
    end)
    -- Closes with the other settings popups (scrolling, combat).
    addon.fontDropdownMenus = addon.fontDropdownMenus or {}
    addon.fontDropdownMenus[menu] = true
    self.glowMenu = menu
    return menu
end

function M:OpenGlowMenu(view, index, anchor)
    local menu = self:GlowMenu()
    menu.view, menu.index = view, index
    view.glowIndex = index
    W.PlacePopup(menu, anchor)
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
    menu.procBox:SetSelected(self.GlowOn(style, menu.index, "proc"))
    menu.readyBox:SetSelected(self.GlowOn(style, menu.index, "ready"))
    menu.procRefresh(); menu.readyRefresh()
    -- The bar's switches gray out what they turn off.
    menu.readyBox:SetEnabled(style.readyGlow)
    for _, button in ipairs(menu.readyButtons) do button:SetEnabled(style.readyGlow) end
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

local function Show(self, button, kind, on, style, color, pulse)
    local set = self.glows[button]
    if not on and not (set and set[kind]) then return end
    local glow = self:Glow(button, kind)
    if on then self.PaintGlow(glow, button, style, color, pulse) end
    glow:SetShown(on)
end

-- Glows on one preview button: on the menu's button, and wherever the real
-- button has a proc now; only kinds switched on for that place.
function M:PreviewGlows(view, button, index, style, real)
    local chosen = view.glowIndex == index
    local proc = (chosen or (real ~= nil and self.procs[real] == true)) and self.GlowOn(style, index, "proc")
    local own = proc and (style.procGlow == "mode" or style.procGlow == "border")
    Show(self, button, "proc", own, style.procGlow, style.procColor, style.procPulse)
    view.alerts = view.alerts or {}
    local blizzard = proc and style.procGlow == "blizzard"
    if blizzard and not view.alerts[button] then view.alerts[button] = BlizzardAlert(button) end
    if view.alerts[button] then view.alerts[button]:SetShown(blizzard) end
    local ready = chosen and style.readyGlow and self.GlowOn(style, index, "ready")
    Show(self, button, "ready", ready, style.readyStyle, style.readyColor, true)
end
