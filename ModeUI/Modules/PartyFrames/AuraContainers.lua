local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Auras in the world through Blizzard's custom aura containers (12.1,
-- Blizzard_AuraContainer, shipped on Forever): the game reads auras in secure
-- code, so groups keep working while auras are secret (combat, encounters).
-- One container per member and group, with one container group per filter
-- (Big and External continue in one row). Buttons are styled once as they're
-- made (initializeFrame): the Mode rim colored by dispel type
-- (AddDispelTypeTexture), the cropped icon, swipe, time text and stack count.
-- A change to how buttons look builds a new container; filters, counts,
-- layout and place change through its setters.
--
-- The dispel highlight is an aura slot on its own container: the slot's one
-- button covers the bars and holds the ModeUI border shape (or a tint), which
-- the game colors by the dispellable debuff's type and shows only while there
-- is one. See docs/PARTY_FRAMES.md and docs/API_COMPATIBILITY.md.
local Kit = addon.Kit
local TEMPLATE = Kit.AURA_CONTAINER_TEMPLATE
local FLOW, AXIS = Kit.AURA_FLOW, Kit.AURA_AXIS

function M:UsesContainers(f) return not f.ghost and Kit.HasAuraContainers() end

local function ColorOf(db) return function(name)
    local key = M.dispelColorKeys[name]
    return key and db[key] or db.auraNoTypeColor
end end
local function Hex(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
local function ColorsKey(db)
    local parts = {}
    for _, key in ipairs({ "auraMagicColor", "auraCurseColor", "auraDiseaseColor", "auraPoisonColor", "auraBleedColor",
        "auraNoTypeColor", "auraTimerColor" }) do parts[#parts + 1] = Hex(db[key]) end
    return table.concat(parts, "|")
end

-- Everything a group's buttons bake in when they're made.
local function LookKey(self, adb, f, width, height)
    local db, g = self.db, f.geometry
    return table.concat({ adb.shape, adb.border, tostring(adb.timer), tostring(adb.timerText), tostring(adb.count),
        tostring(adb.tooltip), width, height, g.px, f.fontPath or "", tostring(db.outline), tostring(db.shadow),
        tostring(db.liftedShadow), tostring(db.slug), ColorsKey(db) }, "|")
end

local function Initializer(self, adb, width, height, px, path)
    local db = self.db
    local style = self:AuraStyle(adb)
    local colors = adb.border == "type" and Kit.AuraDispelColors(ColorOf(db)) or nil
    local formatter = Kit.AuraTimeFormatter()
    local tooltip = adb.tooltip
    return function(button)
        Kit.AuraIconParts(button)
        Kit.LayoutAuraIcon(button, width, height, px, style, path)
        Kit.TintAuraRim(button, Kit.BORDER_COLOR)
        button:SetIcon(button.icon)
        if adb.timer then button:SetDurationCooldown(button.cooldown) else button.cooldown:Hide() end
        -- Game-filled text can't drive the lifted copies.
        button.timer.lift:Hide(); button.count.lift:Hide()
        if adb.timerText then button:SetDurationText(button.timer, formatter and { textFormatter = formatter } or nil)
        else button.timer:Hide() end
        if adb.count then button:SetApplicationCount(button.count) else button.count:Hide() end
        if colors then button:AddDispelTypeTexture(button.rim, Kit.AuraDispelOptions(colors)) end
        -- Tooltips on hover only; clicks fall through to the member.
        if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
        if not tooltip and button.EnableMouse then pcall(button.EnableMouse, button, false) end
    end
end

local function Layout(adb, width, height, px)
    local spacing = adb.spacing * px
    return { elementSpacing = spacing, lineSpacing = spacing, groupSpacing = spacing, elementWidth = width, elementHeight = height }
end

-- Makes (or keeps) a member's container for one group.
local function Container(self, f, group, adb, width, height)
    local key = LookKey(self, adb, f, width, height)
    local current = f.auraContainers[group]
    if current and current.lookKey == key then return current end
    if current then current:SetEnabled(false); current:Hide(); f.auraContainers[group] = nil end
    local filters = self:GroupFilters(group, adb.filter)
    -- A container the client refuses (a filter it doesn't know) leaves the
    -- group empty instead of stopping the module.
    local ok, container = pcall(function()
        local made = CreateFrame("AuraContainer", nil, f.auraLayer, TEMPLATE)
        made:SetSize(1, 1)
        for i = 1, 2 do
            made:AddAuraGroup(group .. i, filters[i] or filters[1], { maxFrameCount = adb.max,
                layout = Layout(adb, width, height, f.geometry.px),
                initializeFrame = Initializer(self, adb, width, height, f.geometry.px, f.fontPath) })
        end
        return made
    end)
    if not ok then return nil end
    container.lookKey = key
    container:SetEnabled(false)
    f.auraContainers[group] = container
    return container
end

local function Place(self, f, container, adb, width, height)
    local corner, point, x, y, across, dx, dy = self:AuraPlacement(f, adb, width, height)
    local px, spacing = f.geometry.px, adb.spacing * f.geometry.px
    container:ClearAllPoints()
    container:SetPoint(corner, f.panel, point, x, y)
    container:SetFlowLayoutAnchorPoint(corner)
    container:SetFlowLayoutAxis(across and AXIS.Horizontal or AXIS.Vertical)
    container:SetFlowLayoutGrowthDirection(dx < 0 and FLOW.Left or FLOW.Right, dy > 0 and FLOW.Up or FLOW.Down)
    -- Per Row: a line holds that many icons, then the next line starts.
    local line = adb.perRow * ((across and width or height) + spacing) - spacing
    if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(math.max(px, line)) end
end

-- The dispel highlight slot: the bars' border shape (or a tint) on the
-- slot's button, colored by the debuff's type by the game.
local function DispelKey(self, f)
    local db, g = self.db, f.geometry
    return table.concat({ db.dispelHighlight, db.dispelFilter, g.width, g.height, g.px, ColorsKey(db) }, "|")
end
local function DispelInitializer(self, f)
    local db, g = self.db, f.geometry
    local style = db.dispelHighlight
    local depth, both = Kit.CapDepth(g.height, g.px), { LEFT = true, RIGHT = true }
    return function(button)
        button:ClearAllPoints(); button:SetAllPoints(f.panel)
        button:SetFrameLevel(f.glowLayer:GetFrameLevel() + 1)
        if button.EnableMouse then pcall(button.EnableMouse, button, false) end
        local regions = {}
        if style == "border" then
            local ring = Kit.CapRing(button, 3)
            Kit.PlaceCapRing(ring, button, 0, g.border, Kit.BORDER_COLOR, depth, both)
            regions = { ring.top, ring.bottom, ring.ends.LEFT.cap, ring.ends.RIGHT.cap }
        else
            local fill = button:CreateTexture(nil, "ARTWORK")
            fill:SetTexture(Kit.FLAT); Kit.Inset(fill, button, g.border)
            local masks = { Kit.EndMask(button), Kit.EndMask(button) }
            Kit.PlaceEndMask(masks[1], button, "LEFT", depth, g.border, true)
            Kit.PlaceEndMask(masks[2], button, "RIGHT", depth, g.border, true)
            Kit.AddMasks({ fill }, masks)
            regions = { fill }
        end
        local options = Kit.AuraDispelOptions(Kit.AuraDispelColors(ColorOf(db), style == "fill" and 0.25 or 1))
        for _, region in ipairs(regions) do button:AddDispelTypeTexture(region, options) end
        button.dispelRegions = regions
    end
end

local function DispelSlot(self, f)
    local db = self.db
    local current = f.dispelContainer
    if db.dispelHighlight == "none" then
        if current then current:SetEnabled(false); current:Hide() end
        return nil
    end
    local key = DispelKey(self, f)
    if current and current.lookKey == key then return current end
    if current then current:SetEnabled(false); current:Hide(); f.dispelContainer = nil end
    local filter = self:GroupFilters("dispellable", db.dispelFilter)[1]
    local ok, container = pcall(function()
        local made = CreateFrame("AuraContainer", nil, f.glowLayer, TEMPLATE)
        made:SetSize(1, 1); made:SetPoint("CENTER", f.panel, "CENTER", 0, 0)
        made:AddAuraSlot("dispel", filter, { initializeFrame = DispelInitializer(self, f) })
        return made
    end)
    if not ok then return nil end
    container.lookKey = key
    f.dispelContainer = container
    return container
end

-- One group's container: its filters, count, layout and place, pointed at the unit.
local function AttachGroup(self, f, group, unit)
    local adb = self.db.auras[group]
    local width, height = self:AuraSize(adb, f.geometry.px)
    local container = Container(self, f, group, adb, width, height)
    if not container then return end
    local filters = self:GroupFilters(group, adb.filter)
    for i = 1, 2 do
        local on = adb.show and filters[i] ~= nil
        if on then
            container:SetAuraGroupFilterString(group .. i, filters[i])
            container:SetAuraGroupMaxFrameCount(group .. i, adb.max)
            container:SetAuraGroupLayout(group .. i, Layout(adb, width, height, f.geometry.px))
        end
        container:SetAuraGroupEnabled(group .. i, on)
    end
    Place(self, f, container, adb, width, height)
    if unit and adb.show then
        container:SetEnabled(true); container:SetUnit(unit); container:Show(); container:UpdateAllAuras()
    else container:SetEnabled(false); container:Hide() end
end

-- Builds, configures and places every container and points them at the
-- member's unit; called when the unit or the settings change.
function M:AttachAuras(f)
    if not self:UsesContainers(f) or not f.geometry then return end
    local unit = self.active and f.unit or nil
    for _, group in ipairs(self.auraGroups) do AttachGroup(self, f, group, unit) end
    self:PaintDispel(f, nil)
    local slot = DispelSlot(self, f)
    if slot then
        if unit then slot:SetEnabled(true); slot:SetUnit(unit); slot:Show(); slot:UpdateAllAuras()
        else slot:SetEnabled(false); slot:Hide() end
    end
end
