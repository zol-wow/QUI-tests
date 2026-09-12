local file = assert(io.open("QUI_CDM/cdm/settings/composer.lua", "r"))
local source = file:read("*a")
file:close()
assert(not source:find("nativeAuraEffects", 1, true),
    "native aura entries must not lose their effect and sound controls")
assert(not source:find("Aura alerts and animated glows are unavailable", 1, true))
for _, widget in ipairs({ "glow", "proc", "glowColor", "alertEvent", "alertEnabled", "alertMode", "alertPreview" }) do
    assert(source:find('GetOverrideWidget(GUI, "' .. widget .. '")', 1, true),
        "missing native aura configuration control: " .. widget)
end
local first = assert(source:find("local function RefreshCDM()", 1, true))
local last = assert(source:find("local function NotifyComposerEntriesChanged", first, true))
local refresh = assert(loadstring("local ns, activeContainer = ...\n"
    .. source:sub(first, last - 1) .. "\nreturn RefreshCDM"))
local calls = 0
local fn = refresh({ CDMAlerts = { RequestNativeSoundRefresh = function() calls = calls + 1 end } })
fn()
assert(calls == 1, "saving an alert must refresh native sound registrations")
print("OK: cdm_composer_native_aura_effects_test")
