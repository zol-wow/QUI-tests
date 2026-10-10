local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local legacyKey = "Cocotaso Hunt - Classic Beta PvE"
local rules = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
_G.UnitName = function() return "Cocotaso Hunt" end
_G.GetRealmName = function() return "Classic Beta PvE" end
_G.Enum = { GameRule = rules }

local function LoadAceDB(isForever, activeRule)
    ns.Client = { isForever = isForever }
    _G.GetBuildInfo = function() return "", "", "", isForever and 16001 or 120105 end
    _G.C_GameRules = { IsGameRuleActive = function(rule) return rule == activeRule end }
    LibStub.libs["AceDB-3.0"] = nil
    LibStub.minors["AceDB-3.0"] = nil
    dofile("libs/AceDB-3.0/AceDB-3.0.lua")
end

local function Seed()
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
    Seed()
    local key = "Cocotaso Hunt - " .. case[1]
    local db = ns.Compatibility.CreateDatabase({ char = { defaultSetting = 99 } })
    assert(db.keys.char == key and db.keys.realm == case[1])
    assert(db.char.ncdm.spells[1] == 123 and db.char.defaultSetting == 99)
    assert(db.char ~= QUIDB.char[legacyKey] and QUIDB.char[legacyKey].defaultSetting == nil)
    assert(db:GetCurrentProfile() == "Custom" and db.profile.sentinel == 17)
    assert(QUIDB.profileKeys[key] == "Custom" and QUIDB.profileKeys[legacyKey] == "Custom")
    assert(db.global.setupWizard.completedAt == 1729)
    local dualSpec = db:RegisterNamespace("LibDualSpec-1.0")
    assert(dualSpec.char.enabled and dualSpec.char[1] == "Custom")
    assert(dualSpec.char ~= QUIDB.namespaces["LibDualSpec-1.0"].char[legacyKey])
    db.char.ncdm.spells[1] = 456
    local again = ns.Compatibility.CreateDatabase({})
    assert(again.char.ncdm.spells[1] == 456 and again:GetCurrentProfile() == "Custom")
end

LoadAceDB(true)
Seed()
_G.UnitName = function() return "Cocotaso", "Hunt" end
assert(ns.Compatibility.CreateDatabase({}).char.ncdm.spells[1] == 123)
_G.UnitName = function() return "Cocotaso Hunt" end
Seed()
local key = "Cocotaso Hunt - PvE"
QUIDB.char[key] = { keep = true }
QUIDB.profileKeys[key] = "Default"
QUIDB.namespaces["LibDualSpec-1.0"].char[key] = { enabled = false }
local db = ns.Compatibility.CreateDatabase({})
assert(db.char.keep and db.char.ncdm == nil and db:GetCurrentProfile() == "Default")
assert(not db:RegisterNamespace("LibDualSpec-1.0").char.enabled)

for _, invalid in ipairs({ false, 42, "", "   ", string.rep("x", 51) }) do
    Seed()
    QUIDB.profileKeys[legacyKey] = invalid
    assert(ns.Compatibility.CreateDatabase({}):GetCurrentProfile() == "Default")
end
Seed()
QUIDB.profileKeys[key] = false
assert(ns.Compatibility.CreateDatabase({}):GetCurrentProfile() == "Default")

LoadAceDB(false)
Seed()
local character = QUIDB.char[legacyKey]
db = ns.Compatibility.CreateDatabase({})
assert(db.keys.char == legacyKey and db.char == character and db:GetCurrentProfile() == "Custom")
assert(QUIDB.char[key] == nil)

LoadAceDB(true)
_G.QUIDB = nil
db = ns.Compatibility.CreateDatabase({})
assert(db:GetCurrentProfile() == "Default" and db.keys.char == key)

print("OK: acedb_forever_upgrade")
