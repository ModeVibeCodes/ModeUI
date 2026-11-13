local _, addon = ...
local M = addon.Windows
if not M then return end

-- Initialize(db): fills defaults and validates. Profile validation runs it on
-- detached copies, so it touches nothing but `db`. Bad data stops with an
-- error; settings are never reset. A window added to the registry later is
-- filled in as skinned; unknown window IDs (from a newer version) are kept.
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid window settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid window setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid window color: " .. key) end
        end
    end
    for id, on in pairs(db.windows) do
        assert(type(id) == "string" and type(on) == "boolean", "Invalid window switch: " .. tostring(id))
    end
    for id in pairs(M.byId) do if db.windows[id] == nil then db.windows[id] = true end end
    for key, r in pairs(M.ranges) do
        local value = db[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid window range: " .. key)
    end
end
