-- tests/unit/cdm_icons_gcd_dedupe_test.lua
-- Run: lua tests/unit/cdm_icons_gcd_dedupe_test.lua

local BuildCooldownStateContext = dofile("tests/helpers/cdm_context_builder_stub.lua")

local function noop() end

function InCombatLockdown() return false end
function GetTime() return 100 end
function wipe(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function CreateFrame()
    return {
        RegisterEvent = noop,
        RegisterUnitEvent = noop,
        UnregisterAllEvents = noop,
        SetScript = noop,
    }
end

C_Timer = {
    After = function(_, callback) callback() end,
    NewTimer = function()
        return { Cancel = noop }
    end,
}

local gcdDuration = { token = "gcd-duration" }
local resolvedDuration = gcdDuration
local resolvedMode = "gcd-only"

local ns = {
    Helpers = {
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "" end,
        CreateDBGetter = function()
            return function()
                return {}
            end
        end,
        IsSecretValue = function() return false end,
        SafeValue = function(value) return value end,
        SafeToNumber = function(value) return value end,
        CanAccessTable = function(tbl) return type(tbl) == "table" end,
    },
    Addon = {
        db = {
            profile = { ncdm = {} },
            char = { ncdm = {} },
        },
    },
    CDMShared = {
        IsRuntimeEnabled = function() return true end,
        IsSafeNumeric = function(value) return type(value) == "number" end,
    },
    CDMSources = {},
    CDMResolvers = {
        BuildCooldownStateContext = BuildCooldownStateContext,
        _textureCycleCache = {},
        _FinalizeImports = noop,
        Subscribe = noop,
        GetSpellTexture = function() return nil end,
        ResolveMacro = function() return nil end,
        GetEntryTexture = function() return nil end,
        IsAuraEntry = function(entry) return entry and entry.kind == "aura" end,
        ResolveSpellActiveState = function() return nil end,
        ResolveCooldownActivityState = function() return nil end,
        ResolveCooldownState = function()
            return {
                mode = resolvedMode,
                active = true,
                isActive = true,
                durObj = resolvedDuration,
                sourceID = 12345,
                spellID = 12345,
            }
        end,
    },
    CDMIconFactory = {
        _FinalizeImports = noop,
        AcquireIcon = noop,
        ReleaseIcon = noop,
    },
    CDMRuntimeStore = {
        SetIconState = noop,
    },
}

dofile("tests/helpers/load_cdm_icon_runtime.lua")(ns)
assert(loadfile("QUI_CDM/cdm/cdm_icon_renderer.lua"))("QUI", ns)
local RuntimeQueries = ns.CDMRuntimeQueries

local durationBindingKeyBuilds
for _, probe in ipairs(ns._memprobes or {}) do
    if probe.name == "CDM_durationBindingKeys" then
        durationBindingKeyBuilds = probe.fn
        break
    end
end

local durationApplyCalls = 0
local lastAppliedDuration
local icon = {
    Cooldown = {
        SetCooldownFromDurationObject = function(_, durObj)
            durationApplyCalls = durationApplyCalls + 1
            lastAppliedDuration = durObj
            return true
        end,
        SetReverse = noop,
        SetSwipeTexture = noop,
        SetDrawSwipe = noop,
        SetDrawEdge = noop,
        SetSwipeColor = noop,
        SetHideCountdownNumbers = noop,
        Show = noop,
        Clear = noop,
    },
    _lastDurObjKey = "gcd-only:12345",
    _lastDurObj = gcdDuration,
    _showingGCDSwipe = nil,
    _showingRealCooldownSwipe = true,
    _spellEntry = {
        id = 12345,
        spellID = 12345,
        kind = "cooldown",
        type = "spell",
        viewerType = "essential",
    },
}

RuntimeQueries.BeginRuntimeQueryBatch()
icon._lastDurationBindingEpoch = RuntimeQueries.GetActiveBatchEpoch()
local keyBuildsBefore = durationBindingKeyBuilds and durationBindingKeyBuilds() or 0
local applied = ns.CDMIcons.ApplyResolvedCooldown(icon)
local keyBuildsAfter = durationBindingKeyBuilds and durationBindingKeyBuilds() or 0

assert(applied == true, "deduped GCD duration should still be treated as applied")
assert(keyBuildsAfter == keyBuildsBefore,
    "legacy duration binding comparison should not allocate a replacement key")
assert(icon._showingGCDSwipe == true, "deduped GCD duration should restore the GCD swipe flag")
assert(icon._showingRealCooldownSwipe == nil, "deduped GCD duration should clear real cooldown swipe state")

local rechargeDuration = { token = "next-charge-duration" }
resolvedMode = "cooldown"
resolvedDuration = rechargeDuration
icon._lastDurObjKey = "cooldown:12345"
icon._lastDurObj = gcdDuration
icon._lastResolvedMode = "cooldown"
icon._lastResolvedSourceID = 12345
RuntimeQueries.EndRuntimeQueryBatch()

RuntimeQueries.BeginRuntimeQueryBatch()
applied = ns.CDMIcons.ApplyResolvedCooldown(icon)
assert(applied == true, "fresh recharge duration should be applied")
assert(durationApplyCalls == 1,
    "same-source cooldown should rebind when its DurationObject changes")
assert(lastAppliedDuration == rechargeDuration,
    "same-source cooldown should bind the fresh DurationObject")

applied = ns.CDMIcons.ApplyResolvedCooldown(icon)
assert(applied == true, "deduped recharge duration should still be treated as applied")
assert(durationApplyCalls == 1,
    "same DurationObject should remain deduped after the refresh")
RuntimeQueries.EndRuntimeQueryBatch()

RuntimeQueries.BeginRuntimeQueryBatch()
applied = ns.CDMIcons.ApplyResolvedCooldown(icon)
assert(applied == true, "next-batch recharge duration should be applied")
assert(durationApplyCalls == 2,
    "same DurationObject should rebind in a later runtime query batch")

applied = ns.CDMIcons.ApplyResolvedCooldown(icon)
assert(applied == true, "same-batch recharge duration should remain applied")
assert(durationApplyCalls == 2,
    "same DurationObject should remain deduped within one runtime query batch")
RuntimeQueries.EndRuntimeQueryBatch()

print("OK: cdm_icons_gcd_dedupe_test")
