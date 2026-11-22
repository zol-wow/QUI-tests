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
--   * settings pages            (the page handler only refreshes and offers
--                                the reload; it must not call SetEnabled again)
--   * setup wizard              (plain toggle, no module code of its own)
--   * search results            (rebuilt from the cached descriptor; the
--                                module entry offers the reload by its rules)
-- Pins are deliberately NOT part of that: a pin is account-wide profile data,
-- so it keeps carrying the bare flag (see step 7).
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
local addonOn, loaderCalls, loaderResult = {}, 0, "reload"
ns.AddonLoader.IsModuleAddonEnabled = function(folder) return addonOn[folder] ~= false end
ns.AddonLoader.SetModuleAddonEnabled = function(folder, on)
    loaderCalls = loaderCalls + 1
    addonOn[folder] = on and true or false
    return loaderResult
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
    loaderCalls, reloadPrompts = 0, 0
    click(widget)
    assert(loaderCalls == 1 and addonOn[module.folder] == true and flags.enabled == true,
        module.folder .. ": click on an OFF switch must enable addon and flag")
    assert(#changes == 1 and changes[1] == true, module.folder .. ": onChange still fires with the new value")
    assert(reloadPrompts == 0,
        module.folder .. ": the toggle leaves the reload prompt to its surface unless told otherwise")
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

    -- 5) A silent programmatic SetValue stays a plain flag write (it is a value
    --    sync, not a user decision about the addon), but it does move the flag
    --    half of the module state: subscribers are told and every view,
    --    including this widget, keeps showing the module state.
    local notified = 0
    local token = Modules:Subscribe(featureId, function() notified = notified + 1 end)
    loaderCalls = 0
    widget:SetValue(false, true)
    assert(loaderCalls == 0 and flags.enabled == false,
        module.folder .. ": SetValue(value, skipCallback) must not drive the addon state")
    assert(notified == 1, module.folder .. ": a silent flag write must notify module subscribers")
    assert(Modules:IsEnabled(featureId) == false and widget.GetValue() == false
        and mirror.GetValue() == false and mirror.GetToggleProgress() == 0,
        module.folder .. ": views follow a silent flag write")
    --    Addon disabled, flag false: silently writing the flag to true must not
    --    make the switch claim the module is on.
    addonOn[module.folder] = false
    widget:SetValue(true, true)
    assert(flags.enabled == true and loaderCalls == 0,
        module.folder .. ": silent write still only writes the flag")
    assert(widget.GetValue() == false and widget.GetToggleProgress() == 0 and widget.checked == false
        and mirror.GetToggleProgress() == 0,
        module.folder .. ": a silent write must not paint the switch ON while the addon is disabled")
    Modules:Unsubscribe(token)

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
    --    The prompt is the module entry's own decision, not a blanket one: when
    --    the addon is already loaded and its flag was not flipped, no reload is
    --    needed and none is offered.
    addonOn[module.folder] = false
    flags.enabled = true
    searchWidget.Refresh()
    loaderCalls, reloadPrompts, loaderResult = 0, 0, "loaded"
    click(searchWidget)
    loaderResult = "reload"
    assert(loaderCalls == 1 and addonOn[module.folder] == true,
        module.folder .. ": search result click enables the already-loaded addon")
    assert(reloadPrompts == 0, module.folder .. ": no reload offered when the module entry needs none")

    -- 7) Pinning keeps carrying the bare profile flag. Pins are account-wide and
    --    are written into the active profile on every login, while "addon
    --    enabled" is per character and cannot be carried by a pin. Pinning the
    --    shown state would let one character's disabled addon write
    --    enabled = false into every other character's profile. (The pin store is
    --    observed at its Pin() seam: the generator's stub database auto-creates
    --    tables for unset keys, so reading entries back is not meaningful here.)
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
    assert(pinnedDescriptor.value == true,
        module.folder .. ": pin must capture the profile flag (true), not this character's addon state")
end

-- 8) A real settings page: the Chat page's "Enable Chat Module" switch. One
--    click is exactly one module write (the page handler must not repeat it)
--    and exactly one reload offer (the page's own).
do
    local created = {}
    local origCheckbox = GUI.CreateFormCheckbox
    function GUI:CreateFormCheckbox(parentFrame, label, dbKey, dbTable, onChange, info)
        local built = origCheckbox(self, parentFrame, label, dbKey, dbTable, onChange, info)
        created[#created + 1] = { key = dbKey, tbl = dbTable, widget = built }
        return built
    end
    local provider = assert(ns.Settings.Providers:Get("chatFrame1"), "chatFrame1 provider must be registered")
    local content = _G.CreateFrame("Frame")
    content:SetSize(800, 600)
    addonOn.QUI_Chat = false
    profile.chat.enabled = true
    provider.build(content, "chatFrame1", 800, { chatSections = { "chatModule" } })
    GUI.CreateFormCheckbox = origCheckbox
    local pageSwitch
    for _, entry in ipairs(created) do
        if entry.key == "enabled" and entry.tbl == profile.chat then pageSwitch = entry.widget end
    end
    assert(pageSwitch, "Chat page must bind its master switch to profile.chat.enabled")
    assert(pageSwitch._quiModuleFeatureId == "moduleAddon_QUI_Chat" and pageSwitch.GetValue() == false,
        "Chat page switch shows the combined module state")
    loaderCalls, reloadPrompts = 0, 0
    click(pageSwitch)
    assert(loaderCalls == 1, "Chat page click must write the module state exactly once, got " .. loaderCalls)
    assert(reloadPrompts == 1, "Chat page click must offer the reload exactly once, got " .. reloadPrompts)
    assert(addonOn.QUI_Chat == true and profile.chat.enabled == true and pageSwitch.GetValue() == true,
        "Chat page click enables the module")
end

-- 9) The other pages bind the same way. The reviewed settings inventory records
--    each page's master switch against its profile flag path; if a page stops
--    binding the live flag table its switch would silently lose the module
--    behaviour, so tie the two together here.
do
    local inventory = assert(io.open("tests/fixtures/settings_controls_inventory.lua", "r"))
    local text = inventory:read("*a")
    inventory:close()
    for _, module in ipairs(MODULES) do
        assert(text:find("|" .. module.dbPath .. "|enabled|", 1, true),
            module.folder .. ": settings inventory must list a control bound to " .. module.dbPath .. ".enabled")
    end
end

-- 10) Ordinary toggles are untouched: a non-flag key reads and writes its value
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
