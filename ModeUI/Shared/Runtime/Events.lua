local _, addon = ...

-- One frame for game events. Each owner (a module or service table) gets at
-- most one handler per event; handlers run in the order owners subscribed.
-- RegisterUnitEvent filters a frame to at most two units, so unit-filtered
-- events stay on a frame owned by the code that needs them.
local Events = { handlers = {}, frame = CreateFrame("Frame") }
addon.Events = Events

local function Dispatch(_, event, ...)
    local list = Events.handlers[event]
    if not list then return end
    -- A handler may unsubscribe while the event is dispatching.
    local snapshot = {}
    for index, entry in ipairs(list) do snapshot[index] = entry end
    for _, entry in ipairs(snapshot) do
        if entry.active then entry.handler(event, ...) end
    end
end
Events.frame:SetScript("OnEvent", Dispatch)

function Events:On(owner, event, handler)
    assert(owner ~= nil and type(event) == "string" and type(handler) == "function", "ModeUI: Events:On(owner, event, handler).")
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
        self.frame:RegisterEvent(event)
    end
    for _, entry in ipairs(list) do
        if entry.owner == owner then entry.handler = handler; return end
    end
    list[#list + 1] = { owner = owner, handler = handler, active = true }
end

function Events:Off(owner, event)
    local list = self.handlers[event]
    if not list then return end
    for index, entry in ipairs(list) do
        if entry.owner == owner then
            entry.active = false
            table.remove(list, index)
            break
        end
    end
    if #list == 0 then
        self.handlers[event] = nil
        self.frame:UnregisterEvent(event)
    end
end

function Events:OffAll(owner)
    local events = {}
    for event in pairs(self.handlers) do events[#events + 1] = event end
    for _, event in ipairs(events) do self:Off(owner, event) end
end

function Events:IsOn(owner, event)
    for _, entry in ipairs(self.handlers[event] or {}) do
        if entry.owner == owner then return true end
    end
    return false
end
