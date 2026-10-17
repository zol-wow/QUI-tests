-- Regression guard: QUI_Bags bags.enabled defaults.
-- The new-profile seed (decoded from importstrings/starter_profile.lua by
-- core/new_profile_defaults.lua) must have bags.enabled = true so
-- newly-created profiles get the bag UI on without user action.
-- core/defaults.lua (live AceDB fallback layer) must keep bags.enabled = false so
-- existing profiles that never wrote the key are NOT retroactively changed.

local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()

local newProfileSeed = ns.GetNewProfileSeed and ns.GetNewProfileSeed()
assert(type(newProfileSeed) == "table", "decoded new-profile seed must be a table")
assert(type(newProfileSeed.bags) == "table",
    "new-profile seed bags must be a table")

-- PRIMARY assertion: new profiles get bags ON.
assert(newProfileSeed.bags.enabled == true,
    "new-profile seed: bags.enabled must be true (new profiles get bags on)")

-- GUARD assertion: live AceDB default stays false so existing profiles are untouched.
local liveBags = ns.defaults and ns.defaults.profile and ns.defaults.profile.bags
assert(type(liveBags) == "table", "live defaults must have a bags subtable")
assert(liveBags.enabled == false,
    "live AceDB default: bags.enabled must remain false (existing profiles untouched)")

assert(newProfileSeed.bags.appearance.markUnusable == true,
    "the Starter seed must enable unusable item tint for new profiles")

local AceDB = LibStub("AceDB-3.0")
local historicalDefaults = { profile = { bags = { appearance = { markUnusable = false } } } }
for _, enabled in ipairs({ false, true }) do
    local saved = {
        profiles = { Existing = { _defaultsVersion = 3, sentinel = true } },
        global = { _shippedProfileDefaults = ns.Helpers.DeepCopy(historicalDefaults.profile) },
    }
    local previous = AceDB:New(saved, historicalDefaults, "Existing")
    previous.profile.bags.appearance.markUnusable = enabled
    previous:RegisterDefaults(nil)
    local storedBags = saved.profiles.Existing.bags
    local storedAppearance = storedBags and storedBags.appearance
    if enabled then
        assert(storedAppearance and rawget(storedAppearance, "markUnusable") == true,
            "AceDB must retain an existing user's explicit true choice")
    else
        assert(not storedAppearance or rawget(storedAppearance, "markUnusable") == nil,
            "AceDB must strip the historical false default from saved variables")
        assert(storedBags == nil, "an all-default appearance must leave no saved parent table")
    end
    local reloaded = AceDB:New(saved, ns.defaults, "Existing")
    ns.Compatibility.RunShippedDefaultsMaintenance(reloaded)
    assert(reloaded.profile.bags.appearance.markUnusable == enabled,
        "reloading an existing profile must preserve its unusable item tint choice")
end

print("PASS: new bag profiles use the Starter seed; existing enabled and unusable item tint choices are preserved")
