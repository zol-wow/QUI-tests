local function noop() end
_G.InCombatLockdown = function() return false end
_G.GetTime = function() return 100 end
_G.IsSpellKnown = function() return true end
_G.IsPlayerSpell = function() return true end
_G.issecretvalue = function() return false end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.CreateFrame = function()
    return { RegisterEvent = noop, RegisterUnitEvent = noop, SetScript = noop,
        UnregisterEvent = noop, UnregisterAllEvents = noop }
end
_G.Enum = { CooldownViewerCategory = {
    Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3,
    HiddenSpell = 4, HiddenAura = 5, SpecAgnosticEssential = 7,
    SpecAgnosticTracked = 6, EquipSlotEssential = 9, EquipSlotTracked = 8,
} }
local STRIKE, STRIKE_AURA, ESSENCE, BONE = 433901, 433899, 433925, 195181
local infos = {
    [157116] = { spellID = STRIKE, overrideSpellID = STRIKE,
        linkedSpellIDs = { STRIKE_AURA }, category = 2, isKnown = true,
        hasAura = false, selfAura = true, buffSlot = 1, cooldownID = 157116 },
    [170469] = { spellID = STRIKE, overrideSpellID = STRIKE,
        overrideTooltipSpellID = ESSENCE, linkedSpellIDs = { ESSENCE },
        category = 2, isKnown = true, hasAura = false, selfAura = true,
        buffSlot = 1, cooldownID = 170469 },
    [9039] = { spellID = BONE, category = 2, isKnown = true },
}
local provider = { layoutManager = {}, displayData = {
    orderedCooldownIDs = { 157116, 170469, 9039 }, cooldownInfoByID = infos,
} }
_G.CooldownViewerSettings = { GetDataProvider = function() return provider end }
_G.C_CooldownViewer = {
    GetCooldownViewerCooldownInfo = function(id) return infos[id] end,
    GetCooldownViewerCategorySet = function(category)
        local ids = {}
        for _, id in ipairs(provider.displayData.orderedCooldownIDs) do
            if infos[id].category == category then ids[#ids + 1] = id end
        end
        return ids
    end,
}
local function entry(id, source)
    return { type = "spell", kind = "aura", id = id, source = source }
end
local buff = { ownedSpells = {
    entry(STRIKE, "blizzardCDM"), entry(ESSENCE, "blizzardCDM"), entry(BONE, "blizzardCDM"),
} }
local ns = {
    Helpers = {},
    Addon = { db = { profile = { ncdm = { buff = buff, trackedBar = {},
        containers = { custom = {} } } }, global = {} } },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_, obj, method, ...) return pcall(obj[method], obj, ...) end,
    CDMSources = { QueryOverrideSpell = function(id) return id end },
    _GetCachedSpellName = function(id) return tostring(id) end,
}
dofile("tests/helpers/load_cdm_spelldata_runtime.lua")(ns)
assert(loadfile("QUI_CDM/cdm/cdm_index.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_catalog.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_spelldata.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_wiring.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_managed_aura_mirrors.lua"))("QUI", ns)
dofile("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua")
local sd = ns.CDMSpellData
local function frame(id)
    return setmetatable({
        cooldownID = id,
        GetCooldownInfo = function() return infos[id] end,
        UsesDynamicAppearance = function() return false end,
    }, { __index = _G.CooldownViewerItemDataMixin })
end
local strikeFrame, essenceFrame, boneFrame = frame(157116), frame(170469), frame(9039)
local wiring = ns.CDMReanchorWiring.New({ index = ns.CDMIndex, bridge = {
    EnumerateItems = function(_, viewer) return viewer.items end,
    ResolveIdentity = function(_, f) return f.cooldownID end,
    GetFrameCooldownInfo = function(_, f) return f:GetCooldownInfo() end,
} })
local function checkSlots()
    local list = sd:BuildSpellListFromOwned("buff")
    assert(#list == 3, "both saved native slots and Bone Shield must survive")
    assert(list[1].spellID == STRIKE and list[1].name == tostring(STRIKE),
        "Vampiric Strike must not inherit the other slot's Essence display")
    assert(list[2].spellID == ESSENCE and list[3].spellID == BONE,
        "Essence and unrelated buffs must retain their display identities")
    assert(#list[1].linkedSpellIDs == 1 and list[1].linkedSpellIDs[1] == STRIKE_AURA,
        "Strike's fallback must not track Essence from another native slot")
    assert(#list[2].linkedSpellIDs == 1 and list[2].linkedSpellIDs[1] == ESSENCE,
        "Essence's fallback must not track Strike's aura")
    local candidates = ns.CDMManagedAuraMirrors.ResolveCandidateIDs(list[1])
    for _, id in ipairs(candidates) do
        assert(id ~= ESSENCE, "Strike's managed mirror must not reacquire Essence through the global aura map")
    end
    assert(#candidates == 2, "Strike's own spell and linked aura must remain available to its mirror")
    for _, frames in ipairs({ { strikeFrame, essenceFrame, boneFrame },
        { essenceFrame, strikeFrame, boneFrame } }) do
        local map = wiring:BuildFrameMap({ items = frames })
        local matched, frameless = wiring:MatchCuratedToFrames(list, map, "buff")
        assert(#matched == 3 and #frameless == 0,
            "native slot matching must not leave a duplicate Essence entry to mint")
        assert(matched[1].frame == strikeFrame and matched[2].frame == essenceFrame,
            "native frame ownership must preserve original slots in either frame order")
    end
end
checkSlots()
strikeFrame.auraSpellID, essenceFrame.auraSpellID = STRIKE_AURA, ESSENCE
checkSlots()
provider.displayData.orderedCooldownIDs = { 170469, 157116, 9039 }
ns.CDMIndex.Notify("test")
checkSlots()
assert(#buff.ownedSpells == 3 and buff.ownedSpells[1].id == STRIKE
    and buff.ownedSpells[2].id == ESSENCE, "saved Composer entries must remain intact")

buff.ownedSpells = { entry(STRIKE_AURA, "blizzardCDM"), entry(ESSENCE, "blizzardCDM") }
local variants = sd:BuildSpellListFromOwned("buff")
assert(variants[1].spellID == STRIKE_AURA and variants[2].spellID == ESSENCE,
    "explicit linked-aura variants must retain their selected identities")
buff.ownedSpells = { entry(STRIKE) }
assert(sd:BuildSpellListFromOwned("buff")[1].spellID == ESSENCE,
    "manual entries must retain the existing ability-to-aura resolver")
buff.ownedSpells = { entry(STRIKE, "blizzardCDM"), entry(ESSENCE, "blizzardCDM") }
ns.Addon.db.profile.ncdm.containers.custom.ownedSpells = buff.ownedSpells
assert(sd:BuildSpellListFromOwned("custom")[1].spellID == ESSENCE,
    "custom aura entries must retain their existing resolver")
for _, info in pairs(infos) do info.category = 3 end
ns.CDMIndex.Notify("test")
ns.Addon.db.profile.ncdm.trackedBar.ownedSpells = buff.ownedSpells
local bars = sd:BuildSpellListFromOwned("trackedBar")
assert(#bars == 2 and bars[1].spellID == STRIKE and bars[2].spellID == ESSENCE,
    "native tracked bars must preserve the same distinct slot identities")
print("OK: cdm_spelldata_native_aura_slots_test")
