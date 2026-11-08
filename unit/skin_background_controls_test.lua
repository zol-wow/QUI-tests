local ns = dofile("tools/_addon_env.lua").LoadCore()
local controls
local providers, features = {}, {}
local profile = { general = { skinBgColor = { .2, .3, .4, .6 } }, loot = {}, lootRoll = {} }
local refreshes = { readyCheck = 0, alerts = 0, swingTimers = 0 }
local frame = { GetHeight = function() return 80 end }
local widget = { SetEnabled = function() end }
local layout = {
    sections = {},
    headerAt = function() end,
    sectionAt = function() return { frame = frame, AddRow = function() end } end,
    closeSection = function() end,
    finish = function() return 80 end,
    relayoutSections = function() end,
}
ns.Helpers.GetProfile = function() return profile end
ns.Helpers.GetCore = function() return { db = { profile = profile } } end
QUI.GetSkinBgColor = function() return unpack(profile.general.skinBgColor) end
QUI.GUI = {
    SetSearchContext = function() end,
    SetSearchSection = function() end,
    CreateFormCheckbox = function(_, _, _, key, db, apply)
        controls[key] = { db = db, apply = apply }
        return widget
    end,
    CreateFormColorPicker = function(_, _, _, key, db, apply, options)
        controls[key] = { db = db, apply = apply, options = options }
        return widget
    end,
    CreateFormSlider = function() return widget end,
    CreateFormDropdown = function() return widget end,
}
ns.L = setmetatable({}, { __index = function(_, key) return key end })
ns.QUI_Options = {
    GetDB = function() return profile end,
    BuildSettingRow = function(_, _, control) return control end,
}
ns.QUI_SettingsLayoutShared = { MakeLayout = function() return layout end }
ns.QUI_BorderControl = { Attach = function() return widget, widget end }
ns.QUI_LayoutMode_Settings = {
    RegisterSharedProvider = function(_, key, provider) providers[key] = provider end,
}
ns.QUI_LayoutMode_Utils = {
    BuildPositionCollapsible = function() end,
    BuildOpenFullSettingsLink = function() end,
}
ns.Settings = {
    Registry = { RegisterFeature = function(_, feature) features[feature.id] = feature end },
    Schema = { Feature = function(value) return value end, Section = function(value) return value end },
}
ns.SwingTimers = {
    entries = {},
    IsEnabled = function() return false end,
    SetEnabled = function() end,
    Refresh = function() refreshes.swingTimers = refreshes.swingTimers + 1 end,
}
_G.QUI_RefreshReadyCheckColors = function() refreshes.readyCheck = refreshes.readyCheck + 1 end
_G.QUI_RefreshAlertColors = function() refreshes.alerts = refreshes.alerts + 1 end
assert(loadfile("modules/utility/settings/ready_check_provider.lua"))("QUI", ns)
assert(loadfile("modules/skinning/settings/skinning_content.lua"))("QUI", ns)
assert(loadfile("modules/qol/settings/swing_timers_content.lua"))("QUI", ns)

local builders = {
    readyCheck = function() providers.readyCheck.build(frame, "readyCheck") end,
    alerts = function() ns.QUI_SkinningOptions.BuildSkinningTab(frame) end,
    swingTimers = function() features.swingTimersPage.sections[1].build(frame) end,
}
for _, prefix in ipairs(arg[1] and { arg[1] } or { "readyCheck", "alerts", "swingTimers" }) do
    controls = {}
    builders[prefix]()
    local override = assert(controls[prefix .. "BgOverride"], prefix .. " settings must expose the background override")
    local hidden = assert(controls[prefix .. "HideBackground"], prefix .. " settings must expose background visibility")
    local color = assert(controls[prefix .. "BackgroundColor"], prefix .. " settings must expose background color and alpha")
    assert(override.db == profile.general and hidden.db == profile.general and color.db == profile.general,
        "feature controls must edit the same general fields as centralized background settings")
    assert(not color.options or not color.options.noAlpha, "background pickers must allow transparent colors")
    assert(not profile.general[prefix .. "BgOverride"], "opening settings must preserve inherited backgrounds")
    local initialColor = profile.general[prefix .. "BackgroundColor"]
    assert(initialColor[1] == .2 and initialColor[4] == .6 and initialColor ~= profile.general.skinBgColor,
        "new custom colors must start from the global color without sharing its table")
    local function change(control, key, value)
        local before = refreshes[prefix]
        control.db[key] = value
        control.apply(value)
        assert(refreshes[prefix] > before, "background changes must immediately refresh their feature")
    end
    change(override, prefix .. "BgOverride", true)
    change(color, prefix .. "BackgroundColor", { .7, .8, .9, .25 })
    local r, g, b, a = ns.Helpers.GetSkinBgColorWithOverride(profile.general, prefix)
    assert(r == .7 and g == .8 and b == .9 and a == .25, "local colors must reach the runtime background resolver")
    local sr, sg, sb, sa = ns.Helpers.GetSkinBgColorWithOverride(profile.general, "untouched")
    assert(sr == .2 and sg == .3 and sb == .4 and sa == .6, "local edits must preserve other surfaces")
    change(hidden, prefix .. "HideBackground", true)
    local _, _, _, hiddenAlpha = ns.Helpers.GetSkinBgColorWithOverride(profile.general, prefix)
    assert(hiddenAlpha == 0, "hide background must remove only the local fill")
    change(override, prefix .. "BgOverride", false)
    local _, _, _, inheritedAlpha = ns.Helpers.GetSkinBgColorWithOverride(profile.general, prefix)
    assert(inheritedAlpha == .6, "disabling override must restore the global background even if locally hidden")
    builders[prefix]()
    assert(profile.general[prefix .. "BackgroundColor"][1] == .7, "reopening settings must retain the custom color")
end
print("OK: skin background controls preserve inheritance and edit the runtime fields")
