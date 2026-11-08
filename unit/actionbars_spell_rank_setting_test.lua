local function noop() end
local function loadIn(path, env, ns)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk("QUI_ActionBars", ns)
end

local ns = {}
loadIn("core/defaults.lua", _G, ns)
assert(ns.defaults.profile.actionBars.global.autoUpgradeSpellRanks == true,
    "spell rank upgrades must be enabled by default")

for _, forever in ipairs({ false, true }) do
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local settings, rows, refreshes = {}, {}, 0
    local widget = { HookScript = noop }
    local gui = { Colors = {}, SetSearchContext = noop, AttachTooltip = noop }
    function gui:CreateFormToggle(_, _, key, db, callback, options)
        return { key = key, db = db, callback = callback, options = options }
    end
    gui.CreateButton, gui.CreateFormDropdown = function() return widget end, function() return widget end
    gui.CreateFormSlider, gui.CreateFormColorPicker = function() return widget end, function() return widget end
    env.QUI = { GUI = gui }
    env.QUI_RefreshActionBars = function() refreshes = refreshes + 1 end
    local options = {
        GetDB = function() return { actionBars = { global = settings } } end,
        BuildSettingRow = function(_, label, control)
            rows[label] = control
            return control
        end,
    }
    local uiNS = { Client = { isForever = forever }, Helpers = {}, QUI_Options = options,
        QUI_SettingsLayoutShared = { MakeLayout = function()
            return { headerAt = noop, sectionAt = function() return { frame = {}, AddRow = noop } end,
                closeSection = noop, getY = function() return 0 end }
        end } }
    dofile("tests/helpers/locale.lua")(uiNS)
    loadIn("QUI_ActionBars/actionbars/settings/action_bars_content.lua", env, uiNS)
    uiNS.QUI_ActionBarsOptions.BuildMasterSettingsTab({ SetHeight = noop })
    local toggle = rows["Auto-upgrade Spell Ranks"]
    if forever then
        assert(toggle, "Forever General settings must expose spell rank upgrades")
        assert(toggle.key == "autoUpgradeSpellRanks" and toggle.db == settings,
            "the toggle must edit actionBars.global")
        assert(type(toggle.callback) == "function", "changing the setting must refresh runtime state")
        toggle.callback()
        assert(refreshes == 1, "the setting must use the shared actionbar refresh")
    else
        assert(not toggle, "Retail must not expose the Forever setting")
    end
end

do
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local combat, rankRefreshes, nativeRefreshes, previewRefreshes = false, 0, 0, 0
    env.InCombatLockdown = function() return combat end
    env.ActionBarsOwned = { useNativeButtons = true, RefreshNativeBars = function()
        nativeRefreshes = nativeRefreshes + 1
    end }
    env.SetChunkEnv = function(level, target) setfenv(level + 1, target) end
    env.CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end
    env.C_Timer = { After = noop }
    local runtimeNS = { ActionBarsEnv = env,
        ActionBarsSpellRanks = { Refresh = function() rankRefreshes = rankRefreshes + 1 end },
        QUI_ActionBarsPreviewDriver = { Refresh = function() previewRefreshes = previewRefreshes + 1 end } }
    loadIn("QUI_ActionBars/actionbars/actionbars_public.lua", env, runtimeNS)
    combat = true
    env.QUI_RefreshActionBars()
    assert(rankRefreshes == 1, "disabling in combat must immediately cancel queued rank upgrades")
    assert(env.ActionBarsOwned.pendingRefresh and nativeRefreshes == 0 and previewRefreshes == 0,
        "combat must still defer normal actionbar refresh")
    combat = false
    env.QUI_RefreshActionBars()
    assert(rankRefreshes == 2 and nativeRefreshes == 1 and previewRefreshes == 1,
        "native actionbars must refresh spell ranks and keep existing refresh behavior")
    runtimeNS.ActionBarsSpellRanks = nil
    env.QUI_RefreshActionBars()
    assert(nativeRefreshes == 2 and previewRefreshes == 2,
        "normal refresh must work without the optional rank module")
end

print("actionbars_spell_rank_setting_test: OK")
