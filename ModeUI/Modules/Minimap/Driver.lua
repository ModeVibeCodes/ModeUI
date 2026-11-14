local _, addon = ...
local M = addon.Minimap
if not M then return end

-- Lifecycle, events, the 0.1 s tick (coordinates, clock, hover), opacity,
-- Edit Mode and settings. Nothing is built or moved until the module is
-- first switched on; frame changes go through Defer, so they wait for the
-- end of combat. Turning the module off asks for a reload: Blizzard's
-- minimap lives inside ModeUI's frames until then.
local Events, L, Defer = addon.Events, addon.L, addon.Defer
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local TICK = 0.1

function M:OnInitialize()
    self.Initialize(self.db)
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("minimap")
    for _, event in ipairs(ZONE_EVENTS) do Events:On(self, event, function() self:UpdateZone() end) end
    Events:On(self, "PLAYER_ENTERING_WORLD", function() self:UpdateZone(); self:CollectButtons() end)
    Events:On(self, "ADDON_LOADED", function(_, name)
        if name == "Blizzard_HybridMinimap" and self.built then self:SkinHybrid() end
        if name == "Blizzard_Minimap" and not self.built then self:Refresh() end
    end)
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do Events:On(self, event, function() self:Refresh() end) end
    self:Refresh()
    -- Addons often make their minimap buttons a little after login.
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 2, 6, 12 }) do C_Timer.After(delay, function() self:CollectButtons() end) end
    end
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    if self.zoomTimer then self.zoomTimer:Cancel(); self.zoomTimer = nil end
    if self.built then addon.ReloadManager:Request("minimap", L["Minimap: reload to give Blizzard's minimap back."]) end
end

function M:Build()
    self.built = true
    self:BuildShape()
    self:BuildText()
    -- Buttons that get tiles and the addon box move out of Blizzard's frames
    -- before those are hidden.
    self:BuildTiles()
    self:BuildContainer()
    self:AdoptBlizzard()
    self.elapsed = 0
    self.holder:SetScript("OnUpdate", function(_, elapsed) self:Tick(elapsed) end)
end

function M:Refresh()
    if not self.active then return end
    Defer:Run("minimap:layout", function()
        if not self.active or not (Minimap and Minimap.SetMaskTexture) then return end
        if not self.built then self:Build() end
        local width, height = self:LayoutShape()
        local extra = self:LayoutText(width, height)
        self.mover:SetSize(width, height + extra)
        local PM = addon.PositionManager
        for _, id in ipairs({ self.ELEMENT_ID, self.QUEUE_ID, self.BUTTONS_ID }) do PM:ApplyPosition(id) end
        self:LayoutTiles()
        if not self.collectedOnce then self.collectedOnce = true; self:CollectButtons() else self:LayoutContainer() end
        self:ApplyOpacity()
        if self.page then self.page:Refresh() end
    end)
end

function M:Tick(elapsed)
    if not self.active then return end
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < TICK then return end
    self.elapsed = 0
    self:UpdateCoords()
    self:UpdateClock()
    self:UpdateHover()
    self:UpdateContainerShown()
end

-- Opacity, or Combat Opacity while fighting.
function M:CurrentOpacity()
    local fighting = self.inCombat
    if fighting == nil then fighting = addon.InCombat() end
    return (fighting and self.db.combatOpacity or self.db.opacity) / 100
end
function M:ApplyOpacity()
    if not self.built then return end
    self.holder:SetAlpha(self:CurrentOpacity())
    self.containerAlpha = nil
    self:UpdateContainerShown()
end
function M:OnCombatStateChanged(inCombat)
    self.inCombat = inCombat
    self:ApplyOpacity()
end

-- In ModeUI's Edit Mode the map, the eye and the addon box each show a
-- stand-in to drag.
function M:SetEditMode(enabled)
    local show = enabled and self.active or false
    self.editing = show
    if not self.built then return end
    local PM = addon.PositionManager
    local movers = { [self.ELEMENT_ID] = self.mover, [self.QUEUE_ID] = self.queueMover, [self.BUTTONS_ID] = self.buttonsMover }
    for id, mover in pairs(movers) do
        PM:SetEditable(id, show)
        mover:SetShown(show)
    end
    self:LayoutTiles()
    self.containerAlpha = nil
    self:UpdateContainerShown()
end

-- Settings ------------------------------------------------------------------

local function Accept(self, candidate)
    if not pcall(self.Initialize, candidate) then return false end
    for key, value in pairs(candidate) do self.db[key] = value end
    self:Refresh()
    if self.page then self.page:Refresh() end
    return true
end

function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" or key == "buttons" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not Accept(self, candidate) then return false end
    if key == "zoomReset" then self:StartZoomReset() end
    return true
end

-- A Blizzard button's tile: field is "shown" or "corner".
function M:SetButton(name, field, value)
    if not self.defaults.buttons[name] or (field ~= "shown" and field ~= "corner") then return false end
    local candidate = Copy(self.db)
    candidate.buttons[name][field] = value
    return Accept(self, candidate)
end
