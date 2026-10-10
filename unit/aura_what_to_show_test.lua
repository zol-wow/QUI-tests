-- Run: lua5.1 tests/unit/aura_what_to_show_test.lua
local ns = dofile("tools/_addon_env.lua").LoadCore()
local E = ns.AuraElements

local failures = 0
local function check(name, ok, detail)
    if ok then print(("  ok  %s"):format(name))
    else failures = failures + 1; print(("FAIL  %s  %s"):format(name, detail or "")) end
end

do -- WhatToShowKeys
    local h = E.WhatToShowKeys("HELPFUL")
    check("helpful keys", table.concat(h, ",") == "all,mine,defensives,important,purgeable,whitelist", table.concat(h, ","))
    local d = E.WhatToShowKeys("HARMFUL")
    local harmfulKeys = {}
    for _, key in ipairs(d) do harmfulKeys[key] = true end
    check("harmful encounter key", harmfulKeys.encounter == true)
    local existing = {}
    for _, key in ipairs(d) do if key ~= "encounter" then existing[#existing + 1] = key end end
    check("harmful existing keys", table.concat(existing, ",") == "all,dispellable,crowdControl,important,boss,roleBoss,whitelist", table.concat(d, ","))
    check("defaults to helpful", table.concat(E.WhatToShowKeys(nil), ",") == "all,mine,defensives,important,purgeable,whitelist")
end

do -- ApplyWhatToShow sets the canonical combo and clears prior modifiers
    local e = E.NewFilterStripElement("HARMFUL")
    e.onlyMine = true; e.gateBossAura = true            -- pre-existing noise
    E.ApplyWhatToShow(e, "dispellable")
    -- Engine-evaluated capability: classify -> HARMFUL|RAID (68675
    -- player-dispellable; talent-aware, live on respec) instead of the
    -- class/spec school table.
    check("dispellable classify", e.filterMode == "classify")
    local nKeys = 0
    for _ in pairs(e.classifications or {}) do nKeys = nKeys + 1 end
    check("dispellable sole classification key", e.classifications.dispellable == true and nKeys == 1)
    check("dispellable no dispel-type filter", e.dispelFilterMode == "off")
    check("dispellable clears onlyMine", e.onlyMine == false)
    check("dispellable clears boss gate", e.gateBossAura == nil)

    local d = E.NewFilterStripElement("HELPFUL")
    E.ApplyWhatToShow(d, "defensives")
    check("defensives classify", d.filterMode == "classify")
    check("defensives keys", d.classifications.bigDefensive and d.classifications.externalDefensive
        and not d.classifications.raid)

    -- 68675 IMPORTANT is offered on BOTH polarities: the AuraFilters comment
    -- naming helpful auras describes the case Blizzard built it for, while the
    -- underlying flag (C_Spell.IsSpellImportant) is spell-level. Either way the
    -- preset lands on classify with exactly one key — never a filterFlags token.
    local imp = E.NewFilterStripElement("HELPFUL")
    imp.gateStealable = true                            -- pre-existing noise
    E.ApplyWhatToShow(imp, "important")
    check("important classify", imp.filterMode == "classify")
    local impKeys = 0
    for _ in pairs(imp.classifications or {}) do impKeys = impKeys + 1 end
    check("important sole classification key", imp.classifications.important == true and impKeys == 1)
    check("important clears purgeable gate", imp.gateStealable == nil)
    local impFS = E.CompileFilters(imp)
    check("important compiles to HELPFUL|IMPORTANT",
        #impFS == 1 and impFS[1] == "HELPFUL|IMPORTANT", table.concat(impFS, ","))

    local impH = E.NewFilterStripElement("HARMFUL")
    E.ApplyWhatToShow(impH, "important")
    local impHFS = E.CompileFilters(impH)
    check("important compiles to HARMFUL|IMPORTANT on the other polarity",
        #impHFS == 1 and impHFS[1] == "HARMFUL|IMPORTANT", table.concat(impHFS, ","))

    local b = E.NewFilterStripElement("HARMFUL")
    E.ApplyWhatToShow(b, "boss")
    check("boss gate", b.gateBossAura == true and b.filterMode == "off")

    local w = E.NewFilterStripElement("HELPFUL")
    w.whitelist = { [774] = true }
    E.ApplyWhatToShow(w, "whitelist")
    check("whitelist mode + keeps map", w.filterMode == "whitelist" and w.whitelist[774] == true)
end

do -- Derive is the exact reverse of Apply for every key
    local KEYS = {
        HELPFUL = { "all", "mine", "defensives", "important", "purgeable", "whitelist" },
        HARMFUL = { "all", "dispellable", "crowdControl", "important", "encounter", "boss", "roleBoss", "whitelist" },
    }
    for _, pol in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, key in ipairs(KEYS[pol]) do
            local e = E.NewFilterStripElement(pol)
            E.ApplyWhatToShow(e, key)
            check(pol .. "/" .. key .. " round-trips", E.DeriveWhatToShow(e) == key, "got " .. tostring(E.DeriveWhatToShow(e)))
        end
    end

    -- Legacy stored preset (pre-engine-token): include + "mine" sentinel
    -- must still derive "dispellable" so old SVs read back correctly.
    local legacy = E.NewFilterStripElement("HARMFUL")
    legacy.dispelFilterMode = "include"; legacy.dispelTypes = "mine"
    check("legacy dispellable derives", E.DeriveWhatToShow(legacy) == "dispellable")
end

do -- Non-canonical states derive to "custom"
    local f = E.NewFilterStripElement("HARMFUL"); f.filterMode = "flags"; f.filterFlags = { PLAYER = true }
    check("flags -> custom", E.DeriveWhatToShow(f) == "custom")

    local two = E.NewFilterStripElement("HARMFUL"); E.ApplyWhatToShow(two, "boss"); two.onlyMine = true
    check("boss+onlyMine -> custom", E.DeriveWhatToShow(two) == "custom")

    local ex = E.NewFilterStripElement("HARMFUL"); ex.dispelFilterMode = "exclude"; ex.dispelTypes = { Magic = true }
    check("dispel exclude -> custom", E.DeriveWhatToShow(ex) == "custom")

    local mix = E.NewFilterStripElement("HELPFUL"); mix.filterMode = "classify"
    mix.classifications = { bigDefensive = true, raid = true }
    check("classify mixed keys -> custom", E.DeriveWhatToShow(mix) == "custom")

    -- blacklist coexists with any intent and never forces custom
    local b = E.NewFilterStripElement("HARMFUL"); E.ApplyWhatToShow(b, "boss"); b.blacklist = { [123] = true }
    check("blacklist ignored by derive", E.DeriveWhatToShow(b) == "boss")
end

do
    local e = E.NewFilterStripElement("HARMFUL")
    e.onlyMine = true
    e.gateBossAura = true
    e.gateBossOrRoleAura = true
    e.gateRoleAura = true
    e.gatePriorityAura = true
    e.gateStealable = true
    e.filterMode = "classify"
    e.classifications = { important = true }
    e.filterFlags = { PLAYER = true }
    e.dispelFilterMode = "include"
    e.dispelTypes = { Magic = true }
    e.nameplateOnly = true
    e.hidePermanent = true
    e.maxDurationSec = 30
    E.ApplyWhatToShow(e, "encounter")
    check("encounter enables source preset", e.gateEncounterDebuffs == true)
    check("encounter clears classification and mine", e.filterMode == "off" and e.onlyMine == false
        and e.classifications.important ~= true and next(e.filterFlags) == nil)
    check("encounter clears boss and role gates", not e.gateBossAura and not e.gateBossOrRoleAura
        and not e.gateRoleAura and not e.gatePriorityAura and not e.gateStealable)
    check("encounter clears dispel restriction", e.dispelFilterMode == "off" and next(e.dispelTypes) == nil)
    check("encounter clears nameplate-only restriction", not e.nameplateOnly)
    check("encounter permits durationless auras", not e.hidePermanent and (tonumber(e.maxDurationSec) or 0) == 0)
    for _, key in ipairs(E.WhatToShowKeys("HARMFUL")) do
        if key ~= "encounter" then
            E.ApplyWhatToShow(e, "encounter")
            E.ApplyWhatToShow(e, key)
            check(key .. " clears encounter gate", not e.gateEncounterDebuffs)
        end
    end
    for _, field in ipairs({ "onlyMine", "gateBossAura", "gateBossOrRoleAura", "gateRoleAura", "gatePriorityAura", "gateStealable" }) do
        E.ApplyWhatToShow(e, "encounter")
        e[field] = true
        check("encounter plus " .. field .. " derives custom", E.DeriveWhatToShow(e) == "custom")
    end
    for _, key in ipairs({ "important", "whitelist" }) do
        E.ApplyWhatToShow(e, key)
        e.gateEncounterDebuffs = true
        check("encounter plus " .. key .. " derives custom", E.DeriveWhatToShow(e) == "custom")
    end
end

print("aura_what_to_show_test " .. (failures == 0 and "OK" or "FAILED"))
os.exit(failures == 0 and 0 or 1)
