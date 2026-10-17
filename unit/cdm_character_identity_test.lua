local env = dofile("tools/_addon_env.lua")
_G.UnitName = function() return "Cocotaso Hunt" end
_G.GetRealmName = function() return "Classic Beta PvE" end
env.LoadLibs()
dofile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXMLBase/TableUtil.lua")

local characterKey = "Cocotaso Hunt - Classic Beta PvE"
local character = { ncdm = { _lastSpecCharKey = characterKey } }
local profile = { _lastSpecCharKey = characterKey }
local db = LibStub("AceDB-3.0"):New({
    char = { [characterKey] = character },
    profiles = { Default = { ncdm = profile } },
    profileKeys = { [characterKey] = "Default" },
}, {}, true)
assert(db.keys.char == characterKey and db.char == character)

local file = assert(io.open("QUI_CDM/cdm/cdm_containers.lua"))
local source = file:read("*a")
file:close()
local function extract(name)
    return assert(source:match("local function " .. name .. "%([^\n]*\n.-\nend"))
end
local core = { db = db }
local getKey, ownedByOther = assert(loadstring(
    "local QUICore, GetDB = ...\n"
    .. extract("GetCurrentCharacterKey") .. "\n"
    .. extract("LiveContainerOwnedByOtherCharacter") .. "\n"
    .. "return GetCurrentCharacterKey, LiveContainerOwnedByOtherCharacter"
))(core, function() return profile end)

assert(getKey() == characterKey and not ownedByOther())
_G.UnitName = function() return "Cocotaso", "Hunt" end
assert(getKey() == db.keys.char,
    "split first/surname returns must not change the active AceDB character identity")
assert(not ownedByOther(), "the active character must retain ownership of its saved CDM state")
assert(db.char == character, "CDM identity must remain attached to the existing character settings")

profile._lastSpecCharKey = "Another Character - Classic Beta PvE"
assert(ownedByOther(), "another character's saved CDM state must remain protected")
core.db = nil
assert(getKey() == nil and not ownedByOther(), "missing database must not assert character ownership")
core.db = {}
assert(getKey() == nil and not ownedByOther(), "missing database keys must not assert character ownership")
core.db = db
profile._lastSpecCharKey = nil
assert(not ownedByOther(), "unstamped CDM state must not be treated as another character's")

local oldKey = "Cocotaso Hunt - Legacy Realm"
character.ncdm._lastSpecCharKey = oldKey
character.ncdm._lastSpecID = 1485
profile._lastSpecCharKey = oldKey
profile._lastSpecID = 1485
profile.essential = { ownedSpells = { 123 }, removedSpells = { [456] = true } }
db.sv.profiles.Inactive = { ncdm = { _lastSpecCharKey = oldKey } }
local foreignKey = "Another Character - Classic Beta PvE"
db.sv.profiles.Foreign = { ncdm = { _lastSpecCharKey = foreignKey } }
local savedSlot
local trackingEnv = setmetatable({
    QUICore = core,
    specTrackingRetryToken = 0,
    GetDB = function() return profile end,
    GetCurrentSpecID = function() return 1485 end,
    GetEffectiveLoadoutID = function() return 0 end,
    GetCurrentProfileName = function() return "Default" end,
    GetSpecLoadoutProfileStore = function(_, _, create)
        if create then savedSlot = savedSlot or {} end
        return savedSlot
    end,
    CDMContainers_API = { GetAllContainerKeys = function() return { "essential" } end },
    GetTrackerSettings = function() return profile.essential end,
    ns = { CDMSpellData = { CheckAllDormantSpells = function() end } },
    TrySnapshotBuiltInContainers = function() return true end,
    SaveSpecProfile = function() end,
}, { __index = _G })
local parts = {}
for _, name in ipairs({
    "GetCurrentCharacterKey", "GetCharNcdmDB", "GetSpecStateDB", "GetSpecProfileStore",
    "StampActiveProfileSpecOwner", "IsSpecManagedContainer", "ClearContainerSpecState",
    "LoadOrSnapshotSpecProfile", "RunCrossSessionDetection", "InitSpecTracking",
}) do
    parts[#parts + 1] = extract(name)
end
parts[#parts + 1] = "return InitSpecTracking"
local trackingChunk = assert(loadstring(table.concat(parts, "\n")))
setfenv(trackingChunk, trackingEnv)
assert(trackingChunk()())
assert(profile.essential.ownedSpells and profile.essential.ownedSpells[1] == 123,
    "historical self-ownership must preserve live spells when the active saved slot is absent")
assert(profile.essential.removedSpells[456], "historical self-ownership must preserve removed spells")
assert(savedSlot and savedSlot.essential.ownedSpells[1] == 123,
    "the missing saved slot must be seeded from preserved live settings")
assert(profile._lastSpecCharKey == characterKey and character.ncdm._lastSpecCharKey == characterKey)
assert(db.sv.profiles.Inactive.ncdm._lastSpecCharKey == characterKey,
    "inactive profiles must retain historical self-ownership after the character stamp is normalized")
assert(db.sv.profiles.Foreign.ncdm._lastSpecCharKey == foreignKey,
    "migration must not claim another character's profile")

print("OK: cdm_character_identity")
