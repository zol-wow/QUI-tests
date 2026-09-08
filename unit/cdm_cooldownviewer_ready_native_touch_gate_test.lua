-- tests/unit/cdm_cooldownviewer_ready_native_touch_gate_test.lua
-- Run: lua tests/unit/cdm_cooldownviewer_ready_native_touch_gate_test.lua
--
-- First login can expose Blizzard CooldownViewer frames before their data
-- provider is ready. Native BuffBarCooldownViewer reads/writes must wait for
-- the shared readiness gate; /reload often masks this because the provider is
-- already warm.

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s:gsub("\r\n", "\n"):gsub("\r", "\n")
end

local function slice(text, startMarker, stopMarker)
    local start = assert(text:find(startMarker, 1, true), "missing " .. startMarker)
    local stop = stopMarker and text:find(stopMarker, start + #startMarker, true)
    return text:sub(start, stop and (stop - 1) or #text)
end

local catalog = read("QUI_CDM/cdm/cdm_catalog.lua")
assert(catalog:find("function CDMCatalog.IsCooldownViewerReady()", 1, true),
    "CDMCatalog must export the CooldownViewer data readiness gate")
assert(catalog:find("IsCooldownViewerAvailable", 1, true),
    "readiness gate must use C_CooldownViewer.IsCooldownViewerAvailable")

local buff = read("QUI_CDM/cdm/cdm_buff_layout.lua")
local layoutBars = slice(buff, "LayoutBuffBars = function()", "-- CHANGE DETECTION")
local readyPos = assert(layoutBars:find("IsCooldownViewerReady()", 1, true),
    "LayoutBuffBars must check CooldownViewer readiness")
local entriesPos = assert(layoutBars:find("GetTrackedBarRuntimeEntries()", 1, true),
    "LayoutBuffBars still mirrors native runtime entries after readiness")
assert(readyPos < entriesPos,
    "LayoutBuffBars must gate native BuffBar reads before building runtime entries")
assert(layoutBars:find("QueueTrackedBarLayoutWhenReady()", readyPos, true),
    "LayoutBuffBars must queue a retry for COOLDOWN_VIEWER_DATA_LOADED")

local editlock = read("QUI_CDM/cdm/cdm_reanchor_editlock.lua")
local install = slice(editlock, "function CDMReanchorEditLock:Install(getViewer)")
assert(install:find("_IsCooldownViewerReady()", 1, true),
    "Edit lock must wait for CooldownViewer readiness before viewer lookup/mutation")

local containers = read("QUI_CDM/cdm/cdm_containers.lua")
local readyQueue = slice(containers,
    "local function QueueReanchorHooksWhenCooldownViewerReady(markDirty)",
    "local _reanchorGlowOverlays")
assert(readyQueue:find("reanchorHooksReadyMarkDirty or canMarkDirty", 1, true),
    "COOLDOWN_VIEWER_DATA_LOADED hook retry must request an out-of-combat initial re-claim")

local refreshHooks = slice(containers,
    "function ownedEngine:RefreshReanchorRuntimeHooks(markDirty)",
    "function ownedEngine:BootstrapReanchorRuntime()")
assert(refreshHooks:find("IsCooldownViewerReady()", 1, true),
    "native re-anchor hook install must check CooldownViewer readiness")
assert(refreshHooks:find("QueueReanchorHooksWhenCooldownViewerReady(markDirty)", 1, true),
    "native re-anchor hook install must retain the data-ready retry")
local queuePos = assert(refreshHooks:find("QueueReanchorHooksWhenCooldownViewerReady(markDirty)", 1, true))
local gracePos = assert(refreshHooks:find("if not ns._cdmCombatReloadGrace then return false end", 1, true),
    "only combat /reload may install viewer guards before data readiness")
local installPos = assert(refreshHooks:find("hk:InstallViewerHooks(getViewer)", 1, true))
assert(queuePos < gracePos and gracePos < installPos,
    "combat /reload must install viewer guards synchronously before Blizzard's PEW rebuild")
assert(refreshHooks:find("InstallGlobalMixinHooks", 1, true),
    "native re-anchor hook install must include global CooldownViewer item mixin hooks")

local bootstrapHooks = slice(containers,
    "function ownedEngine:BootstrapReanchorRuntime()",
    "-- Task C (G6 + G8)")
assert(bootstrapHooks:find("BlankReanchoredNativeItemFrame", 1, true),
    "re-anchor bootstrap must provide a native frame blanker")
assert(bootstrapHooks:find("isInitialReanchorDone", 1, true),
    "acquire blanking must be gated until initial reanchor completes")
assert(bootstrapHooks:find("blankKeys = { buff = true }", 1, true),
    "Essential/Utility acquire blanking must stay disabled to avoid native pool flicker")
assert(bootstrapHooks:find("blankKeys = { trackedBar = true }", 1, true),
    "tracked buff-bar acquire blanking must be explicitly enabled")
assert(bootstrapHooks:find("bridge:Sink(frame)", 1, true),
    "combat /reload acquire guards must sink newly rebuilt Essential/Utility frames")
assert(bootstrapHooks:find("ns._cdmCombatReloadGrace or IsInitialReanchorDone(key)", 1, true),
    "combat /reload must guard post-load pool acquires before the first data-ready reanchor")

local guardBody = assert(bootstrapHooks:match(
    "installGuard = function%(frame, key%)%s*(.-)%s*end,%s*installGuardKeys"),
    "combat /reload acquire guard callback must be extractable")
local loadSource = loadstring or load
local installGuard = assert(loadSource(
    "return function(ns, boot, frame, key)\n" .. guardBody .. "\nend"))()
local guarded, sunk = {}, {}
local frame = {}
installGuard({ _cdmCombatReloadGrace = true }, { bridge = {
    InstallAnchorGuard = function(_, value) guarded[#guarded + 1] = value end,
    IsClaimed = function() return false end,
    Sink = function(_, value) sunk[#sunk + 1] = value end,
} }, frame, "essential")
assert(guarded[1] == frame and sunk[1] == frame,
    "combat /reload acquire must install the guard and sink the new Essential frame")

local runtimeNS = {}
assert(loadfile("QUI_CDM/cdm/cdm_reanchor.lua"))("QUI", runtimeNS)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_hooks.lua"))("QUI", runtimeNS)
local function hook(owner, method, callback)
    local original = owner[method]
    owner[method] = function(...)
        original(...)
        callback(...)
    end
end
local raw = {
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    ClearAllPoints = function(f) f.points = {} end,
    SetPoint = function(f, point, relativeTo, relativePoint, x, y)
        f.points[point] = { relativeTo, relativePoint, x, y }
    end,
}
local screen, container = {}, {}
local liveBridge = runtimeNS.CDMReanchor.New({raw = raw, sinkAnchor = screen, hooksecurefunc = hook})
local ready = false
local viewer = { RefreshLayout = function() end, OnAcquireItemFrame = function() end }
local liveHooks = runtimeNS.CDMReanchorHooks.New({
    keys = { "essential" },
    hooksecurefunc = hook,
    installGuardKeys = { essential = true },
    isInitialReanchorDone = function() return ready end,
    installGuard = function(f, key)
        installGuard({}, {bridge = liveBridge}, f, key)
    end,
    schedule = function() end,
})
liveHooks:InstallViewerHooks(function() return viewer end)
local fresh = { alpha = 1, points = {}, SetPoint = raw.SetPoint }
viewer:OnAcquireItemFrame(fresh)
assert(fresh.alpha == 1, "cold initialization must wait for QUI's first placement pass")
ready = true
for _, key in ipairs({ "essential", "utility" }) do
    local item = { alpha = 1, points = {}, SetPoint = raw.SetPoint }
    installGuard({}, {bridge = liveBridge}, item, key)
    assert(item.alpha == 0, "normal pool acquisition must suppress new " .. key .. " icons before the delayed refresh")
    item:SetPoint("CENTER", screen, "CENTER", 0, 0)
    assert(item.points.CENTER == nil and item.points.TOPLEFT[4] == -10000,
        "native layout cannot display an unclaimed cooldown between acquire and refresh")
    liveBridge:Overlay(item, container)
    installGuard({}, {bridge = liveBridge}, item, key)
    assert(item.alpha == 1 and item.points.TOPLEFT[1] == container,
        "reacquiring a claimed cooldown must preserve its visible placement")
end
viewer:OnAcquireItemFrame(fresh)
assert(fresh.alpha == 0, "the actual acquire hook must suppress after initial placement completes")

local initialize = slice(containers,
    "function ownedEngine:Initialize()",
    "local function DrainPendingLoadoutSwitch")
assert(initialize:find('UnitAffectingCombat("player")', 1, true),
    "combat /reload must latch physical combat before ForceLoadCDM")

local getViewerFrame = slice(containers,
    "function CDMProvider:GetViewerFrame(key)",
    "function CDMProvider:GetViewerFrames()")
assert(not getViewerFrame:find("_G%[blizzName%]"),
    "CDMProvider:GetViewerFrame must not return Blizzard globals before owned containers initialize")
assert(getViewerFrame:find("return nil", 1, true),
    "CDMProvider:GetViewerFrame must fail closed before owned containers initialize")

print("OK: cdm_cooldownviewer_ready_native_touch_gate_test")
