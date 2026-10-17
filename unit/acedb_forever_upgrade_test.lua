local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local name, surname, displayName = "Cocotaso", "Hunt", "Cocotaso Hunt"
local physicalRealm = "Classic Beta PvE"
local currentKey = "Cocotaso Hunt"
local rules = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
_G.UnitName = function() return displayName end
_G.UnitNameUnmodified = function() return name, surname end
_G.GetRealmName = function() return physicalRealm end
_G.Enum = { GameRule = rules }

local function LoadAceDB(isForever, activeRule)
    ns.Client = { isForever = isForever }
    _G.RegionalUniqueNamesEnabled = function() return isForever end
    _G.GetBuildInfo = function() return "", "", "", isForever and 16001 or 120105 end
    _G.C_GameRules = { IsGameRuleActive = function(rule) return rule == activeRule end }
    LibStub.libs["AceDB-3.0"] = nil
    LibStub.minors["AceDB-3.0"] = nil
    dofile("libs/AceDB-3.0/AceDB-3.0.lua")
end

local function Seed(legacyKey)
    _G.QUIDB = {
        char = { [legacyKey] = { ncdm = { _lastSpecCharKey = legacyKey, spells = { 123 } } } },
        profileKeys = { [legacyKey] = "Custom" },
        profiles = { Custom = { sentinel = 17 }, Default = { sentinel = 23 } },
        global = { setupWizard = { completedAt = 1729 } },
        namespaces = { ["LibDualSpec-1.0"] = { char = { [legacyKey] = { enabled = true, [1] = "Custom" } } } },
    }
end

for _, case in ipairs({ { "PvE" }, { "PvP", 3 }, { "RP", 2 }, { "Hardcore", 1 } }) do
    LoadAceDB(true, case[2])
    for _, legacyKey in ipairs({ currentKey .. " - " .. case[1], currentKey .. " - " .. physicalRealm,
        name .. " - " .. case[1], name .. " - " .. physicalRealm }) do
        Seed(legacyKey)
        local db = ns.Compatibility.CreateDatabase({ char = { defaultSetting = 99 } })
        assert(db.keys.char == currentKey and db.keys.realm == case[1],
            "Forever must use the unmodified full name without a ruleset suffix")
        assert(db.char.ncdm.spells[1] == 123 and db.char.defaultSetting == 99,
            "both ruleset and physical-realm character settings must migrate")
        assert(db.char ~= QUIDB.char[legacyKey] and QUIDB.char[legacyKey].defaultSetting == nil)
        assert(db:GetCurrentProfile() == "Custom" and db.profile.sentinel == 17)
        assert(QUIDB.profileKeys[currentKey] == "Custom" and QUIDB.profileKeys[legacyKey] == "Custom")
        assert(db.global.setupWizard.completedAt == 1729)
        local dualSpec = db:RegisterNamespace("LibDualSpec-1.0")
        assert(dualSpec.char.enabled and dualSpec.char[1] == "Custom",
            "spec mappings must follow the migrated character identity")
        assert(dualSpec.char ~= QUIDB.namespaces["LibDualSpec-1.0"].char[legacyKey])
        db.char.ncdm.spells[1] = 456
        local again = ns.Compatibility.CreateDatabase({})
        assert(again.char.ncdm.spells[1] == 456 and again:GetCurrentProfile() == "Custom",
            "reloading must preserve migrated settings instead of recopying legacy data")
    end
end

LoadAceDB(true)
local physicalKey, rulesetKey = currentKey .. " - " .. physicalRealm, currentKey .. " - PvE"
Seed(physicalKey)
QUIDB.char[rulesetKey] = { keepRuleset = true }
QUIDB.profileKeys[rulesetKey] = "Default"
local db = ns.Compatibility.CreateDatabase({})
assert(db.char.keepRuleset and db.char.ncdm == nil and db:GetCurrentProfile() == "Default",
    "the most recent ruleset identity must take precedence over older physical-realm data")

Seed(physicalKey)
QUIDB.char[currentKey] = { keep = true }
QUIDB.profileKeys[currentKey] = "Default"
QUIDB.namespaces["LibDualSpec-1.0"].char[currentKey] = { enabled = false }
db = ns.Compatibility.CreateDatabase({})
assert(db.char.keep and db.char.ncdm == nil and db:GetCurrentProfile() == "Default")
assert(not db:RegisterNamespace("LibDualSpec-1.0").char.enabled,
    "existing regional character and namespace data must not be overwritten")

for _, invalid in ipairs({ false, 42, "", "   ", string.rep("x", 51) }) do
    Seed(physicalKey)
    QUIDB.profileKeys[physicalKey] = invalid
    assert(ns.Compatibility.CreateDatabase({}):GetCurrentProfile() == "Default")
end
Seed(physicalKey)
QUIDB.profileKeys[currentKey] = false
assert(ns.Compatibility.CreateDatabase({}):GetCurrentProfile() == "Default")

displayName = "Display Alias"
Seed("Display Alias - PvE")
assert(ns.Compatibility.CreateDatabase({}).char.ncdm.spells[1] == 123,
    "legacy display-name keys must migrate to the unmodified regional name")
displayName = currentKey
surname = nil
LoadAceDB(true)
Seed(name .. " - PvE")
db = ns.Compatibility.CreateDatabase({})
assert(db.keys.char == name and db.char.ncdm.spells[1] == 123,
    "a character without a surname must not acquire a nil suffix")

name, surname = currentKey, nil
LoadAceDB(false)
Seed(physicalKey)
local character = QUIDB.char[physicalKey]
db = ns.Compatibility.CreateDatabase({})
assert(db.keys.char == physicalKey and db.char == character and db:GetCurrentProfile() == "Custom")
assert(QUIDB.char[currentKey] == nil, "Retail must retain its realm-qualified character identity")

name, surname = "Cocotaso", "Hunt"
LoadAceDB(true)
_G.QUIDB = nil
db = ns.Compatibility.CreateDatabase({})
assert(db:GetCurrentProfile() == "Default" and db.keys.char == currentKey)

local secret = dofile("tests/helpers/secret_sentinel.lua")
local restore = secret.InstallSecretStub()
assert(secret.LoadInstrumented("core/compatibility.lua"))("QUI", ns)
for _, hiddenName in ipairs({ "display", "unmodified", "both" }) do
    Seed(rulesetKey)
    local opaque = secret.MakeSecretSentinel()
    _G.UnitName = function() return hiddenName ~= "unmodified" and opaque or displayName end
    _G.UnitNameUnmodified = function() return hiddenName ~= "display" and opaque or name, surname end
    db = ns.Compatibility.CreateDatabase({})
    assert(db.char.ncdm.spells[1] == 123 and db:GetCurrentProfile() == "Custom",
        "restricted legacy aliases must not prevent migration from the trusted database key")
end
secret.RestoreSecretStub(restore)

print("OK: acedb_forever_upgrade")
