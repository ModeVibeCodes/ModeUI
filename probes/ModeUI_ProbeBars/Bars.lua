local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- /mprobe bars: Action Bars and the Cooldown Manager in one Mode window, built
-- the first time it opens.
local window
Kit.Register("bars", "Action Bars and Cooldown Manager (Phase 6)", function()
    window = window or Kit.Window("Bars", "Bars", 760, 470, {
        { id = "action", label = "Action Bars", build = ns.BuildActionBars },
        { id = "cooldowns", label = "Cooldown Manager", build = ns.BuildCooldownManager },
    })
    return window
end)
