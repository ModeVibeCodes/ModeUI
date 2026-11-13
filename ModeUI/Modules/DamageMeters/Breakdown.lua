local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- The spell breakdown: clicking a row opens a panel beside the window with
-- that source's spells, drawn like the window itself (same rim, bars and
-- text), each bar in the source's color with the spell's icon. It follows
-- the window's meter and fight and updates with it. Clicking its header, or
-- the same row again, closes it. A death opens the game's Death Recap.
--
-- The game names a source by its GUID, which can be secret in combat, and it
-- refuses secret arguments from addon code. Then the panel says so and fills
-- in once the GUID is public again (after combat), finding the source by its
-- rank. Spell IDs, names and icons may be secret: they go to C_Spell, which
-- accepts them, and on to SetText and SetTexture.
local Kit, L = addon.Kit, addon.L
local DM = addon.Domain.DamageMeter
local Public, Number = addon.IsPublic, addon.IsNumber
M.BREAKDOWN_ROWS = 12
local ICON_CROP = 0.08

function M:BreakdownPanel()
    if self.breakdown then return self.breakdown end
    local panel = self:BuildShell(UIParent, "ModeUIDamageMeterBreakdown")
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel.header:SetScript("OnClick", function() self:CloseBreakdown() end)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        panel.offset = math.max(0, (panel.offset or 0) - delta)
        self:RenderBreakdown()
    end)
    panel:Hide()
    self.breakdown = panel
    return panel
end

-- A source's public GUID or creature ID; nil for a secret one.
local function Identity(source)
    local guid, creature = source.sourceGUID, source.sourceCreatureID
    if not Public(guid) or type(guid) ~= "string" or guid == "" then guid = nil end
    if not Number(creature) then creature = nil end
    return guid, creature
end

function M:OpenBreakdown(window, row)
    local source = row.source
    if not source or self.editing or self.testing then return end
    local style = self:Style(window)
    local info = DM.typeById[style.meterType]
    if info.deaths then
        local recap = source.deathRecapID
        if Number(recap, 1) and type(OpenDeathRecapUI) == "function" and not addon.InCombat() then pcall(OpenDeathRecapUI, recap) end
        return
    end
    local panel = self:BreakdownPanel()
    local guid, creature = Identity(source)
    if panel:IsShown() and panel.window == window and panel.rank == row.rank then self:CloseBreakdown(); return end
    local class = source.classFilename
    if not Public(class) or type(class) ~= "string" then class = "" end
    panel.window, panel.rank, panel.guid, panel.creature, panel.class = window, row.rank, guid, creature, class
    panel.offset, panel.paintKey = 0, nil
    panel:Show()
    self:RenderBreakdown()
end

function M:CloseBreakdown()
    if self.breakdown then self.breakdown:Hide() end
end

-- Beside its window, on the side facing the middle of the screen.
local function Place(panel, frame, px)
    local gap = 4 * px
    local x, middle = frame:GetCenter(), UIParent:GetCenter()
    panel:ClearAllPoints()
    if Number(x) and Number(middle) and x > middle then panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -gap, 0)
    else panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", gap, 0) end
end

-- The source a closed-over rank points at now, while its GUID is public.
function M:FindBreakdownSource(panel, session, meterType)
    if panel.guid or panel.creature then return true end
    local data = DM.Session(session, meterType)
    local source = data and data.sources[panel.rank]
    if not source then return false end
    panel.guid, panel.creature = Identity(source)
    return panel.guid ~= nil or panel.creature ~= nil
end

function M:RenderBreakdown()
    local panel = self.breakdown
    if not panel or not panel:IsShown() then return end
    local window = panel.window
    local frame, style = self.frames[window], self:Style(window)
    local info = DM.typeById[style.meterType]
    local session = self:SessionOf(window)
    local known = self:FindBreakdownSource(panel, session, style.meterType)
    local data = known and DM.Source(session, style.meterType, panel.guid, panel.creature)
    local spells = data and data.spells or {}
    local rows = math.max(1, math.min(#spells, self.BREAKDOWN_ROWS))
    local key = window .. ":" .. rows .. ":" .. (self.paintRevision or 0)
    if panel.paintKey ~= key then
        self:PaintShell(panel, style, rows)
        panel.paintKey = key
    end
    local g = panel.g
    Place(panel, frame, g.px)
    -- Header: the source's name (may be secret) and the meter.
    local sessionData = DM.Session(session, style.meterType)
    local source = sessionData and sessionData.sources[panel.rank]
    if style.header then
        -- Tested for presence only through the public table, never the name itself.
        local name = ""
        if source then name = source.name end
        if Public(name) and type(name) ~= "string" then name = "" end
        Kit.Write(panel.header.title, name)
        local meter = L[info.label]
        Kit.Write(panel.header.info, style.titleUpper and meter:upper() or meter)
    end
    local color = self.BarColor(style, panel.class)
    panel.offset = math.max(0, math.min(panel.offset or 0, #spells - rows))
    for i = 1, rows do
        local row, spell = panel.rows[i], spells[panel.offset + i]
        if spell then
            row.bar:SetStatusBarColor(color[1], color[2], color[3], style.barOpacity / 100)
            row.bar:SetMinMaxValues(0, M.Amount(data.max))
            row.bar:SetValue(M.Amount(spell.totalAmount))
            if style.icon ~= "none" then
                row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                row.icon:SetTexture(DM.SpellIcon(spell.spellID)); row.icon:Show()
            end
            local name, pet = DM.SpellName(spell.spellID), spell.creatureName
            if Public(pet) and type(pet) == "string" and pet ~= "" then Kit.Formatted(row.name, "%s (%s)", name, pet)
            else Kit.Write(row.name, name) end
            local text = style.textColor
            row.name:SetTextColor(text[1], text[2], text[3], 1)
            self.WriteValue(row.value, spell, data.total, style, info)
            row:EnableMouse(false)
            row:Show()
        else
            row:Hide()
        end
    end
    local empty = #spells == 0
    panel.empty:SetText(empty and (known and L["No spells recorded."] or L["Spell details show after combat."]) or "")
    panel.empty:SetShown(empty)
end
