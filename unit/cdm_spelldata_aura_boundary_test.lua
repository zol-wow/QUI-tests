local function forbidden()
    error("CDM SpellData must not access aura queries")
end
local forbiddenAPI = setmetatable({}, { __index = forbidden })
C_UnitAuras = forbiddenAPI
AuraUtil = forbiddenAPI
local inCombat = false
function InCombatLockdown() return inCombat end
function wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end
C_Timer = { After = function() end }
local frames = {}
function CreateFrame()
    local frame = { events = {}, unitEvents = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event, ...) self.unitEvents[event] = { ... } end
    function frame:UnregisterAllEvents() self.events = {}; self.unitEvents = {} end
    function frame:SetScript(_, handler) self.script = handler end
    frames[#frames + 1] = frame
    return frame
end
local refreshed, glowUnits = {}, {}
local ns = {
    Helpers = {},
    CDMShared = { IsRuntimeEnabled = function() return true end },
    CDMSources = { QueryItemSpell = function(itemID) return "Item Spell", itemID + 1 end },
    AuraGlue = forbiddenAPI,
    CDMCatalog = {
        RebuildBlizzardCatalogMaps = function(_, _, _, abilityMap, auraIDs)
            abilityMap[7001] = 8001
            auraIDs[7001] = { 8001 }
        end,
    },
    CDMIcons = {
        HandleRuntimeRefresh = function(event, unit, payload)
            assert(event == "UNIT_AURA" and payload == nil)
            refreshed[#refreshed + 1] = unit
        end,
    },
    _OwnedGlows = {
        HandleUnitAuraChanged = function(unit, payload)
            assert(payload == nil)
            glowUnits[#glowUnits + 1] = unit
        end,
    },
}
dofile("tests/helpers/load_cdm_spelldata_runtime.lua")(ns)
assert(loadfile("QUI_CDM/cdm/cdm_spelldata.lua"))("QUI", ns)
assert(#frames == 0, "loading catalog data must not create an aura capture frame")
ns.CDMSpellData:Initialize()
assert(#frames == 1, "initialization needs only the catalog runtime frame")
local frame = frames[1]
assert(frame.unitEvents.UNIT_AURA and not frame.unitEvents.UNIT_SPELLCAST_SUCCEEDED)
local payload = setmetatable({}, { __index = function() error("aura payload must stay unread") end })
for _, combat in ipairs({ false, true }) do
    inCombat = combat
    frame.script(frame, "UNIT_AURA", "player", payload)
    frame.script(frame, "PLAYER_TARGET_CHANGED")
    frame.script(frame, "PLAYER_REGEN_ENABLED")
    for _, kind in ipairs({ "aura", "cooldown" }) do
        local result = ns.CDMAuraRuntime.ResolveState({ spellID = 7001, entryKind = kind })
        assert(result.isActive == false and result.durObj == nil,
            "ordinary auras belong to native containers")
    end
end
assert(#refreshed == 4 and #glowUnits == 4)
assert(refreshed[1] == "player" and refreshed[2] == "target")
assert(ns.CDMSpellData:GetAuraIDsForSpell(7001)[1] == 8001)
assert(ns.CDMAuraRuntime.ResolveAbilityAuraSpellID(7001) == 8001)
assert(ns.CDMSpellData:HasResolvableAuraForItem(7000) == 8001)
_G.QUI = { SpellScanner = { GetScannedItemInfo = function(itemID)
    return itemID == 9000 and { buffSpellID = 9002 } or nil
end } }
assert(ns.CDMSpellData:HasResolvableAuraForItem(9000) == 9002)
assert(ns.CDMSpellData:HasResolvableAuraForItem(10000) == nil)
for _, name in ipairs({ "GetCapturedAuraForLookup", "GetCapturedAuraDataByInstanceID", "GetActiveAuras" }) do
    assert(ns.CDMSpellData[name] == nil, name .. " must be retired")
end
for _, name in ipairs({ "GetApplications", "SetApplicationsGetter", "GetCapturedAuraForLookup", "SetCapturedAuraGetter" }) do
    assert(ns.CDMAuraRuntime[name] == nil, name .. " must be retired")
end
ns.CDMSpellData:DisableRuntime()
assert(frame.script == nil and next(frame.events) == nil and next(frame.unitEvents) == nil)
print("OK: cdm_spelldata_aura_boundary_test")
