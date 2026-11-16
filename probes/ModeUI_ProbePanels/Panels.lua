local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- /mprobe panels: the Phase 7 panels in one Mode window, each tab built the
-- first time it opens.
local window
Kit.Register("panels", "Chat, Meters, Tooltip, Bags, Minimap (Phase 7)", function()
    window = window or Kit.Window("Panels", "Panels", 760, 520, {
        { id = "chat", label = "Chat", build = ns.BuildChat },
        { id = "meters", label = "Damage Meters", build = ns.BuildMeters },
        { id = "tooltip", label = "Tooltip", build = ns.BuildTooltip },
        { id = "bags", label = "Bags", build = ns.BuildBags },
        { id = "minimap", label = "Minimap", build = ns.BuildMinimap },
    })
    return window
end)
