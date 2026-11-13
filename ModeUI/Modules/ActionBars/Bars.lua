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
local P, Number = addon.Positioning, addon.IsNumber

M.STATE_SNIPPET = [[
    self:SetAttribute("modeshown", newstate)
    if newstate == "show" and not self:GetAttribute("modeoverride") then self:Show() else self:Hide() end
]]
M.OVERRIDE_SHOW = [[ owner:SetAttribute("modeoverride", true); owner:Hide() ]]
M.OVERRIDE_HIDE = [[
    owner:SetAttribute("modeoverride", nil)
    if owner:GetAttribute("modeshown") == "show" then owner:Show() end
]]
-- Paging: the bar's state driver picks a page; this sets it on every button
-- (a number, or "none" to let the button follow its Blizzard bar). It runs in
-- the game's secure environment, so pages change in combat too.
M.PAGE_SNIPPET = [[
    local page = tonumber(newstate)
    for i = 1, 12 do
        local button = self:GetFrameRef("button" .. i)
        if button then button:SetAttribute("actionpage", page) end
    end
]]

function M:Build()
    if self.built then return end
    self.built = true
    self.hider = CreateFrame("Frame", "ModeUIActionBarHider", UIParent)
    self.hider:Hide()
    for _, bar in ipairs(self.bars) do self:BuildBar(bar) end
end

function M:BuildBar(bar)
    local spec = self.barSpecs[bar]
    local header = CreateFrame("Frame", self.frameNames[bar], UIParent, "SecureHandlerStateTemplate")
    header:SetFrameStrata("MEDIUM")
    header:SetAttribute("_onstate-modevis", self.STATE_SNIPPET)
    header:SetAttribute("_onstate-modepage", self.PAGE_SNIPPET)
    header:SetSize(1, 1); header:SetPoint("CENTER")
    header:Hide()
    self.headers[bar] = header
    self.slots[bar] = {}
    local buttons = {}
    for i = 1, spec.count do
        self.slots[bar][i] = self:BuildSlot(header)
        local button = _G[spec.prefix .. i]
        if type(button) == "table" and button.SetParent then
            buttons[i], self.barOf[button], self.indexOf[button] = button, bar, i
            -- The paging snippet reaches the buttons of bars that page.
            if self.pages[bar] and SecureHandlerSetFrameRef then SecureHandlerSetFrameRef(header, "button" .. i, button) end
        end
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
        -- Blizzard's buttons are 45 square; a size the game won't tell is taken as that.
        local width, height = button:GetWidth(), button:GetHeight()
        if not Number(width, 1, 400) or not Number(height, 1, 400) then width, height = 45, 45 end
        self.homes[button] = { parent = button:GetParent(), width = width, height = height, points = points }
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
        -- Edit Mode and Keybind Mode show every slot, so a bar keeps its shape.
        slot:SetShown(inside and (style.showEmpty or self.editing == true or self.binding == true))
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
    local paging = self:PageConditions(bar)
    if paging then RegisterStateDriver(header, "modepage", paging)
    else
        UnregisterStateDriver(header, "modepage")
        if header:GetAttribute("state-modepage") ~= "none" then header:SetAttribute("state-modepage", "none") end
    end
    self:SyncPosition(bar)
    self:LayoutGhost(bar)
end

-- Switching the module off gives every button back to its Blizzard bar and
-- the art back to the screen; Blizzard's button look returns on reload.
function M:Restore()
    for _, bar in ipairs(self.bars) do
        local header = self.headers[bar]
        UnregisterStateDriver(header, "modevis")
        UnregisterStateDriver(header, "modepage")
        -- Buttons follow their Blizzard bars' pages again.
        header:SetAttribute("state-modepage", "none")
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
-- frames, and a stand-in can anchor to another bar's stand-in). Each bar is
-- pinned to the screen where its stand-in is, on whole pixels, outside
-- combat, so a secure bar never hangs from another frame.
function M:SyncPosition(bar)
    local header, ghost = self.headers[bar], self.ghosts[bar]
    if not header or not ghost or addon.InCombat() then return end
    local x, y, width, height = P:Geometry(ghost)
    local px = self.PixelSize(header)
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    header:ClearAllPoints()
    if not x then
        -- Not measurable yet: hang from the stand-in until the next refresh.
        header:SetAllPoints(ghost)
        return
    end
    header:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Snap(x - width / 2 - (UIParent:GetLeft() or 0)),
        Snap(y - height / 2 - (UIParent:GetBottom() or 0)))
end

-- Bars anchored to a moved bar move with it, so every bar follows.
function M:SyncAll()
    for _, bar in ipairs(self.bars) do self:SyncPosition(bar) end
end

function M:CreateGhost(bar)
    local ghost = CreateFrame("Frame", self.frameNames[bar] .. "Mover", UIParent)
    ghost:SetFrameStrata("HIGH")
    ghost.slots = {}
    ghost.fill = ghost:CreateTexture(nil, "BACKGROUND", nil, -8)
    ghost.bar = bar
    self.ghosts[bar] = ghost
    self:LayoutGhost(bar)
    -- Measured before registering; the Position Manager then moves it.
    ghost:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    local id = self.elementIds[bar]
    local ok, element = addon.PositionManager:RegisterElement(id, ghost, { moduleId = self.id,
        defaultPosition = self.defaultPositions[bar], allowedTargets = self.allowedTargets[bar],
        canDrag = function() return self.active == true and self.db[bar].show end,
        label = L[self.barSpecs[bar].label], onPositionChanged = function() self:SyncAll() end })
    assert(ok, "ModeUI: action bar position registration failed: " .. tostring(element))
    ghost:Hide()
end

-- While a stand-in is dragged, the bars follow it frame by frame.
local function Follow(self)
    for _, bar in ipairs(self.bars) do
        local element = addon.PositionManager:Element(self.elementIds[bar])
        if element and element.dragging then self:SyncAll(); return end
    end
end

-- In Edit Mode every bar that's switched on shows with its stand-in over it:
-- a cyan highlight with the bar's name in the middle.
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
    if self.editing and not self.follower then
        self.follower = CreateFrame("Frame")
        self.follower:SetScript("OnUpdate", function() Follow(self) end)
    end
    if self.follower then self.follower:SetShown(self.editing == true) end
end
