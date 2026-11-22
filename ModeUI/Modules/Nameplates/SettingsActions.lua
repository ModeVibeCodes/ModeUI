local _, addon = ...
local M, L = addon.Nameplates, addon.L
if not M then return end

-- A preview click: show that kind (and aura group) and scroll to the setting.
function M:JumpTo(kind, target, group)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    page.SetEditing(kind)
    if group and target == "indicator" then page.SetIndicatorPart(group)
    elseif group then page.SetAuraGroup(group) end
    page:Reveal(page.jumpTargets[target])
    return true
end

-- The footer's Copy To… and Reset… (Shared/Settings/Actions.lua). Copy To…
-- copies the kind being edited (read when the menu opens) to the other;
-- Reset… resets one kind or both. Whether each kind uses ModeUI plates stays.
local COPY = {
    enemy = { to = "friendly", label = "Enemy style to Friendly plates",
        prompt = "Copy the whole look of Enemy plates to Friendly plates? Whether each kind uses ModeUI plates stays its own." },
    friendly = { to = "enemy", label = "Friendly style to Enemy plates",
        prompt = "Copy the whole look of Friendly plates to Enemy plates? Whether each kind uses ModeUI plates stays its own." },
}
local RESET = {
    { kinds = { "enemy" }, label = "Enemy plates", prompt = "Put every Enemy plates setting back to its default? Use ModeUI Plates stays as it is." },
    { kinds = { "friendly" }, label = "Friendly plates", prompt = "Put every Friendly plates setting back to its default? Use ModeUI Plates stays as it is." },
    { kinds = { "enemy", "friendly" }, label = "All of Nameplates", prompt = "Put every Nameplates setting back to its default? Use ModeUI Plates stays as it is for each kind." },
}
function M:CopyActions()
    local from = self.page and self.page.nameplateEditing and self.page.nameplateEditing() or "enemy"
    local copy = COPY[from]
    return { { label = L[copy.label], prompt = L[copy.prompt], run = function() M:CopyStyle(from, copy.to) end } }
end
function M:ResetScopes()
    local items = {}
    for _, scope in ipairs(RESET) do
        items[#items + 1] = { label = L[scope.label], prompt = L[scope.prompt],
            run = function() for _, kind in ipairs(scope.kinds) do M:ResetSettings(kind) end end }
    end
    return items
end
