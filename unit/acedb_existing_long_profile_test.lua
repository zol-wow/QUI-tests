local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local legacyName = string.rep("x", 51)
local unicodeName = string.rep("é", 51)
local missingLongName = string.rep("y", 51)
local characterKey = "TestChar - TestRealm"

local function LoadAceDB()
    LibStub.libs["AceDB-3.0"] = nil
    LibStub.minors["AceDB-3.0"] = nil
    local previousCreateFrame = CreateFrame
    _G.CreateFrame = function()
        return {
            RegisterEvent = function() end,
            SetScript = function(self, name, fn) self[name] = fn end,
        }
    end
    dofile("libs/AceDB-3.0/AceDB-3.0.lua")
    _G.CreateFrame = previousCreateFrame
    return LibStub("AceDB-3.0")
end

for _, name in ipairs({ legacyName, unicodeName }) do
    local library = LoadAceDB()
    local saved = {
        profileKeys = { [characterKey] = name },
        profiles = { [name] = { sentinel = 123 }, Default = { sentinel = 456 } },
    }
    local db = library:New(saved, { profile = { enabled = true } }, true)
    assert(db:GetCurrentProfile() == name and db.profile.sentinel == 123,
        "loading an existing long profile must retain its selection and settings")
    local child = db:RegisterNamespace("EmptyChild", { profile = { enabled = true } })
    assert(child.keys.profile == name, "a new namespace must follow its parent's long profile")
    db:SetProfile("Default")
    db:SetProfile(name)
    assert(db.profile.sentinel == 123 and child.keys.profile == name,
        "switching to an existing long profile must propagate into namespaces")
    for _, invalid in ipairs({ missingLongName, "", "   " }) do
        assert(not pcall(db.SetProfile, db, invalid), "new invalid names must remain rejected")
        assert(db:GetCurrentProfile() == name and db.profile.sentinel == 123)
    end
    library.frame.OnEvent(library.frame, "PLAYER_LOGOUT")
    assert(saved.profileKeys[characterKey] == name and saved.profiles[name].sentinel == 123,
        "logout must retain the existing long profile pointer and settings")
    db = LoadAceDB():New(saved, {}, true)
    assert(db:GetCurrentProfile() == name and db.profile.sentinel == 123,
        "reloading saved data must retain the existing long profile")
    local explicit = LoadAceDB():New({ profiles = { [name] = { sentinel = 789 } } }, {}, name)
    assert(explicit:GetCurrentProfile() == name and explicit.profile.sentinel == 789,
        "an explicit existing long default profile must remain supported")
end

ns.Client = { isForever = true }
_G.GetBuildInfo = function() return "1.60.1", "70205", "", 16001 end
_G.RegionalUniqueNamesEnabled = function() return true end
_G.C_GameRules = { IsGameRuleActive = function() return false end }
_G.Enum = { GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 } }
LoadAceDB()
_G.QUIDB = {
    profileKeys = { [characterKey] = legacyName },
    profiles = { [legacyName] = { sentinel = 123 }, Default = { sentinel = 456 } },
}
local db = ns.Compatibility.CreateDatabase({})
assert(db.keys.char == "TestChar" and db:GetCurrentProfile() == legacyName
    and db.profile.sentinel == 123,
    "Forever identity migration must preserve an existing long profile selection")
assert(QUIDB.profileKeys[characterKey] == legacyName
    and QUIDB.profileKeys["TestChar"] == legacyName,
    "Forever migration must preserve the legacy pointer and copy the new pointer")

LibStub.libs["AceDB-3.0"] = nil
LibStub.minors["AceDB-3.0"] = nil
local previousLibrary = LibStub:NewLibrary("AceDB-3.0", 39)
previousLibrary.db_registry = {}
dofile("libs/AceDB-3.0/AceDB-3.0.lua")
assert(LibStub("AceDB-3.0") == previousLibrary and previousLibrary.New,
    "the patched library must upgrade a previously registered upstream minor 39")

print("OK: acedb_existing_long_profile")
