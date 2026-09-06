-- tests/unit/cdm_trackedbar_owned_layout_test.lua
-- Run: lua tests/unit/cdm_trackedbar_owned_layout_test.lua

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data:gsub("\r\n", "\n")
end

local buffLayout = readAll("QUI_CDM/cdm/cdm_buff_layout.lua")
local layoutStart = assert(buffLayout:find("LayoutBuffBars = function()", 1, true),
    "LayoutBuffBars definition not found")
local layoutEnd = assert(buffLayout:find("local lastIconState = { count = -1 }", layoutStart, true),
    "LayoutBuffBars end marker not found")
local layoutBody = buffLayout:sub(layoutStart, layoutEnd)

local suppressPos = assert(layoutBody:find("ns.CDMBlizzardBuffBarSuppressor:Apply(settings)", 1, true),
    "LayoutBuffBars must apply native viewer suppression")
local readinessPos = assert(layoutBody:find("IsCooldownViewerReady()", 1, true),
    "LayoutBuffBars must retain its data-readiness gate")
assert(suppressPos < readinessPos,
    "LayoutBuffBars must hide the native viewer before waiting for data readiness")
assert(not layoutBody:find('RefreshBuiltin("trackedBar"', 1, true),
    "LayoutBuffBars must not route trackedBar through the re-anchor runtime")
assert(layoutBody:find("local runtimeEntries = GetTrackedBarRuntimeEntries()", 1, true),
    "LayoutBuffBars must read Blizzard tracked-bar children as the owned bar data source")
assert(layoutBody:find('CDMBars:Refresh(viewer, settings, resolvedBarWidth, "trackedBar", runtimeEntries)', 1, true),
    "LayoutBuffBars must refresh addon-owned trackedBar StatusBars from native runtime entries")

local sourceViewerStart = assert(buffLayout:find("local function GetTrackedBarSourceViewer()", 1, true),
    "tracked-bar source viewer resolver not found")
local sourceViewerEnd = assert(buffLayout:find("\nend\n\nlocal function GetTrackedBarName", sourceViewerStart, true),
    "tracked-bar source viewer resolver end not found")
local sourceViewerBody = buffLayout:sub(sourceViewerStart, sourceViewerEnd)
assert(sourceViewerBody:find('return _G["BuffBarCooldownViewer"] or GetBuffBarViewer()', 1, true),
    "tracked-bar runtime scanner must prefer Blizzard's BuffBarCooldownViewer over QUI's owned viewer")

local containers = readAll("QUI_CDM/cdm/cdm_containers.lua")
assert(containers:find('local REANCHOR_KEYS = { "essential", "utility", "buff" }', 1, true),
    "trackedBar must be excluded from the re-anchor hook key set")
assert(not containers:find('local REANCHOR_KEYS = { "essential", "utility", "buff", "trackedBar" }', 1, true),
    "trackedBar must not be registered as a re-anchor hook key")
assert(containers:find("ns._cdmTrackedBarLifecycleHooks", 1, true),
    "trackedBar must still install a separate BuffBarCooldownViewer lifecycle hook")
assert(containers:find('keys = { "trackedBar" }', 1, true),
    "trackedBar lifecycle hook must listen to BuffBarCooldownViewer without joining REANCHOR_KEYS")
assert(containers:find("ns.CDMBuffLayout.LayoutBars()", 1, true),
    "trackedBar lifecycle hook must refresh the owned Buff Bars layout")
assert(not containers:find("immediateRefreshLayoutKeys = { trackedBar = true }", 1, true),
    "trackedBar RefreshLayout must use the delayed lifecycle scheduler")
assert(not containers:find("immediateAcquireKeys", 1, true),
    "Buff and trackedBar acquisition must use the delayed lifecycle path")
assert(containers:find("CooldownViewerSettings.OnShow", 1, true)
    and containers:find("CooldownViewerSettings.OnHide", 1, true),
    "CooldownViewerSettings show/hide must resync native reanchor and trackedBar lifecycle hooks")
local initStart = assert(containers:find("function ownedEngine:Initialize()", 1, true),
    "owned engine initializer not found")
local initEnd = assert(containers:find("\n    local function DrainPendingLoadoutSwitch", initStart, true),
    "owned engine initializer end marker not found")
local initBody = containers:sub(initStart, initEnd)
assert(not initBody:find("C_Timer.After(1.0", 1, true)
    and not initBody:find("C_Timer.After(3.0", 1, true)
    and not initBody:find("C_Timer.After(6.0", 1, true),
    "CDM startup must not schedule unconditional full re-anchor passes")
local pewStart = assert(containers:find('elseif event == "PLAYER_ENTERING_WORLD" then', 1, true),
    "PLAYER_ENTERING_WORLD handler not found")
local pewEnd = assert(containers:find('elseif event == "PLAYER_SPECIALIZATION_CHANGED" then', pewStart, true),
    "PLAYER_ENTERING_WORLD handler end marker not found")
local pewBody = containers:sub(pewStart, pewEnd)
assert(pewBody:find("RefreshReanchorRuntimeHooks(false)", 1, true),
    "PLAYER_ENTERING_WORLD must install native hooks without scheduling a duplicate dirty pass")
assert(containers:find('local EDIT_LOCK_KEYS = { "essential", "utility", "buff", "trackedBar" }', 1, true),
    "trackedBar must remain Edit Mode locked/suppressed even though it is not re-anchored")
assert(containers:find("keys = EDIT_LOCK_KEYS,", 1, true),
    "Edit Mode lock must use the broader Edit Mode key set")

local editStart = assert(containers:find("_G.QUI_OnEditModeEnterCDM = function()", 1, true),
    "Edit Mode enter function not found")
local editEnd = assert(containers:find("_G.QUI_OnEditModeExitCDM = function()", editStart, true),
    "Edit Mode exit function not found")
local editBody = containers:sub(editStart, editEnd)
assert(not editBody:find('RefreshBuiltin("trackedBar"', 1, true),
    "Edit Mode enter must not refresh trackedBar through the re-anchor runtime")
assert(editBody:find("ns.CDMBars:Refresh(containers.trackedBar", 1, true),
    "Edit Mode enter must populate owned trackedBar bars")
assert(not editBody:find("ForceAllActive", 1, true),
    "Edit Mode enter must let LayoutBars expose pooled bars without reading rendered text")

local barRenderer = readAll("QUI_CDM/cdm/cdm_bar_renderer.lua")
assert(barRenderer:find("NormalizeTrackedBarRuntimeEntries(runtimeEntries)", 1, true),
    "bar renderer must normalize native tracked-bar entries for owned bars")
assert(barRenderer:find('containerKey == "trackedBar"', 1, true),
    "runtime entry override must be scoped to trackedBar only")
assert(not barRenderer:find("NameText:GetText()", 1, true),
    "bar renderer must keep rendered text opaque and pass secret values only to C sinks")

local realEnv = readAll("QUI_CDM/cdm/cdm_reanchor_realenv.lua")
assert(not realEnv:find("_InstallBarReskinHooks", 1, true)
    and not realEnv:find('hooksecurefunc(live, "SetBarContent"', 1, true)
    and not realEnv:find('hooksecurefunc(live, "SetBarWidth"', 1, true),
    "owned tracked bars must not install native tracked-bar reskin hooks")

do
    local start = assert(containers:find(
        "            if EventRegistry and EventRegistry.RegisterCallback", 1, true))
    local stop = assert(containers:find(
        "\n        end\n        self:InstallReanchorProcGlowHooks", start, true))
    local install = assert(loadstring("return function(ns, EventRegistry, C_Timer)\n"
        .. containers:sub(start, stop - 1) .. "\nend"))()
    local callbacks, timers = {}, {}
    local iconRefreshes, barRefreshes = 0, 0
    install({
        _cdmReanchorHooks = { MarkAllDirty = function() iconRefreshes = iconRefreshes + 1 end },
        _cdmTrackedBarLifecycleHooks = { MarkAllDirty = function() barRefreshes = barRefreshes + 1 end },
    }, {
        RegisterCallback = function(_, event, callback) callbacks[event] = callback end,
    }, {
        After = function(delay, callback) timers[delay] = callback end,
    })
    callbacks["CooldownViewerSettings.OnHide"]()
    assert(iconRefreshes == 0 and barRefreshes == 0,
        "settings close must let Blizzard finish before requesting reanchors")
    assert(timers[0.1] and timers[0.3],
        "settings close must retain the reference's delayed reanchor and later buff-bar sync")
    timers[0.1]()
    assert(iconRefreshes == 1 and barRefreshes == 1,
        "settled settings close refreshes both lifecycle groups")
    timers[0.3]()
    assert(iconRefreshes == 1 and barRefreshes == 2,
        "late native pool changes receive a separate buff-bar refresh")
end

print("OK: cdm_trackedbar_owned_layout_test")
