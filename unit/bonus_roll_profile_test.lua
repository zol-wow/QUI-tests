local h = dofile("tools/_addon_env.lua").BuildHarness({ noSeed = true })
local core, db = h.QUICore, h.db
local sourceName = db:GetCurrentProfile()
local settings = db.profile.general.bonusRoll

assert(settings.enabled == false, "fresh profiles must show every bonus roll")
assert(settings.mythicPlus.mode == "show", "fresh profiles must not filter keystones")
settings.enabled = true
settings.announce = false
settings.difficulty[15].encounters[1234] = true
settings.difficulty[172].hide = true
settings.difficulty[999].hide = true
settings.mythicPlus.mode = "minimum"
settings.mythicPlus.minLevel = 12

local encoded = assert(core:ExportProfileSelectionToString({ "qol" }))
db:SetProfile("Bonus roll destination")
db.profile.general.skinReadyCheck = false
local ok, err = core:ImportProfileSelectionFromString(encoded, { "qol" })
assert(ok, err)
local copied = db.profile.general.bonusRoll
assert(copied.enabled and not copied.announce, "QoL imports must preserve bonus-roll controls")
assert(copied.difficulty[15].encounters[1234], "QoL imports must retain boss-specific filters")
local normal = copied.difficulty[14]
assert(not (normal and normal.encounters and normal.encounters[1234]),
    "Heroic boss filters must not hide Normal rolls")
assert(copied.difficulty[172].hide and copied.difficulty[999].hide,
    "world-boss and learned difficulty filters must survive import")
assert(copied.mythicPlus.mode == "minimum" and copied.mythicPlus.minLevel == 12,
    "keystone mode and threshold must survive import")
assert(db.profile.general.skinReadyCheck == false, "QoL import must preserve unrelated skin settings")

copied.difficulty[15].encounters[1234] = false
db:SetProfile(sourceName)
assert(db.profile.general.bonusRoll.difficulty[15].encounters[1234],
    "editing an imported boss filter must not change the source profile")
db:SetProfile("Fresh bonus roll profile")
assert(not db.profile.general.bonusRoll.enabled, "new profiles must not inherit another profile's filters")

print("OK: bonus_roll_profile_test")
