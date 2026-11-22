-- Standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs"): every Interface
-- and Panels module page uses only the standard tab names, in the standard
-- order, each tab holding at least one setting, and none of the retired
-- labels of the glossary; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

-- The pages of the element modules (Interface and Panels). System pages
-- (Profiles, Optimizations, Class Colors, Appearance) keep their own tabs.
local ELEMENTS = { "actionBars", "bags", "buffsDebuffs", "chat", "damageMeters", "minimap", "nameplates",
    "partyFrames", "tooltip", "unitFrames", "windows" }

local checked = ELEMENTS

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS, obsidian = true })
local LIST = #checked > 0 and ("{ \"" .. table.concat(checked, "\", \"") .. "\" }") or "{}"
local problems = world.run("local ELEMENTS = " .. LIST .. [[

    SlashCmdList.MODEUI()
    local window, W = addon.configWindow, addon.ConfigWidgets
    local problems = {}
    local function Add(text) problems[#problems + 1] = text end
    local function Retired(text)
        if type(text) ~= "string" then return nil end
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        return W.RETIRED_LABELS[text] and text
    end
    -- Every text in a row, its cells and controls (three levels down).
    local function Texts(frame, depth, found)
        if depth > 3 then return end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:GetObjectType() == "FontString" then found[#found + 1] = region:GetText() end
        end
        for _, child in ipairs({ frame:GetChildren() }) do Texts(child, depth + 1, found) end
    end
    for _, id in ipairs(ELEMENTS) do
        if not addon.modules[id] then Add(id .. ": no such module")
        else
            addon:SelectConfigPage(id)
            local page = window.pages[id]
            if not page.standardTabs then Add(id .. ": tabs not made with W.StandardTabs") end
            local last, counts = 0, {}
            for _, section in ipairs(page.sectionTabs and page.sectionTabs.sections or page.sections) do
                local index = W.STANDARD_TAB_INDEX[section.title]
                if not index then Add(id .. ": tab '" .. tostring(section.title) .. "' is not a standard tab")
                elseif index <= last then Add(id .. ": tab '" .. section.title .. "' out of the standard order")
                else last = index end
                counts[section] = 0
            end
            for _, row in ipairs(page.rows) do
                if row.section and counts[row.section] and row.settingsTitle and not row.settingsQuiet then
                    counts[row.section] = counts[row.section] + 1
                end
                for _, title in ipairs({ row.settingsTitle, row.settingsGroupTitle }) do
                    local old = Retired(title)
                    if old then Add(id .. ": retired label '" .. old .. "' (use " .. W.RETIRED_LABELS[old] .. ")") end
                end
                local found = {}
                Texts(row, 0, found)
                for _, text in ipairs(found) do
                    local old = Retired(text)
                    if old then Add(id .. ": retired label '" .. old .. "' in a control (use " .. W.RETIRED_LABELS[old] .. ")") end
                end
            end
            for section, count in pairs(counts) do
                if count == 0 then Add(id .. ": tab '" .. section.title .. "' has no settings") end
            end
        end
    end
    table.sort(problems)
    local seen, unique = {}, {}
    for _, text in ipairs(problems) do if not seen[text] then seen[text] = true; unique[#unique + 1] = text end end
    return unique
]], "settings_taxonomy")

if #problems > 0 then
    error("standard tabs: " .. #problems .. " problem(s)\n  " .. table.concat(problems, "\n  "), 0)
end
print("standard tabs: every element page uses the standard tabs and terms")
