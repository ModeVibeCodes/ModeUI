local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- What you track in Blizzard's Cooldown Manager, read from its Cooldown
-- Settings (Domain.Cooldowns.Layout), for the settings window (owner,
-- November 20, 2026):
--   * the preview shows each viewer's spells from it even while Blizzard's
--     viewer has no frames (hidden, or not shown since you logged in), so
--     every buff you track there is on Tracked Buffs (and every cooldown on
--     Essential or Utility) in full color, never sample icons;
--   * the + slot's list counts a spell as tracked from it, in full color,
--     for information while it has no frame;
--   * a spell or buff Blizzard's Cooldown Manager doesn't track says so in
--     its tooltip and spell menu (NOT_TRACKED).
-- On screen, the icons are still Blizzard's own frames: a viewer that's
-- hidden in Blizzard's Edit Mode shows nothing until it's on.
local L, Cooldowns, Style = addon.L, addon.Domain.Cooldowns, addon.Style
M.NOT_TRACKED = "Not tracked by Blizzard's Cooldown Manager. Track it there to show it."

-- Your setup (layout[category] = learned IDs in order; layout.category[id]),
-- or nil when the game can't say.
function M:BlizzardLayout() return Cooldowns.Layout and Cooldowns.Layout() or nil end

-- Whether Blizzard's Cooldown Manager tracks a spell (a cooldown ID key, in
-- any of the four viewers, learned or not): true or false; nil for custom
-- spells and items (they don't need it) or when the game can't say.
function M:InBlizzardCDM(key, layout)
    if type(key) ~= "string" or not key:match("^%d+$") then return nil end
    layout = layout or self:BlizzardLayout()
    if not layout then return nil end
    return layout.category[tonumber(key)] ~= nil
end
function M:NotTracked(key, layout) return self:InBlizzardCDM(key, layout) == false end

-- Whether Blizzard's Cooldown Manager shows a spell itself, by spell ID
-- (Forever's tracks racials and items in its spec-independent and
-- equipment categories where its data has them): ModeUI's own icon for the
-- same spell then stands aside (Racials.lua), so nothing shows twice.
function M:BlizzardTracksSpell(spellID, layout)
    layout = layout or self:BlizzardLayout()
    if not layout or type(spellID) ~= "number" then return false end
    for id in pairs(layout.category) do
        if Cooldowns.SpellID(id) == spellID then return true end
    end
    return false
end

-- The keys a viewer shows by your setup, in your order.
function M:LayoutKeys(viewer, layout)
    local spec, list = self.viewerSpecs[viewer], {}
    layout = layout or self:BlizzardLayout()
    if not spec or not layout then return list end
    for _, id in ipairs(layout[spec.category] or {}) do list[#list + 1] = string.format("%d", id) end
    return list
end

-- The bar a viewer's spell shows on (Owner, for a spell with no frame): the
-- bar that took it, when that bar takes spells from the viewer.
function M:KeyOwner(viewer, key)
    local custom = self.assigned and self.assigned[key]
    if custom then
        for _, source in ipairs(self:Sources(custom)) do if source == viewer then return custom end end
    end
    return viewer
end

-- The keys a viewer has frames for now.
function M:FramedKeys(viewer)
    local keys = {}
    for _, item in ipairs(self:Items(viewer)) do
        local key = self:SpellKey(item)
        if key then keys[key] = true end
    end
    return keys
end

-- Spells your setup tracks in a bar's source viewers that have no frame
-- yet, past those in `have` (keys): { key, icon, name, source, owner,
-- frameless = true }, the Candidates shape.
function M:FramelessCandidates(id, have)
    local list, layout = {}, self:BlizzardLayout()
    for _, viewer in ipairs(self:Sources(id)) do
        local framed = self:FramedKeys(viewer)
        for _, key in ipairs(self:LayoutKeys(viewer, layout)) do
            if not framed[key] and not have[key] then
                have[key] = true
                local spell = self:SpellOf(key)
                list[#list + 1] = { key = key, icon = spell and Cooldowns.SpellIcon(spell), name = self:SpellLabel(key),
                    source = viewer, owner = self:KeyOwner(viewer, key), frameless = true }
            end
        end
    end
    return list
end

-- A spell's tooltip: its name, the warning while Blizzard's Cooldown
-- Manager doesn't track it, then `detail` (what a click does).
function M:ShowSpellTip(owner, name, untracked, detail)
    local tip = _G.GameTooltip
    if not tip or type(tip.SetOwner) ~= "function" or type(tip.SetText) ~= "function" then return end
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:SetText(name or "")
    if untracked then tip:AddLine(Style.ColorText(L[M.NOT_TRACKED], Style.Tone.rosewood)) end
    if detail then tip:AddLine(Style.ColorText(detail, Style.Tone.text)) end
    tip:Show()
end
function M:HideSpellTip(owner)
    local tip = _G.GameTooltip
    if tip and type(tip.Hide) == "function" and (type(tip.GetOwner) ~= "function" or tip:GetOwner() == owner) then tip:Hide() end
end
