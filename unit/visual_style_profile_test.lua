local env = dofile("tools/_addon_env.lua")
local h = env.LoadHarness({
    QUI_DB = {
        profileKeys = { ["TestChar - TestRealm"] = "Default" },
        profiles = {
            Default = {
                _defaultsVersion = 3,
                _shippedDefaults = { general = { texture = "Quazii v5", font = "Quazii" } },
                general = {
                    texture = "Flat", font = "Custom Font", themePreset = "Custom",
                    addonAccentColor = { 0.12, 0.34, 0.56, 1 }, skinGameMenu = false,
                    skinBgColor = { 0.2, 0.1, 0.05, 0.4 },
                },
                frameAnchoring = { customFrame = { offsetX = 123, offsetY = -45 } },
            },
            Legacy = {
                _defaultsVersion = 3,
                general = { visualStyle = "Legacy", texture = "Flat", skinGameMenu = true },
            },
        },
        global = { _shippedProfileDefaults = { general = { texture = "Quazii v5" } } },
    },
}, { noSeed = true })

h.ns.Compatibility.RunShippedDefaultsMaintenance(h.db)
local p = h.db.profile
assert(h.defaults.profile.general.visualStyle == "Satin")
assert(p.general.visualStyle == "Satin", "old snapshot must inherit new visual style")
assert(p.general.texture == "Flat" and p.general.font == "Custom Font")
assert(p.general.themePreset == "Custom" and p.general.addonAccentColor[2] == 0.34)
assert(p.general.skinGameMenu == false)
assert(p.general.skinBgColor[1] == 0.2 and p.general.skinBgColor[2] == 0.1
    and p.general.skinBgColor[3] == 0.05 and p.general.skinBgColor[4] == 0.4,
    "existing custom background must survive visual style enablement")
assert(p.frameAnchoring.customFrame.offsetX == 123 and p.frameAnchoring.customFrame.offsetY == -45)

h.db:SetProfile("Legacy")
assert(h.db.profile.general.visualStyle == "Legacy", "explicit legacy choice must survive maintenance")
assert(h.db.profile.general.texture == "Flat" and h.db.profile.general.skinGameMenu == true)
h.db:SetProfile("Default")
h.db.profile.general.visualStyle = "Legacy"
local themeString = assert(h.QUICore:ExportProfileSelectionToString({ "theme" }))
h.db.profile.general.visualStyle = "Satin"
local ok, err = h.QUICore:ImportProfileSelectionFromString(themeString, { "theme" })
assert(ok, err)
assert(h.db.profile.general.visualStyle == "Legacy", "theme import must carry visual style")

h.db.profile.general.visualStyle = "Legacy"
local sourceString = assert(h.QUICore:ExportProfileToString())
h.db.profile.general.visualStyle = "Satin"
ok, err = h.QUICore:ImportProfileSelectionFromString(sourceString, { "qol" })
assert(ok, err)
assert(h.db.profile.general.visualStyle == "Satin", "unchecked theme must preserve visual style")
assert(h.db.profile.general.texture == "Flat" and h.db.profile.general.themePreset == "Custom")
assert(h.db.profile.general.skinBgColor[1] == 0.2 and h.db.profile.general.skinBgColor[4] == 0.4)
assert(h.db.profile.frameAnchoring.customFrame.offsetX == 123)

local fresh = env.LoadHarness(nil)
local function assertCharcoal(profile)
    for i, value in ipairs({ 0.0745, 0.1059, 0.1176, 1 }) do
        assert(profile.general.skinBgColor[i] == value, "fresh profile must use charcoal background")
    end
end
assert(fresh.db.profile.general.visualStyle == "Satin")
assert(fresh.db.profile.general.themePreset == "Satin Gold")
assertCharcoal(fresh.db.profile)
fresh.db:SetProfile("New Profile")
assert(fresh.db.profile.general.visualStyle == "Satin")
assert(fresh.db.profile.general.themePreset == "Satin Gold")
assertCharcoal(fresh.db.profile)

print("visual_style_profile_test: OK")
