_G.AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2,
    ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7,
    AuraInstanceIDOnly = 8 }
_G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
_G.AuraContainerItemEnchantmentSortMethod = { Slot = 0, Duration = 1 }
_G.CreateSecureDelegate = function(fn) return fn end
_G.TimerUtil = { CreateTimedSignalCallbackMap = function() return {} end }
_G.Enum = { SecrecyLevel = { NeverSecret = 0, ContextuallySecret = 1 } }

local ns = dofile("tools/_addon_env.lua").LoadCore()
local E, G = ns.AuraElements, ns.AuraGlue
local noiseIDs = { 57723, 80354, 57724, 390435, 264689, 160455, 95809, 124255, 71041, 206151 }
local neverSecret = { [5555] = true }
for _, sid in ipairs(noiseIDs) do neverSecret[sid] = true end
_G.C_Secrets = {
    GetSpellAuraSecrecy = function(sid)
        return neverSecret[sid] and Enum.SecrecyLevel.NeverSecret or Enum.SecrecyLevel.ContextuallySecret
    end,
    ShouldAurasBeSecret = function() return true end,
}
_G.UnitCanAssist = function() return true end
_G.UnitIsPlayerControlledOrGroupMember = function() return true end
_G.AuraUtil = {
    IsValidFilterString = function() return true end,
    IsRoleAura = function(aura) return aura.isRoleAura == true end,
    IsPriorityDebuff = function() return false end,
}
local auras = {}
_G.C_UnitAuras = {
    IsAuraFilteredOutByInstanceID = function(_, instanceID, filter)
        assert(filter == "HARMFUL", "encounter group must use the harmful engine filter")
        return not auras[instanceID].isHarmful
    end,
}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua"))("Blizzard_AuraContainer", {})
local AuraContainerUtil = _G.AuraContainerUtil

local failures = 0
local function check(name, ok)
    if ok then print("  ok  " .. name)
    else failures = failures + 1; print("FAIL  " .. name) end
end

local e = E.NewFilterStripElement("HARMFUL")
e.blacklist = { [5555] = true, [4444] = false }
e.gateBossAura = true
e.gateBossOrRoleAura = true
e.hidePermanent = true
e.maxDurationSec = 30
E.ApplyWhatToShow(e, "encounter")
local cf = E.CompileCandidateFilters(e)
check("encounter excludes player and pet sources", cf and cf.isFromPlayerOrPlayerPet == false)
check("encounter does not require boss or role flags", cf and cf.isBossAura == nil
    and cf.isBossOrRoleAura == nil and cf.isRoleAura == nil and cf.isPriorityAura == nil)
check("encounter has no duration gate", cf and cf.maxDuration == nil)
for _, sid in ipairs(noiseIDs) do
    check("encounter excludes DBM noise " .. sid, cf and cf.excludeSpellIDs and cf.excludeSpellIDs[sid] == true)
end
check("encounter merges user blacklist", cf and cf.excludeSpellIDs and cf.excludeSpellIDs[5555] == true
    and cf.excludeSpellIDs[4444] == nil)
local blacklistCount = 0
for _ in pairs(e.blacklist) do blacklistCount = blacklistCount + 1 end
check("encounter leaves stored blacklist untouched", blacklistCount == 2
    and e.blacklist[5555] == true and e.blacklist[4444] == false)
if cf and cf.excludeSpellIDs then cf.excludeSpellIDs[5555] = nil end
check("candidate blacklist is a fresh table", e.blacklist[5555] == true)
local second = E.NewFilterStripElement("HARMFUL")
E.ApplyWhatToShow(second, "encounter")
local secondCF = E.CompileCandidateFilters(second)
check("user blacklist never contaminates another element", secondCF and secondCF.excludeSpellIDs
    and secondCF.excludeSpellIDs[5555] == nil)
local helpful = E.NewFilterStripElement("HELPFUL")
helpful.gateEncounterDebuffs = true
check("helpful ignores the encounter gate", E.CompileCandidateFilters(helpful) == nil)
second.onlyMine = true
local conflicting = E.CompileCandidateFilters(second)
check("mine cannot bypass encounter source and noise exclusions", conflicting.isFromPlayerOrPlayerPet == false
    and conflicting.excludeSpellIDs[57724] == true)
assert(loadfile("modules/trackers/aura_display_templates.lua"))("QUI", ns)
local templates = ns.QUI_AuraDisplayTemplates
check("encounter label reaches aura display summaries", templates.WhatToShowLabel("encounter") == "Encounter Debuffs"
    and templates.BuildElementSummary(e, "Player"):find("Encounter Debuffs", 1, true) ~= nil)
local labelFound = false
for _, option in ipairs(templates.WhatToShowOptions("HARMFUL")) do
    if option.value == "encounter" and option.text == "Encounter Debuffs" then labelFound = true end
end
check("encounter label reaches aura display creation options", labelFound)

e.hidePermanent = false
e.maxDurationSec = 0
local groups = G.ElementGroups("player", e, G.ElementProfile(e), false)
check("encounter compiles one harmful container group", #groups == 1 and groups[1].filter == "HARMFUL")
check("source and noise filters reach the live group", groups[1] and groups[1].candidateFilters
    and groups[1].candidateFilters.isFromPlayerOrPlayerPet == false
    and groups[1].candidateFilters.excludeSpellIDs[57724] == true)

local function aura(sid, duration, fromPlayer)
    local instanceID = #auras + 1
    local data = {
        auraInstanceID = instanceID,
        spellId = sid,
        isHarmful = true,
        isHelpful = false,
        duration = duration,
        isFromPlayerOrPlayerPet = fromPlayer,
        isBossAura = false,
        isRoleAura = false,
    }
    auras[instanceID] = data
    return data
end
local bossDebuff = aura(900001, 60, false)
local environmental = aura(900002, 0, false)
local playerDebuff = aura(900003, 20, true)
local sated = aura(57724, 600, false)
local userBlocked = aura(5555, 10, false)
local function visible(data)
    for _, group in ipairs(groups) do
        if AuraContainerUtil.ShouldIncludeAuraForFilterString("player", data, group.filter)
            and AuraContainerUtil.DoesAuraPassCandidateFilters("player", data, group.candidateFilters) then
            return true
        end
    end
    return false
end
check("unflagged boss debuff survives", visible(bossDebuff))
check("durationless environmental debuff survives", visible(environmental))
check("player or pet debuff is excluded", not visible(playerDebuff))
check("NeverSecret Sated is excluded on a friendly player", not visible(sated))
check("NeverSecret user-blacklisted debuff is excluded", not visible(userBlocked))
check("identity filtering remains restricted for encounter spells",
    AuraContainerUtil.CanApplyIdentityCandidateFilters("player", bossDebuff) == false)
check("noise exclusion uses Blizzard's NeverSecret exemption",
    AuraContainerUtil.CanApplyIdentityCandidateFilters("player", sated) == true)
local old = E.NewFilterStripElement("HARMFUL")
E.ApplyWhatToShow(old, "roleBoss")
check("boss-or-role preset demonstrates the original missing aura",
    AuraContainerUtil.DoesAuraPassCandidateFilters("player", bossDebuff, E.CompileCandidateFilters(old)) == false)
E.ApplyWhatToShow(e, "all")
local cleared = E.CompileCandidateFilters(e)
check("All removes source and built-in noise filters", cleared and cleared.isFromPlayerOrPlayerPet == nil
    and cleared.excludeSpellIDs[57724] == nil and cleared.excludeSpellIDs[5555] == true)

print("aura_encounter_debuff_filter_test " .. (failures == 0 and "OK" or "FAILED"))
os.exit(failures == 0 and 0 or 1)
