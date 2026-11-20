local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M or not addon.Themes then return end

-- The Cooldown Manager's part of the Mode-Obsidian theme
-- (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"; ModeUI's
-- Shared/Runtime/Themes.lua): icon faces still at Mono panel take
-- Mode-Obsidian's, and every bar's empty part (tracked bars, resource bars,
-- the Cast Bar) is Mode-Obsidian Track at 85%. The bars are already Dark by
-- default; borders follow the theme in Style. Runs once per profile, when
-- the companion starts.
local TRACK = "media:Mode-Obsidian Track"
local function Track(style)
    if type(style) ~= "table" or style.barBackground == nil then return end
    style.barBackground, style.barBackgroundOpacity = TRACK, 85
end
addon.Themes:Contribute("obsidian", "cooldownManager", function(db)
    local Swap = addon.Themes.SwapColor
    for _, viewer in ipairs(M.viewers) do Swap(db[viewer], "backgroundColor", "mono", "panel"); Track(db[viewer]) end
    for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do Swap(bar, "backgroundColor", "mono", "panel"); Track(bar) end
    for _, id in ipairs(M.resources or {}) do Track(type(db.resources) == "table" and db.resources[id]) end
    Track(db.castBar)
end)
