local function noop() end
_G.CreateFrame = function()
    return { RegisterEvent = noop, RegisterUnitEvent = noop, SetScript = noop }
end
_G.InCombatLockdown = function() return false end
_G.GetTime = function() return 10 end
local probes = 0
local function forbidden()
    probes = probes + 1
    error("CDM must not resolve aura presence through addon queries")
end
local ns = {
    Helpers = {},
    CDMSources = {},
    CDMSpellData = { GetCapturedAuraForLookup = forbidden },
}
assert(loadfile("QUI_CDM/cdm/cdm_runtime_queries.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_resolvers.lua"))("QUI", ns)
if ns.CDMResolvers.ResolveAuraActiveState then
    pcall(ns.CDMResolvers.ResolveAuraActiveState, { id = 1307927, kind = "aura" })
end
assert(probes == 0, "non-CDM aura presence must be delegated to native containers")
assert(ns.CDMResolvers.ResolveAuraActiveState == nil,
    "the obsolete addon aura-presence resolver must be removed")
print("OK: cdm_resolvers_aura_active_state_test")
