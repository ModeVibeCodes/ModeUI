local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Filling the Resource Bars from the game, their colors and texts, when
-- each shows, and their settings. Health and power can be secret (always
-- for health on Forever): values go only to StatusBar SetMinMaxValues and
-- SetValue, AbbreviateNumbers and the FontString setters, all of which
-- accept secrets from addon code; percentages come from UnitHealthPercent
-- and UnitPowerPercent through the 0-100 curve. Nothing compares a value.
-- Combo points light one box each (SetValue(count) on boxes spanning
-- i - 1 to i, Kit.FillResourcePoints).
local Kit, Domain = addon.Kit, addon.Domain
local Health, Power, Resource, UnitColor = Domain.Health, Domain.Power, Domain.ClassResource, Domain.UnitColor
local Call = Domain.Query.Call
local Tone = addon.Style.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Smooth eases the bar toward a new value (Enum.StatusBarInterpolation,
-- SetValue's second argument; never secret). A client without it snaps.
local function Interpolation()
    local enum = Enum and Enum.StatusBarInterpolation
    return enum and enum.ExponentialEaseOut
end

local function Fill(bar, okMax, max, okValue, value, smooth)
    if okMax then pcall(bar.SetMinMaxValues, bar, 0, max) end
    if not okValue then return end
    local ease = smooth and Interpolation() or nil
    if ease ~= nil and pcall(bar.SetValue, bar, value, ease) then return end
    pcall(bar.SetValue, bar, value)
end

-- Text modes: Current, Percent, Current and Percent (Kit.ValueText) and
-- Current / Max (Show Text off hides the text instead).
function M.ResourceValueText(text, mode, percentFn, okValue, value, okMax, max)
    if mode == "currentMax" then
        local hasValue, current, hasMax, top = false, nil, false, nil
        if okValue then hasValue, current = Call(AbbreviateNumbers, value) end
        if okMax then hasMax, top = Call(AbbreviateNumbers, max) end
        if hasValue and hasMax and pcall(Kit.Formatted, text, "%s / %s", current, top) then return end
        mode = "current"
    end
    Kit.ValueText(text, mode, percentFn, "player", okValue, value)
end

-- Bar Color: the power's own color (Power Type), your class color, or the
-- bar's color, always as { r, g, b } by index. Class colors come from
-- Domain.UnitColor keyed (.r, .g, .b), the others indexed.
function M:ResourceColor(id, token)
    local style = self.db.resources[id]
    if style.colorMode == "power" then return Power.Color(token) end
    if style.colorMode == "class" then
        local class = UnitColor.PlayerClass("player")
        if class then return { class.r, class.g, class.b } end
    end
    return style.barColor
end
function M.PaintResource(frame, color, opacity)
    for i = 1, frame.count or 0 do frame.boxes[i].bar:SetStatusBarColor(color[1], color[2], color[3], opacity) end
end

-- Bar Mode (owner, November 17, 2026): Dark is the unit frames' dark mode,
-- the fill in darkFill (combo points too) with its end line, and the text in
-- the bar's own color (Power Type), your class color or a custom one.
function M:ResourceFill(id, color)
    return self.db.resources[id].barMode == "dark" and Tone.darkFill or color
end
function M:ResourceTextColor(id, barColor)
    local style = self.db.resources[id]
    if style.barMode ~= "dark" then return style.textColor end
    if style.darkText == "custom" then return style.darkTextColor end
    if style.darkText == "class" then
        local class = UnitColor.PlayerClass("player")
        if class then return { class.r, class.g, class.b } end
    end
    return barColor
end
-- Colors the text, only when its color changes (power updates come often).
function M:PaintResourceText(frame, id, barColor)
    local c = self:ResourceTextColor(id, barColor)
    local key = string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3])
    if frame.textKey == key then return end
    frame.textKey = key
    frame.text:SetTextColor(c[1], c[2], c[3], 1)
end
-- Fill, rim and text for a bar whose color is `color`.
function M:PaintResourceLook(frame, id, color, opacity)
    M.PaintResource(frame, self:ResourceFill(id, color), opacity)
    self:PaintResourceEdges(frame, id, color)
    self:PaintResourceText(frame, id, color)
end

-- Whether a bar has anything to show for this character now.
function M:ResourceActive(id)
    if id == "combo" then return Resource.Active() end
    if id == "mana" then return Power.AlternateManaActive("player") end
    return true
end

-- Fills one bar (and shows or hides it).
function M:UpdateResource(id)
    local frame = self.resourceFrames and self.resourceFrames[id]
    if not frame then return end
    local style = self.db.resources[id]
    local shown = self.active == true and style.show and self:ResourceActive(id)
    frame:SetShown(shown)
    if not shown then return end
    -- A new point count (another form or class resource) lays it out again.
    if self.resourceSpecs[id].segmented and frame.count ~= self:ResourceBoxCount(id) then self:LayoutResource(id); return end
    local opacity = style.barOpacity / 100
    if id == "combo" then
        local ok, value = Resource.Read()
        Kit.FillResourcePoints(frame.boxes, frame.count, ok, value)
        -- The Full color layers light only at the maximum (Resources.lua).
        for i = 1, frame.count do
            local full = frame.boxes[i].full
            if full and full:IsShown() then if ok then pcall(full.SetValue, full, value) else full:SetValue(frame.count - 1) end end
        end
        self:PaintResourceLook(frame, id, self:ResourceColor(id), opacity)
        if style.text == "current" and ok then
            if not pcall(Kit.Formatted, frame.text, "%d", value) then Kit.Write(frame.text, "") end
        else Kit.Write(frame.text, "") end
    elseif id == "health" then
        local okMax, max, okValue, value = Health.Read("player")
        Fill(frame.boxes[1].bar, okMax, max, okValue, value, style.smooth)
        self:PaintResourceLook(frame, id, self:ResourceColor(id), opacity)
        self.ResourceValueText(frame.text, style.text, Health.Percent, okValue, value, okMax, max)
    else
        local powerType, token
        if id == "mana" then powerType, token = Power.ManaType(), "MANA"
        else powerType, token = Power.Read("player") end
        local okMax, max, okValue, value = Power.ReadType("player", powerType)
        Fill(frame.boxes[1].bar, okMax, max, okValue, value, style.smooth)
        self:PaintResourceLook(frame, id, self:ResourceColor(id, token), opacity)
        self:UpdateResourceMarks(frame, id, token, okMax, max)
        self.ResourceValueText(frame.text, style.text, function(unit, curve) return Power.Percent(unit, powerType, curve) end,
            okValue, value, okMax, max)
    end
    frame:SetAlpha(self:StyleAlpha(style, frame))
end

-- Applies every bar's alpha; true when one that's on uses Mouseover (the
-- fader in Visibility.lua then keeps checking).
function M:UpdateResourceAlpha()
    if not self.resourceFrames then return false end
    local fading = false
    for _, id in ipairs(self.resources) do
        local style = self.db.resources[id]
        self.resourceFrames[id]:SetAlpha(self:StyleAlpha(style, self.resourceFrames[id]))
        fading = fading or (self.active and style.show and style.visibility == "mouseover")
    end
    return fading
end

-- Events ------------------------------------------------------------------------

-- The player's unit events on a frame of the module's own (unit-filtered),
-- with form changes and the target (combo points live on it; Forever's
-- COMBO_TARGET_CHANGED moves them to a new target without a power event).
-- Events a client may lack go through pcall: RegisterEvent errors on them.
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }
local OPTIONAL_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "COMBO_TARGET_CHANGED" }
local RELAYOUT = { UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true, PLAYER_ENTERING_WORLD = true }

function M:OnResourceEvent(event)
    if not self.active then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then self:UpdateResource("health")
    elseif event == "UNIT_POWER_FREQUENT" then
        self:UpdateResource("power"); self:UpdateResource("mana"); self:UpdateResource("combo")
    elseif RELAYOUT[event] then
        self:RefreshResources()
        if self.resourcePage and self.resourcePage:IsShown() then self.resourcePage:Refresh() end
    else self:UpdateResource("combo") end
end

function M:SetResourceEvents(on)
    local frame = self.resourceEvents
    if not frame then
        if not on then return end
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event) self:OnResourceEvent(event) end)
        self.resourceEvents = frame
    end
    if frame.on == on then return end
    frame.on = on
    for _, event in ipairs(UNIT_EVENTS) do
        if on then frame:RegisterUnitEvent(event, "player") else frame:UnregisterEvent(event) end
    end
    for _, event in ipairs(EVENTS) do
        if on then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
    for _, event in ipairs(OPTIONAL_EVENTS) do
        if on then pcall(frame.RegisterEvent, frame, event) else pcall(frame.UnregisterEvent, frame, event) end
    end
end

-- Settings ----------------------------------------------------------------------

local function Changed(self, id, alphaOnly)
    if self.active then
        if alphaOnly then self:UpdateFade()
        -- With Group Resources on, a change to one bar of the block (Power
        -- switched off breaks it up) lays every bar out again.
        elseif self.db.resourceLayout == "grouped" and self.resourceSpecs[id].group then
            self:RefreshResources(); self:UpdateFade()
        else self:LayoutResource(id); self:RenderResourceMovers(); self:UpdateFade() end
    end
    if not alphaOnly and addon.EditMode then addon.EditMode:RefreshElements() end
    if self.resourcePage then
        self.resourcePage:Refresh()
        if not alphaOnly then self.resourcePage:Layout() end
    end
    if self.window then self:RefreshList() end
    return true
end

-- Values are checked by Initialize on a copy before they're kept.
function M:SetResourceOption(id, key, value)
    local defaults = self.resourceDefaults[id]
    if not self:CanConfigure() or not defaults or defaults[key] == nil then return false end
    local candidate = Copy(self.db)
    candidate.resources[id][key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db.resources[id][key] = candidate.resources[id][key]
    return Changed(self, id, self.resourceAlphaKeys[key])
end

-- Back to ModeUI's defaults; whether it shows and its size stay.
function M:ResetResource(id)
    if not self:CanConfigure() or not self.resourceDefaults[id] then return false end
    local style = Copy(self.resourceDefaults[id])
    for key in pairs(self.resourceIdentityKeys) do style[key] = Copy(self.db.resources[id][key]) end
    local target = self.db.resources[id]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    return Changed(self, id, false)
end

-- Owner for the shared font and color widgets; id() names the bar.
function M:ResourceAppearanceOwner(id)
    -- A color another bar has (a tick color on Combo Points) reads white: its row is hidden there.
    local appearance = setmetatable({}, { __index = function(_, key)
        local value = M.db.resources[id()][key]
        if value == nil and M.resourceColorKeys[key] then return addon.Style.Tone.mono.white end
        return value
    end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetResourceOption(id(), key, value) end
    return owner
end
