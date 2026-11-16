local _, addon = ...
local M = addon.Minimap
if not M then return end

-- Addon Buttons: other addons' minimap buttons in a tray of Mode tiles (the
-- approved probe), placed in ModeUI's Edit Mode (under the map by default).
-- Each button sits on a tile (Button Size wide, a little shorter, Spacing
-- apart, in the `group` edge), scaled into it, with LibDBIcon's round frame art faded, so
-- its clicks and menus are its own. Buttons are found the way button
-- collector addons find them: LibDBIcon's list, then named children of the
-- Minimap that look like buttons, skipping map pins (gathering and note
-- addons), Blizzard's own frames, protected frames and ModeUI's. Blizzard's
-- addon compartment (which holds ModeUI's entry) is the first cell. Moving
-- is done with Adopt (reparent and re-place after the addon moves its
-- button); no addon function is replaced.
local Kit, L, Style = addon.Kit, addon.L, addon.Style
-- LibDBIcon's round border and background art (file IDs and paths).
local ROUND_ART = { [136430] = true, [136467] = true }
local ROUND_PATHS = { "TrackingBorder", "Minimap%-Background" }
-- Map pins and other minimap children that aren't buttons.
local SKIP = { "^HandyNotes", "^TomTom", "^GatherMate", "^GatherNote", "^HereBeDragons", "^Questie", "^QuestHelper",
    "^ModeUI", "^Minimap", "^GameTime", "^HybridMinimap" }

local function Public(value) return addon.IsPublic(value) end

local function Candidate(frame)
    if not frame or not frame.GetName or not frame.GetObjectType then return false end
    local name = frame:GetName()
    if not Public(name) or type(name) ~= "string" then return false end
    if name:find("^LibDBIcon10_") then return true end
    for _, pattern in ipairs(SKIP) do if name:find(pattern) then return false end end
    if issecurevariable and issecurevariable(name) then return false end -- Blizzard's own
    if frame.IsProtected then
        local protected = frame:IsProtected()
        if not Public(protected) or protected then return false end
    end
    if frame:GetObjectType() ~= "Button" then return false end
    if not (frame:GetScript("OnClick") or frame:GetScript("OnMouseUp")) then return false end
    local w, h = frame:GetSize()
    return addon.IsNumber(w, 14, 64) and addon.IsNumber(h, 14, 64) and math.abs(w - h) <= 8
end

function M:BuildContainer()
    local mover = CreateFrame("Frame", "ModeUIMinimapButtonsMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(self.db.size, 28)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT)
    Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.buttonsMover = mover
    local box = CreateFrame("Frame", "ModeUIMinimapButtons", UIParent)
    box:SetFrameStrata("LOW")
    box:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    self.container, self.cells, self.collected, self.collectedList = box, {}, {}, {}
    local ok, reason = addon.PositionManager:RegisterElement(self.BUTTONS_ID, mover, { moduleId = self.id,
        defaultPosition = self.BUTTONS_POSITION, label = L["Addon Buttons"], anyTarget = true,
        canDrag = function() return self.active == true end })
    assert(ok, "ModeUI: addon buttons position registration failed: " .. tostring(reason))
    mover:Hide()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.RegisterCallback then
        pcall(lib.RegisterCallback, self, "LibDBIcon_IconCreated", function() self:CollectButtons() end)
    end
end

local function FadeRoundArt(button)
    for _, region in ipairs({ button:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local id = region.GetTextureFileID and region:GetTextureFileID()
            local path = region.GetTexture and region:GetTexture()
            local round = Public(id) and ROUND_ART[id]
            if not round and Public(path) and type(path) == "string" then
                for _, pattern in ipairs(ROUND_PATHS) do if path:find(pattern) then round = true end end
            end
            if round then region:SetAlpha(0) end
        end
    end
end

function M:AddButton(button)
    if not button or self.collected[button] then return end
    self.collected[button] = true
    self.collectedList[#self.collectedList + 1] = button
    local cell = self:NewTile(self.container)
    self.cells[button] = cell
    self:Adopt(button, cell, function(frame) frame:SetPoint("CENTER", cell, "CENTER", 0, 0) end, 1)
    if button ~= AddonCompartmentFrame then FadeRoundArt(button) end
    self:FollowShown(button, function() self:LayoutContainer() end)
end

-- Finds new buttons; safe to run again (addons make buttons late).
function M:CollectButtons()
    if not self.active or not self.container then return end
    if AddonCompartmentFrame then self:AddButton(AddonCompartmentFrame) end
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        local ok, names = pcall(lib.GetButtonList, lib)
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                local found, button = pcall(lib.GetMinimapButton, lib, name)
                if found and button then self:AddButton(button) end
            end
        end
    end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if not self.collected[child] and Candidate(child) then self:AddButton(child) end
    end
    self:LayoutContainer()
end

-- A cell's scale: LibDBIcon buttons by their 18 px icon, others by size.
local function Scale(button, cell)
    if button.icon and button:GetName() and Public(button:GetName()) and tostring(button:GetName()):find("^LibDBIcon10_") then
        return cell * 0.8 / 18
    end
    local w, h = button:GetSize()
    if not (addon.IsNumber(w, 1) and addon.IsNumber(h, 1)) then return 1 end
    return cell / math.max(w, h)
end

function M:LayoutContainer()
    local box = self.container
    if not box or not self.px then return end
    local db, px = self.db, self.px
    local size = addon.Skin.Snap(db.buttonSize, px)
    local tall = Style.IconHeight(math.floor(size / px + 0.5)) * px
    local gap = addon.Skin.Snap(db.buttonSpacing, px)
    -- The tiles' edges stay inside the tray (and line up with the map's sides).
    local inner = (self.BORDER_PIXELS[db.buttonBorder] or 1) * px
    local shown = {}
    for _, button in ipairs(self.collectedList) do
        local cell = self.cells[button]
        local visible = button:IsShown()
        cell:SetShown(visible)
        if visible then shown[#shown + 1] = button end
    end
    self.containerEmpty = #shown == 0
    local count = math.max(1, #shown)
    local columns = count
    if db.matchWidth and self.mapWidth then
        columns = math.max(1, math.floor((self.mapWidth - 2 * inner + gap) / (size + gap)))
    end
    columns = math.min(columns, count)
    local rows = math.ceil(count / columns)
    local width = db.matchWidth and self.mapWidth or (2 * inner + columns * size + (columns - 1) * gap)
    local height = 2 * inner + rows * tall + (rows - 1) * gap
    box:SetSize(width, height)
    self.buttonsMover:SetSize(width, height)
    for index, button in ipairs(shown) do
        local cell = self.cells[button]
        cell:SetFrameLevel(box:GetFrameLevel() + 4)
        self:LayoutTile(cell, size, tall)
        local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", box, "TOPLEFT", inner + column * (size + gap), -(inner + row * (tall + gap)))
        self:Replace(button, nil, Scale(button, tall))
    end
    self:UpdateContainerShown()
end

-- Always, Mouseover (shown while the pointer is over it) or Hidden; in Edit
-- Mode it always shows. With no buttons to hold it stays hidden.
function M:UpdateContainerShown()
    local box = self.container
    if not box then return end
    local mode = self.db.addonButtons
    box:SetShown(self.active and (self.editing == true or (mode ~= "hidden" and not self.containerEmpty)))
    local alpha = 1
    if mode == "mouseover" and not self.editing then alpha = box:IsMouseOver() and 1 or 0 end
    alpha = alpha * self:CurrentOpacity()
    if alpha ~= self.containerAlpha then self.containerAlpha = alpha; box:SetAlpha(alpha) end
end
