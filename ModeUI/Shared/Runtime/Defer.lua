local _, addon = ...

-- Work that must wait until combat ends: protected frame changes, and refreshes
-- that touch them. Each task has a key; queuing the same key again replaces the
-- earlier task, so only the latest wins. The queue runs in order on
-- PLAYER_REGEN_ENABLED.
local Defer = { order = {}, tasks = {} }
addon.Defer = Defer

-- Queue a task without checking combat (for callers that already know).
function Defer:Queue(key, task)
    assert(type(key) == "string" and key ~= "" and type(task) == "function", "ModeUI: Defer:Queue(key, task).")
    if not self.tasks[key] then self.order[#self.order + 1] = key end
    self.tasks[key] = task
end

-- Run the task now outside combat, otherwise queue it. Returns true if it ran.
function Defer:Run(key, task)
    if addon.InCombat() then self:Queue(key, task); return false end
    self:Cancel(key)
    task()
    return true
end

function Defer:Cancel(key)
    if not self.tasks[key] then return end
    self.tasks[key] = nil
    for index, queued in ipairs(self.order) do
        if queued == key then table.remove(self.order, index); break end
    end
end

function Defer:IsQueued(key) return self.tasks[key] ~= nil end

-- Tasks queued while flushing (for example a refresh that finds combat again)
-- wait for the next PLAYER_REGEN_ENABLED.
function Defer:Flush()
    local order, tasks = self.order, self.tasks
    self.order, self.tasks = {}, {}
    for _, key in ipairs(order) do tasks[key]() end
end

addon.Events:On(Defer, "PLAYER_REGEN_ENABLED", function() Defer:Flush() end)
