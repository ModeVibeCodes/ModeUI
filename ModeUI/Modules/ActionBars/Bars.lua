local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- The bars: one secure header per bar holds Blizzard's buttons for it. The
-- buttons keep their Blizzard bar as `bar`, so paging (stances, vehicles,
-- override bars) still comes from Blizzard. Blizzard's bar art (the main bar,
-- pet bar and stance bar) moves under a hidden frame; the other Blizzard bars
-- have no art and are left alone. All of this happens outside combat only.
--
-- Each header shows by a state driver of macro conditions. Its handler also
-- keeps Action Bar 1 hidden while the game shows its own vehicle bar, which
-- covers the same keys.
local L = addon.L
local Number = addon.IsNumber

M.STATE_SNIPPET = [[
    self:SetAttribute("modeshown", newstate)
    if newstate == "show" and not self:GetAttribute("modeoverride") then self:Show() else self:Hide() end
]]
M.OVERRIDE_SHOW = [[ owner:SetAttribute("modeoverride", true); owner:Hide() ]]
M.OVERRIDE_HIDE = [[
    owner:SetAttribute("modeoverride", nil)
    if owner:GetAttribute("modeshown") == "show" then owner:Show() end
]]

local function FrameName(bar)
    local spec = M.barSpecs[bar]
    if spec.pet then return "ModeUIPetBar" elseif spec.stance then return "ModeUIStanceBar" end
    return "ModeUIActionBar" .. bar:sub(4)
end

function M:Build()
    if self.built then return end
    self.built = true
    self.hider = CreateFrame("Frame", "ModeUIActionBarHider", UIParent)
    self.hider:Hide()
    for _, bar in ipairs(self.bars) do self:BuildBar(bar) end
end

function M:BuildBar(bar)
    local spec = self.barSpecs[bar]
    local header = CreateFrame("Frame", FrameName(bar), UIParent, "SecureHandlerStateTemplate")
    header:SetFrameStrata("MEDIUM")
    header:SetAttribute("_onstate-modevis", self.STATE_SNIPPET)
    local default = self.defaultPositions[bar]
    header:SetSize(1, 1); header:SetPoint(default.point, UIParent, default.relativePoint, default.x, default.y)
    header:Hide()
    self.headers[bar] = header
    self.slots[bar] = {}
    local buttons = {}
    for i = 1, spec.count do
        self.slots[bar][i] = self:BuildSlot(header)
        local button = _G[spec.prefix .. i]
        if type(button) == "table" and button.SetParent then buttons[i] = button; self.barOf[button] = bar end
    end
    self.buttons[bar] = buttons
    if spec.override then self:WatchOverrideBar(header) end
    self:CreateGhost(bar)
end

-- Action Bar 1 steps aside while the game's own vehicle or override bar shows.
function M:WatchOverrideBar(header)
    local override = _G.OverrideActionBar
    if type(override) ~= "table" or type(SecureHandlerWrapScript) ~= "function" then return end
    local shown = pcall(SecureHandlerWrapScript, override, "OnShow", header, self.OVERRIDE_SHOW)
    local hidden = pcall(SecureHandlerWrapScript, override, "OnHide", header, self.OVERRIDE_HIDE)
    self.overrideWatched = shown and hidden
    if override.IsShown and override:IsShown() then header:SetAttribute("modeoverride", true) end
end

-- Blizzard's bars that have art go under the hidden frame; their parents are
-- remembered so switching the module off can put them back.
function M:HideBlizzard()
    self.homes = self.homes or {}
    for _, bar in ipairs(self.bars) do
        for _, name in ipairs(self.barSpecs[bar].blizzard or {}) do
            local frame = _G[name]
            if type(frame) == "table" and frame.SetParent and frame:GetParent() ~= self.hider then
                if self.homes[frame] == nil then self.homes[frame] = { parent = frame:GetParent() } end
                frame:SetParent(self.hider)
            end
        end
    end
end

-- A button moves onto its ModeUI bar (or, past the bar's count, the hidden
-- frame); the first time, where it came from is remembered for switching the
-- module off.
local function Adopt(self, button, parent)
    if self.homes[button] == nil then
        local points = {}
        for i = 1, button:GetNumPoints() do points[i] = { button:GetPoint(i) } end
        self.homes[button] = { parent = button:GetParent(), width = button:GetWidth(), height = button:GetHeight(), points = points }
    end
    if button:GetParent() ~= parent then button:SetParent(parent) end
end

-- Lays out one bar: its size, buttons, empty slots and show conditions.
function M:ApplyBar(bar)
    local style, header, spec = self.db[bar], self.headers[bar], self.barSpecs[bar]
    local count = self:ButtonCount(bar)
    local g = self.Geometry(style, math.max(1, count), self.PixelSize(header))
    header:SetSize(g.width, g.height)
    local level = header:GetFrameLevel()
    for i = 1, spec.count do
        local button, slot = self.buttons[bar][i], self.slots[bar][i]
        local inside = i <= count
        if inside then
            self.Place(slot, header, g, i)
            slot:SetFrameLevel(level + 1)
            self:PaintSlot(slot, style, g)
        end
        slot:SetShown(inside and style.showEmpty)
        if button then
            if inside then
                Adopt(self, button, header)
                self.Place(button, header, g, i)
                button:SetFrameLevel(level + 3)
                self:SkinButton(button, style, g)
            else
                -- Buttons past the bar's count wait on the hidden frame.
                Adopt(self, button, self.hider)
            end
        end
    end
    RegisterStateDriver(header, "modevis", self:Conditions(bar, count))
    self:SyncPosition(bar)
    self:LayoutGhost(bar)
end

-- Switching the module off gives every button back to its Blizzard bar and
-- the art back to the screen; Blizzard's button look returns on reload.
function M:Restore()
    for _, bar in ipairs(self.bars) do
        local header = self.headers[bar]
        UnregisterStateDriver(header, "modevis")
        -- Leaving the vehicle bar must not show an emptied bar again.
        header:SetAttribute("modeshown", nil)
        header:Hide()
        if self.ghosts[bar] then self.ghosts[bar]:Hide() end
    end
    for frame, home in pairs(self.homes or {}) do
        frame:SetParent(home.parent)
        if home.width then
            frame:ClearAllPoints()
            for _, point in ipairs(home.points) do frame:SetPoint(unpack(point)) end
            frame:SetSize(home.width, home.height)
        end
        self.homes[frame] = nil
    end
    addon.ReloadManager:Request("actionBars", L["Action Bars: reload to give the buttons back their Blizzard look."])
end

-- Edit Mode moves a plain stand-in (Position Manager refuses protected
-- frames); the bar copies its anchor outside combat, on whole pixels.
function M:SyncPosition(bar)
    local header, ghost = self.headers[bar], self.ghosts[bar]
    if not header or not ghost or addon.InCombat() then return end
    local count = ghost:GetNumPoints()
    if not Number(count, 1, 10) then return end
    local px = self.PixelSize(header)
    local function Snap(v) return Number(v, -100000, 100000) and math.floor(v / px + 0.5) * px or v end
    header:ClearAllPoints()
    for i = 1, count do
        local point, relative, relativePoint, x, y = ghost:GetPoint(i)
        header:SetPoint(point, relative or UIParent, relativePoint, Snap(x), Snap(y))
    end
end

function M:CreateGhost(bar)
    local ghost = CreateFrame("Frame", FrameName(bar) .. "Mover", UIParent)
    ghost:SetFrameStrata("HIGH")
    ghost.slots = {}
    ghost.fill = ghost:CreateTexture(nil, "BACKGROUND", nil, -8)
    ghost.label = addon.Kit.Text(ghost)
    ghost.label:SetPoint("CENTER")
    ghost.bar = bar
    self.ghosts[bar] = ghost
    self:LayoutGhost(bar)
    local default = self.defaultPositions[bar]
    ghost:SetPoint(default.point, UIParent, default.relativePoint, default.x, default.y)
    local id = self.elementIds[bar]
    local ok, element = addon.PositionManager:RegisterElement(id, ghost, { moduleId = self.id,
        defaultPosition = default, allowedTargets = { "screen" },
        canDrag = function() return self.active == true and self.db[bar].show end,
        onPositionChanged = function() self:SyncPosition(bar) end })
    assert(ok, "ModeUI: action bar position registration failed: " .. tostring(element))
    element.label = L[self.barSpecs[bar].label]
    ghost:Hide()
end

-- Stand-ins show in Edit Mode for every bar that's switched on.
function M:RenderGhosts()
    for _, bar in ipairs(self.bars) do
        local ghost = self.ghosts[bar]
        if ghost then
            local show = self.editing == true and self.active == true and self.db[bar].show
            addon.PositionManager:SetEditable(self.elementIds[bar], show)
            if show then self:LayoutGhost(bar) end
            ghost:SetShown(show)
        end
    end
end
