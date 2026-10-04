local profile = {}
local elements = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        GetProfile = function() return profile end,
        GetModuleSettings = function(name, defaults)
            if not profile[name] then
                profile[name] = {}
                for key, value in pairs(defaults) do profile[name][key] = value end
            end
            return profile[name]
        end,
    },
    QUI_LayoutMode = {
        RegisterElement = function(_, def) elements[def.key] = def end,
        UnregisterElement = function(_, key) elements[key] = nil end,
    },
}

for _, path in ipairs({
    "core/settings/util.lua", "core/settings/registry.lua", "core/settings/schema.lua",
    "core/settings/nav.lua", "core/settings/render_adapters.lua", "core/settings/renderer.lua",
    "modules/trackers/aura_displays.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end

local AD = ns.QUI_AuraDisplays
local Registry = ns.Settings.Registry
local display = AD.NewDisplay("First")
local second = AD.NewDisplay("Second")
local group = AD.GetGroup("Group", true)
AD.RegisterLayoutElement(display)
AD.RegisterLayoutElement(second)
AD.RegisterGroupLayoutElement("Group", group)
local keys = {
    AD.ANCHOR_PREFIX .. display.id,
    AD.ANCHOR_PREFIX .. second.id,
    AD.GROUP_ANCHOR_PREFIX .. group.id,
}
local feature = assert(Registry:GetFeatureByLookupKey(keys[1]),
    "Aura Display movers must resolve a settings feature")
local calls = {}
ns.QUI_LayoutMode_Utils = {
    BuildPositionCollapsible = function(_, key, _, sections)
        calls.position = key
        sections[#sections + 1] = "position"
    end,
    BuildOpenFullSettingsLink = function(_, key, sections)
        calls.link = key
        sections[#sections + 1] = "settings"
    end,
    StandardRelayout = function(host, sections)
        assert(sections[1] == "position" and sections[2] == "settings")
        host.height = 144
    end,
}
local host = { GetHeight = function(self) return self.height end }
for _, key in ipairs(keys) do
    assert(elements[key], "settings lookup must belong to an existing mover")
    assert(Registry:GetFeatureByLookupKey(key) == feature)
    local height = ns.Settings.Renderer:RenderFeature(feature, host, {
        surface = "layout", providerKey = key,
    })
    assert(height == 144 and calls.position == key and calls.link == key,
        "each mover must render its own anchor controls and settings link")
    local route = ns.Settings.Nav:GetRouteByLookupKey(key)
    assert(route.tileId == "auras" and route.subPageIndex == 6,
        "settings links must open the Aura Displays page")
end
AD.RegisterLayoutElement(display)
assert(#feature.lookupKeys == 3, "repeat registration must not duplicate settings lookups")
AD.UnregisterLayoutElement(display.id, true)
AD.UnregisterGroupLayoutElement(group, true)
assert(not Registry:GetFeatureByLookupKey(keys[1]) and not elements[keys[1]])
assert(not Registry:GetFeatureByLookupKey(keys[3]) and not elements[keys[3]])
assert(Registry:GetFeatureByLookupKey(keys[2]) == feature and elements[keys[2]],
    "removing one mover must preserve sibling settings controls")
print("PASS: aura_displays_layout_settings_test")
