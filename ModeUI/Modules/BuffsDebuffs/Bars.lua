local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Each bar is one of Blizzard's custom aura containers on the player
-- (Blizzard_AuraContainer; docs/API_COMPATIBILITY.md): the game reads the
-- auras in secure code, so bars keep working while auras are secret. One aura
-- group per kind the bar shows, in M.categories order; each group's filter
-- leaves out the kinds before it, so an aura shows once. Weapon enchants are
-- the container's item enchantments. Buttons are styled once as they're made
-- (initializeFrame): the Mode icon (Kit.AuraIconParts) on a child frame with
-- room under it for time text, the Mode-Blizz edge, rim by debuff type, glow,
-- swipe, stacks, tooltip and right-click cancel. A change to how buttons look
-- builds a new container; filters, counts, sorting and layout change in place.
local Kit, Style = addon.Kit, addon.Style
local TEMPLATE = Kit.AURA_CONTAINER_TEMPLATE
local FLOW, AXIS = Kit.AURA_FLOW, Kit.AURA_AXIS

-- The game's sort for each choice (AuraContainerSortMethod, exported by
-- Blizzard_AuraContainerShared.lua).
local function SortMethod(choice)
    local methods = AuraContainerSortMethod
    if not methods then return nil end
    if choice == "time" then return methods.Expiration end
    if choice == "name" then return methods.Name end
    return methods.Default
end

-- The blacklist as the game's spell set.
function M:BlacklistSet()
    if #self.db.blacklist == 0 then return nil end
    local set = {}
    for _, id in ipairs(self.db.blacklist) do set[id] = true end
    return set
end

-- The aura groups a bar shows: { key, filter, candidates }, in order. All
-- stands alone; a token kind leaves out the tokens before it. Boss Debuffs
-- can't be left out of later kinds (isBossAura = false would also drop auras
-- whose field the game leaves unset), so a boss debuff with a type can show
-- under both.
function M:Groups(id)
    local bar = self.db.bars[id]
    local base = bar.kind == "buffs" and "HELPFUL" or "HARMFUL"
    local blacklist = self:BlacklistSet()
    local groups, before = {}, {}
    for _, category in ipairs(self.categories[bar.kind]) do
        if bar.cats[category.id] and not category.enchant and (category.all or not bar.cats.all) then
            local filter = base
            if category.token then filter = filter .. "|" .. category.token end
            for _, token in ipairs(before) do filter = filter .. "|!" .. token end
            local candidates = {}
            if category.dispel then candidates.includeDispelTypes = { [category.dispel] = true } end
            if category.other then
                candidates.excludeDispelTypes = {}
                for _, kind in ipairs(self.DISPEL_TYPES) do candidates.excludeDispelTypes[kind] = true end
            end
            if category.boss then candidates.isBossAura = true end
            if category.maxDuration then candidates.maxDuration = category.maxDuration end
            candidates.excludeSpellIDs = blacklist
            groups[#groups + 1] = { key = id .. "_" .. category.id, filter = filter, candidates = next(candidates) and candidates or nil }
            if category.token then before[#before + 1] = category.token end
        end
    end
    return groups
end

-- The text style the icons use (Kit.Font's style table).
function M:TextStyle(bar)
    local db = self.db
    return setmetatable({ auraTimerText = bar.timer == "center", auraBorderSize = bar.borderSize,
        auraTimerColor = db.timerColor }, { __index = db })
end

local function Hex(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
-- Everything a bar's buttons bake in when they're made.
function M:LookKey(id, px)
    local bar, db = self.db.bars[id], self.db
    return table.concat({ bar.kind, bar.width, bar.timer, tostring(bar.swipe), tostring(bar.count), tostring(bar.tooltip),
        tostring(bar.cancel), bar.edgeStyle, bar.edgeMetal, bar.borderSize, tostring(bar.byType), bar.glow, bar.glowColor,
        Hex(bar.glowCustomColor), tostring(bar.cats.enchant), px, db.fontMedia, db.font, tostring(db.outline),
        tostring(db.shadow), Hex(db.textColor), Hex(db.timerColor) }, "|")
end

local function Metal(bar) return bar.edgeMetal ~= "default" and bar.edgeMetal or nil end
local function TypeColor(name)
    if name == "none" then return Style.Tone.metal.gunmetal.mid end
    return Style.Tone.debuffType[name] or Style.Tone.metal.gunmetal.mid
end

-- Lays one icon (a Kit.AuraIconParts frame) out in the bar's look.
function M:LayoutIcon(icon, bar, px)
    local width, height = self:IconSize(bar, px)
    local path = Kit.FontPath(self.db, self.id)
    Kit.LayoutAuraIcon(icon, width, height, px, self:TextStyle(bar), path)
    Kit.AuraBorderStyle(icon, bar.edgeStyle, Metal(bar))
    icon.cooldown:SetShown(bar.swipe)
    icon.count:SetShown(bar.count)
    return width, height, path
end
-- Time text under the icon, centered, in the Mode face.
function M:LayoutBelow(text, bar, px, path, icon)
    Kit.Font(text, self:TextStyle(bar), 10, Style.Weighted(path, "bold"), px)
    text:ClearAllPoints()
    text:SetPoint("TOP", icon, "BOTTOM", 0, -2 * px)
    text:SetJustifyH("CENTER")
end

local function Initializer(self, id, px)
    local bar = self.db.bars[id]
    local typed = bar.byType and Kit.AuraDispelOptions(Kit.AuraDispelColors(TypeColor)) or nil
    local formatter = Kit.AuraTimeFormatter(true)
    local cancel = bar.kind == "buffs" and bar.cancel
    local cellWidth, cellHeight = self:CellSize(bar, px)
    return function(button)
        -- The button is the cell: the icon at its top, time text under it.
        button:SetSize(cellWidth, cellHeight)
        local icon = CreateFrame("Frame", nil, button)
        Kit.AuraIconParts(icon)
        local _, _, path = self:LayoutIcon(icon, bar, px)
        icon:SetPoint("TOP", button, "TOP", 0, 0)
        icon:Show()
        button.modeIcon = icon
        button:SetIcon(icon.icon)
        if bar.swipe then button:SetDurationCooldown(icon.cooldown) end
        -- Game-filled text can't drive the lifted copies.
        icon.timer.lift:Hide(); icon.count.lift:Hide()
        if bar.count then button:SetApplicationCount(icon.count) end
        local options = formatter and { textFormatter = formatter } or nil
        if bar.timer == "center" then button:SetDurationText(icon.timer, options)
        elseif bar.timer == "below" then
            local below = Kit.Text(button)
            self:LayoutBelow(below, bar, px, path, icon)
            button.modeBelow = below
            button:SetDurationText(below, options)
        end
        if typed then Kit.DispelAuraRim(button, typed, nil, icon) end
        -- The glow: by debuff type through the game's colors, or a fixed color.
        if bar.glow ~= "none" then
            local gcd = bar.glow == "gcd"
            if bar.glowColor == "type" and bar.kind == "debuffs" then
                local region, alpha = gcd and icon.flash or icon.glow, gcd and Kit.AURA_FLASH_ALPHA or Kit.AURA_GLOW_ALPHA
                region:Show()
                if gcd and icon.flashAnim then icon.flashAnim:Play() end
                button:AddDispelTypeTexture(region, Kit.AuraDispelOptions(Kit.AuraDispelColors(TypeColor, alpha)))
            else Kit.GlowAura(icon, bar.glowCustomColor, bar.glow) end
        end
        if button.SetTooltipAnchorPoint then pcall(button.SetTooltipAnchorPoint, button, "ANCHOR_BOTTOMLEFT") end
        -- A right-click cancels a buff (the game's own cancel, on the click
        -- the game's Cast on Key Down setting picks).
        if cancel and button.SetCancelAuraButtons then
            local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
            pcall(button.SetCancelAuraButtons, button, down and "RightButtonDown" or "RightButtonUp")
        elseif button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
        if not bar.tooltip and not cancel and button.EnableMouse then pcall(button.EnableMouse, button, false) end
    end
end

local function Layout(self, bar, px)
    local width, height = self:CellSize(bar, px)
    local spacing = bar.spacing * px
    return { elementSpacing = spacing, lineSpacing = spacing, groupSpacing = spacing, groupLineSpacing = spacing,
        elementWidth = width, elementHeight = height }
end

-- Makes (or keeps) a bar's container, with one group per kind it shows (the
-- game makes ten buttons per group up front, so kinds a bar doesn't show get
-- none). Picking other kinds builds a new container.
local function Container(self, id, px)
    local groups = self:Groups(id)
    local keys = {}
    for _, group in ipairs(groups) do keys[#keys + 1] = group.key end
    local look = self:LookKey(id, px) .. "|" .. table.concat(keys, ",")
    local current = self.containers[id]
    if current and current.lookKey == look then return current end
    if current then current:SetEnabled(false); current:Hide(); self.containers[id] = nil end
    local bar = self.db.bars[id]
    local ok, container = pcall(function()
        local made = CreateFrame("AuraContainer", nil, self.holders[id], TEMPLATE)
        made:SetSize(1, 1)
        made.groupKeys = keys
        local init = Initializer(self, id, px)
        for _, group in ipairs(groups) do
            made:AddAuraGroup(group.key, group.filter, { maxFrameCount = bar.max, layout = Layout(self, bar, px),
                candidateFilters = group.candidates, initializeFrame = init })
        end
        if bar.cats.enchant and made.AddItemEnchantment and AuraContainerItemEnchantmentSlot then
            for _, slot in ipairs({ "MainHand", "OffHand" }) do
                made:AddItemEnchantment(AuraContainerItemEnchantmentSlot[slot], { initializeFrame = init })
            end
            made.enchants = true
        end
        return made
    end)
    if not ok then return nil end
    container.lookKey = look
    container.blacklistKey = table.concat(self.db.blacklist, ",")
    self.containers[id] = container
    return container
end

-- Points a container's groups at what the bar shows now.
local function Configure(self, id, container, px)
    local bar = self.db.bars[id]
    local wanted = {}
    for _, group in ipairs(self:Groups(id)) do wanted[group.key] = group end
    local sort, direction = SortMethod(bar.sort), AuraContainerSortDirection and AuraContainerSortDirection.Normal
    -- Candidate filters make the game read every aura again, so they're only
    -- sent when the blacklist changed.
    local blacklist = table.concat(self.db.blacklist, ",")
    local candidates = container.blacklistKey ~= blacklist
    container.blacklistKey = blacklist
    for _, key in ipairs(container.groupKeys) do
        local group = wanted[key]
        if group then
            pcall(container.SetAuraGroupFilterString, container, key, group.filter)
            container:SetAuraGroupMaxFrameCount(key, bar.max)
            container:SetAuraGroupLayout(key, Layout(self, bar, px))
            if candidates and container.SetAuraGroupCandidateFilters then
                pcall(container.SetAuraGroupCandidateFilters, container, key, group.candidates)
            end
            if sort and container.SetAuraGroupSortMethod then pcall(container.SetAuraGroupSortMethod, container, key, sort, direction) end
        end
        container:SetAuraGroupEnabled(key, group ~= nil)
    end
    if container.enchants and container.SetItemEnchantmentLayout then
        local layout = Layout(self, bar, px)
        layout.placement = CustomAuraContainerItemEnchantmentPlacement and CustomAuraContainerItemEnchantmentPlacement.AfterAuraGroups
        pcall(container.SetItemEnchantmentLayout, container, layout)
    end
end

-- The flow: from the start corner, the way the icons grow, rows across.
local function Place(self, id, container, px)
    local bar = self.db.bars[id]
    local corner = self:StartCorner(bar)
    container:ClearAllPoints()
    container:SetPoint(corner, self.holders[id], corner, 0, 0)
    container:SetFlowLayoutAnchorPoint(corner)
    local horizontal = self.HORIZONTAL[bar.grow]
    container:SetFlowLayoutAxis(horizontal and AXIS.Horizontal or AXIS.Vertical)
    local h = (horizontal and bar.grow or bar.wrap) == "left" and FLOW.Left or FLOW.Right
    local v = (horizontal and bar.wrap or bar.grow) == "up" and FLOW.Up or FLOW.Down
    container:SetFlowLayoutGrowthDirection(h, v)
    local cw, ch = self:CellSize(bar, px)
    local line = bar.perRow * ((horizontal and cw or ch) + bar.spacing * px) - bar.spacing * px
    if container.SetFlowLayoutMaximumLineSize then container:SetFlowLayoutMaximumLineSize(math.max(px, line)) end
end

-- Builds, configures and shows (or hides) one bar.
function M:ApplyBar(id)
    local holder = self.holders[id]
    if not holder then return end
    local bar = self.db.bars[id]
    local on = self.active == true and bar.show and not self.editing and Kit.HasAuraContainers()
    holder:SetShown(self.active == true and bar.show)
    local container = self.containers[id]
    if not on then
        if container then container:SetEnabled(false); container:Hide() end
        return
    end
    local px = Kit.PixelSize(holder)
    container = Container(self, id, px)
    if not container then return end
    Configure(self, id, container, px)
    Place(self, id, container, px)
    container:SetEnabled(true); container:SetUnit("player"); container:Show()
    container:UpdateAllAuras()
end
