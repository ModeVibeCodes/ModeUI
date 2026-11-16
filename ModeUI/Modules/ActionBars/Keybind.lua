local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- Keybind Mode (/kb, or Keybind Mode on the settings page): hover any button
-- on a shown bar and press a key, mouse button or wheel to bind it; Escape
-- while hovering clears that button. Every bar that's switched on shows, with
-- all its slots, so empty slots can be bound too. A Mode panel at the top
-- saves or discards the changes; leaving any other way (Escape away from a
-- button, entering combat) saves them. Bindings change outside combat only.
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local Public = addon.IsPublic

-- The game's binding command for each bar's buttons (Blizzard's
-- commandNamePrefix plus "BUTTON" and the index; Bindings.xml).
M.bindingPrefix = { bar1 = "ACTIONBUTTON", bar2 = "MULTIACTIONBAR1BUTTON", bar3 = "MULTIACTIONBAR2BUTTON",
    bar4 = "MULTIACTIONBAR3BUTTON", bar5 = "MULTIACTIONBAR4BUTTON", bar6 = "MULTIACTIONBAR5BUTTON",
    bar7 = "MULTIACTIONBAR6BUTTON", bar8 = "MULTIACTIONBAR7BUTTON", pet = "BONUSACTIONBUTTON", stance = "SHAPESHIFTBUTTON" }
local MOUSE = { LeftButton = true, RightButton = true }

function M:BindingCommand(bar, index) return self.bindingPrefix[bar] .. index end

-- The keys bound to a command, as plain strings.
local function Keys(command)
    local keys = { GetBindingKey(command) }
    for i = #keys, 1, -1 do if not Public(keys[i]) or type(keys[i]) ~= "string" then table.remove(keys, i) end end
    return keys
end
local function Short(key) return M.ShortKey(GetBindingText and GetBindingText(key, true) or key) end

-- The key with the held modifiers, as the game names it ("SHIFT-1").
local function Chord(key)
    if CreateKeyChordStringUsingMetaKeyState then return CreateKeyChordStringUsingMetaKeyState(key) end
    local prefix = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
    return prefix .. key
end
local function Ignored(key)
    if IsKeyPressIgnoredForBinding then return IsKeyPressIgnoredForBinding(key) end
    return key:find("SHIFT$") or key:find("CTRL$") or key:find("ALT$") or key == "UNKNOWN"
end

function M:Bind(catcher, key)
    if addon.InCombat() or not catcher then return false end
    if Ignored(key) then return false end
    local command, label = catcher.command, catcher.label
    for _, old in ipairs(Keys(command)) do SetBinding(old) end
    if key == "ESCAPE" then
        self:KeybindStatus(string.format(L["Cleared %s."], label))
    else
        local chord = Chord(key)
        if not SetBinding(chord, command) then self:KeybindStatus(string.format(L["%s can't be bound."], chord)); return false end
        self:KeybindStatus(string.format(L["%s is now %s."], label, Short(chord)))
    end
    self.bindingsChanged = true
    self:RefreshCatchers()
    return true
end

-- One catcher per button place, laid over the bar while the mode is on.
local function Catcher(self, header)
    local catcher = CreateFrame("Button", nil, header)
    catcher:EnableMouse(true); catcher:EnableMouseWheel(true)
    catcher:RegisterForClicks("AnyUp")
    catcher.fill = catcher:CreateTexture(nil, "OVERLAY")
    catcher.fill:SetAllPoints(); catcher.fill:SetTexture(Kit.FLAT)
    catcher.key = Kit.Text(catcher)
    catcher.key:SetPoint("CENTER")
    catcher:SetScript("OnEnter", function()
        self.hovered = catcher; self:PaintCatcher(catcher)
        if GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(catcher, "ANCHOR_TOP")
            GameTooltip:SetText(catcher.label)
            GameTooltip:AddLine(L["Press a key to bind it. Escape clears."], 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    catcher:SetScript("OnLeave", function()
        if self.hovered == catcher then self.hovered = nil end
        self:PaintCatcher(catcher)
        if GameTooltip then GameTooltip:Hide() end
    end)
    catcher:SetScript("OnMouseDown", function(_, button)
        if not MOUSE[button] then self:Bind(catcher, GetConvertedKeyOrButton and GetConvertedKeyOrButton(button) or button) end
    end)
    catcher:SetScript("OnMouseWheel", function(_, delta) self:Bind(catcher, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    return catcher
end

function M:PaintCatcher(catcher)
    local hovered = self.hovered == catcher
    Kit.Tint(catcher.fill, T.primary, hovered and 0.35 or 0.12)
    local keys = Keys(catcher.command)
    catcher.key:SetText(keys[1] and Short(keys[1]) or "")
    local white = addon.Style.Tone.mono.white
    catcher.key:SetTextColor(white[1], white[2], white[3], 1)
end

-- Lays the catchers over every shown bar's places.
function M:RefreshCatchers()
    self.catchers = self.catchers or {}
    for _, bar in ipairs(self.bars) do
        local list = self.catchers[bar] or {}
        self.catchers[bar] = list
        local header, style = self.headers[bar], self.db[bar]
        -- The micro menu and bag bar have no action bindings.
        local count = self.binding and style.show and not self.barSpecs[bar].utility and self:ButtonCount(bar) or 0
        local g = self.Geometry(style, math.max(1, count), self.PixelSize(header))
        for i = 1, math.max(count, #list) do
            local catcher = list[i]
            if i <= count then
                catcher = catcher or Catcher(self, header)
                list[i] = catcher
                catcher.command = self:BindingCommand(bar, i)
                catcher.label = string.format(L["%s, button %d"], L[self.barSpecs[bar].label], i)
                self.Place(catcher, header, g, i)
                catcher:SetFrameLevel(header:GetFrameLevel() + 20)
                Kit.Font(catcher.key, { outline = true, shadow = true, textColor = Kit.palette.text }, 12, Kit.FontPath(style, self.id), g.px)
                self:PaintCatcher(catcher)
                catcher:Show()
            elseif catcher then catcher:Hide() end
        end
    end
end

local function Panel(self)
    local panel = CreateFrame("Frame", "ModeUIKeybindPanel", UIParent)
    panel:SetSize(380, 112); panel:SetPoint("TOP", UIParent, "TOP", 0, -48)
    panel:SetFrameStrata("DIALOG"); panel:EnableMouse(true)
    W.Texture(panel, "Window"); W.Texture(panel, "BorderSilver", "BORDER")
    W.Heading(panel, L["Keybind Mode"], T.fontSize.section, 20, -16, 340, T.text)
    panel.status = W.Label(panel, "", nil, 20, -44, 340, T.muted)
    local save = W.Button(panel, L["Save"], 166, 30); save:SetPoint("BOTTOMLEFT", 20, 16); save:SetSelected(true)
    save:SetScript("OnClick", function() self:SetKeybindMode(false, true) end)
    local discard = W.Button(panel, L["Discard"], 166, 30, "secondary"); discard:SetPoint("BOTTOMRIGHT", -20, 16)
    discard:SetScript("OnClick", function() self:SetKeybindMode(false, false) end)
    panel.saveButton, panel.discardButton = save, discard
    -- Keys reach the hovered button; Escape away from a button leaves (saving).
    panel:EnableKeyboard(true)
    panel:SetScript("OnKeyDown", function(_, key)
        local hovered = self.hovered
        panel:SetPropagateKeyboardInput(not hovered and key ~= "ESCAPE")
        if hovered then self:Bind(hovered, key) elseif key == "ESCAPE" then self:SetKeybindMode(false, true) end
    end)
    panel:Hide()
    return panel
end

function M:KeybindStatus(text)
    if self.keybindPanel then self.keybindPanel.status:SetText(text) end
end

-- on: enter or leave. save (when leaving): keep the changes (default) or
-- put back the bindings from before.
function M:SetKeybindMode(on, save)
    if on then
        if self.binding then return true end
        if not self.active then print(L["ModeUI: turn on Action Bars to use Keybind Mode."]); return false end
        if addon.InCombat() then print(L["ModeUI: Keybind Mode is available outside combat."]); return false end
        if addon.editMode then addon:SetEditMode(false) end
        if addon.configWindow and addon.configWindow:IsShown() then addon.configWindow:Hide() end
        self.binding, self.bindingsChanged = true, false
        self.keybindPanel = self.keybindPanel or Panel(self)
        self.keybindPanel:Show()
        self:KeybindStatus(L["Hover a button and press a key."])
        addon.Events:On(self.keybindPanel, "PLAYER_REGEN_DISABLED", function() self:SetKeybindMode(false, true) end)
        self:Apply()
        self:RefreshCatchers()
        return true
    end
    if not self.binding then return true end
    self.binding, self.hovered = false, nil
    addon.Events:OffAll(self.keybindPanel)
    if self.bindingsChanged and GetCurrentBindingSet then
        pcall(save == false and LoadBindings or SaveBindings, GetCurrentBindingSet())
    end
    self.keybindPanel:Hide()
    self:RefreshCatchers()
    self:Refresh()
    return true
end

function M:ToggleKeybindMode() return self:SetKeybindMode(not self.binding) end
