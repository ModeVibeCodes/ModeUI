local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- /mprobe frames: Group Frames and Nameplates in one Mode window, built the
-- first time it opens.
local window
Kit.Register("frames", "Group Frames and Nameplates (Phase 5)", function()
    window = window or Kit.Window("Frames", "Frames", 900, 600, {
        { id = "group", label = "Group Frames", build = ns.BuildGroupFrames },
        { id = "plates", label = "Nameplates", build = ns.BuildNameplates },
    })
    return window
end)
