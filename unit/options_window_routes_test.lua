local specs, routes = {}, {}
local general = {}
local profile = { general = general, minimapButton = { hide = false } }
local rows, refreshed = {}, 0
local function Frame()
    return {
        SetPoint = function() end,
        ClearAllPoints = function() end,
        SetJustifyH = function() end,
        SetWordWrap = function() end,
        SetHeight = function(self, value) self.height = value end,
        GetHeight = function(self) return self.height or 0 end,
    }
end
_G.CreateFrame = Frame
local gui = { Colors = { textMuted = {} }, SetSearchContext = function() end }
function gui:CreateLabel() return Frame() end
function gui:CreateFormCheckbox(_, _, key, db, callback)
    return { key = key, db = db, callback = callback }
end
function gui:CreateFormSlider(_, _, _, _, _, key, db, callback)
    return { key = key, db = db, callback = callback }
end
function gui:CreateFormDropdown(_, _, _, key, db, callback)
    return { key = key, db = db, callback = callback }
end
function gui:RefreshOptionsMotion() refreshed = refreshed + 1 end
_G.QUI = { GUI = gui }
local ns = { QUI_Options = {
    RegisterFeatureTile = function(_, spec) specs[spec.id] = spec end,
    GetDB = function() return profile end,
    CreateAccentDotLabel = function() return Frame() end,
    BuildSettingRow = function(_, label, widget) return { label = label, widget = widget } end,
    CreateSettingsCardGroup = function()
        local frame = Frame()
        return {
            frame = frame,
            AddRow = function(left, right) rows[#rows + 1] = { left, right } end,
            Finalize = function() frame:SetHeight(32) end,
        }
    end,
} }
(dofile("tests/helpers/locale.lua"))(ns)
for _, path in ipairs({
    "core/settings/util.lua", "core/settings/schema.lua", "core/settings/registry.lua",
    "core/settings/nav.lua", "core/settings/provider_features.lua", "core/settings_layout_shared.lua",
    "modules/qol/settings/qol_content.lua", "modules/layout/settings/bonus_roll_provider.lua",
    "QUI_Options/tiles/global.lua", "QUI_Options/tiles/qol.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
ns.QUI_GlobalTile.Register({})
ns.QUI_QoLTile.Register({})

local expected = {
    "fpsPreset", "combatText", "automation", "popupBlocker", "quickSalvage", "consumables",
    "targetDistance", "merchantGrid", "friendsList", "extendedIgnore", "eventSounds",
    "soundMute", "notifications", "bonusRoll",
}
assert(#specs.qol.subPages == #expected, "QoL keeps every page outside Options Window")
for index, id in ipairs(expected) do
    local page = specs.qol.subPages[index]
    assert(page.id == id, "unexpected QoL page at " .. index)
    for _, route in ipairs(page.navRoutes) do
        local key = route.tabIndex .. ":" .. route.subTabIndex
        assert(not routes[key], "duplicate legacy navigation route: " .. key)
        routes[key] = { tileId = "qol", subPageIndex = index }
    end
    local featureId = page.featureId
    local nav = assert(ns.Settings.Nav:GetRoute(featureId), "missing feature navigation: " .. featureId)
    assert(nav.tileId == "qol" and nav.subPageIndex == index, "feature route disagrees with QoL page: " .. featureId)
    local legacyIndex = index < 8 and index or index + 2
    assert(page.searchContext.subTabIndex == legacyIndex, "legacy search numbering shifted: " .. id)
end
local page = specs.global.subPages[7]
assert(page.id == "optionsWindow" and page.name == "Options Window", "General owns the Options Window page")
assert(#page.featureIds == 2 and page.featureIds[1] == "quiPanel" and page.featureIds[2] == "reloadBehavior",
    "Options Window renders both existing features")
for _, route in ipairs(page.navRoutes) do
    local key = route.tabIndex .. ":" .. route.subTabIndex
    assert(not routes[key], "Options Window steals a retained QoL route")
    routes[key] = { tileId = "global", subPageIndex = 7 }
end
for _, legacyIndex in ipairs({ 8, 9 }) do
    local route = assert(routes["17:" .. legacyIndex], "missing legacy Options Window route")
    assert(route.tileId == "global" and route.subPageIndex == 7, "old Panel/Reload link must open Options Window")
end
for _, featureId in ipairs(page.featureIds) do
    local feature = assert(ns.Settings.Registry:GetFeature(featureId))
    assert(feature.category == "global" and feature.nav.tileId == "global" and feature.nav.subPageIndex == 7,
        "feature route must agree with General Options Window")
    assert(ns.QUI_QoLOptions.BuildGeneralTab(Frame(), nil, featureId) > 0, "existing feature must still render")
end
local bindings = {}
for _, cells in ipairs(rows) do
    for _, cell in ipairs(cells) do bindings[cell.widget.key] = cell.widget end
end
assert(bindings.configPanelAlpha.db == profile and bindings.hide.db == profile.minimapButton,
    "existing panel settings retain their saved-value bindings")
local tint
gui.Colors.optionsWindow = { 0.082, 0.105, 0.129, 0.98 }
gui.MainFrame = { _bg = { SetVertexColor = function(_, ...) tint = { ... } end } }
bindings.configPanelAlpha.callback(0.65)
assert(tint[1] == 0.082 and tint[3] == 0.129 and tint[4] == 0.65,
    "panel opacity updates the rounded background without requiring a native backdrop")
assert(bindings.allowReloadInCombat.db == general, "reload retains its existing saved-value binding")
local motion = assert(bindings.optionsMotion, "Options Window exposes motion preference")
assert(motion.db == general and general.optionsMotion == true, "motion defaults enabled in profile general settings")
general.optionsMotion = false
motion.callback()
assert(refreshed == 1, "changing motion refreshes active options animations")
ns.QUI_QoLOptions.BuildGeneralTab(Frame(), nil, "quiPanel")
assert(general.optionsMotion == false, "rendering must preserve disabled motion preference")
general.consumableMacros = {}
rows = {}
local macrosPage = specs.qol.subPages[6]
local macrosFeature = assert(ns.Settings.Registry:GetFeature(macrosPage.featureId))
assert(macrosFeature.id == "consumableMacros", "QoL Consumables mounts the macro editor rather than the Raid Buffs check editor")
assert(macrosFeature.sections[1].build(Frame()) > 0, "the registered QoL feature builds its actual controls")
local macroBindings = {}
for _, cells in ipairs(rows) do
    for _, cell in ipairs(cells) do
        macroBindings[cell.widget.key] = cell.widget.db
    end
end
for _, key in ipairs({ "enabled", "chatNotifications", "selectedFlask", "selectedPotion", "selectedHealth", "selectedHealthstone", "selectedAugment", "selectedVantus", "selectedWeapon" }) do
    assert(macroBindings[key] == general.consumableMacros, "native macro control retains the profile binding: " .. key)
end
assert(macroBindings.alwaysShow == nil and macroBindings.showOnReadyCheck == nil, "QoL macros excludes the separately owned consumable-check controls")
print("options_window_routes_test: ok")
