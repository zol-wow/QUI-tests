-- tests/unit/options_module_master_toggle_state_test.lua
-- Regression: a module's sidebar switch and its "Enable ..." switch elsewhere in
-- the options disagreed.
--
-- A module addon is ON only when BOTH hold:
--   1) its addon is enabled for this character (C_AddOns enable state), and
--   2) its profile flag (AddonManifest legacyFlag, e.g. profile.chat.enabled)
--      is not false.
-- The sidebar pill reads that combined state through the module entry. Every
-- other switch for the same module was an ordinary form toggle bound to the
-- profile flag alone. With the addon disabled for the character and the flag
-- still true (another profile, or another character sharing the profile, turned
-- the module off / on) the sidebar showed OFF and the other switch showed ON --
-- and its first click wrote OFF instead of turning the module on.
--
-- Rule under test: a pill toggle bound to a module addon's enable flag IS that
-- module's master switch, on every surface that builds one. It shows and sets
-- the shared module state (QUI_Modules), never the bare flag:
--   * settings pages            (page onChange also calls SetEnabled; idempotent)
--   * setup wizard              (plain toggle, no module code of its own)
--   * search results            (rebuilt from the cached descriptor; this
--                                surface adds the reload prompt)
--   * pinning                   (pins what the switch shows)
--
-- Uses the REAL framework, module registry and module-addon entries, loaded
-- headlessly via the search-cache generator's WoW-API stub preamble.
-- Run: lua tests/unit/options_module_master_toggle_state_test.lua

local GEN_PATH = "tools/generate_search_cache.lua"
local CUT_MARKER = 'local frame = create_stub_node("Frame", nil, false)'
local fh = assert(io.open(GEN_PATH, "rb"), "cannot open " .. GEN_PATH)
local src = fh:read("*a"); fh:close()
local cut = assert(src:find(CUT_MARKER, 1, true),
    "generator preamble cut marker not found -- update CUT_MARKER")
local ns = assert((loadstring or load)(src:sub(1, cut - 1) .. "\nreturn ns", "@gen-preamble"))()

local GUI = assert(_G.QUI and _G.QUI.GUI, "framework did not initialize QUI.GUI")
-- The generator preamble does not load the shared module-state registry.
if not ns.QUI_Modules then
    assert(loadfile("core/modules.lua"))("QUI", ns)
end
local Modules = assert(ns.QUI_Modules, "core/modules.lua must publish ns.QUI_Modules")
local Pins = assert(ns.Settings and ns.Settings.Pins, "pins must be loaded")
assert(type(Pins.GetEntry) == "function" and type(Pins.Pin) == "function", "pins API changed -- update this test")
local profile = assert(_G.QUI.db and _G.QUI.db.profile, "stub profile missing")

-- Real Set/GetScript so widgets' own OnClick handlers can be driven (the
-- generator maps SetScript to a shared noop).
local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(frameType, name, parent, ...)
    local node = realCreateFrame(frameType, name, parent, ...)
    local scripts = {}
    node.SetScript = function(_, event, handler) scripts[event] = handler end
    node.GetScript = function(_, event) return scripts[event] end
    return node
end

-- Per-character addon enable state, as C_AddOns reports it to the real
-- module-addon entries (core/settings/content/module_addons_content.lua).
local addonOn, loaderCalls = {}, 0
ns.AddonLoader.IsModuleAddonEnabled = function(folder) return addonOn[folder] ~= false end
ns.AddonLoader.SetModuleAddonEnabled = function(folder, on)
    loaderCalls = loaderCalls + 1
    addonOn[folder] = on and true or false
    return "reload"
end

local reloadPrompts = 0
GUI.ShowConfirmation = function(_, options)
    if type(options) == "table" and options.reload then reloadPrompts = reloadPrompts + 1 end
end

local MODULES = {
    { folder = "QUI_Chat",        flags = profile.chat,           dbPath = "profile.chat" },
    { folder = "QUI_GroupFrames", flags = profile.quiGroupFrames, dbPath = "profile.quiGroupFrames" },
    { folder = "QUI_Nameplates",  flags = profile.nameplates,     dbPath = "profile.nameplates" },
    { folder = "QUI_UnitFrames",  flags = profile.quiUnitFrames,  dbPath = "profile.quiUnitFrames" },
}

local parent = _G.CreateFrame("Frame")
local function click(widget)
    local button = assert(widget.track, "pill toggle must expose its button as .track")
    button:GetScript("OnClick")(button)
end

for _, module in ipairs(MODULES) do
    local featureId = "moduleAddon_" .. module.folder
    local flags = assert(module.flags, module.folder .. ": profile flag table missing from the stub profile")
    assert(Modules:GetEntry(featureId), module.folder .. ": real module entry must be registered")

    -- The flag binding identifies the module; nothing else does.
    assert(Modules:GetFeatureForFlag(flags, "enabled") == featureId,
        module.folder .. ": enable flag must resolve to its module")
    assert(Modules:GetFeatureForFlag(flags, "someOtherKey") == nil,
        module.folder .. ": other keys of the same table are not the master switch")
    assert(Modules:GetFeatureForFlag({}, "enabled") == nil, "an unrelated table is not a module flag")

    -- 1) Addon disabled for the character, profile flag still true: a plain
    --    toggle bound to the flag (the setup wizard builds exactly this) shows
    --    OFF, matching the sidebar, and building it writes nothing.
    addonOn[module.folder] = false
    flags.enabled = true
    local changes = {}
    local widget = GUI:CreateFormToggle(parent, "Enable", "enabled", flags, function(value)
        changes[#changes + 1] = value
    end, {})
    assert(widget._quiModuleFeatureId == featureId, module.folder .. ": toggle must know its module")
    assert(Modules:IsEnabled(featureId) == false, module.folder .. ": sidebar state is off")
    assert(flags.enabled == true, module.folder .. ": widget init must not write the profile flag")
    assert(widget.GetValue() == false,
        module.folder .. ": switch must read the module's combined state, not the raw profile flag")
    assert(widget.GetToggleProgress() == 0, module.folder .. ": switch must paint OFF")

    -- 2) Clicking the OFF switch turns the module ON through the shared state,
    --    with no module code in the surface's own onChange. (The old toggle
    --    read the raw flag as ON and wrote OFF.)
    loaderCalls = 0
    click(widget)
    assert(loaderCalls == 1 and addonOn[module.folder] == true and flags.enabled == true,
        module.folder .. ": click on an OFF switch must enable addon and flag")
    assert(#changes == 1 and changes[1] == true, module.folder .. ": onChange still fires with the new value")
    assert(widget.GetValue() == true and Modules:IsEnabled(featureId) == true,
        module.folder .. ": switch and sidebar agree after enabling")

    -- 3) A second switch on the same binding (page + search result open at
    --    once) follows changes made through the first one.
    local mirror = GUI:CreateFormToggle(parent, "Enable", "enabled", flags, nil, {})
    click(widget)
    assert(addonOn[module.folder] == false and flags.enabled == false,
        module.folder .. ": second click disables addon and flag")
    assert(widget.GetValue() == false and mirror.GetValue() == false and mirror.GetToggleProgress() == 0,
        module.folder .. ": mirrored switch repaints from the module state")

    -- 4) A change made elsewhere (sidebar pill) reaches the switch.
    Modules:SetEnabled(featureId, true, { suppressReloadPrompt = true })
    assert(widget.GetValue() == true and widget.GetToggleProgress() == 1,
        module.folder .. ": sidebar change repaints the switch")

    -- 5) A silent programmatic SetValue stays a plain value write.
    loaderCalls = 0
    widget:SetValue(false, true)
    assert(loaderCalls == 0 and flags.enabled == false,
        module.folder .. ": SetValue(value, skipCallback) must not drive the module state")

    -- 6) Search results rebuild the switch from its cached descriptor (shipped
    --    builds always take this path). It must show the combined state, route
    --    the click through the module state and offer the reload itself.
    addonOn[module.folder] = false
    flags.enabled = true
    local searchWidget = assert(GUI:CreateSearchWidgetFromDescriptor(parent, {
        label = "Enable " .. module.folder,
        widgetDescriptor = { kind = "checkbox", dbKey = "enabled", dbPath = module.dbPath },
    }), module.folder .. ": search descriptor must build a widget")
    assert(searchWidget.GetValue() == false,
        module.folder .. ": search result switch must show the combined state")
    loaderCalls, reloadPrompts = 0, 0
    click(searchWidget)
    assert(loaderCalls == 1 and addonOn[module.folder] == true and flags.enabled == true,
        module.folder .. ": search result click must enable addon and flag")
    assert(reloadPrompts == 1, module.folder .. ": search result must offer the reload exactly once")
    assert(widget.GetValue() == true, module.folder .. ": page switch follows the search result click")

    -- 7) Pinning captures what the switch shows. With the addon disabled and the
    --    flag true the switch shows OFF, so OFF is what gets pinned. (The pin
    --    store is observed at its Pin() seam: the generator's stub database
    --    auto-creates tables for unset keys, so reading entries back is not
    --    meaningful here.)
    addonOn[module.folder] = false
    flags.enabled = true
    widget.Refresh()
    assert(widget.GetValue() == false, module.folder .. ": precondition: switch shows OFF")
    local pinButton = assert(widget._quiPinButton, module.folder .. ": master switch must stay pinnable")
    local realGetEntry, realPin = Pins.GetEntry, Pins.Pin
    local pinnedPath, pinnedDescriptor
    Pins.GetEntry = function() return nil end
    Pins.Pin = function(_, path, descriptor)
        pinnedPath, pinnedDescriptor = path, descriptor
        return true
    end
    pinButton:GetScript("OnClick")(pinButton)
    Pins.GetEntry, Pins.Pin = realGetEntry, realPin
    assert(type(pinnedPath) == "string" and type(pinnedDescriptor) == "table",
        module.folder .. ": pin button must request a pin")
    assert(pinnedDescriptor.value == false,
        module.folder .. ": pin must capture the shown module state (OFF), not the raw flag (true)")
end

-- 8) Ordinary toggles are untouched: a non-flag key reads and writes its value
--    directly, on pages and in search results, with no reload prompt.
local plainStore = profile.chat
plainStore.quiTestPlainToggle = true
addonOn.QUI_Chat = false
local plain = GUI:CreateFormToggle(parent, "Plain", "quiTestPlainToggle", plainStore, nil, {})
assert(plain._quiModuleFeatureId == nil and plain.GetValue() == true, "ordinary toggle reads its bound value")
loaderCalls, reloadPrompts = 0, 0
click(plain)
assert(plainStore.quiTestPlainToggle == false and loaderCalls == 0, "ordinary toggle writes its bound value")
local plainSearch = assert(GUI:CreateSearchWidgetFromDescriptor(parent, {
    label = "Plain",
    widgetDescriptor = { kind = "checkbox", dbKey = "quiTestPlainToggle", dbPath = "profile.chat" },
}))
click(plainSearch)
assert(plainStore.quiTestPlainToggle == true and loaderCalls == 0 and reloadPrompts == 0,
    "ordinary search result toggle: plain write, no module call, no reload prompt")
plainStore.quiTestPlainToggle = nil

print("OK: options_module_master_toggle_state_test")
