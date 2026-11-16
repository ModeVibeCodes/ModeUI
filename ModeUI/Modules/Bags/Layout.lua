local _, addon = ...
local M = addon.Bags
if not M then return end

-- Where everything goes. The window is Columns slots wide; the slots fill
-- rows from its top left, in sections:
--   Bags      the backpack and the equipped bags (each its own block with
--             Separate Bags), plus the reagent bag unless it has its own
--   Reagents  the reagent bag (Reagent Section)
--   Keyring   the keyring (Keyring, when the game shows one)
-- Sort shows the items in an order without moving them: Bag Order (as they
-- lie in the bags), or Quality, Type or Name, with empty slots last. Clean
-- Up is the game's own sort, which moves them. All sizes are whole physical
-- pixels; nothing here measures text. Slots are Slot Size wide and a little
-- shorter (Style.IconHeight, as every Mode icon); Spacing is the gap
-- between slots, their 1px `group` edges inside it.
local Kit, L, Style = addon.Kit, addon.L, addon.Style
local Containers = addon.Domain.Containers

function M:Geometry()
    local db, px = self.db, Kit.PixelSize(self.frame)
    local function Snap(v) return v <= 0 and 0 or math.max(px, math.floor(v / px + 0.5) * px) end
    local g = { px = px, border = Style.EdgeReach("window") * px, columns = db.columns }
    g.slot, g.gap, g.pad = Snap(db.slotSize), Snap(db.spacing), Snap(db.padding)
    g.slotH = Style.IconHeight(math.floor(g.slot / px + 0.5)) * px
    g.inset = Snap(6)
    g.header = Snap(math.max(20, db.titleSize + 10))
    g.search = db.showSearch and Snap(math.max(20, db.titleSize + 8)) or 0
    g.footer = self.FooterHeight(db, g)
    g.label = Snap(math.max(14, db.titleSize + 2))
    g.sectionGap = Snap(math.max(6, 2 * db.spacing))
    g.left = g.border + g.pad
    g.searchTop = g.border + g.header + px + g.pad
    g.gridTop = g.searchTop + (g.search > 0 and g.search + g.pad or 0)
    g.gridWidth = g.columns * g.slot + (g.columns - 1) * g.gap
    g.width = 2 * g.left + g.gridWidth
    return g
end

-- The sections and the bags in each, in order.
function M:Sections()
    local db, main, reagents = self.db, {}, {}
    for _, bag in ipairs(Containers.HeldBags()) do
        if Containers.NumSlots(bag) > 0 then
            if Containers.IsReagent(bag) and db.reagentSection then reagents[#reagents + 1] = bag
            else main[#main + 1] = bag end
        end
    end
    local sections = {}
    if db.splitBags then
        for _, bag in ipairs(main) do sections[#sections + 1] = { bags = { bag } } end
    elseif #main > 0 then sections[1] = { bags = main } end
    if #reagents > 0 then sections[#sections + 1] = { bags = reagents, label = L["Reagents"] } end
    local keyring = Containers.KEYRING
    if db.keyring and Containers.HasKeyring() and Containers.NumSlots(keyring) > 0 then
        sections[#sections + 1] = { bags = { keyring }, label = L["Keyring"] }
    end
    return sections
end

-- Sort keys: quality (best first), item class, then name; empty slots last,
-- and ties in bag order, so the view never shuffles between redraws.
local function Name(entry) return entry.item and type(entry.item.name) == "string" and entry.item.name or "" end
local function Quality(entry) return entry.item and type(entry.item.quality) == "number" and entry.item.quality or -1 end
local function Class(entry)
    local classID, subClassID = Containers.ItemClass(entry.item and entry.item.link)
    return type(classID) == "number" and classID or 99, type(subClassID) == "number" and subClassID or 99
end
local ORDERS = {
    quality = function(a, b)
        if Quality(a) ~= Quality(b) then return Quality(a) > Quality(b) end
        local ac, as = Class(a); local bc, bs = Class(b)
        if ac ~= bc then return ac < bc end
        if as ~= bs then return as < bs end
        return Name(a) < Name(b)
    end,
    type = function(a, b)
        local ac, as = Class(a); local bc, bs = Class(b)
        if ac ~= bc then return ac < bc end
        if as ~= bs then return as < bs end
        if Quality(a) ~= Quality(b) then return Quality(a) > Quality(b) end
        return Name(a) < Name(b)
    end,
    name = function(a, b)
        if Name(a) ~= Name(b) then return Name(a) < Name(b) end
        return Quality(a) > Quality(b)
    end,
}
function M.Order(entries, mode)
    local compare = ORDERS[mode]
    if not compare then return entries end
    table.sort(entries, function(a, b)
        if (a.item ~= nil) ~= (b.item ~= nil) then return a.item ~= nil end
        if a.item and b.item then
            if compare(a, b) then return true end
            if compare(b, a) then return false end
        end
        return a.order < b.order
    end)
    return entries
end

-- The slots of a section's bags, each with what it holds, in view order.
function M:Entries(section)
    local entries = {}
    for _, bag in ipairs(section.bags) do
        for slot = 1, Containers.NumSlots(bag) do
            entries[#entries + 1] = { bag = bag, slot = slot, item = Containers.Item(bag, slot), order = #entries + 1 }
        end
    end
    return self.Order(entries, self.db.sortMode)
end

-- A small section title over a hairline, reused per section.
function M:SectionLabel(index)
    local labels = self.frame.labels
    if not labels[index] then
        local text = Kit.Text(self.frame)
        local line = self.frame:CreateTexture(nil, "BORDER")
        Style.ApplyAsset(line, "Solid")
        labels[index] = { text = text, line = line }
    end
    return labels[index]
end

-- Where each section title and slot goes, top to bottom, and the window's
-- height: no frames are touched, so the size is known before any slot exists.
function M:Plan(g)
    local plan, y = { sections = {} }, g.gridTop
    for index, section in ipairs(self:Sections()) do
        if index > 1 then y = y + g.sectionGap end
        local placed = { label = section.label, y = y, slots = {} }
        if section.label then y = y + g.label + g.gap end
        local entries = self:Entries(section)
        for i, entry in ipairs(entries) do
            local column, row = (i - 1) % g.columns, math.floor((i - 1) / g.columns)
            placed.slots[i] = { entry = entry, x = g.left + column * (g.slot + g.gap), y = y + row * (g.slotH + g.gap) }
        end
        local rows = math.max(1, math.ceil(#entries / g.columns))
        y = y + rows * g.slotH + (rows - 1) * g.gap
        plan.sections[index] = placed
    end
    plan.height = y + g.pad + (g.footer > 0 and g.footer + g.pad or 0) + g.border
    return plan
end

-- The window's size alone (closed, or for Edit Mode's stand-in).
function M:Measure()
    if not self.frame then return end
    local g = self.g or self:Geometry()
    self:SizeWindow(g.width, self:Plan(g).height)
end

function M:PaintLabel(index, text, y, g)
    local db, frame = self.db, self.frame
    local label = self:SectionLabel(index)
    local look = { font = db.font, fontMedia = db.fontMedia, outline = false, shadow = true, textColor = Style.Tone.graphite.muted }
    Kit.Font(label.text, look, math.max(8, db.titleSize - 2), Kit.FontPath(db, self.id), g.px)
    label.text:SetText(text)
    label.text:ClearAllPoints(); label.text:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left, -y)
    label.line:ClearAllPoints()
    label.line:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left, -(y + g.label - g.px))
    label.line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.left, -(y + g.label - g.px))
    label.line:SetHeight(g.px)
    Style.Paint(label.line, Style.Tone.graphite.line)
    label.text:Show(); label.line:Show()
end

-- Places every slot and sizes the window. Blizzard's item buttons aren't
-- protected (its source); should the client report one as protected, the
-- layout waits for the end of combat.
function M:Layout()
    local frame = self.frame
    if not frame then return end
    if addon.InCombat() and self.slots and self.slots[1] and self.slots[1].IsProtected then
        local protected = self.slots[1]:IsProtected()
        if not addon.IsPublic(protected) or protected then self.layoutPending = true; return end
    end
    local g = self.g or self:Geometry()
    local plan, used, labels = self:Plan(g), {}, 0
    for _, section in ipairs(plan.sections) do
        if section.label then labels = labels + 1; self:PaintLabel(labels, section.label, section.y, g) end
        for _, place in ipairs(section.slots) do
            local entry = place.entry
            local button = self:Button(entry.bag, entry.slot)
            self.entries[button] = entry
            self:PaintSlot(button, g)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", place.x, -place.y)
            button:Show()
            self:PaintItem(button, entry.item)
            used[button] = true
        end
    end
    for i = labels + 1, #frame.labels do frame.labels[i].text:Hide(); frame.labels[i].line:Hide() end
    -- Slots of bags that shrank or left stay hidden.
    for _, button in ipairs(self.slots or {}) do
        if not used[button] then button:Hide(); self.entries[button] = nil end
    end
    self:SizeWindow(g.width, plan.height)
end
