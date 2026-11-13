local _, addon = ...
addon.categories, addon.categoryOrder = {}, {}

-- Categories organize modules in the sidebar; they have no enable state or lifecycle.
function addon:RegisterCategory(id, definition)
    assert(not self.initialized, "ModeUI: register categories before initialization.")
    assert(type(id) == "string" and id ~= "" and not self.categories[id], "ModeUI: unique category ID required.")
    assert(not self.modules or not self.modules[id], "ModeUI: category/module IDs must be distinct.")
    assert(type(definition) == "table" and type(definition.title) == "string", "ModeUI: category title required.")
    self.categories[id] = { id = id, title = definition.title, modules = {} }
    self.categoryOrder[#self.categoryOrder + 1] = id
end

addon:RegisterCategory("interface", { title = "Interface" })
addon:RegisterCategory("global", { title = "Global" })
