-- tests/unit/cdm_buff_layout_reanchor_repair_net_test.lua
-- Run: lua tests/unit/cdm_buff_layout_reanchor_repair_net_test.lua
--
-- Repair net under test: the player UNIT_AURA coalesce in cdm_buff_layout was
-- blind under the re-anchor engine -- its combat gate counted visible icons from
-- CDMIconFactory:GetIconPool("buff"), which the engine leaves EMPTY (matched buff
-- entries are direct-anchored native Blizzard frames), and LayoutBuffIcons
-- early-returns when the engine owns the surface. So one lost/dropped
-- OnActiveStateChanged event left the buff surface stuck (invisible active buff
-- or stale expired icon) until unrelated churn. The reference addon layers
-- redundant repair triggers; the QUI equivalent is routing the aura coalesce to
-- the re-anchor hooks' throttled re-claim (MarkDirty -> Flush -> RefreshBuiltin).

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data:gsub("\r\n", "\n")
end

local src = readAll("QUI_CDM/cdm/cdm_buff_layout.lua")

assert(not src:find(":MarkClean()", 1, true),
    "buff layout must not write Blizzard viewer dirty state")

local bodyStart = assert(src:find("local iconAuraCoalesce = CreateFrame", 1, true),
    "icon aura coalesce frame not found")
local bodyEnd = assert(src:find("if ns.AuraEvents then", bodyStart, true),
    "icon aura coalesce end marker not found")
local body = src:sub(bodyStart, bodyEnd)

assert(body:find('ns._cdmReanchorHooks:MarkDirty("buff")', 1, true),
    "aura coalesce must route a re-anchor repair re-claim (MarkDirty 'buff') when the engine owns the buff surface")

local reanchorPos = body:find("_cdmBoot", 1, true)
local legacyPos = body:find('GetIconPool("buff")', 1, true)
assert(reanchorPos, "re-anchor routing must gate on ns._cdmBoot (engine active)")
assert(legacyPos, "legacy owned-pool count path should remain for the non-engine path")
assert(reanchorPos < legacyPos,
    "re-anchor routing must run BEFORE the legacy owned-pool count (the pool is empty under the engine, so the legacy gate is blind)")

-- INSTALL must be UNCONDITIONAL. ADDON_LOADED handlers fire in registration
-- (TOC) order: cdm_buff_layout registers BEFORE cdm_containers, so when
-- Initialize() runs the provider engine is not initialized yet and
-- GetBuffIconViewer() (-> CDMProvider:GetViewerFrame) returns nil. Gating the
-- UNIT_AURA subscription install on that init-time viewer skipped it EVERY
-- session -- the repair net never existed in-game (proven by GetLastDiag:
-- aura live, last refresh pass 60s stale). The coalesce handler and the
-- subscriber both re-fetch the viewer per-event, so install-time presence
-- is irrelevant.
local regionStart = assert(src:find("local lastAuraIconCount = 0", 1, true),
    "event-based updates header not found")
local regionEnd = assert(src:find('local barAuraCoalesce = CreateFrame("Frame")', regionStart, true),
    "bar aura coalesce marker not found")
local region = src:sub(regionStart, regionEnd)
assert(region:find('AuraEvents:Subscribe("player"', 1, true),
    "player UNIT_AURA subscription must exist in the icon repair-net region")
assert(not region:find("if iconViewer then", 1, true),
    "UNIT_AURA subscription install must NOT be gated on the init-time viewer "
    .. "(nil during ADDON_LOADED on every boot -- provider engine initializes later)")

do
    local nativeBar = { Layout = function() end }
    local env = setmetatable({
        BuffBarCooldownViewer = nativeBar,
        QUI_GetCDMViewerFrame = function() return nil end,
        C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end },
        C_Timer = { After = function() end },
        InCombatLockdown = function() return false end,
        CreateFrame = function()
            return {
                Hide = function() end,
                RegisterEvent = function() end,
                SetScript = function() end,
            }
        end,
        hooksecurefunc = function(target, method)
            assert(target ~= nativeBar or method ~= "Layout",
                "buff layout must leave native BuffBar Layout unhooked during initialization")
        end,
    }, { __index = _G })
    env._G = env
    local runtimeNS = {
        Helpers = {
            GetCore = function() return nil end,
            CreateStateTable = function() return {} end,
            CreateDBGetter = function() return function() return nil end end,
        },
    }
    local chunk = assert(loadfile("QUI_CDM/cdm/cdm_buff_layout.lua"))
    setfenv(chunk, env)
    chunk("QUI_CDM", runtimeNS)
    runtimeNS.CDMBuffLayout.Initialize()
end

do
    local noop = function() end
    local settings = { enabled = true, iconSize = 42, padding = 2 }
    local viewer = {}
    function viewer:SetSize(w, h) self.width, self.height = w, h end
    local owned = {}
    function owned:IsShown() return true end
    function owned:GetAlpha() return 1 end
    function owned:GetScale() return 1 end
    function owned:GetPoint() return "CENTER", viewer, "CENTER", self.x, 0 end
    function owned:ClearAllPoints() end
    function owned:SetPoint(_, _, _, x) self.x = x end
    local anchorChecks = 0
    local env = setmetatable({
        QUI_GetCDMViewerFrame = function(key) if key == "buffIcon" then return viewer end end,
        QUI_HasFrameAnchor = function()
            anchorChecks = anchorChecks + 1
            return true
        end,
        QUI_SetCDMViewerBounds = function(_, w, h) viewer.boundsW, viewer.boundsH = w, h end,
        InCombatLockdown = function() return false end,
        C_Timer = { After = noop },
        CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end,
    }, { __index = _G })
    env._G = env
    local runtimeNS = {
        _cdmBoot = {},
        Addon = {
            GetPixelSize = function() return 1 end,
            PixelSnapCenter = function(_, x) return x end,
        },
        Helpers = {
            GetCore = function() return nil end,
            CreateStateTable = function() return {} end,
            CreateDBGetter = function() return function() return { buff = settings } end end,
            IsEditModeActive = function() return false end,
        },
        CDMIconFactory = { GetIconPool = function() return { owned } end },
    }
    for _, name in ipairs({ "cdm_layout", "cdm_reanchor_runtime", "cdm_buff_layout" }) do
        local chunk = assert(loadfile("QUI_CDM/cdm/" .. name .. ".lua"))
        setfenv(chunk, env)
        chunk("QUI_CDM", runtimeNS)
    end
    local native1, native2 = {}, {}
    local plan = runtimeNS.CDMLayout.BuildBuffGridLayout(settings, {
        { frame = native1, liveFrame = native1, reanchored = true },
        { frame = native2, liveFrame = native2, reanchored = true },
        { frame = owned },
    })
    local runtime = runtimeNS.CDMReanchorRuntime.New({
        bridge = { InstallAnchorGuard = noop, OverlayRect = noop },
        positionOwned = function(icon, container, point, relPoint, x, y)
            icon:SetPoint(point, container, relPoint, x, y)
        end,
    })
    assert(runtime:PositionEntries(viewer, plan, "buff") == 3)
    viewer:SetSize(plan.metrics.iconWidth, plan.metrics.totalHeight)
    viewer.boundsW, viewer.boundsH = viewer.width, viewer.height
    assert(viewer.width == 130 and owned.x == 44)

    runtimeNS.CDMBuffLayout.LayoutIcons()
    assert(viewer.width == 130 and viewer.boundsW == 130 and owned.x == 44,
        "legacy buff layout must preserve the native engine's complete plan and bounds")
    assert(anchorChecks == 1, "native engine must retain buff container anchoring")

    runtimeNS._cdmBoot = nil
    runtimeNS.CDMBuffLayout.LayoutIcons()
    assert(viewer.width == 42 and viewer.boundsW == 42 and owned.x == 0,
        "legacy buff layout must still position and size its owned icons without the native engine")
end

print("OK: cdm_buff_layout_reanchor_repair_net_test")
