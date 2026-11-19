local _, addon = ...

-- Built-in layouts (owner, November 18, 2026): a whole screen of ModeUI
-- settings a profile starts from. Each module adds its own part of a layout
-- (Modules/<Name>/Layouts.lua, or a companion's), so a layout never reaches
-- into another module's settings. A layout builds a new profile; it never
-- changes an existing one, so nothing the player placed moves.
--   addon.Layouts:Register(id, { label = "DPS / Tank", profileName = "Mode-Default", seed = true, allModules = true })
-- `allModules`: every module (but alwaysOn and planned ones) starts on.
--   addon.Layouts:Contribute(id, moduleId, function(db, ctx) ... end)
--   addon.Layouts:Build(id, variant) -> profile, or nil and a reason
-- `db` is the module's settings in a fresh profile (its defaults filled in);
-- `ctx` gives the screen variant and writes Edit Mode places and matches:
--   ctx.variant            "1080" or "1440" (the game's UI height, nearest)
--   ctx.V(values)          values[ctx.variant], else values["1080"]
--   ctx.Place(elementId, target, point, relativePoint, x, y)
--   ctx.Match(elementId, axis, targetElementId)   Edit Mode's Match Width/Height pick
--   ctx.modules            every module's settings in the profile being built
-- The values come from the owner's layout editor (the DPS / Tank canvas,
-- saved November 18, 2026); docs/ARCHITECTURE.md, "Layouts".
local L = { layouts = {}, order = {}, parts = {} }
addon.Layouts = L

-- The two UI heights a layout has places for: 1080p and 1440p at the
-- pixel-perfect scale (1 UI unit = 1 physical pixel). Taller UIs take 1440's.
L.VARIANTS = { "1080", "1440" }
function L.Variant(height)
    return addon.IsNumber(height, 1, 100000) and height >= 1260 and "1440" or "1080"
end

function L:Register(id, spec)
    assert(type(id) == "string" and id ~= "" and not self.layouts[id], "ModeUI: Layouts:Register(id, spec) with a new id.")
    assert(type(spec) == "table" and type(spec.label) == "string" and addon.Profiles:Name(spec.profileName) == spec.profileName,
        "ModeUI: a layout needs a label and a valid profile name.")
    self.layouts[id] = spec
    self.order[#self.order + 1] = id
    self.parts[id] = {}
end
function L:Get(id) return self.layouts[id] end

function L:Contribute(id, moduleId, fn)
    assert(self.layouts[id], "ModeUI: unknown layout " .. tostring(id))
    assert(type(moduleId) == "string" and type(fn) == "function", "ModeUI: Layouts:Contribute(id, moduleId, fn).")
    for _, part in ipairs(self.parts[id]) do assert(part.module ~= moduleId, "ModeUI: " .. moduleId .. " already adds to " .. id) end
    local parts = self.parts[id]
    parts[#parts + 1] = { module = moduleId, fn = fn }
end

local function Context(profile, variant)
    local ctx = { variant = variant, modules = profile.modules }
    function ctx.V(values) return values[variant] ~= nil and values[variant] or values["1080"] end
    function ctx.Place(elementId, target, point, relativePoint, x, y)
        local position = { target = target, placement = "center", point = point, relativePoint = relativePoint, x = x, y = y }
        local ok, reason = addon.PositionManager:ValidatePosition(position, true)
        assert(ok, "invalid place for " .. tostring(elementId) .. ": " .. tostring(reason))
        profile.positions[elementId] = position
    end
    function ctx.Match(elementId, axis, targetId)
        assert(axis == "width" or axis == "height", "invalid match axis")
        profile.sizeMatches[elementId] = profile.sizeMatches[elementId] or {}
        profile.sizeMatches[elementId][axis] = targetId
    end
    return ctx
end

-- A new profile: every module's defaults, then each installed module's part
-- of the layout, then the same check an imported profile gets.
function L:Build(id, variant)
    local spec = self.layouts[id]
    if not spec then return nil, "Unknown layout." end
    variant = variant == "1440" and "1440" or "1080"
    local profile, reason = addon.Database:NewProfile()
    if not profile then return nil, reason end
    if spec.allModules then
        for moduleId, module in pairs(addon.modules) do
            local db = profile.modules[moduleId]
            if type(db) == "table" and db.enabled ~= nil and not module.alwaysOn and not module.planned then db.enabled = true end
        end
    end
    local ctx = Context(profile, variant)
    for _, part in ipairs(self.parts[id]) do
        local db = addon.modules[part.module] and profile.modules[part.module]
        if db then
            local ok, err = pcall(part.fn, db, ctx)
            if not ok then return nil, part.module .. ": " .. tostring(err):gsub("^[^:]*:%d+: ", "") end
        end
    end
    return addon.Database:ValidateProfile(profile)
end

-- The UI height now, for the variant a new profile takes.
function L:CurrentVariant()
    local ok, height = pcall(UIParent.GetHeight, UIParent)
    return self.Variant(ok and height or nil)
end

-- Once per account (ModeUIDB.builtLayouts), a layout marked `seed` becomes
-- its own profile, unless a profile already has that name. It is never made
-- active here: the player switches to it on the Profiles page. Runs at
-- PLAYER_LOGIN, when every companion addon has registered its module.
function L:Seed()
    local root = addon.root
    if not addon.initialized or type(root) ~= "table" then return end
    for _, id in ipairs(self.order) do
        local spec = self.layouts[id]
        if spec.seed and not root.builtLayouts[id] then
            root.builtLayouts[id] = true
            if not addon.Profiles:Exists(spec.profileName) then
                local ok, message = addon.Profiles:CreateFromLayout(spec.profileName, id)
                if ok then addon:PrintAction("New profile " .. spec.profileName .. " (" .. spec.label .. " layout). Switch to it in /modeui, Profiles.", "info")
                else addon:PrintAction(tostring(message), "warning") end
            end
        end
    end
end

addon.Events:On(L, "PLAYER_LOGIN", function() L:Seed() end)

-- Mode's own layout for damage dealers and tanks, with every module on.
L:Register("mode-default", { label = "DPS / Tank", profileName = "Mode-Default", seed = true, allModules = true })
-- Mode's healer layout (owner, November 19, 2026; the prototype in
-- design/healer-layout/): a mana frame over the party column left of
-- center, everything else as DPS / Tank but the Cooldown Manager's middle.
L:Register("healer", { label = "Healer", profileName = "Mode-Healer", seed = true, allModules = true })
