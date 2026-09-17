local function noop() end
local function fail() error("fallback must not mutate native controls or enter secure execution") end

for _, case in ipairs({
    { "1.60.1", "69893", true },
    { "1.60.1", 69893, true },
    { "1.60.1", "69894", false },
    { "12.1.5", "69893", false },
}) do
    local ns = {}
    local scope = setmetatable({ GetBuildInfo = function() return case[1], case[2], "", 16001 end }, { __index = _G })
    local chunk = assert(loadfile("core/client.lua"))
    setfenv(chunk, scope)
    chunk("QUI", ns)
    assert(ns.Client.restrictedExecutionUnavailable == case[3], "workaround must match only verified affected client/build")
end

local timers, created, hooks, elements = {}, {}, 0, {}
local world = setmetatable({}, { __index = _G })
world._G = world
world.setfenv = setfenv
world.UIParent = {}
world.WOW_PROJECT_ID, world.WOW_PROJECT_MAINLINE = 1, 1
world.InCombatLockdown = function() return false end
world.GetBuildInfo = function() return "1.60.1", "69893", "", 16001 end
world.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
world.BeginActionBarTransition = noop
world.hooksecurefunc = function() hooks = hooks + 1 end
world.CreateFrame = function(_, name, _, template)
    assert(not template or not template:find("SecureHandler"), "must not create a restricted-script handler")
    local frame = { scripts = {}, attributes = {} }
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    frame.Hide, frame.RegisterEvent = noop, noop
    if name then created[name] = frame end
    return frame
end
local native = setmetatable({}, { __index = function() return fail end })
for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "PetActionBar", "StanceBar", "PossessActionBar", "OverrideActionBar" }) do
    world[name] = native
end
local ns = {
    Helpers = { GetCore = noop, CreateStateTable = function() return {}, noop end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    QUI_LayoutMode = { RegisterElement = function(_, element) elements[#elements + 1] = element end },
}
local function load(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, world)
    chunk("QUI_ActionBars", ns)
end
load("core/client.lua")
for _, file in ipairs({ "actionbars_env.lua", "actionbars.lua", "actionbars_builder.lua", "actionbars_flyout.lua", "actionbars_public.lua" }) do
    load("QUI_ActionBars/actionbars/" .. file)
end
world.GSEOptions = { Multiclick = true }
world.GSE = { ReloadSequences = fail }
load("QUI_ActionBars/actionbars/gse_compat.lua")
assert(world.GSEOptions.Multiclick == true, "native fallback must preserve GSE options")
local env = ns.ActionBarsEnv
local owned = ns.ActionBarsOwned
local nativeBuilds, nativeRefreshes, nativeInitializations = 0, 0, 0
env.BuildNativeBar = function() nativeBuilds = nativeBuilds + 1 end
owned.InitializeNativeBars = function(self) nativeInitializations = nativeInitializations + 1; self.initialized = true end
owned.RefreshNativeBars = function() nativeRefreshes = nativeRefreshes + 1 end
env.GetDB = function() return { bars = { bar1 = { hidePageArrow = true } } } end
env.PatchLibKeyBoundForOwnedButtons = fail
env.ownedEventFrame = setmetatable({}, { __index = function() return fail end })
env.RefreshNativeKeybinds = noop
env.GetBarFrame = function(key)
    assert(key == "microbar" or key == "bags", "standard bars must use native presentation")
    return nil
end
owned:Initialize()
owned:Refresh()
for _, addon in ipairs({ "QUI_ActionBars", "Blizzard_ActionBar", "Blizzard_PlayerSpells" }) do
    env.initFrame.scripts.OnEvent(env.initFrame, "ADDON_LOADED", addon)
end
for _, callback in ipairs(timers) do callback() end
for _, bar in ipairs(env.ALL_MANAGED_BAR_KEYS) do env.BuildBar(bar) end
world.QUI_RefreshActionBars()
world.QUI_ApplyUseOnKeyDown()
world.QUI_ApplyPageArrowVisibility(true)
assert(env.EnsureOwnedFlyoutFrame() == nil, "fallback must retain native flyout")
assert(owned.initialized and owned.useNativeButtons, "Forever must initialize the native-button presentation path")
assert(nativeInitializations > 0 and nativeRefreshes > 0 and nativeBuilds == #env.LINKED_OWNED_BAR_KEYS)
assert(#elements > 0, "QUI layout controls must be restored")
assert(not owned.useOwnedFlyout and hooks == 0, "fallback must not hook native bar transitions")
assert(created.QUI_ActionBarLayoutHandler == nil)
assert(world.loadstring_untainted == nil, "must not fabricate Blizzard's private compiler")

owned.restrictedExecutionUnavailable = false
owned.useNativeButtons = false
owned.initialized = false
local entered = false
env.PatchLibKeyBoundForOwnedButtons = function() entered = true; error("supported initialization reached") end
local ok, err = pcall(owned.Initialize, owned)
assert(not ok and tostring(err):find("supported initialization reached", 1, true), tostring(err))
assert(entered, "supported clients must still enter owned action-bar initialization")
print("OK: Forever routes action bars to QUI native-button presentation without secure snippets")
