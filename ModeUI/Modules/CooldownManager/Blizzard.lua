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
M.sourceOf = setmetatable({}, { __mode = "k" }) -- item frame -> its Blizzard viewer
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
    for _, item in ipairs(items) do self.sourceOf[item] = viewer end
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
        M.Safe(function()
            M.sourceOf[item] = viewer; M:HookItem(viewer, item)
            if M.active then M:DressItem(M:Owner(item), item) end
        end)
    end)
    -- Blizzard's grid has just placed every item; ModeUI places them again,
    -- right away (the viewer and the custom bars it feeds), so nothing shows
    -- at Blizzard's spot for a frame.
    HookMethod(frame, "Layout", function() M.Safe(function() if M.active then M:LayoutSource(viewer) end end) end)
    -- The tracked spells changed in place (no new layout).
    HookMethod(frame, "RefreshData", function() M.Safe(function() if M.active then M:QueueSource(viewer) end end) end)
end

-- Item hooks, once per item frame (Blizzard reuses them from a pool).
function M:HookItem(viewer, item)
    if self.itemHooked[item] or not hooksecurefunc then return end
    self.itemHooked[item] = true
    -- Shown and hidden as auras come and go (Hide When Inactive): its bar
    -- closes the gap on the next frame.
    HookMethod(item, "UpdateShownState", function(hooked)
        M.Safe(function() if M.active then M:QueueLayout(M:Owner(hooked)) end end)
    end)
    if self:IsBar(viewer) then
        -- Bar Content re-anchors the bar to the icon.
        HookMethod(item, "SetBarContent", function(hooked) M.Safe(function() if M.active then M:LayoutBarParts(hooked) end end) end)
        return
    end
    -- Blizzard sets the swipe, edge and gray on every cooldown refresh;
    -- ModeUI's go back on after it, with the glows that follow the state.
    -- Bars refresh every frame and have neither.
    for _, method in ipairs({ "RefreshSpellCooldownInfo", "RefreshCooldownInfo", "RefreshIconDesaturation" }) do
        HookMethod(item, method, function(hooked) M.Safe(function() if M.active then M:StyleCooldown(hooked) end end) end)
    end
    -- Blizzard tints the icon for range, usability and mana.
    HookMethod(item, "RefreshIconColor", function(hooked)
        M.Safe(function()
            local state = M.dress[hooked]
            if M.active and state and M.db[state.viewer] then M:StyleRange(hooked, M.db[state.viewer]) end
        end)
    end)
    -- A tracked buff coming or going (its active state can be secret).
    HookMethod(item, "SetIsActive", function(hooked) M.Safe(function() if M.active then M:ApplyGlows(hooked) end end) end)
end

-- Re-lays a bar out on the next frame, once however often it's asked.
M.pending = {}
function M:QueueLayout(id)
    if not id or self.pending[id] then return end
    self.pending[id] = true
    local function Run()
        M.pending[id] = nil
        if M.active and M:HasBar(id) then M.Safe(function() M:LayoutViewer(id) end) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end
-- A viewer, and every custom bar that takes spells from it.
function M:LayoutSource(viewer)
    self:LayoutViewer(viewer)
    for _, id in ipairs(self:CustomsFrom(viewer)) do self:LayoutViewer(id) end
end
function M:QueueSource(viewer)
    self:QueueLayout(viewer)
    for _, id in ipairs(self:CustomsFrom(viewer)) do self:QueueLayout(id) end
end

-- The key of what an item shows: the cooldown ID a Blizzard item tracks
-- ("1234"), a custom spell icon's spell ("s1234"), or nil.
function M:SpellKey(item)
    if self.iconKey[item] then return self.iconKey[item] end
    local id = Cooldowns.ItemCooldownID(item)
    return id and string.format("%d", id) or nil
end

-- A spell's own switch ("hide", or a glow: "proc", "active", "ready",
-- "buff") on a bar: on while stored (a glow's look is what's stored).
function M:SpellSwitch(id, key, kind)
    local style = self.db[id]
    local entry = key and style and style.spells[key]
    if kind == "hide" then return entry ~= nil and entry.hide == true end
    return entry ~= nil and type(entry[kind]) == "table"
end
-- A spell's glow look while that glow is on, else nil.
function M:SpellGlow(id, key, kind)
    local style = self.db[id]
    local entry = key and style and style.spells[key]
    local look = entry and entry[kind]
    if type(look) == "table" then return look end
end

-- Whether the game's Cooldown Manager can show anything now, and why not.
function M:GameState()
    if not self:Frame("essential") then return "missing" end
    local available = Cooldowns.Available()
    if available == false then return "unavailable" end
    if Cooldowns.Enabled() == false then return "off" end
    return "on"
end
