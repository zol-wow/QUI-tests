-- tests/unit/aura_slots_dynamic_groups_test.lua
-- Dynamic layout for tracked icon elements: S.DynamicGroups turns the spell
-- list into one single-frame aura GROUP per spell. Blizzard's flow layout
-- skips empty groups, so icons pack together without Lua ever reading aura
-- presence. This pins the group recipe and that it shares S.Sync's assist /
-- never-secret gating. Run: lua tests/unit/aura_slots_dynamic_groups_test.lua

local fails = 0
local function check(name, ok, detail)
    if ok then print("  ok  " .. name)
    else fails = fails + 1; print("FAIL  " .. name .. (detail and ("  " .. detail) or "")) end
end

_G.InCombatLockdown = function() return false end

local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
ns.Addon = ns.Addon or {}
ns.Addon.AuraSkin = { WireButton = function() end }

local S = assert(loadfile("core/aura_slots.lua"))("QUI", ns)
local E = ns.AuraElements

local function MakeContainer(unit)
    return { GetUnit = function() return unit end }
end

local function SetLiveAssistProbe(assistable)
    _G.UnitIsConnected = function() return assistable end
    _G.UnitIsDeadOrGhost = function() return false end
    _G.UnitCanAssist = function() return true end
    _G.UnitIsVisible = function() return true end
    _G.UnitPhaseReason = function() return nil end
end

-- Gating -------------------------------------------------------------------
do
    local plain = E.NewTrackedElement({ 801, 802 }, "icon")
    check("gate: tracked elements default to fixed slots", S.UsesDynamicGroups(plain) == false)
    plain.dynamicLayout = true
    check("gate: icon elements opt in via dynamicLayout", S.UsesDynamicGroups(plain) == true)
    local bar = E.NewTrackedElement({ 801 }, "bar")
    bar.dynamicLayout = true
    check("gate: bars stay on fixed slots", S.UsesDynamicGroups(bar) == false)
    local square = E.NewTrackedElement({ 801 }, "square")
    square.dynamicLayout = true
    check("gate: squares stay on fixed slots", S.UsesDynamicGroups(square) == false)
    local strip = E.NewFilterStripElement("HELPFUL")
    strip.dynamicLayout = true
    check("gate: strips are never dynamic tracked groups", S.UsesDynamicGroups(strip) == false)
    check("gate: non-table input is false", S.UsesDynamicGroups(nil) == false)
end

-- Group recipe on the player ------------------------------------------------
do
    local e = E.NewTrackedElement({ 801, 802, "junk", 803 }, "icon")
    e.dynamicLayout = true
    e.spacing = 2
    local c = MakeContainer("player")
    local groups = S.DynamicGroups(c, e, { spacing = 3 })
    check("recipe: one group per numeric spell, in configured order",
        #groups == 3 and groups[1].candidateFilters.includeSpellIDs[801]
        and groups[2].candidateFilters.includeSpellIDs[802]
        and groups[3].candidateFilters.includeSpellIDs[803])
    check("recipe: keys are unique and free of '|'",
        groups[1].key ~= groups[2].key and groups[2].key ~= groups[3].key
        and not groups[1].key:find("|", 1, true))
    check("recipe: exactly one frame per group",
        groups[1].maxFrameCount == 1 and groups[2].maxFrameCount == 1 and groups[3].maxFrameCount == 1)
    check("recipe: gap rides groupSpacing from the profile, element spacing is zero",
        groups[1].groupSpacing == 3 and groups[1].elementSpacing == 0)
    check("recipe: base filter string follows the aura type",
        groups[1].filter == "HELPFUL" and groups[2].filter == "HELPFUL")
    check("recipe: no assist record on the player", c._quiAssistApplied == nil)

    local fallback = S.DynamicGroups(MakeContainer("player"), e, nil)
    check("recipe: spacing falls back to the element when no profile", fallback[1].groupSpacing == 2)

    e.onlyMineSpells = { [802] = true }
    groups = S.DynamicGroups(MakeContainer("player"), e, { spacing = 0 })
    check("recipe: per-spell only-mine lands on that group's filter + candidate",
        groups[2].filter == "HELPFUL|PLAYER"
        and groups[2].candidateFilters.isFromPlayerOrPlayerPet == true
        and groups[1].filter == "HELPFUL" and groups[1].candidateFilters.isFromPlayerOrPlayerPet == nil)
    check("recipe: zero spacing yields zero groupSpacing", groups[1].groupSpacing == 0)

    -- HARMFUL identity filters are only enforceable on hostile tokens (same
    -- rule as S.Sync), so the harmful recipe is checked on a boss unit.
    e.onlyMineSpells = nil
    e.onlyMine = true
    e.auraType = "HARMFUL"
    groups = S.DynamicGroups(MakeContainer("boss1"), e, { spacing = 1 })
    check("recipe: element-wide only-mine + harmful", #groups == 3
        and groups[1].filter == "HARMFUL|PLAYER"
        and groups[3].candidateFilters.isFromPlayerOrPlayerPet == true)

    e.enabled = false
    check("recipe: disabled element yields no groups",
        #S.DynamicGroups(MakeContainer("player"), e, { spacing = 1 }) == 0)
end

-- Identity-filter gating shared with S.Sync ---------------------------------
do
    local e = E.NewTrackedElement({ 801, 802 }, "icon")
    e.dynamicLayout = true
    check("gating: HELPFUL on a hostile token renders nothing",
        #S.DynamicGroups(MakeContainer("boss1"), e, { spacing = 1 }) == 0)
    e.auraType = "HARMFUL"
    check("gating: HARMFUL on a friendly group token renders nothing",
        #S.DynamicGroups(MakeContainer("party1"), e, { spacing = 1 }) == 0)

    e.auraType = "HELPFUL"
    _G.Enum = _G.Enum or {}
    _G.Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
    _G.C_Secrets = {
        GetSpellAuraSecrecy = function(spellID)
            if spellID == 802 then return _G.Enum.SecrecyLevel.NeverSecret end
            return _G.Enum.SecrecyLevel.AlwaysSecret
        end,
    }
    SetLiveAssistProbe(false)
    local c = MakeContainer("party1")
    local groups = S.DynamicGroups(c, e, { spacing = 1 })
    check("gating: unassistable party unit parks secret spells (never-match recipe)",
        #groups == 2 and groups[1].candidateFilters.maxDuration == 0
        and groups[1].candidateFilters.includeSpellIDs == nil)
    check("gating: never-secret spell keeps real candidates while parked",
        groups[2].candidateFilters.includeSpellIDs ~= nil
        and groups[2].candidateFilters.includeSpellIDs[802] == true)
    check("gating: live-governed container records the assist verdict", c._quiAssistApplied == false)

    SetLiveAssistProbe(true)
    c = MakeContainer("party1")
    groups = S.DynamicGroups(c, e, { spacing = 1 })
    check("gating: assistable party unit gets real filters",
        groups[1].candidateFilters.includeSpellIDs ~= nil and c._quiAssistApplied == true)
end

if fails > 0 then error(fails .. " failure(s) in aura_slots_dynamic_groups_test") end
print("OK: aura_slots_dynamic_groups_test (all checks passed)")
