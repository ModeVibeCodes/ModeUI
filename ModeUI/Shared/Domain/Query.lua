local _, addon = ...
local Public = addon.IsPublic

-- Guarded game API calls for the Domain readers. Unit APIs may be missing on a
-- client, may error for an unknown unit, and may return secret values.
local Query = {}
addon.Domain = addon.Domain or {}
addon.Domain.Query = Query

-- pcall when the API exists: ok, ... (ok is false when it is missing or failed).
function Query.Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local Call = Query.Call

-- Only plain booleans count; a secret or failed answer is "unknown".
function Query.Truthy(fn, ...)
    local ok, v = Call(fn, ...)
    return ok and Public(v) and v == true
end

-- Up to three public return values, or nothing if any of them is secret.
function Query.Plain(fn, ...)
    local ok, v, w, x = Call(fn, ...)
    if ok and Public(v) and Public(w) and Public(x) then return v, w, x end
end

-- Up to seven return values, with any secret one replaced by nil; nothing if
-- the API is missing or failed.
function Query.Read(fn, ...)
    if type(fn) ~= "function" then return end
    local results = { pcall(fn, ...) }
    if not results[1] then return end
    for i = 2, #results do if not Public(results[i]) then results[i] = nil end end
    return unpack(results, 2, 8)
end
