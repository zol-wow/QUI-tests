local function RunSettings(forever)
    local controls, profile = {}, { general = {}, loot = {}, lootRoll = {} }
    local widget = { SetEnabled = function() end }
    local gui = {
        SetSearchContext = function() end,
        CreateFormCheckbox = function(_, _, _, key, db, apply)
            controls[key] = { db = db, apply = apply }
            return widget
        end,
        CreateFormSlider = function() return widget end,
        CreateFormDropdown = function() return widget end,
        CreateFormColorPicker = function() return widget end,
    }
    QUI = { GUI = gui }
    local layout = {
        headerAt = function() end,
        sectionAt = function() return { frame = {}, AddRow = function() end } end,
        closeSection = function() end,
        finish = function() end,
    }
    local ns = {
        Client = { isForever = forever },
        L = setmetatable({}, { __index = function(_, key) return key end }),
        Helpers = { GetCore = function() return QUI end },
        QUI_Options = {
            GetDB = function() return profile end,
            BuildSettingRow = function(_, _, control) return control end,
        },
        QUI_SettingsLayoutShared = { MakeLayout = function() return layout end },
        QUI_BorderControl = { Attach = function() return widget, widget end },
    }
    assert(loadfile(arg[1] or "modules/skinning/settings/skinning_content.lua"))("QUI", ns)
    ns.QUI_SkinningOptions.BuildSkinningTab({})
    assert(controls.skinInstanceFrames and controls.skinProfessions and controls.skinSpellBook,
        "both clients must retain their supported native panel settings")
    if forever then
        assert(controls.skinLegacySystem and controls.skinStable,
            "Forever must expose selectable Legacy and pet stable skins")
        assert(controls.skinLegacySystem.db == profile.general and controls.skinStable.db == profile.general,
            "Forever skin controls must save to the active general settings")
        assert(profile.general.skinLegacySystem == false and profile.general.skinStable == false,
            "new optional skins must start disabled")
        assert(not controls.skinKeystoneFrame,
            "Forever excludes ChallengesUI and must not offer an unusable Keystone skin")
    else
        assert(not controls.skinLegacySystem and not controls.skinStable,
            "Forever-specific skins must stay out of Retail settings")
        assert(controls.skinKeystoneFrame, "Retail must retain its Keystone skin setting")
    end
    return controls, profile
end

local foreverControls, foreverProfile = RunSettings(true)
local retailControls, retailProfile = RunSettings(false)

local harness = dofile("tools/_addon_env.lua").BuildHarness({ noSeed = true })
local core = harness.QUICore
assert(harness.defaults.profile.general.skinLegacySystem == false
    and harness.defaults.profile.general.skinStable == false,
    "new skins must have explicit optional profile defaults")
local skinKeys = {}
for _, world in ipairs({ { foreverControls, foreverProfile }, { retailControls, retailProfile } }) do
    for key, control in pairs(world[1]) do
        if control.db == world[2].general and key:match("^skin%u") then
            skinKeys[key] = true
            core.db.profile.general[key] = true
        end
    end
end
local exported = assert(core:ExportProfileSelectionToString({ "skinning" }))
core.db:SetProfile("Forever skin import")
for key in pairs(skinKeys) do core.db.profile.general[key] = false end
core.db.profile.general.autoRepair = "off"
assert(core:ImportProfileSelectionFromString(exported, { "skinning" }))
for key in pairs(skinKeys) do
    assert(core.db.profile.general[key] == true,
        "selective skin imports must carry the visible " .. key .. " choice")
end
assert(core.db.profile.general.autoRepair == "off", "skin imports must preserve unrelated gameplay settings")

print("OK: Forever skin settings follow native availability and survive selective export/import")
