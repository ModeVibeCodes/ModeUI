local _, addon = ...

-- Account-wide profiles of ModeUI settings (modules, positions, shared media).
-- The active profile is live; switching profiles applies on the next reload,
-- so secure frames and every module start cleanly from the new settings.
local P = {}
addon.Profiles = P
local D -- addon.Database, resolved on first use
local function DB() D = D or addon.Database; return D end
local function Root() return addon.root end

P.EXPORT_FORMAT = "ModeUI"
P.EXPORT_VERSION = 1

function P:Name(name)
    if type(name) ~= "string" or not addon.IsPublic(name) then return end
    name = name:match("^%s*(.-)%s*$")
    if #name < 1 or #name > 48 or name:find("[%z\1-\31\127|]") then return end
    return name
end

function P:List(root)
    root = root or Root()
    local names = {}
    for name in pairs(root.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function P:Active() return Root().activeProfile end
function P:Pending() return Root().pendingProfile end
function P:Exists(name) return type(name) == "string" and Root().profiles[name] ~= nil end

function P:Notify(message)
    if message then self.status = message end
    addon:SendMessage(addon.Messages.PROFILES_CHANGED, self.status)
end

local function Result(ok, message)
    if ok then P:Notify(message) else P.status = message; P:Notify() end
    return ok, message
end

local function NewName(name)
    local clean = P:Name(name)
    if not clean then return nil, "Use 1-48 characters, without | or control characters." end
    if Root().profiles[clean] then return nil, "A profile named " .. clean .. " already exists." end
    return clean
end

-- New profile from defaults, or a copy of an existing profile (the active
-- profile is copied from its live, already-saved settings).
function P:Create(name, source)
    local clean, reason = NewName(name)
    if not clean then return Result(false, reason) end
    local profile
    if source == nil then profile, reason = DB():NewProfile()
    else
        if not self:Exists(source) then return Result(false, "Profile not found.") end
        profile, reason = DB():ValidateProfile(Root().profiles[source])
    end
    if not profile then return Result(false, reason) end
    Root().profiles[clean] = profile
    return Result(true, source and ("Copied " .. source .. " to " .. clean .. ".") or ("Created " .. clean .. "."))
end

-- New profile from a built-in layout (Shared/Runtime/Layouts.lua), at the
-- places for this UI height (1080p or 1440p).
function P:CreateFromLayout(name, layout)
    local clean, reason = NewName(name)
    if not clean then return Result(false, reason) end
    local spec = addon.Layouts:Get(layout)
    if not spec then return Result(false, "Layout not found.") end
    local profile, why = addon.Layouts:Build(layout, addon.Layouts:CurrentVariant())
    if not profile then return Result(false, "Couldn't build the " .. spec.label .. " layout: " .. tostring(why)) end
    Root().profiles[clean] = profile
    return Result(true, "Created " .. clean .. " from the " .. spec.label .. " layout. Switch to it to use it.")
end

-- A copy of `source` in a theme (Shared/Runtime/Themes.lua): the theme's
-- module parts run on the copy; the source stays as it is.
function P:CreateThemed(name, source, theme)
    local clean, reason = NewName(name)
    if not clean then return Result(false, reason) end
    if not self:Exists(source) then return Result(false, "Profile not found.") end
    if not (addon.Themes:Valid(theme) and theme) then return Result(false, "Theme not found.") end
    local copy = addon.ProfileCodec.Copy(Root().profiles[source])
    copy.theme, copy.themeParts = theme, {}
    local profile, why = DB():ValidateProfile(copy)
    if not profile then return Result(false, why) end
    Root().profiles[clean] = profile
    return Result(true, "Copied " .. source .. " to " .. clean .. " in " .. addon.Themes:Label(theme) .. ". Switch to it to use it.")
end

function P:Rename(old, name)
    if not self:Exists(old) then return Result(false, "Profile not found.") end
    local clean, reason = NewName(name)
    if not clean then return Result(false, reason) end
    local root = Root()
    root.profiles[clean], root.profiles[old] = root.profiles[old], nil
    for _, key in ipairs({ "activeProfile", "pendingProfile", "failedProfile" }) do
        if root[key] == old then root[key] = clean end
    end
    if root.pendingProfile then addon.ReloadManager:Request("profile", "Switch to profile " .. root.pendingProfile .. ".") end
    return Result(true, "Renamed " .. old .. " to " .. clean .. ".")
end

function P:Delete(name)
    if not self:Exists(name) then return Result(false, "Profile not found.") end
    local root = Root()
    if name == root.activeProfile then return Result(false, "The active profile can't be deleted. Switch to another profile first.") end
    root.profiles[name] = nil
    if root.pendingProfile == name then root.pendingProfile = nil; addon.ReloadManager:Clear("profile") end
    if root.failedProfile == name then root.failedProfile = nil end
    return Result(true, "Deleted " .. name .. ".")
end

-- Choose the profile to use; it applies on the next reload.
function P:Select(name)
    if not self:Exists(name) then return Result(false, "Profile not found.") end
    local root = Root()
    if name == root.activeProfile then
        root.pendingProfile = nil; addon.ReloadManager:Clear("profile")
        return Result(true, name .. " is already the active profile.")
    end
    local valid, reason = DB():ValidateProfile(root.profiles[name])
    if not valid then return Result(false, "Can't use " .. name .. ": " .. reason) end
    root.pendingProfile = name
    addon.ReloadManager:Request("profile", "Switch to profile " .. name .. ".", function()
        if root.pendingProfile and DB():ValidateProfile(root.profiles[root.pendingProfile]) then return true end
        return false, "The selected profile is no longer valid."
    end)
    return Result(true, "Reload to switch to " .. name .. ".")
end

function P:CancelSelection()
    Root().pendingProfile = nil
    addon.ReloadManager:Clear("profile")
    return Result(true, "Kept " .. self:Active() .. ".")
end

-- Export: a versioned envelope holding only profile settings, never account data.
function P:Export(name)
    if not self:Exists(name) then return nil, "Profile not found." end
    local profile, reason = DB():ValidateProfile(Root().profiles[name])
    if not profile then return nil, reason end
    local owned = {}
    for key in pairs(DB().profileKeys) do owned[key] = profile[key] end
    local ok, text = pcall(addon.ProfileCodec.Encode,
        { format = self.EXPORT_FORMAT, version = self.EXPORT_VERSION, name = name, profile = owned })
    if ok then return text end
    return nil, tostring(text):gsub("^[^:]*:%d+: ", "")
end

function P:UniqueName(base)
    base = self:Name(base) or "Imported Profile"
    if not Root().profiles[base] then return base end
    if #base > 40 then base = base:sub(1, 40) end
    local index = 2
    while Root().profiles[base .. " (" .. index .. ")"] do index = index + 1 end
    return base .. " (" .. index .. ")"
end

-- Returns the validated profile and the name it would be saved under, or nil
-- and a reason. Strings from other addons (including Play The Game Tools) are refused.
function P:PrepareImport(text, name)
    if type(text) ~= "string" or text:match("^%s*$") then return nil, nil, "Paste a ModeUI profile string." end
    local ok, envelope = pcall(addon.ProfileCodec.Decode, text)
    if not ok or type(envelope) ~= "table" then return nil, nil, "This isn't a valid profile string." end
    if envelope.format ~= self.EXPORT_FORMAT then return nil, nil, "This profile string isn't from ModeUI." end
    if envelope.version ~= self.EXPORT_VERSION or type(envelope.profile) ~= "table" then
        return nil, nil, "This profile string comes from a different ModeUI version."
    end
    for key in pairs(envelope.profile) do
        if not DB().profileKeys[key] then return nil, nil, "The profile string contains unexpected data." end
    end
    local modules = envelope.profile.modules
    if modules ~= nil and type(modules) ~= "table" then return nil, nil, "The profile string contains unexpected data." end
    for id in pairs(modules or {}) do
        if not addon.modules[id] then return nil, nil, "The profile uses a module this version of ModeUI doesn't have." end
    end
    local resolved
    if type(name) == "string" and not name:match("^%s*$") then
        local reason
        resolved, reason = NewName(name)
        if not resolved then return nil, nil, reason end
    else resolved = self:UniqueName(envelope.name) end
    local profile, reason = DB():ValidateProfile(envelope.profile)
    if not profile then return nil, nil, reason end
    return profile, resolved
end

function P:Import(text, name)
    local profile, resolved, reason = self:PrepareImport(text, name)
    if not profile then return Result(false, reason) end
    Root().profiles[resolved] = profile
    local ok, message = Result(true, "Imported " .. resolved .. ". Switch to it to use it.")
    return ok, message, resolved
end
