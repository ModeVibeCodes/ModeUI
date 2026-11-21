local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The secure group header (SecureGroupHeaderTemplate, Forever's
-- Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua): it lists you
-- and your party, sorts them, gives each button its unit and shows, hides and
-- places the buttons itself, in combat too. ModeUI only sets its attributes,
-- outside combat. All five buttons are made up front (the startingIndex trick
-- other group frames use), so none is ever created in combat, and each gets
-- its face then. The header is anchored to UIParent at the edge the group
-- grows from, copied from a plain stand-in that Edit Mode moves
-- (Position Manager refuses protected frames), so it never shifts as members
-- join or leave.
local Kit = addon.Kit
M.HEADER_NAME = "ModeUIPartyHeader"
-- Click to target, right-click for the unit menu; set in the restricted
-- environment when the header makes a button.
M.INITIAL_CONFIG = [[
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    self:GetParent():CallMethod("InitializeMember", self:GetName())
]]
-- Growth direction -> the header's point and which offset carries the spacing.
M.growthPoints = { down = { "TOP", 0, -1 }, up = { "BOTTOM", 0, 1 }, right = { "LEFT", 1, 0 }, left = { "RIGHT", -1, 0 } }
M.ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"

local function Children(header)
    local list = {}
    for i = 1, M.MAX_MEMBERS do
        local child = header:GetAttribute("child" .. i) or header[i]
        if child then list[#list + 1] = child end
    end
    return list
end

-- Gives a header button its face, scripts and events, once.
function M:SetupMember(f)
    if not f or f.partyReady then return end
    -- Buttons are made up front; one made later waits for the end of combat.
    if addon.InCombat() then addon.Defer:Run("partyFrames:setup:" .. tostring(f:GetName()), function() self:SetupMember(f) end); return end
    f.partyReady, f.secure = true, true
    f:RegisterForClicks("AnyUp")
    f:SetScript("OnEnter", function(button)
        local unit = button:GetAttribute("unit")
        if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, button) end
        if unit and GameTooltip and GameTooltip.SetUnit then GameTooltip:SetUnit(unit); GameTooltip:Show() end
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self:BuildFace(f)
    self:HookHover(f)
    f.events = CreateFrame("Frame")
    f.events:SetScript("OnEvent", function(_, event, unit) self:OnMemberEvent(f, event, unit) end)
    f:HookScript("OnAttributeChanged", function(button, name, value)
        if name == "unit" then self:SetMemberUnit(button, value) end
    end)
    f:HookScript("OnShow", function(button) self:QueueMember(button) end)
    self.members[#self.members + 1] = f
    if not addon.InCombat() then self:ApplyLayout(f) end
    self:SetMemberUnit(f, f:GetAttribute("unit"))
end

function M:CreateHeader()
    if self.header or addon.InCombat() then return end
    local header = CreateFrame("Frame", self.HEADER_NAME, UIParent, "SecureGroupHeaderTemplate")
    self.header = header
    function header.InitializeMember(_, name) self:SetupMember(_G[name]) end
    header:SetFrameStrata("LOW")
    header:SetAttribute("template", "SecureUnitButtonTemplate")
    header:SetAttribute("templateType", "Button")
    header:SetAttribute("initialConfigFunction", self.INITIAL_CONFIG)
    header:SetAttribute("showParty", true)
    header:SetAttribute("showRaid", false)
    header:SetAttribute("unitsPerColumn", self.MAX_MEMBERS)
    header:SetAttribute("maxColumns", 1)
    -- UI modes (pet battles and the like) hide unit frames by this roleset,
    -- as Blizzard's own (TargetFrame.lua); protected, so outside combat.
    if header.SetRolesets then pcall(header.SetRolesets, header, "unitFrames") end
    header:SetPoint("TOP", UIParent, "CENTER", self.defaultPosition.x, self.defaultPosition.y)
    -- Make every button now: a negative starting index lists more units than
    -- the group has, so the header creates all of them; then back to normal.
    header:SetAttribute("startingIndex", 1 - self.MAX_MEMBERS)
    header:Show()
    header:SetAttribute("startingIndex", 1)
    for _, child in ipairs(Children(header)) do self:SetupMember(child) end
end

-- When the header may show: in a party (not a raid), and alone too with Show
-- When Solo. A state driver, so it follows the group in combat.
function M:VisibilityCondition()
    if self.db.showSolo then return "[group:raid] hide; show" end
    return "[group:raid] hide; [group] show; hide"
end

-- Every attribute and size, outside combat. Displayed buttons keep their old
-- points when the header re-anchors them, so they're cleared first.
function M:ConfigureHeader()
    local header, db = self.header, self.db
    if not header or addon.InCombat() then return end
    header:SetScale(db.scale / 100)
    local px = Kit.PixelSize(header)
    local spacing = math.floor(db.spacing + 0.5) * px
    local growth = self.growthPoints[db.growth]
    for _, f in ipairs(self.members) do
        f:ClearAllPoints()
        self:ApplyLayout(f)
        local g = f.geometry
        f:SetSize(g.width, g.height)
    end
    header:SetAttribute("_ignore", true)
    header:SetAttribute("showPlayer", db.showPlayer)
    header:SetAttribute("showSolo", db.showSolo)
    header:SetAttribute("point", growth[1])
    header:SetAttribute("xOffset", growth[2] * spacing)
    header:SetAttribute("yOffset", growth[3] * spacing)
    header:SetAttribute("sortMethod", "INDEX")
    header:SetAttribute("sortDir", db.reverseOrder and "DESC" or "ASC")
    if db.sortBy == "role" then
        header:SetAttribute("groupBy", "ASSIGNEDROLE")
        header:SetAttribute("groupingOrder", self.ROLE_ORDER)
    else
        header:SetAttribute("groupBy", nil)
        header:SetAttribute("groupingOrder", nil)
    end
    header:SetAttribute("_ignore", nil)
    -- Any attribute change makes a visible header list and place its buttons.
    self.headerVersion = (self.headerVersion or 0) + 1
    header:SetAttribute("modeUIVersion", self.headerVersion)
    self:SyncHeaderPosition()
end

-- Shows the header (through its state driver) while the module is on.
function M:SyncHeaderShown()
    local header = self.header
    if not header or addon.InCombat() then return end
    local condition = self.active and self:VisibilityCondition() or nil
    if condition == self.visibility then return end
    if self.visibility then UnregisterAttributeDriver(header, "state-visibility") end
    self.visibility = condition
    if condition then RegisterAttributeDriver(header, "state-visibility", condition) else header:Hide() end
end

-- The header's start edge goes where the stand-in's is, in UIParent's
-- coordinates (both have the same scale), snapped to whole pixels.
function M:SyncHeaderPosition()
    local header, ghost = self.header, self.ghost
    if not header or not ghost or addon.InCombat() then return end
    local left, bottom, width, height = ghost:GetLeft(), ghost:GetBottom(), ghost:GetWidth(), ghost:GetHeight()
    local Number = addon.IsNumber
    if not (Number(left) and Number(bottom) and Number(width) and Number(height)) then return end
    local right, top = left + width, bottom + height
    local px = Kit.PixelSize(header)
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    -- By the point the header lays its members out from (its `point`
    -- attribute: TOP for a column growing down), at the same point of the
    -- stand-in, so members joining or leaving never move the first one. Not
    -- by a corner: SecureGroupHeaders.lua centers each member on that point
    -- and sets the header's own width from child1:GetWidth() whenever it lays
    -- them out, so a header a little wider than its members moved the whole
    -- column sideways by half the difference (owner, November 20, 2026: the
    -- party column 2px right of the Player frame's right edge).
    local point = self.growthPoints[self.db.growth][1]
    local x = point:find("RIGHT") and right or point:find("LEFT") and left or (left + right) / 2
    local y = point:find("TOP") and top or point:find("BOTTOM") and bottom or (bottom + top) / 2
    header:ClearAllPoints()
    header:SetPoint(point, UIParent, "BOTTOMLEFT", Snap(x), Snap(y))
end
