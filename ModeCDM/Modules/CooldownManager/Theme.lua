local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M or not addon.Themes then return end

-- The Cooldown Manager's part of the Mode-Obsidian theme
-- (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"; ModeUI's
-- Shared/Runtime/Themes.lua): icon faces still at Mono panel take
-- Mode-Obsidian's, and every bar's empty part (tracked bars, resource bars,
-- the Cast Bar) is Mode-BG at 85%. The bars are already Dark by
-- default; borders follow the theme in Style. Runs once per profile, when
-- the companion starts.
local TRACK = "media:Mode-BG"
-- A border that follows the Bar Style keeps the Bar Style's metal (owner,
-- November 24, 2026: Gunmetal); so does the Bar Style itself.
local function Track(style)
    if type(style) ~= "table" then return end
    if not (type(style.follow) == "table" and style.follow.border) then addon.Themes.DefaultMetal(style) end
    if style.barBackground == nil then return end
    style.barBackground, style.barBackgroundOpacity = TRACK, 85
end
addon.Themes:Contribute("obsidian", "cooldownManager", function(db)
    local Swap = addon.Themes.SwapColor
    for _, viewer in ipairs(M.viewers) do Swap(db[viewer], "backgroundColor", "mono", "panel"); Track(db[viewer]) end
    for _, bar in pairs(type(db.customBars) == "table" and db.customBars or {}) do
        local style = type(bar) == "table" and db[bar.id]
        if type(style) == "table" then Swap(style, "backgroundColor", "mono", "panel"); Track(style) end
    end
    for _, id in ipairs(M.resources or {}) do Track(type(db.resources) == "table" and db.resources[id]) end
    Track(db.castBar)
    if type(db.barStyle) == "table" then Swap(db.barStyle, "backgroundColor", "mono", "panel") end
end)
