-- tests/unit/cdm_hud_visibility_no_blizzard_fallback_test.lua
-- Run: lua tests/unit/cdm_hud_visibility_no_blizzard_fallback_test.lua
--
-- CDM HUD visibility may fade QUI-owned containers, but must not enumerate
-- Blizzard CooldownViewer globals during cold login. Touching those viewers from
-- the generic visibility controller can taint Blizzard's UNIT_AURA path.

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local hud = read("QUI_CDM/cdm/hud_visibility.lua")
assert(not hud:find("DEFAULT_VIEWER_FRAME_NAMES", 1, true),
    "hud_visibility must not keep a Blizzard CooldownViewer fallback list")
assert(not hud:find("GetViewerFrameNames", 1, true),
    "hud_visibility must not ask the provider for Blizzard viewer names")
assert(not hud:find("_G[blizzName]", 1, true),
    "hud_visibility must not collect Blizzard viewer globals")

-- Re-anchored viewer fade: live Blizzard item frames stay parented to their
-- native viewers (SetPoint bridge, never SetParent), so container fades never
-- reach the icon art/swipe/count. The CDM controller must drive viewer alpha
-- too — but only through the boot-gated helper, never by enumerating globals.
local helperStart = assert(hud:find("local function ApplyReanchorViewerAlpha(alpha)", 1, true),
    "hud_visibility must define ApplyReanchorViewerAlpha (re-anchored viewer fade)")
local helperStop = assert(hud:find("\nend", helperStart, true))
local helper = hud:sub(helperStart, helperStop)
assert(helper:find("ns._cdmBoot", 1, true),
    "viewer fade must be gated on ns._cdmBoot (inert during cold login)")
assert(helper:find("GetViewerForKey", 1, true),
    "viewer fade must resolve viewers via the boot wiring, not globals")
assert(helper:find("_securecall(_rawViewerSetAlpha, viewer, alpha)", 1, true),
    "viewer fade must write alpha via securecall'd raw SetAlpha")
assert(helper:find("if not IsCDMMasterEnabled() then alpha = 1 end", 1, true),
    "viewer fade must pin viewers to alpha 1 while the CDM master toggle is off")

-- All four CDM alpha-application sites must drive the viewers: the fade tick,
-- the already-at-target early return, the layout-mode snap, and the
-- curve-driven HP override. The first three route through the shared
-- visibility controller's onAlpha hook, which the CDM controller wires to
-- ApplyReanchorViewerAlpha; the HP override applies it directly.
assert(hud:find("onAlpha = function(alpha) ApplyReanchorViewerAlpha(alpha) end", 1, true),
    "the CDM visibility controller must wire onAlpha to ApplyReanchorViewerAlpha")
assert(hud:find("ApplyReanchorViewerAlpha(damagedAlpha)", 1, true),
    "the curve-driven HP override must drive the viewer fade")
for _, method in ipairs({ "Tick", "StartFade", "Snap" }) do
    local start = assert(hud:find("function VisibilityController:" .. method .. "(", 1, true),
        "missing VisibilityController:" .. method)
    local stop = assert(hud:find("\nend", start, true))
    assert(hud:sub(start, stop):find("self.onAlpha(", 1, true),
        "VisibilityController:" .. method .. " must apply the onAlpha hook")
end

local containers = read("QUI_CDM/cdm/cdm_containers.lua")
local start = assert(containers:find("function CDMProvider:GetViewerFrames()", 1, true),
    "missing CDMProvider:GetViewerFrames")
local stop = assert(containers:find("\nend", start, true), "missing end of GetViewerFrames")
local block = containers:sub(start, stop)
assert(block:find("return self.emptyFrames", 1, true),
    "CDMProvider:GetViewerFrames must return emptyFrames before owned containers initialize")
assert(not block:find("_G[blizzName]", 1, true),
    "CDMProvider:GetViewerFrames must not return Blizzard globals pre-init")

local function RawSetAlpha(frame, alpha)
    frame.alpha = alpha
end
local function MakeFrame()
    return {
        alpha = 1,
        SetAlpha = RawSetAlpha,
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end
_G.CreateFrame = MakeFrame
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end
_G.wipe = function(values)
    for key in pairs(values) do values[key] = nil end
end
local inCombat, ready = true, true
_G.InCombatLockdown = function() return inCombat end
_G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return ready end }
local profile = { ncdm = { enabled = true, trackedBar = { enabled = true } } }
local core = { db = { profile = profile } }
_G.QUI = core
local nativeViewers = {}
local ownedBar = MakeFrame()
ownedBar._quiCdmKey = "trackedBar"
local ns = {
    Addon = core,
    CDMProvider = { GetViewerFrames = function() return { ownedBar } end },
    _cdmBoot = { wiring = { GetViewerForKey = function(_, key) return nativeViewers[key] end } },
}
local helperEnd = assert(hud:find("local function ShouldHideForLocationRules", 1, true))
local applyNativeAlpha, getFrames = assert(loadstring(hud:sub(1, helperEnd - 1)
    .. "\nreturn ApplyReanchorViewerAlpha, GetCDMFrames"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_blizzard_buffbar_suppression.lua"))("QUI", ns)
local suppressor = ns.CDMBlizzardBuffBarSuppressor
assert(getFrames()[1] == ownedBar, "QUI-owned tracked bars must remain in the HUD fade collection")
for _, scenario in ipairs({ "combat", "unready" }) do
    inCombat = scenario == "combat"
    ready = scenario ~= "unready"
    for _, key in ipairs({ "essential", "utility", "buff", "trackedBar" }) do
        nativeViewers[key] = MakeFrame()
    end
    local nativeBar = nativeViewers.trackedBar
    _G.BuffBarCooldownViewer = nativeBar
    suppressor:Apply(profile.ncdm.trackedBar)
    assert(nativeBar.alpha == 0, scenario .. " suppression precondition failed")
    for _, alpha in ipairs({ 1, 0.4, 0, {} }) do
        applyNativeAlpha(alpha)
        assert(nativeBar.alpha == 0, scenario .. " HUD fade must not bypass native tracked-bar suppression")
        assert(nativeViewers.buff.alpha == alpha, "native buff icons must continue following the HUD fade")
    end
    profile.ncdm.trackedBar.enabled = false
    suppressor:Apply(profile.ncdm.trackedBar)
    applyNativeAlpha(0)
    assert(nativeBar.alpha == 1, "disabled tracked bars must remain restored by the suppressor")
    profile.ncdm.trackedBar.enabled = true
    suppressor:Apply(profile.ncdm.trackedBar)
    profile.ncdm.enabled = false
    suppressor:Apply(profile.ncdm.trackedBar)
    applyNativeAlpha(0)
    assert(nativeBar.alpha == 1, "disabled CDM master must leave the native tracked bar restored")
    profile.ncdm.enabled = true
end

print("OK: cdm_hud_visibility_no_blizzard_fallback_test")
