local _, addon = ...

-- Internal messages between ModeUI's modules and services, so no module has to
-- know about another. Built on the bundled CallbackHandler-1.0:
--   addon.RegisterMessage(owner, "ModeUI_X", function(message, ...) end)
--   addon.UnregisterMessage(owner, "ModeUI_X")
--   addon:SendMessage("ModeUI_X", ...)
-- Each owner gets one handler per message. Handler order is not guaranteed.
local CallbackHandler = LibStub("CallbackHandler-1.0")
local registry = CallbackHandler:New(addon, "RegisterMessage", "UnregisterMessage", "UnregisterAllMessages")
addon.callbacks = registry

function addon:SendMessage(message, ...)
    assert(type(message) == "string" and message:sub(1, 7) == "ModeUI_", "ModeUI: message names start with ModeUI_.")
    registry:Fire(message, ...)
end

-- Messages in use. Add new ones here so every sender and listener agrees.
addon.Messages = {
    -- (moduleId, enabled) after a module was switched on or off.
    MODULE_TOGGLED = "ModeUI_ModuleToggled",
    -- () after the Class Colors settings changed.
    CLASS_COLORS_CHANGED = "ModeUI_ClassColorsChanged",
    -- (status) after a profile was created, switched, renamed, deleted or imported.
    PROFILES_CHANGED = "ModeUI_ProfilesChanged",
}
