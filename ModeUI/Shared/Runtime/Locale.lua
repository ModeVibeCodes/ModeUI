local _, addon = ...

-- User-facing text goes through L["English text"]. Until a translation for the
-- client's language is registered, every key returns itself, so English is
-- always the fallback. Saved settings store IDs ("sky", "left"), never labels,
-- so changing language never touches saved data.
local L = setmetatable({}, { __index = function(_, key) return key end })
addon.L = L

-- A translation file calls this once with its strings; only the client's own
-- language is applied. Untranslated keys keep falling back to English.
function addon:RegisterLocale(locale, strings)
    assert(type(locale) == "string" and #locale == 4, "ModeUI: locale code required, e.g. \"deDE\".")
    assert(type(strings) == "table", "ModeUI: locale strings must be a table.")
    if locale ~= GetLocale() then return false end
    for key, text in pairs(strings) do
        assert(type(key) == "string" and type(text) == "string", "ModeUI: locale entries must be strings.")
        rawset(L, key, text)
    end
    return true
end
