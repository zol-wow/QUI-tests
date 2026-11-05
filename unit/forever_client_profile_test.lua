local env = dofile("tools/_addon_env.lua")
local h = env.BuildHarness()
local ns = h.ns
local function client(version, interfaceVersion)
    _G.GetBuildInfo = function() return version, "69893", "", interfaceVersion end
    assert(loadfile("core/client.lua"))("QUI", ns)
end

client("1.60.1", 16001)
assert(ns.Client.isForever and ns.Client.flavor == "forever")
assert(ns.Client.interfaceVersion == 16001 and ns.Client.build == "69893")
h.db.profile.general.font = "Forever font"
local foreverExport = h.QUICore:ExportProfileToString()
assert(foreverExport:match("^QUI1:"))
local ok, err = h.QUICore:ImportProfileFromString(foreverExport, "Forever")
assert(ok, tostring(err))
assert(h.db.profile._quiClient == nil, "export metadata must not become a saved setting")

client("12.1.5", 120105)
assert(not ns.Client.isForever and ns.Client.flavor == "retail")
h.db.profile.general.font = "Retail font"
ok, err = h.QUICore:ImportProfileFromString(foreverExport, "FromForever")
assert(ok, "Forever profiles must import into Retail: " .. tostring(err))
assert(h.db:GetCurrentProfile() == "FromForever" and h.db.profile.general.font == "Forever font",
    "cross-client full imports must apply settings to the selected profile")
assert(h.db.profile._quiClient == nil, "client metadata must not become a saved setting")

h.db.profile.general.font = "Retail font"
local retailExport = h.QUICore:ExportProfileToString()
local retailTheme = assert(h.QUICore:ExportProfileSelectionToString({ "theme" }))
client("1.60.1", 16001)
h.db.profile.general.font = "Forever font"
local analyzed, preview = h.QUICore:AnalyzeProfileImportString(retailExport)
assert(analyzed and type(preview.categories) == "table", "cross-client import preview must work")
local sanitized, payload, _, stripped, sanitizeError = h.QUICore:SanitizeProfileImportString(retailExport)
assert(sanitized and #stripped == 0, "valid Retail settings must survive sanitization: " .. tostring(sanitizeError))
assert(payload._quiClient == "retail" and payload.general.font == "Retail font",
    "sanitization must preserve the source data")
ok, err = h.QUICore:ImportProfileFromString(retailExport, "FromRetail")
assert(ok, "Retail profiles must import into Forever: " .. tostring(err))
assert(h.db.profile.general.font == "Retail font", "Retail full import must apply settings")
assert(h.db.profile._quiClient == nil, "client metadata must not become a saved setting")

h.db.profile.general.font = "Forever font"
ok, err = h.QUICore:ImportProfileSelectionFromString(retailTheme, { "theme" })
assert(ok and h.db.profile.general.font == "Retail font",
    "selected Retail exports must import into Forever: " .. tostring(err))
h.db.profile.general.font = "Forever font"
ok, err = h.QUICore:ImportProfileFromValidatedPayload(payload, "RetailDirect")
assert(ok and h.db.profile.general.font == "Retail font",
    "validated cross-client full import must apply settings: " .. tostring(err))
h.db.profile.general.font = "Forever font"
ok, err = h.QUICore:ImportProfileSelectionFromValidatedPayload(payload, { "theme" })
assert(ok and h.db.profile.general.font == "Retail font",
    "validated cross-client selection must apply settings: " .. tostring(err))

local before = h.db:GetCurrentProfile()
ok, err = h.QUICore:ImportProfileFromValidatedPayload({ _quiClient = "retail", general = false }, "InvalidShape")
assert(not ok and err:find("incompatible setting types", 1, true),
    "cross-client imports must still validate setting types")
ok, err = h.QUICore:ImportProfileFromValidatedPayload({ _quiClient = "retail", bad = function() end }, "InvalidTree")
assert(not ok and err:find("unsupported value type", 1, true),
    "cross-client imports must still reject unsupported values")
assert(h.db:GetCurrentProfile() == before, "invalid imports must not switch profiles")

client("12.1.5", 120105)
h.db.global.nameplateProfiles = { Retail = { simplified = { scale = 1.25 } } }
local plates = assert(h.QUICore:ExportNameplateProfileToString("Retail"))
ok, err = h.QUICore:ImportNameplateProfileFromString(plates, "RetailCopy")
assert(ok, "same-client nameplate import must work: " .. tostring(err))
client("1.60.1", 16001)
ok, err = h.QUICore:ImportNameplateProfileFromString(plates, "ForeverPlates")
assert(ok, "Retail nameplate profiles must import into Forever: " .. tostring(err))
assert(h.db.global.nameplateProfiles.ForeverPlates.simplified.scale == 1.25,
    "cross-client nameplate import must preserve settings")

ns.Client = nil
local legacyExport = h.QUICore:ExportProfileToString()
client("12.1.5", 120105)
ok, err = h.QUICore:ImportProfileFromString(legacyExport, "LegacyRetail")
assert(ok, "existing untagged Retail exports must still import: " .. tostring(err))
client("1.15.9", 11509)
assert(not ns.Client.isForever, "Classic Era must not be identified as Forever")
client("16.0.1", 160001)
assert(not ns.Client.isForever, "a six-digit Retail interface is not Forever")

print("OK: Forever identity and cross-client profile imports")
