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
local foreverExport = h.QUICore:ExportProfileToString()
assert(foreverExport:match("^QUI1:"))
local ok, err = h.QUICore:ImportProfileFromString(foreverExport, "Forever")
assert(ok, tostring(err))
assert(h.db.profile._quiClient == nil, "export metadata must not become a saved setting")

client("12.1.5", 120105)
assert(not ns.Client.isForever and ns.Client.flavor == "retail")
local before = h.db:GetCurrentProfile()
ok, err = h.QUICore:ImportProfileFromString(foreverExport, "WrongClient")
assert(not ok and err:find("different WoW client", 1, true), tostring(err))
assert(h.db:GetCurrentProfile() == before, "rejected import must not switch profiles")
local sanitized, _, _, _, sanitizeError = h.QUICore:SanitizeProfileImportString(foreverExport)
assert(not sanitized and sanitizeError:find("different WoW client", 1, true),
    "sanitization must not strip the client boundary")
local analyzed = h.QUICore:AnalyzeProfileImportString(foreverExport)
assert(not analyzed, "preview must reject a different client too")
local retailExport = h.QUICore:ExportProfileToString()
client("1.60.1", 16001)
ok, err = h.QUICore:ImportProfileFromString(retailExport, "WrongClient2")
assert(not ok and err:find("different WoW client", 1, true), tostring(err))
ok = h.QUICore:ImportProfileFromValidatedPayload({ _quiClient = "retail" }, "WrongDirect")
assert(not ok, "direct payload import must enforce the client boundary")
ok = h.QUICore:ImportProfileSelectionFromValidatedPayload({ _quiClient = "retail" }, {}, "WrongSelection")
assert(not ok, "selected payload import must enforce the client boundary")
ok = h.QUICore:ImportProfileFromValidatedPayload({ _quiClient = {} }, "InvalidClient")
assert(not ok, "malformed client metadata must not bypass validation")

client("12.1.5", 120105)
h.db.global.nameplateProfiles = { Retail = { simplified = { scale = 1.25 } } }
local plates = assert(h.QUICore:ExportNameplateProfileToString("Retail"))
ok, err = h.QUICore:ImportNameplateProfileFromString(plates, "RetailCopy")
assert(ok, "same-client nameplate import must work: " .. tostring(err))
client("1.60.1", 16001)
ok, err = h.QUICore:ImportNameplateProfileFromString(plates, "WrongPlates")
assert(not ok and err:find("different WoW client", 1, true),
    "nameplate spell lists must retain client validation")
assert(h.db.global.nameplateProfiles.WrongPlates == nil, "rejected nameplate import must not write settings")

ns.Client = nil
local legacyExport = h.QUICore:ExportProfileToString()
client("12.1.5", 120105)
ok, err = h.QUICore:ImportProfileFromString(legacyExport, "LegacyRetail")
assert(ok, "existing untagged Retail exports must still import: " .. tostring(err))
client("1.15.9", 11509)
assert(not ns.Client.isForever, "Classic Era must not be identified as Forever")
client("16.0.1", 160001)
assert(not ns.Client.isForever, "a six-digit Retail interface is not Forever")

print("OK: Forever identity and profile client isolation")
