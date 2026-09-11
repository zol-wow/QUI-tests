local attempts = 0
local function forbidden()
    attempts = attempts + 1
    error("item aura metadata must not query aura activity")
end
_G.QUI = { SpellScanner = {
    IsItemActive = forbidden,
    IsSpellActive = forbidden,
    GetScannedItemInfo = function(id)
        assert(id == 100)
        return { useSpellID = 200, buffSpellID = 300 }
    end,
    GetScannedSpellInfo = function(id)
        assert(id == 200)
        return { buffSpellID = 400 }
    end,
} }
_G.C_Item = { GetItemSpell = function(id) assert(id == 100); return "Use", 200 end }
local ns = { SafeCall = function(_, fn, ...) return pcall(fn, ...) end }
assert(loadfile("QUI_CDM/cdm/cdm_sources.lua"))("QUI", ns)
local read = ns.CDMSources.GetItemAuraSpellIDs or ns.CDMSources.QueryScannedItemAuraInfo
local ok, ids = pcall(read, 100)
assert(attempts == 0, "item metadata lookup must not call scanner active-state methods")
assert(ok and ids[1] == 200 and ids[2] == 300 and ids[3] == 400 and #ids == 3,
    "native item aura filters need the use spell plus learned buff IDs")
ns.ConsumableMacros = { GetVariantOrderForItem = function() return { 100, 101 } end }
_G.QUI.SpellScanner.GetScannedItemInfo = function(id)
    if id == 101 then return { buffSpellID = 500 } end
end
_G.QUI.SpellScanner.GetScannedSpellInfo = function() return nil end
ids = ns.CDMSources.GetItemAuraSpellIDs(100)
assert(ids[1] == 200 and ids[2] == 500 and #ids == 2,
    "a sibling item quality's learned aura ID must remain available to native filters")
print("OK: cdm_sources_scanned_item_aura_test")
