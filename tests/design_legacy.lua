-- Files that predate the Mode design standard, with how many uses of each
-- banned pattern they still hold (see tests/design.lua). Counts only go down;
-- an entry goes when its file is clean. Never add a file here.
return {
    ["ModeCDM/Modules/CooldownManager/Bars.lua"] = { bar = 1 },
    ["ModeCDM/Modules/CooldownManager/Settings.lua"] = { color = 1 },
    ["ModeCDM/Modules/CooldownManager/SettingsTabs.lua"] = { color = 1 },
    ["ModeCDM/Modules/CooldownManager/SpellMenu.lua"] = { color = 1 },
    ["Modules/ActionBars/Init.lua"] = { color = 5 },
    ["Modules/ActionBars/Keybind.lua"] = { color = 1 },
    ["Modules/ActionBars/Settings.lua"] = { color = 2 },
    ["Modules/Minimap/Shape.lua"] = { mask = 1 }, -- Minimap:SetMaskTexture, the map's own shape
    ["Modules/Nameplates/Init.lua"] = { color = 10 },
    ["Modules/Nameplates/Migrations.lua"] = { color = 1 },
    ["Modules/PartyFrames/AuraInit.lua"] = { color = 1 },
    ["Modules/PartyFrames/Init.lua"] = { color = 6 },
    ["Modules/UnitFrames/Init.lua"] = { color = 11 },
    ["Modules/Windows/Init.lua"] = { color = 22 },
    ["Shared/Domain/Power.lua"] = { color = 2 },
    ["Shared/Kit/Palette.lua"] = { color = 18 },
    ["Shared/Kit/Points.lua"] = { bar = 1 },
    ["Shared/Kit/Shape.lua"] = { bar = 4 },
    ["Shared/Kit/Text.lua"] = { color = 1 },
    ["Shared/Media/MediaCatalog.lua"] = { font = 26 },
    ["Shared/Media/Textures.lua"] = { path = 1 },
    ["Shared/Placement/PositionHighlights.lua"] = { color = 4 },
    ["Shared/Runtime/Feedback.lua"] = { color = 2 },
    ["Shared/Settings/Widgets/Core.lua"] = { color = 6 },
}
