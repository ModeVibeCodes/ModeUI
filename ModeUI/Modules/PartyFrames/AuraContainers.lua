local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Auras in the world through Blizzard's custom aura containers (12.1,
-- Blizzard_AuraContainer, shipped on Forever): the game reads auras in secure
-- code, so groups keep working while auras are secret (combat, encounters).
-- One container per member and anchor holds every group on that anchor and
-- place, in group order, so they continue as one row; each group is one
-- container group per filter (Big and External continue in one row). Debuff
-- groups keep their dispel type through candidateFilters (includeDispelTypes;
-- Other Debuffs: excludeDispelTypes). Buttons are styled once as they're made
-- (initializeFrame): rim by type or a fixed color (AddDispelTypeTexture), the
-- icon, swipe, time text, stack count and the glow. A change to how buttons
-- look builds a new container; filters, counts and layout change through its
-- setters. The debuff effects are in Dispel.lua. See docs/PARTY_FRAMES.md.
local Kit = addon.Kit
local TEMPLATE = Kit.AURA_CONTAINER_TEMPLATE
local FLOW, AXIS = Kit.AURA_FLOW, Kit.AURA_AXIS

function M:UsesContainers(f) return not f.ghost and Kit.HasAuraContainers() end

local function Hex(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
local function ColorsKey(db)
    local parts = {}
    for _, key in ipairs({ "auraMagicColor", "auraCurseColor", "auraDiseaseColor", "auraPoisonColor", "auraBleedColor",
        "auraNoTypeColor", "auraTimerColor" }) do parts[#parts + 1] = Hex(db[key]) end
    return table.concat(parts, "|")
end
local function ColorOf(self) return function(name) return self:TypeColor(name) end end

-- Everything a group's buttons bake in when they're made.
local function GroupKey(self, group, f)
    local adb = self.db.auras[group]
    local width, height = self:AuraSize(adb, f.geometry.px)
    return table.concat({ group, adb.border, adb.borderSize, Hex(adb.borderColor), adb.glow, adb.glowColor, Hex(adb.glowCustomColor),
        tostring(adb.timer), tostring(adb.timerText), tostring(adb.count), tostring(adb.tooltip), width, height }, ",")
end
local function LookKey(self, groups, f)
    local db = self.db
    local parts = { f.geometry.px, f.fontPath or "", tostring(db.outline), tostring(db.shadow), tostring(db.liftedShadow),
        tostring(db.slug), ColorsKey(db) }
    for _, group in ipairs(groups) do parts[#parts + 1] = GroupKey(self, group, f) end
    return table.concat(parts, "|")
end

local function Initializer(self, group, width, height, px, path)
    local adb = self.db.auras[group]
    local style = self:AuraStyle(adb)
    local typed = adb.border == "type" and Kit.AuraDispelOptions(Kit.AuraDispelColors(ColorOf(self))) or nil
    local formatter = Kit.AuraTimeFormatter()
    return function(button)
        Kit.AuraIconParts(button)
        Kit.LayoutAuraIcon(button, width, height, px, style, path)
        local rim = self:AuraRimColor(adb, nil)
        button.rim:SetShown(rim ~= nil)
        if rim then Kit.TintAuraRim(button, rim) end
        button:SetIcon(button.icon)
        if adb.timer then button:SetDurationCooldown(button.cooldown) else button.cooldown:Hide() end
        -- Game-filled text can't drive the lifted copies.
        button.timer.lift:Hide(); button.count.lift:Hide()
        if adb.timerText then button:SetDurationText(button.timer, formatter and { textFormatter = formatter } or nil)
        else button.timer:Hide() end
        if adb.count then button:SetApplicationCount(button.count) else button.count:Hide() end
        if typed then button:AddDispelTypeTexture(button.rim, typed) end
        -- The glow: by type through the game's dispel colors, or a fixed color.
        if adb.glow ~= "none" then
            local gcd = adb.glow == "gcd"
            local region, alpha = gcd and button.flash or button.glow, gcd and Kit.AURA_FLASH_ALPHA or Kit.AURA_GLOW_ALPHA
            if adb.glowColor == "type" then
                region:Show()
                if gcd and button.flashAnim then button.flashAnim:Play() end
                button:AddDispelTypeTexture(region, Kit.AuraDispelOptions(Kit.AuraDispelColors(ColorOf(self), alpha)))
            else Kit.GlowAura(button, adb.glowCustomColor, adb.glow) end
        end
        -- Tooltips on hover only; clicks fall through to the member.
        if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
        if not adb.tooltip and button.EnableMouse then pcall(button.EnableMouse, button, false) end
    end
end

local function Layout(adb, width, height, px)
    local spacing = adb.spacing * px
    return { elementSpacing = spacing, lineSpacing = spacing, groupSpacing = spacing, elementWidth = width, elementHeight = height }
end

-- The candidate filters that keep a group to its dispel type.
local OTHER = {}
for _, kind in ipairs(M.dispelTypes) do OTHER[kind] = true end
function M:CandidateFilters(group)
    local kind = self.groupDispelType[group]
    if kind then return { includeDispelTypes = { [kind] = true } } end
    if group == "otherDebuffs" then return { excludeDispelTypes = OTHER } end
end

-- Makes (or keeps) a member's container for one anchor and its groups.
local function Container(self, f, key, groups)
    local look = LookKey(self, groups, f)
    local current = f.auraContainers[key]
    if current and current.lookKey == look then return current end
    if current then current:SetEnabled(false); current:Hide(); f.auraContainers[key] = nil end
    local px = f.geometry.px
    -- A container the client refuses (a filter it doesn't know) leaves its
    -- groups empty instead of stopping the module.
    local ok, container = pcall(function()
        local made = CreateFrame("AuraContainer", nil, f.auraLayer, TEMPLATE)
        made:SetSize(1, 1)
        for _, group in ipairs(groups) do
            local adb = self.db.auras[group]
            local width, height = self:AuraSize(adb, px)
            local filters = self:GroupFilters(group, adb.filter)
            for i = 1, 2 do
                made:AddAuraGroup(group .. i, filters[i] or filters[1], { maxFrameCount = adb.max,
                    layout = Layout(adb, width, height, px), candidateFilters = self:CandidateFilters(group),
                    initializeFrame = Initializer(self, group, width, height, px, f.fontPath) })
            end
        end
        return made
    end)
    if not ok then return nil end
    container.lookKey = look
    f.auraContainers[key] = container
    return container
end

local function Place(self, f, container, adb)
    local width, height = self:AuraSize(adb, f.geometry.px)
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

-- Builds, configures and places every container and points them at the
-- member's unit; called when the unit or the settings change.
function M:AttachAuras(f)
    if not self:UsesContainers(f) or not f.geometry then return end
    local unit = self.active and f.unit or nil
    local buckets, order, lead = self:AuraBuckets()
    local used = {}
    for _, key in ipairs(order) do
        local groups = buckets[key]
        local container = Container(self, f, key, groups)
        used[key] = true
        if container then
            local any = false
            for _, group in ipairs(groups) do
                local adb = self.db.auras[group]
                local width, height = self:AuraSize(adb, f.geometry.px)
                local filters = self:GroupFilters(group, adb.filter)
                for i = 1, 2 do
                    local on = adb.show and filters[i] ~= nil
                    if on then
                        container:SetAuraGroupFilterString(group .. i, filters[i])
                        container:SetAuraGroupMaxFrameCount(group .. i, adb.max)
                        container:SetAuraGroupLayout(group .. i, Layout(adb, width, height, f.geometry.px))
                    end
                    container:SetAuraGroupEnabled(group .. i, on)
                    any = any or on
                end
            end
            Place(self, f, container, self.db.auras[lead[key]])
            if unit and any then
                container:SetEnabled(true); container:SetUnit(unit); container:Show(); container:UpdateAllAuras()
            else container:SetEnabled(false); container:Hide() end
        end
    end
    for key, container in pairs(f.auraContainers) do
        if not used[key] then container:SetEnabled(false); container:Hide() end
    end
    self:PaintDispel(f, nil)
    self:AttachDispel(f, unit)
end
