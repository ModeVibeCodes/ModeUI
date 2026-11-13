local _, addon = ...
local L = addon.L

-- The module registry. Modules register from their Init.lua before startup;
-- at startup each one is initialized with its saved settings and then enabled
-- or left off. Runtime never names a specific module.
addon.categories, addon.categoryOrder = {}, {}
addon.modules, addon.moduleOrder = {}, {}

-- Categories organize modules in the sidebar; they have no enable state or lifecycle.
function addon:RegisterCategory(id, definition)
    assert(not self.initialized, "ModeUI: register categories before initialization.")
    assert(type(id) == "string" and id ~= "" and not self.categories[id], "ModeUI: unique category ID required.")
    assert(not self.modules[id], "ModeUI: category/module IDs must be distinct.")
    assert(type(definition) == "table" and type(definition.title) == "string", "ModeUI: category title required.")
    self.categories[id] = { id = id, title = definition.title, modules = {} }
    self.categoryOrder[#self.categoryOrder + 1] = id
end

-- Sidebar order (owner, November 13, 2026): Global, then Interface (Blizzard's
-- own UI restyled: windows, chat, meters, bars), then Frames (unit frames,
-- nameplates and, later, party frames). Within a category, modules keep the
-- order their XML is listed in ModeUI.toc.
addon:RegisterCategory("global", { title = L["Global"] })
addon:RegisterCategory("interface", { title = L["Interface"] })
addon:RegisterCategory("frames", { title = L["Frames"] })

function addon:RegisterModule(id, module)
    assert(not self.initialized, "ModeUI: register modules before initialization.")
    assert(type(id) == "string" and id ~= "", "ModeUI: module ID required.")
    assert(type(module) == "table" and type(module.title) == "string", "ModeUI: module title required.")
    assert(not self.modules[id], "ModeUI: duplicate module ID: " .. id)
    assert(not self.categories[id], "ModeUI: category/module IDs must be distinct.")
    if module.category then
        assert(self.categories[module.category] and not module.developer, "ModeUI: valid gameplay category required.")
        local members = self.categories[module.category].modules
        members[#members + 1] = id
    end
    module.id = id
    module.enabled = false
    self.modules[id] = module
    self.moduleOrder[#self.moduleOrder + 1] = id
end

local function Transition(module, enabled)
    if module.planned then module.enabled = false; return end
    if module.alwaysOn then enabled = true end
    if module.enabled == enabled then return end
    local callback = enabled and module.OnEnable or module.OnDisable
    if callback then callback(module) end
    module.enabled = enabled
    if not enabled and addon.PreviewStates then addon.PreviewStates:Stop(module.id) end
end

function addon:InitializeModules()
    for _, id in ipairs(self.moduleOrder) do
        local module = self.modules[id]
        local settings = self.db.modules[id]
        if settings == nil then
            settings = { enabled = module.defaultEnabled ~= false }
            self.db.modules[id] = settings
        end
        assert(type(settings) == "table", "ModeUI: invalid settings for " .. id)
        if settings.enabled == nil then settings.enabled = module.defaultEnabled ~= false end
        assert(type(settings.enabled) == "boolean", "ModeUI: invalid enabled setting for " .. id)
        module.db = settings
        if module.OnInitialize then module:OnInitialize() end
        Transition(module, settings.enabled)
        if self.SyncModuleDisplayModes then self:SyncModuleDisplayModes(module) end
    end
end

function addon:SetModuleEnabled(id, enabled)
    assert(self.initialized and self.modules[id], "ModeUI: module unavailable.")
    assert(type(enabled) == "boolean", "ModeUI: enabled must be boolean.")
    local module = self.modules[id]
    if module.planned or module.alwaysOn then return end
    Transition(module, enabled)
    module.db.enabled = enabled
    if self.SyncModuleDisplayModes then self:SyncModuleDisplayModes(module) end
    self:SendMessage(self.Messages.MODULE_TOGGLED, id, enabled)
end

-- Every enabled module hears when combat starts and ends.
function addon:BroadcastCombatState(inCombat)
    for _, id in ipairs(self.moduleOrder) do
        local module = self.modules[id]
        if module.enabled and module.OnCombatStateChanged then module:OnCombatStateChanged(inCombat) end
    end
end
