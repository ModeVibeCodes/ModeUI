local _, addon = ...
local M = addon.Bags
if not M then return end

-- Lifecycle, events and settings. Nothing is built until the module is first
-- switched on; then the window and every slot's button are made at once
-- (never in combat: EnsureButtons). While the window is closed, bag changes
-- just mark it stale; it redraws as it opens.
local Events, L, Containers = addon.Events, addon.L, addon.Domain.Containers
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:OnInitialize()
    self.Initialize(self.db)
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

-- Bag contents change: everything is drawn again (once, after the game's
-- burst of BAG_UPDATEs). The rest touch only what they name.
local EVENTS = {
    BAG_UPDATE_DELAYED = "Update", BAG_CONTAINER_UPDATE = "BagsChanged", PLAYER_ENTERING_WORLD = "EnteredWorld",
    -- Comes just before the combat lockdown starts.
    PLAYER_REGEN_DISABLED = "EnsureButtons",
    -- These come in bursts (item data arriving for many items at once).
    QUEST_LOG_UPDATE = "QueueUpdate", GET_ITEM_INFO_RECEIVED = "QueueUpdate",
    ITEM_LOCK_CHANGED = "UpdateStates", INVENTORY_SEARCH_UPDATE = "UpdateStates", BAG_NEW_ITEMS_UPDATED = "UpdateStates",
    BAG_UPDATE_COOLDOWN = "UpdateCooldowns", PLAYER_MONEY = "UpdateFooter",
}

function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("bags")
    self:BuildWindow()
    self:EnsureButtons()
    self:HookBlizzard()
    for event, method in pairs(EVENTS) do Events:On(self, event, function() self[method](self) end) end
    Events:On(self, "PLAYER_REGEN_ENABLED", function() self:CombatEnded() end)
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do Events:On(self, event, function() self:Refresh() end) end
    self:Capture()
    self:Refresh()
    self:SetOpen(self:BlizzardOpen())
end

-- Blizzard's frames go back under their own parents (open bags show there
-- at once) and the window hides.
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self:Capture()
    self:SetOpen(false)
    if self.mover then addon.PositionManager:SetEditable(self.ELEMENT_ID, false); self.mover:Hide() end
end

function M:CombatEnded()
    if self.capturePending then self:Capture() end
    self:EnsureButtons()
    if self.layoutPending then self.layoutPending = nil; self:Update() end
end

-- Shows or hides the window. Closing clears the search, as Blizzard's box
-- does, and closes the Sort menu.
function M:SetOpen(open)
    open = open == true and self.active == true and self.frame ~= nil
    if self.open == open then return end
    self.open = open
    local frame = self.frame
    if not frame then return end
    if open then
        frame:Show()
        self:Update()
    else
        frame:Hide()
        self:CloseSortMenu()
        self:ClearSearch()
    end
end

-- Redraws the window if it's open; otherwise it redraws when it opens (and
-- only its size is worked out, for Edit Mode's stand-in).
function M:Update()
    if not self.frame then return end
    if not self.open then self.stale = true; self:Measure(); return end
    self.stale = nil
    self:Layout()
end

-- A bag was equipped, removed or swapped: its slots get their buttons.
function M:BagsChanged()
    self:EnsureButtons()
    self:Update()
end

-- A loading screen: every slot gets its button, and slots never drawn yet
-- are drawn once behind it (the window open for one frame, then back to
-- Blizzard's state), as Bagnon does, so each button has been set up and
-- shown by the game out of combat before it's first used in combat.
function M:EnteredWorld()
    self:EnsureButtons()
    if self.open or InCombatLockdown() or not self:HasUndrawn() then self:Update(); return end
    self:SetOpen(true)
    C_Timer.After(0, function() self:SetOpen(self:BlizzardOpen()) end)
end

-- One redraw a tenth of a second after the first of a burst.
function M:QueueUpdate()
    if not self.open then self.stale = true; return end
    if self.queued then return end
    self.queued = true
    C_Timer.After(0.1, function() self.queued = nil; self:Update() end)
end

-- Look and size changed: paint the window again.
function M:Refresh()
    if not self.active or not self.frame then return end
    self:PaintWindow()
    self:Update()
    self:PlaceMover()
    if self.page then self.page:Refresh() end
end

-- Locks, search matches and new-item marks, without placing slots again.
function M:UpdateStates()
    if not self.open or not self.slots then return end
    for _, button in ipairs(self.slots) do
        if button:IsShown() then self:PaintState(button) end
    end
end

function M:UpdateCooldowns()
    if not self.open or not self.slots then return end
    for _, button in ipairs(self.slots) do
        if button:IsShown() then self:PaintCooldown(button) end
    end
end

function M:CleanUp()
    if addon.InCombat() then return false end
    return Containers.CleanUp()
end

-- Edit Mode -------------------------------------------------------------------

-- In ModeUI's Edit Mode the window's stand-in shows, sized like the window.
function M:SetEditMode(enabled)
    local show = enabled == true and self.active == true
    self.editing = show
    if not self.mover then return end
    addon.PositionManager:SetEditable(self.ELEMENT_ID, show)
    self.mover:SetShown(show)
    self:PlaceMover()
end

-- Settings --------------------------------------------------------------------

function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = candidate[key]
    self:Refresh()
    if self.page then self.page:Layout() end
    return true
end

function M:ResetToDefaults()
    for key, value in pairs(self.defaults) do self.db[key] = Copy(value) end
    self:Refresh()
    if self.page then self.page:Layout() end
    return true
end

-- The owner the shared font and color rows read and write through.
function M:AppearanceOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return true end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

function M:Status()
    if not self.active then return L["Off. Turn the module on to show every bag in one window."] end
    local used, total = self:SlotCounts()
    return string.format(L["On. %d of %d slots used. Open your bags (B) to see the window."], used, total)
end

-- Used and total slots in the held bags (the keyring not counted).
function M:SlotCounts()
    local used, total = 0, 0
    for _, bag in ipairs(Containers.HeldBags()) do
        local size = Containers.NumSlots(bag)
        total = total + size
        used = used + math.max(0, size - Containers.FreeSlots(bag))
    end
    return used, total
end
