-- tests/unit/options_module_master_toggle_state_test.lua
-- Regression: the sidebar pill for a module addon and the "Enable ..." master
-- switch on that module's settings page disagreed.
--
-- A module addon is ON only when BOTH hold:
--   1) its addon is enabled for this character (C_AddOns enable state), and
--   2) its profile flag (e.g. profile.chat.enabled) is not false.
-- The sidebar pill reads that combined state through the module entry's
-- isEnabled(). The page switch read only the profile flag, so with the addon
-- disabled for the character and the flag still true (another profile, or
-- another character sharing the profile, turned the module off / on) the
-- sidebar showed OFF while the page showed ON -- and the first click on the
-- page switch wrote OFF instead of turning the module on.
--
-- A page master switch now names its module (registryInfo.moduleFeatureId) and
-- the pill toggle reads the module entry's combined state.
--
-- Loads the REAL framework headlessly via the search-cache generator's WoW-API
-- stub preamble (same technique as tests/unit/test_form_toggle_inverted_init.lua).
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
local Registry = assert(ns.Settings and ns.Settings.Registry, "settings registry missing")
local Schema = assert(ns.Settings.Schema, "settings schema missing")

-- Real Set/GetScript so the widget's own OnClick can be driven (the generator
-- maps SetScript to a shared noop).
local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(frameType, name, parent, ...)
    local node = realCreateFrame(frameType, name, parent, ...)
    local scripts = {}
    node.SetScript = function(_, event, handler) scripts[event] = handler end
    node.GetScript = function(_, event) return scripts[event] end
    return node
end

-- A module addon modelled on module_addons_content.lua: per-character addon
-- state AND a profile flag.
local FEATURE = "moduleAddon_TestModule"
local addonOn = false
local profile = { enabled = true }
local setCalls = 0
Registry:RegisterFeature(Schema.Feature({
    id = FEATURE,
    category = "global",
    moduleEntry = {
        isEnabled = function() return addonOn and profile.enabled ~= false end,
        setEnabled = function(val)
            setCalls = setCalls + 1
            profile.enabled = val and true or false
            addonOn = val and true or false
        end,
    },
}))
assert(Modules:GetEntry(FEATURE), "test module entry must resolve through QUI_Modules")

local function findToggle(widget)
    return assert(widget.track, "pill toggle must expose its button as .track")
end

local parent = _G.CreateFrame("Frame")
local function onChange(enabled)
    Modules:SetEnabled(FEATURE, enabled, { suppressReloadPrompt = true })
end

-- 1) Addon disabled for the character, profile flag still true: the page
--    switch must show OFF, matching the sidebar pill.
local widget = GUI:CreateFormCheckbox(parent, "Enable Test Module", "enabled", profile, onChange,
    { moduleFeatureId = FEATURE })
assert(Modules:IsEnabled(FEATURE) == false, "sidebar state: module is off")
assert(profile.enabled == true, "widget init must not write the profile flag")
assert(widget.GetValue() == false,
    "page master switch must read the module's combined state, not the raw profile flag")
assert(widget.GetToggleProgress() == 0, "page master switch must paint OFF")

-- 2) Clicking the OFF switch turns the module ON (the old code read the raw
--    flag as ON and wrote OFF).
findToggle(widget):GetScript("OnClick")(findToggle(widget))
assert(setCalls == 1, "click must route through the shared module state once")
assert(profile.enabled == true and addonOn == true, "click on an OFF switch must enable the module")
assert(widget.GetValue() == true, "page master switch reads ON after enabling")

-- 3) Clicking again turns it OFF in both layers.
findToggle(widget):GetScript("OnClick")(findToggle(widget))
assert(setCalls == 2 and profile.enabled == false and addonOn == false, "second click disables the module")
assert(widget.GetValue() == false, "page master switch reads OFF after disabling")

-- 4) A change made elsewhere (sidebar pill) reaches the page switch on Refresh.
addonOn, profile.enabled = true, true
widget.Refresh()
assert(widget.GetValue() == true and widget.GetToggleProgress() == 1,
    "Refresh must repaint from the module's combined state")

-- 5) Without moduleFeatureId, or with an unknown module, the toggle keeps
--    reading its bound value.
addonOn = false
local plain = GUI:CreateFormCheckbox(parent, "Plain", "enabled", profile, nil, {})
assert(plain.GetValue() == true, "ordinary toggles are unaffected")
local unknown = GUI:CreateFormCheckbox(parent, "Unknown", "enabled", profile, nil,
    { moduleFeatureId = "moduleAddon_DoesNotExist" })
assert(unknown.GetValue() == true, "an unregistered module falls back to the bound value")

-- 6) Every settings page that mirrors a module ADDON master switch names its
--    module, so the page and the sidebar cannot drift apart again.
local function readAll(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end
local mirrored = {
    ["QUI_Chat/chat/settings/chat_frame1_provider.lua"] = "moduleAddon_QUI_Chat",
    ["QUI_GroupFrames/groupframes/settings/group_frames_schema.lua"] = "moduleAddon_QUI_GroupFrames",
    ["QUI_Nameplates/nameplates/settings/nameplates_schema.lua"] = "moduleAddon_QUI_Nameplates",
    ["QUI_UnitFrames/unitframes/settings/unit_frames_schema.lua"] = "moduleAddon_QUI_UnitFrames",
}
for path, featureId in pairs(mirrored) do
    assert(readAll(path):find('moduleFeatureId = "' .. featureId .. '"', 1, true),
        path .. " master switch must declare moduleFeatureId = " .. featureId)
end

print("OK: options_module_master_toggle_state_test")
