-- tests/unit/aura_spell_browse_search_test.lua
-- Run: lua tests/unit/aura_spell_browse_search_test.lua
--
-- Source-text pins for the Browse popup's real spell search. The popup used
-- to render only the caller's curated presets, so anything else required a
-- known spell ID. It now leads with the dynamic catalog (Active Auras, My
-- Spellbook, Talents, Recently Seen), caps unsearched sections, badges
-- buffs/debuffs, and falls back to an exact-name lookup when nothing matches.
-- The popup is a headless-hostile frame builder; the executable half lives in
-- aura_spell_catalog_test.lua.

local function read(p)
    local h = io.open(p, "rb")
    if not h then return nil end
    local s = h:read("*a")
    h:close()
    return s
end

local fails = 0
local function check(n, ok)
    if ok then print("  ok  " .. n) else fails = fails + 1; print("FAIL  " .. n) end
end

local list = read("QUI_Options/aura_spell_list.lua")
local catalog = read("modules/trackers/aura_spell_catalog.lua")
local toc = read("QUI.toc")

check("spell list exists", list ~= nil)
check("catalog module exists", catalog ~= nil)
if not (list and catalog and toc) then
    print(("%d failures"):format(fails + 1))
    os.exit(1)
end

check("catalog module is loaded by the main TOC",
    toc:find("aura_spell_catalog.lua", 1, true) ~= nil)
check("catalog exports ns.QUI_AuraSpellCatalog",
    catalog:find("ns.QUI_AuraSpellCatalog = Catalog", 1, true) ~= nil)

-- Popup integration ----------------------------------------------------------
check("browse rows draw from catalog sections plus caller presets",
    list:find("local function EffectiveBrowseSections(opts)", 1, true) ~= nil
    and list:find("Catalog.BuildSections()", 1, true) ~= nil)
check("callers can opt out via skipCatalog",
    list:find("opts.skipCatalog", 1, true) ~= nil)
check("unsearched sections are capped with a type-to-search hint",
    list:find("BROWSE_SECTION_LIMIT", 1, true) ~= nil
    and list:find('ns.L["+ %d more - type to search"]', 1, true) ~= nil)
check("total rendered rows are bounded",
    list:find("BROWSE_TOTAL_LIMIT", 1, true) ~= nil)
check("rows badge buffs and debuffs",
    list:find('ns.L["debuff"]', 1, true) ~= nil
    and list:find('ns.L["buff"]', 1, true) ~= nil)
check("empty searches fall back to an exact-name lookup",
    list:find("Catalog.ExactNameMatch(filter)", 1, true) ~= nil
    and list:find('ns.L["Name Match"]', 1, true) ~= nil)
check("opening the popup refreshes the live catalog",
    list:find("Catalog.InvalidateCache()", 1, true) ~= nil)

-- Variant disambiguation -------------------------------------------------------
check("searching merges per-id evidence across sections",
    list:find("Catalog.MergeVariantSource(m, section.key, spell)", 1, true) ~= nil)
check("same-name variants cluster, best evidence first",
    list:find("table.sort(group, Catalog.CompareVariants)", 1, true) ~= nil
    and list:find('ns.L["%s (%d IDs)"]', 1, true) ~= nil)
check("clusters offer add-all for multi-spell pickers",
    list:find('ns.L["+ Add all %d variants"]', 1, true) ~= nil
    and list:find("opts.multiAdd", 1, true) ~= nil)
check("rows show spell tooltips for reading variants apart",
    list:find("GameTooltip.SetSpellByID", 1, true) ~= nil)
check("badges surface active/seen/spellbook/talent evidence",
    list:find('ns.L["active on you"]', 1, true) ~= nil
    and list:find('ns.L["seen on you"]', 1, true) ~= nil)
check("catalog ranks active > seen > spellbook > talent",
    catalog:find("function Catalog.VariantScore", 1, true) ~= nil
    and catalog:find("function Catalog.CompareVariants", 1, true) ~= nil)
check("the editor's multi-spell pickers enable add-all",
    (read("QUI_Options/aura_elements_editor.lua") or ""):find("multiAdd = true", 1, true) ~= nil)

-- Recorder safety ------------------------------------------------------------
check("recorder is combat-gated",
    catalog:find("if InCombatLockdown and InCombatLockdown() then return false end", 1, true) ~= nil)
check("scans respect the aura secrecy gate (secret even OOC in M+/raids)",
    catalog:find("glue.AurasAreSecret()", 1, true) ~= nil
    and catalog:find("if not AurasReadable() then return end", 1, true) ~= nil)
check("aura reads reject secret values",
    catalog:find("IsSecret(aura)", 1, true) ~= nil)
check("seen store lives account-wide and is capped",
    catalog:find("db.auraSpellSeen", 1, true) ~= nil
    and catalog:find("SEEN_CAP", 1, true) ~= nil)

if fails > 0 then
    print(("%d failures"):format(fails))
    os.exit(1)
end
print("OK: aura_spell_browse_search_test")
