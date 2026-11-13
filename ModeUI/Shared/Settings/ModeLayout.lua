local _,addon=...
local W,T=addon.ConfigWidgets,addon.InterfaceTheme

-- Each module may declare a presentation plan as module.modeLayout (never a
-- saved setting). With { decorateOnly = true } the page keeps its own sections
-- and cards, and the Mode layer only compacts color rows: each becomes one
-- field with the swatch and the hex value in muted text; clicking it picks.

local function CompactColors(page)
    for _,color in ipairs(page.settingsColors or {}) do
        color.hex:Hide();if color.apply then color.apply:Hide() end
        local pick=color.pick
        pick.compactHex=true
        pick:SetLabelColor(T.muted)
        pick.label:SetText(color.hex:GetText() or "")
        pick:SetWidth(96)
    end
end

-- Existing rows, controls, callbacks, search entries and visibility predicates
-- remain the owners of their behavior. This layer only restyles them.
function W.ApplyModeModuleLayout(page,id)
    if T.id~="mode" or page.modeLayout then return end
    local module=addon.modules[id]
    local plan=module and module.modeLayout
    if not plan then return end
    page.modeFooterLayout=true
    CompactColors(page)
    page.modeLayout={plan=plan}
end
