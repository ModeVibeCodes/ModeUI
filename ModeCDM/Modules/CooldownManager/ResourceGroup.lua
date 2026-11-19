local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Group Resources (owner, November 17, 2026): Power, Combo Points and
-- Alternate Mana in one border, like the unit frames' bar block (health and
-- power in one edge, a 1px black line between them). Power hosts the block:
-- its stand-in is the block's Edit Mode element, and its Border, Border
-- Style, Rim Color, Width and Match Width are the block's. Each bar keeps its
-- own height, colors, texts and visibility; a bar that's off or has nothing
-- to show (combo points in Bear Form) leaves the block, which closes up.
-- Inside the block only the block has a height floor, so 4-6px strips work.
-- Health never joins. With Power off the bars stand apart again.
local Kit, Style, Tone = addon.Kit, addon.Style, addon.Style.Tone

-- Whether Group Resources is on and `id` is one of the block's bars.
function M:ResourceGrouped(id)
    return self.db.resourceLayout == "grouped" and self.resourceSpecs[id].group == true and self.db.resources.power.show == true
end
-- A bar laid out inside Power's block (not Power itself).
function M:ResourceInBlock(id) return id ~= "power" and self:ResourceGrouped(id) end

-- The bars in the block now, top down.
function M:ResourceGroupMembers()
    local list = {}
    for _, id in ipairs(self.resourceGroup) do
        if self.db.resources[id].show and self:ResourceActive(id) then list[#list + 1] = id end
    end
    return list
end

-- Separate Resources or Group Resources; outside combat, like every setting.
function M:SetResourceLayout(layout)
    if not self:CanConfigure() or self.db.resourceLayout == layout then return self.db.resourceLayout == layout end
    local candidate = addon.ProfileCodec.Copy(self.db)
    candidate.resourceLayout = layout
    if not pcall(self.Initialize, candidate) then return false end
    self.db.resourceLayout = layout
    if self.active then self:RefreshResources(); self:UpdateFade() end
    if addon.EditMode then addon.EditMode:RefreshElements() end
    if self.resourcePage then self.resourcePage:Refresh(); self.resourcePage:Layout() end
    if self.window then self:RefreshList() end
    return true
end

local function Block(host)
    local block = host.block
    if block then return block end
    block = CreateFrame("Frame", nil, host)
    block.edge = Style.Edge(block, M.EDGE, { pieces = true })
    block.lines = {}
    host.block = block
    return block
end

-- Lays the block out on Power's stand-in, then fills every bar in it.
function M:LayoutResourceGroup()
    local frames, movers = self.resourceFrames, self.resourceMovers
    if not frames then return end
    local host, mover = frames.power, movers.power
    local px = Kit.PixelSize(mover)
    local width = self:ResourceWidth("power", px)
    local style = self.db.resources.power
    local reach = M.ResourceReach(style, px)
    local inner = math.max(px, width - 2 * reach)
    local members, heights, total = self:ResourceGroupMembers(), {}, 0
    for i, id in ipairs(members) do
        heights[i] = M.ResourceBarHeight(self.db.resources[id], px, true)
        total = total + heights[i] + (i > 1 and px or 0)
    end
    -- The block, not its bars, keeps to the border's floor: Power grows.
    local floor = M.ResourceFloor(style, px)
    if total < floor then heights[1] = heights[1] + floor - total; total = floor end
    mover:SetSize(width, total + 2 * reach)
    self:PlaceResourceFrame(host, mover)
    local block = Block(host)
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", host, "TOPLEFT", reach, -reach)
    block:SetSize(inner, total)
    -- Above the bars (its innermost ring covers their corners), under the texts.
    block:SetFrameLevel(host:GetFrameLevel() + 3)
    block.edge:SetRim(style.edgeSize); block.edge:SetStyle(style.edgeStyle, style.edgeMetal)
    block.edge:SetShown(style.border ~= "none")
    block.edge:Layout()
    block:Show()
    local y = 0
    for i, id in ipairs(members) do
        local frame, h = frames[id], heights[i]
        if id == "power" then
            self:LayoutResourceFrame(frame, id, inner, px, false, { inBlock = true, height = h, x = reach, y = reach, textHost = "box" })
        else
            self:UnsnapResourceFrame(frame)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -y)
            frame:SetSize(inner, h)
            frame:SetFrameLevel(host:GetFrameLevel())
            -- Each text sits in the middle of its own strip.
            self:LayoutResourceFrame(frame, id, inner, px, false, { inBlock = true, height = h })
        end
        -- The 1px black line under every bar but the last.
        local line = block.lines[i]
        if i < #members then
            if not line then line = block:CreateTexture(nil, "ARTWORK"); line:SetTexture(Kit.FLAT); block.lines[i] = line end
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -(y + h))
            line:SetSize(inner, px)
            Style.Paint(line, Tone.shadow)
            line:Show()
        elseif line then line:Hide() end
        y = y + h + px
    end
    for i = math.max(1, #members), #block.lines do block.lines[i]:Hide() end
    -- Combo Points' and Alternate Mana's stand-ins fold to a line under the
    -- block, so whatever hangs from them stays close.
    for _, id in ipairs(self.resourceGroup) do
        if id ~= "power" then movers[id]:SetSize(width, px) end
    end
    for _, id in ipairs(self.resourceGroup) do self:UpdateResource(id) end
end
