local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
local popupName = "QUI_CDM_EDITMODE_MANUAL"

local function newSession()
    local state = {
        loaded = true,
        enabled = true,
        moduleEnabled = true,
        combat = false,
        mismatch = false,
        reads = 0,
        shown = {},
        hidden = {},
        events = {},
    }
    local frame = {
        RegisterEvent = function(_, event) state.events[event] = true end,
        UnregisterEvent = function(_, event) state.events[event] = nil end,
        SetScript = function(_, script, handler)
            assert(script == "OnEvent")
            state.handler = handler
        end,
    }
    _G.CreateFrame = function() return frame end
    _G.C_CVar = {
        AreCVarsLoaded = function() return state.loaded end,
        GetCVarBool = function(name)
            assert(name == "cooldownViewerEnabled")
            state.reads = state.reads + 1
            return state.enabled
        end,
        SetCVar = function() error("policy must not write native CVars") end,
    }
    _G.SetCVar = _G.C_CVar.SetCVar
    _G.C_EditMode = {
        GetLayouts = function()
            return {
                activeLayout = 2,
                layouts = { { systems = {
                    { system = 13, systemIndex = 1, settings = {
                        { setting = 6, value = state.mismatch and 2 or 0 },
                    } },
                } } },
            }
        end,
        SaveLayouts = function() error("policy must not write native layouts") end,
    }
    _G.EditModePresetLayoutManager = {
        GetCopyOfPresetLayouts = function() return { {} } end,
    }
    _G.Enum = {
        EditModeSystem = { CooldownViewer = 13 },
        EditModeCooldownViewerSetting = { VisibleSetting = 6, HideWhenInactive = 8 },
        CooldownViewerVisibleSetting = { Always = 0 },
        EditModeCooldownViewerSystemIndices = { BuffIcon = 3, BuffBar = 4 },
    }
    _G.InCombatLockdown = function() return state.combat end
    _G.QUI_IsCDMMasterEnabled = function() return state.moduleEnabled end
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which)
        assert(which == popupName)
        local text = assert(_G.StaticPopupDialogs[which]).text
        state.shown[#state.shown + 1] = text
        state.visible = text
        return {}
    end
    _G.StaticPopup_Hide = function(which)
        assert(which == popupName)
        state.hidden[#state.hidden + 1] = which
        state.visible = nil
    end
    state.fire = function(event, ...)
        if state.events[event] then state.handler(frame, event, ...) end
    end
    local ns = {}
    loadChunk("QUI_CDM/cdm/cdm_editmode_policy.lua", "cdm_editmode_policy.lua")("QUI", ns)
    return state
end

do
    local s = newSession()
    s.loaded, s.enabled = false, false
    s.fire("PLAYER_ENTERING_WORLD")
    assert(s.reads == 0 and #s.shown == 0, "login must wait for saved CVars before reading the enable flag")
    s.loaded, s.enabled = true, true
    s.fire("VARIABLES_LOADED")
    assert(s.reads > 0 and #s.shown == 0, "saved enabled setting must prevent the false disabled warning")
end

do
    local s = newSession()
    s.enabled = false
    s.fire("VARIABLES_LOADED")
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "0")
    assert(s.reads == 0 and #s.shown == 0, "variables and CVar updates before entering world must not prompt")
    s.fire("PLAYER_ENTERING_WORLD")
    assert(#s.shown == 1 and s.visible:find("is disabled", 1, true), "ready disabled setting must prompt")
    s.fire("PLAYER_ENTERING_WORLD")
    s.fire("VARIABLES_LOADED")
    assert(#s.shown == 1, "readiness events must not repeat the initial warning")
end

do
    local s = newSession()
    s.loaded, s.enabled = false, false
    s.fire("PLAYER_ENTERING_WORLD")
    s.loaded = true
    s.fire("VARIABLES_LOADED")
    assert(#s.shown == 1 and s.visible:find("is disabled", 1, true),
        "a genuinely disabled saved setting must warn after readiness")
    s.enabled = true
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "0")
    assert(s.visible == nil and #s.hidden == 1, "current CVar value must clear the disabled warning, ignoring event payload")
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.shown == 1 and #s.hidden == 1, "repeated enable updates must not repeat popup operations")
end

do
    local s = newSession()
    s.enabled = false
    s.fire("PLAYER_ENTERING_WORLD")
    local reads = s.reads
    s.enabled = true
    s.fire("CVAR_UPDATE", "unrelatedSetting", "1")
    assert(s.reads == reads and #s.hidden == 0, "unrelated updates must leave the disabled warning alone")
    s.enabled = false
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.hidden == 0 and #s.shown == 1, "false actual setting must not clear or repeat the warning")
    s.enabled = nil
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.hidden == 0 and #s.shown == 1, "unknown actual setting must not clear or repeat the warning")
    s.enabled = true
    s.fire("CVAR_UPDATE", "COOLDOWNVIEWERENABLED", "1")
    assert(s.visible == nil and #s.hidden == 1, "CVar names must be matched without case sensitivity")
end

do
    local s = newSession()
    s.enabled, s.mismatch = false, true
    s.fire("PLAYER_ENTERING_WORLD")
    s.enabled = true
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.hidden == 1 and #s.shown == 2, "enabling must replace the disabled notice when layout setup is still needed")
    assert(s.visible:find("layout mismatch", 1, true) and not s.visible:find("is disabled", 1, true),
        "replacement notice must describe the remaining layout issue")
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.hidden == 1 and #s.shown == 2, "layout notice remains one-shot")
end

do
    local s = newSession()
    s.fire("PLAYER_ENTERING_WORLD")
    s.enabled = false
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "0")
    assert(#s.shown == 0, "later manual disabling must not create a new login warning after successful startup")
end

do
    local s = newSession()
    s.loaded, s.enabled = false, false
    s.fire("PLAYER_ENTERING_WORLD")
    s.loaded, s.combat = true, true
    s.fire("VARIABLES_LOADED")
    assert(#s.shown == 0 and s.events.PLAYER_REGEN_ENABLED, "readiness in combat must defer the warning")
    s.combat = false
    s.fire("PLAYER_REGEN_ENABLED")
    assert(#s.shown == 1 and not s.events.PLAYER_REGEN_ENABLED, "combat end must finish the deferred initial check")
end

do
    local s = newSession()
    s.enabled, s.combat = false, true
    s.fire("PLAYER_ENTERING_WORLD")
    assert(#s.shown == 0 and s.events.PLAYER_REGEN_ENABLED, "combat login must still defer the initial warning")
    s.enabled, s.combat = true, false
    s.fire("PLAYER_REGEN_ENABLED")
    assert(#s.shown == 0, "deferred login must read the setting at combat end")
end

do
    local s = newSession()
    s.enabled = false
    s.fire("PLAYER_ENTERING_WORLD")
    s.enabled, s.combat = true, true
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "1")
    assert(#s.hidden == 0 and s.events.PLAYER_REGEN_ENABLED, "CVar cleanup in combat must defer popup changes")
    s.combat = false
    s.fire("PLAYER_REGEN_ENABLED")
    assert(#s.hidden == 1 and s.visible == nil, "combat end must clear the outdated disabled warning")
end

do
    local s = newSession()
    s.enabled, s.moduleEnabled = false, false
    s.fire("PLAYER_ENTERING_WORLD")
    s.fire("CVAR_UPDATE", "cooldownViewerEnabled", "0")
    assert(#s.shown == 0, "disabled QUI CDM must not prompt")
end

print("OK: cdm_editmode_policy_lifecycle_test")
