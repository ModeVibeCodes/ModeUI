local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Blizzard's viewers and the hooks that follow them. Blizzard's code in the
-- Cooldown Manager works on secret cooldown and aura values, which it may
-- only do while it runs untainted, so ModeUI:
--   * never writes a field on a viewer or item frame (its own state lives in
--     weak tables keyed by the frame),
--   * never calls a Blizzard method that refreshes or lays out,
--   * only post-hooks (hooksecurefunc), and runs every hook body through
--     pcall so a ModeUI error never surfaces inside Blizzard's call.
-- The viewers and items are plain frames: anchors, sizes, alpha and textures
-- may change in combat.
local Cooldowns = addon.Domain.Cooldowns
M.viewerOf = setmetatable({}, { __mode = "k" }) -- item frame -> viewer ID
M.itemHooked = setmetatable({}, { __mode = "k" })
M.viewerHooked = setmetatable({}, { __mode = "k" })

-- Reports a hook's error once per message, without breaking Blizzard's call.
local reported = {}
function M.Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[tostring(err)] then
        reported[tostring(err)] = true
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

function M:Frame(viewer) return Cooldowns.Viewer(viewer) end

-- The items a viewer holds now, in Blizzard's order.
function M:Items(viewer)
    local frame = self:Frame(viewer)
    local items = frame and Cooldowns.Items(frame) or {}
    for _, item in ipairs(items) do self.viewerOf[item] = viewer end
    return items
end

-- Hooks each viewer once, as soon as Blizzard's Cooldown Manager is loaded.
-- Returns whether every viewer was found.
function M:HookViewers()
    if not hooksecurefunc then return false end
    local all = true
    for _, viewer in ipairs(self.viewers) do
        local frame = self:Frame(viewer)
        if frame and not self.viewerHooked[frame] then
            self.viewerHooked[frame] = true
            self:HookViewer(viewer, frame)
        elseif not frame then all = false end
    end
    return all
end

local function HookMethod(frame, method, fn)
    if type(frame[method]) == "function" then hooksecurefunc(frame, method, fn) end
end

function M:HookViewer(viewer, frame)
    -- A new item: skin and place it. Blizzard set its scale and size first.
    HookMethod(frame, "OnAcquireItemFrame", function(_, item)
        M.Safe(function() M.viewerOf[item] = viewer; M:HookItem(viewer, item); if M.active then M:DressItem(viewer, item) end end)
    end)
    -- Blizzard's grid has just placed every item; ModeUI places them again,
    -- right away, so nothing shows at Blizzard's spot for a frame.
    HookMethod(frame, "Layout", function() M.Safe(function() if M.active then M:LayoutViewer(viewer) end end) end)
    -- The tracked spells changed in place (no new layout): per-spell
    -- switches and glows follow the cooldown IDs.
    HookMethod(frame, "RefreshData", function() M.Safe(function() if M.active then M:QueueLayout(viewer) end end) end)
end

-- Item hooks, once per item frame (Blizzard reuses them from a pool).
function M:HookItem(viewer, item)
    if self.itemHooked[item] or not hooksecurefunc then return end
    self.itemHooked[item] = true
    -- Shown and hidden as auras come and go (Hide When Inactive): the
    -- viewer closes the gap on the next frame.
    HookMethod(item, "UpdateShownState", function(hooked)
        M.Safe(function() if M.active then M:QueueLayout(M.viewerOf[hooked]) end end)
    end)
    -- Blizzard sets the swipe and edge on every cooldown refresh; ModeUI's
    -- go back on after it. Bars refresh every frame and have no swipe.
    if not self:IsBar(viewer) then
        for _, method in ipairs({ "RefreshSpellCooldownInfo", "RefreshCooldownInfo" }) do
            HookMethod(item, method, function(hooked) M.Safe(function() if M.active then M:StyleCooldown(hooked) end end) end)
        end
    else
        -- Bar Content re-anchors the bar to the icon.
        HookMethod(item, "SetBarContent", function(hooked) M.Safe(function() if M.active then M:LayoutBarParts(hooked) end end) end)
    end
end

-- Re-lays a viewer out on the next frame, once however often it's asked.
M.pending = {}
function M:QueueLayout(viewer)
    if not viewer or self.pending[viewer] then return end
    self.pending[viewer] = true
    local function Run()
        M.pending[viewer] = nil
        if M.active then M.Safe(function() M:LayoutViewer(viewer) end) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

-- The cooldown ID an item tracks, as a settings key ("1234"), or nil.
function M:SpellKey(item)
    local id = Cooldowns.ItemCooldownID(item)
    return id and string.format("%d", id) or nil
end

-- A spell's own switch ("hide", "proc", "ready") in a viewer: hide is on
-- while stored; proc and ready are on unless stored off.
function M:SpellSwitch(viewer, key, kind)
    local entry = key and self.db[viewer].spells[key]
    if kind == "hide" then return entry ~= nil and entry.hide == true end
    return not (entry and entry[kind] == false)
end

-- Whether the game's Cooldown Manager can show anything now, and why not.
function M:GameState()
    if not self:Frame("essential") then return "missing" end
    local available = Cooldowns.Available()
    if available == false then return "unavailable" end
    if Cooldowns.Enabled() == false then return "off" end
    return "on"
end
