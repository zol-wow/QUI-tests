-- tests/unit/cdm_aura_runtime_test.lua
-- Run: lua tests/unit/cdm_aura_runtime_test.lua

local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_aura.lua", "cdm_aura_runtime.lua")("QUI", ns)

local runtime = assert(ns.CDMAuraRuntime, "CDMAuraRuntime table was not exported")

local resolvedParams
local resolvedState = { isActive = true, auraUnit = "player", totemSlot = 1 }
runtime.SetResolver(function(params)
    resolvedParams = params
    return resolvedState
end)

local state = runtime.ResolveState({ spellID = 12345 })
assert(state == resolvedState, "aura runtime should return the registered resolved state")
assert(resolvedParams.spellID == 12345, "aura runtime should pass params to the registered resolver")

runtime.SetAbilityAuraSpellIDResolver(function(spellID)
    if spellID == 100 then
        return 200, true
    end
    return spellID, false
end)

local mapped, remapped = runtime.ResolveAbilityAuraSpellID(100)
assert(mapped == 200 and remapped == true,
    "aura runtime should delegate ability-to-aura lookup")
assert(runtime.HasAbilityAuraMapping(100) == true,
    "aura runtime should report registered ability-to-aura mappings")
assert(runtime.HasAbilityAuraMapping(101) == false,
    "aura runtime should reject non-remapped ability IDs")

print("OK: cdm_aura_runtime_test")
