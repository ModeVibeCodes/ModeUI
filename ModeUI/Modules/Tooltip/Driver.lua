local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- Lifecycle, Blizzard post-hooks, placement and combat.
--   Look       each tooltip is skinned once and repainted as it shows; the
--              lines get the Mode face before a data tooltip shows
--              (TooltipDataProcessor post-call) and on show for plain ones.
--   Placement  GameTooltip_SetDefaultAnchor post-hook: the main tooltip's
--              default spot becomes ModeUI's Tooltip anchor (an Edit Mode
--              element), grown from Anchor Point, or the cursor. Blizzard's
--              own placement (its Edit Mode HUD Tooltip) no longer applies;
--              ModeUI never moves Blizzard's container.
--   Combat     Hide in Combat hides the main tooltip as it shows while in
--              combat (Shift shows it), and when combat starts.
-- GameTooltip isn't protected: SetPoint, SetOwner and Hide are plain calls,
-- in combat too. Nothing is written to Blizzard's tables, and no tooltip
-- size, text or unit value is measured or compared (they can be secret).
local Events, L, Kit, Skin = addon.Events, addon.L, addon.Kit, addon.Skin
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:OnInitialize()
    self.Initialize(self.db)
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

function M:Tooltips()
    local list = {}
    for _, name in ipairs(self.TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip and tooltip.GetObjectType then list[#list + 1] = tooltip end
    end
    return list
end

function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("tooltip")
    self:BuildMover()
    self:InstallHooks()
    Events:On(self, "PLAYER_REGEN_DISABLED", function() self:CombatStarted() end)
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do Events:On(self, event, function() self:Refresh() end) end
    self:Refresh()
end

-- Blizzard's look comes back with a reload; placement and combat hiding stop now.
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    if self.skinned then addon.ReloadManager:Request("tooltip", L["Tooltip: reload to give tooltips back their Blizzard look."]) end
    if self.mover then self.mover:Hide() end
end

-- Post-hooks and scripts, installed once; each does nothing while off.
function M:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true
    for _, tooltip in ipairs(self:Tooltips()) do
        tooltip:HookScript("OnShow", function(shown) self:OnTooltipShow(shown) end)
    end
    if hooksecurefunc and GameTooltip_SetDefaultAnchor then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent) self:Place(tooltip, parent) end)
    end
    -- Data tooltips (units, items, spells...): fonts, size and colors
    -- before Blizzard shows them, so the size it measures is the Mode
    -- face's. Unit tooltips are filled again every few frames; this runs
    -- each time.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        local all = TooltipDataProcessor.AllTypes
        if all ~= nil then
            pcall(TooltipDataProcessor.AddTooltipPostCall, all, function(tooltip, data)
                if self.active and self.skinnedTooltips and self.skinnedTooltips[tooltip] then self:Dress(tooltip, data) end
            end)
        end
    end
end

function M:Refresh()
    if not self.active then return end
    self.skinned = true
    self.skinnedTooltips = self.skinnedTooltips or setmetatable({}, { __mode = "k" })
    for _, tooltip in ipairs(self:Tooltips()) do
        self.skinnedTooltips[tooltip] = true
        self:Skin(tooltip)
        self:Dress(tooltip)
    end
    self:PlaceMover()
    if self.page then self.page:Refresh() end
end

-- Fonts, size and text colors; answers whether the fonts changed.
function M:Dress(tooltip, data)
    local changed = self:ApplyFonts(tooltip)
    self:ApplySize(tooltip)
    self:ColorLines(tooltip, data)
    return changed
end

-- A tooltip showing: its border color, its fonts, size and colors (sized
-- again if the fonts changed), and the combat check for the main tooltip.
function M:OnTooltipShow(tooltip)
    if not self.active or self.resizing then return end
    if tooltip == GameTooltip and self:HiddenByCombat() then tooltip:Hide(); return end
    self:Paint(tooltip, self:ContentColor(tooltip))
    local data = tooltip.GetPrimaryTooltipData and select(2, pcall(tooltip.GetPrimaryTooltipData, tooltip)) or nil
    if self:Dress(tooltip, type(data) == "table" and data or nil) then
        -- Show again so the tooltip measures its lines in the new face (an
        -- already shown frame doesn't run OnShow again).
        self.resizing = true
        tooltip:Show()
        self.resizing = false
    end
end

-- Hide in Combat: in combat, unless Shift is held (with Shift Shows It).
function M:HiddenByCombat()
    if not self.db.hideInCombat or not addon.InCombat() then return false end
    if self.db.shiftShows and IsShiftKeyDown and IsShiftKeyDown() then return false end
    return true
end
function M:CombatStarted()
    if self.db.hideInCombat and GameTooltip and GameTooltip:IsShown() and not (self.db.shiftShows and IsShiftKeyDown and IsShiftKeyDown()) then
        GameTooltip:Hide()
    end
end

-- Placement ------------------------------------------------------------------

-- The main tooltip's default spot: the anchor, or the cursor.
function M:Place(tooltip, parent)
    if not self.active or tooltip ~= GameTooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if self.db.position == "cursor" then
        tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
        return
    end
    local mover = self.mover
    if not mover then return end
    local point = self.db.anchorPoint
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, mover, point, 0, 0)
end

-- The Edit Mode stand-in: a plain frame the Position Manager moves. The
-- tooltip hangs from its Anchor Point.
function M:BuildMover()
    if self.mover then return end
    local mover = CreateFrame("Frame", "ModeUITooltipMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(self.MOVER_WIDTH, self.MOVER_HEIGHT)
    mover.parts = Skin.Panel(mover, "BACKGROUND", -8)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("CENTER")
    mover:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", self.DEFAULT_POSITION.x, self.DEFAULT_POSITION.y)
    self.mover = mover
    local ok, reason = addon.PositionManager:RegisterElement(self.ELEMENT_ID, mover, { moduleId = self.id,
        defaultPosition = self.DEFAULT_POSITION, label = L["Tooltip"], anyTarget = true,
        canDrag = function() return self.active == true and self.db.position == "anchor" end })
    assert(ok, "ModeUI: tooltip position registration failed: " .. tostring(reason))
    mover:Hide()
end

function M:PlaceMover()
    local mover = self.mover
    if not mover then return end
    local px = Kit.PixelSize(mover)
    Skin.PaintPanel(mover.parts, mover, self.db.backgroundColor, 0.85, Kit.palette.accent, px)
    Skin.Font(mover.label, Kit.FontPath(self.db, self.id), self.db.textSize, false, true, px)
    mover.label:SetText(L["Tooltip"])
    mover.label:SetTextColor(1, 1, 1, 1)
end

-- In ModeUI's Edit Mode the anchor shows (while the tooltip uses it).
function M:SetEditMode(enabled)
    local show = enabled and self.active and self.db.position == "anchor" or false
    self.editing = show
    if not self.mover then return end
    addon.PositionManager:SetEditable(self.ELEMENT_ID, show)
    self.mover:SetShown(show)
end

-- Settings --------------------------------------------------------------------

function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = candidate[key]
    if key == "position" and self.editing ~= nil then self:SetEditMode(addon.editMode) end
    self:Refresh()
    if self.page then self.page:Layout() end
    return true
end

function M:ResetToDefaults()
    for key, value in pairs(self.defaults) do self.db[key] = Copy(value) end
    self:Refresh()
    return true
end

function M:AppearanceOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return true end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

function M:Status()
    if not self.active then return L["Off. Turn the module on to restyle and place tooltips."] end
    local where = self.db.position == "cursor" and L["at the cursor"] or L["at its Edit Mode anchor"]
    return string.format(L["On. The tooltip shows %s%s."], where,
        self.db.hideInCombat and L[", hidden in combat"] or "")
end
