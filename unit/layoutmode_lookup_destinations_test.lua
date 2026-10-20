local ns = {
    L = setmetatable({}, { __index = function(_, key) return "localized:" .. key end }),
    Helpers = {},
    QUI_Options = {},
    QUI_ModulesSettingsLayout = { NINE_POINT_OPTIONS = {} },
}
QUI = { GUI = { Colors = {} } }

local function load(path)
    assert(loadfile(path))("QUI", ns)
end

load("core/settings/util.lua")
load("core/settings/registry.lua")
load("core/settings/schema.lua")
load("core/settings/nav.lua")
load("core/settings/surface_features.lua")
ns.Settings.Fields = {
    Dropdown = function(spec) return spec end,
    Button = function(spec) return spec end,
}
ns.Settings.RenderAdapters = {}

local navigated
ns.QUI_UnitFramesSettingsSurface = {
    SetSelectedUnit = function(unit) navigated = { unit = unit } end,
    NavigateSearchEntry = function(entry)
        navigated = { unit = entry.surfaceUnitKey, tab = entry.surfaceTabKey }
        return true
    end,
}

load("QUI_UnitFrames/unitframes/settings/unit_frames.lua")
load("QUI_ActionBars/actionbars/settings/action_bars.lua")
load("QUI_ActionBars/actionbars/settings/action_bars_per_bar.lua")
load("modules/layout/settings/third_party_anchoring_content.lua")

local Nav = ns.Settings.Nav
for _, entry in ipairs({
    { "playerFrame", "player", "frame" },
    { "targetFrame", "target", "frame" },
    { "totFrame", "targettarget", "frame" },
    { "focusFrame", "focus", "frame" },
    { "petFrame", "pet", "frame" },
    { "bossFrames", "boss", "frame" },
    { "playerCastbar", "player", "castbar" },
    { "targetCastbar", "target", "castbar" },
    { "focusCastbar", "focus", "castbar" },
    { "petCastbar", "pet", "castbar" },
    { "totCastbar", "targettarget", "castbar" },
}) do
    local route, feature = Nav:GetLookupTarget(entry[1])
    assert(route.tileId == "unit_frames" and route.subPageIndex == 1)
    assert(route.surfaceUnitKey == entry[2], entry[1] .. " must select its unit")
    assert(route.surfaceTabKey == entry[3], entry[1] .. " must select its settings tab")
    feature.onNavigate(entry[1])
    assert(navigated.unit == entry[2])
    assert(feature.searchNavigate(route))
    assert(navigated.unit == entry[2] and navigated.tab == entry[3])
end

for _, entry in ipairs({
    { "buffFrame", "auras", 4, "localized:Buffs" },
    { "debuffFrame", "auras", 4, "localized:Debuffs" },
    { "extraActionButton", "action_bars", 6, "localized:Extra Action Button" },
    { "zoneAbility", "action_bars", 6, "localized:Zone Ability" },
    { "dandersParty", "global", 5, "DandersFrames \226\128\148 localized:Party Frames" },
    { "dandersRaid", "global", 5, "DandersFrames \226\128\148 localized:Raid Frames" },
    { "dandersPinned1", "global", 5, "DandersFrames \226\128\148 localized:Pinned Set 1" },
    { "dandersPinned2", "global", 5, "DandersFrames \226\128\148 localized:Pinned Set 2" },
}) do
    local route = assert(Nav:GetLookupTarget(entry[1]))
    assert(route.tileId == entry[2] and route.subPageIndex == entry[3])
    assert(route.scrollToLabel == entry[4], entry[1] .. " must target its localized subsection")
end

print("OK: mover lookup routes select matching unit tabs and localized subsections")
