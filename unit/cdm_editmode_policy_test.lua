-- tests/unit/cdm_editmode_policy_test.lua
-- Run: lua tests/unit/cdm_editmode_policy_test.lua

local registeredEvents = {}
local eventHandler
_G.CreateFrame = function()
    return {
        RegisterEvent = function(_, event) registeredEvents[event] = true end,
        UnregisterEvent = function(_, event) registeredEvents[event] = nil end,
        SetScript = function(_, name, fn)
            if name == "OnEvent" then eventHandler = fn end
        end,
    }
end

local ENUMS = {
    cooldownSystem = 13,
    visSetting = 6,
    visAlways = 0,
    hideEnum = 8,
    buffIconIdx = 3,
    buffBarIdx = 4,
}

_G.Enum = {
    EditModeSystem = { CooldownViewer = ENUMS.cooldownSystem },
    EditModeCooldownViewerSetting = {
        VisibleSetting = ENUMS.visSetting,
        HideWhenInactive = ENUMS.hideEnum,
    },
    CooldownViewerVisibleSetting = { Always = ENUMS.visAlways, InCombat = 1, Hidden = 2 },
    EditModeCooldownViewerSystemIndices = {
        Essential = 1,
        Utility = 2,
        BuffIcon = ENUMS.buffIconIdx,
        BuffBar = ENUMS.buffBarIdx,
    },
}

local layoutInfoToReturn
_G.C_EditMode = {
    GetLayouts = function() return layoutInfoToReturn end,
}

local popupsShown = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which)
    popupsShown[#popupsShown + 1] = which
    return {}
end
_G.QUI_IsCDMMasterEnabled = function() return true end

local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns)
local P = assert(ns.CDMEditModePolicy, "CDMEditModePolicy exported")
assert(type(P.NeedsManualSetup) == "function", "read-only detector exported")
assert(type(P.Enforce) == "function", "Enforce exported")

local function mkSystems(settingsByIdx)
    local systems = {}
    for idx = 1, 4 do
        systems[#systems + 1] = {
            system = ENUMS.cooldownSystem,
            systemIndex = idx,
            settings = settingsByIdx[idx] or {},
        }
    end
    systems[#systems + 1] = {
        system = 99,
        systemIndex = 1,
        settings = { { setting = ENUMS.visSetting, value = 2 } },
    }
    return systems
end

do
    local systems = mkSystems({})
    assert(P.NeedsManualSetup(systems, ENUMS) == false, "defaults need no setup")
    for i = 1, 4 do
        assert(#systems[i].settings == 0, "detector must not insert default settings")
    end
end

do
    local systems = mkSystems({ [1] = { { setting = ENUMS.visSetting, value = 2 } } })
    assert(P.NeedsManualSetup(systems, ENUMS) == true, "hidden viewer needs manual setup")
    assert(systems[1].settings[1].value == 2, "detector must not rewrite visibility")
end

do
    local systems = mkSystems({
        [ENUMS.buffIconIdx] = { { setting = ENUMS.hideEnum, value = 0 } },
        [1] = { { setting = ENUMS.hideEnum, value = 0 } },
    })
    assert(P.NeedsManualSetup(systems, ENUMS) == true, "active buff viewer needs manual setup")
    assert(systems[ENUMS.buffIconIdx].settings[1].value == 0,
        "detector must not rewrite Hide When Inactive")
    assert(systems[1].settings[1].value == 0,
        "non-buff Hide When Inactive remains outside the policy")
end

do
    local systems = mkSystems({
        [ENUMS.buffBarIdx] = {
            { setting = ENUMS.visSetting, value = ENUMS.visAlways },
            { setting = ENUMS.hideEnum, value = 1 },
        },
    })
    assert(P.NeedsManualSetup(systems, ENUMS) == false, "correct stored values need no setup")
end

do
    local systems = mkSystems({})
    assert(P.NeedsManualSetup({ systems[5] }, ENUMS) == false, "non-CDM systems are ignored")
    assert(systems[5].settings[1].value == 2, "non-CDM settings remain untouched")
end

assert(registeredEvents["PLAYER_ENTERING_WORLD"], "policy registers PLAYER_ENTERING_WORLD")
assert(type(eventHandler) == "function", "policy installs an OnEvent handler")

local standingPresetManager = {
    GetCopyOfPresetLayouts = function()
        return { { systems = mkSystems({}) }, { systems = mkSystems({}) } }
    end,
}
_G.EditModePresetLayoutManager = standingPresetManager

local function staleLayout()
    return {
        activeLayout = 3,
        layouts = {
            { systems = mkSystems({ [1] = { { setting = ENUMS.visSetting, value = 2 } } }) },
        },
    }
end

layoutInfoToReturn = staleLayout()
local originalLayouts = layoutInfoToReturn.layouts
eventHandler(nil, "PLAYER_ENTERING_WORLD")
assert(popupsShown[1] == "QUI_CDM_EDITMODE_MANUAL", "stale layout shows manual instructions")
local manualDialog = assert(_G.StaticPopupDialogs["QUI_CDM_EDITMODE_MANUAL"],
    "stale layout registers manual instructions")
assert(manualDialog.text:find("/qui > Module Addons", 1, true),
    "manual instructions name the exact QUI settings path")
assert(layoutInfoToReturn.layouts == originalLayouts, "detector must not replace Blizzard's layout list")
assert(layoutInfoToReturn.layouts[1].systems[1].settings[1].value == 2,
    "detector must not rewrite the active layout")
eventHandler(nil, "PLAYER_ENTERING_WORLD")
assert(#popupsShown == 1, "enforcement is one-shot per session")

do
    local ns2 = {}
    popupsShown = {}
    layoutInfoToReturn = { activeLayout = 3, layouts = { { systems = mkSystems({}) } } }
    loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns2)
    eventHandler(nil, "PLAYER_ENTERING_WORLD")
    assert(#popupsShown == 0, "correct layout shows no popup")
end

do
    local ns3 = {}
    popupsShown = {}
    _G.EditModePresetLayoutManager = {
        GetCopyOfPresetLayouts = function()
            return { { systems = mkSystems({ [1] = { { setting = ENUMS.visSetting, value = 2 } } }) } }
        end,
    }
    layoutInfoToReturn = { activeLayout = 1, layouts = {} }
    loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns3)
    eventHandler(nil, "PLAYER_ENTERING_WORLD")
    assert(#popupsShown == 0, "preset layouts remain read-only and do not prompt")
    _G.EditModePresetLayoutManager = standingPresetManager
end

do
    local ns4 = {}
    popupsShown = {}
    _G.EditModePresetLayoutManager = nil
    layoutInfoToReturn = staleLayout()
    loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns4)
    eventHandler(nil, "PLAYER_ENTERING_WORLD")
    assert(#popupsShown == 0, "missing preset data does not guess the active layout")
    assert(layoutInfoToReturn.layouts[1].systems[1].settings[1].value == 2,
        "missing preset data leaves stored settings untouched")
    _G.EditModePresetLayoutManager = standingPresetManager
end

do
    local ns5 = {}
    popupsShown = {}
    local regs = {}
    local frameStub = {
        RegisterEvent = function(_, event) regs[event] = true end,
        UnregisterEvent = function(_, event) regs[event] = nil end,
    }
    _G.InCombatLockdown = function() return true end
    layoutInfoToReturn = staleLayout()
    loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns5)
    eventHandler(frameStub, "PLAYER_ENTERING_WORLD")
    assert(#popupsShown == 0, "combat login defers the policy check")
    assert(regs["PLAYER_REGEN_ENABLED"], "combat login waits for PLAYER_REGEN_ENABLED")
    _G.InCombatLockdown = function() return false end
    eventHandler(frameStub, "PLAYER_REGEN_ENABLED")
    assert(popupsShown[1] == "QUI_CDM_EDITMODE_MANUAL", "regen shows manual instructions")
    assert(regs["PLAYER_REGEN_ENABLED"] == nil, "regen listener unregisters after firing")
    _G.InCombatLockdown = nil
end

local toc = assert(io.open("QUI_CDM/QUI_CDM.toc", "r"))
for line in toc:lines() do
    local rel = line:match("^%s*(cdm[\\/]%S+%.lua)%s*$")
    if rel then
        local path = "QUI_CDM/" .. rel:gsub("\\", "/")
        local file = assert(io.open(path, "rb"))
        local source = file:read("*a")
        file:close()
        assert(not source:find("SaveLayouts", 1, true),
            path .. " must not save Blizzard Edit Mode layouts from addon execution")
        assert(not source:find("cdmEditModeSavePending", 1, true),
            path .. " must not retain the obsolete automatic-save state")
    end
end
toc:close()

print("OK: cdm_editmode_policy_test")
