local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(source:sub(1, cut - 1) .. "\nreturn ns"))()
assert(loadfile("QUI_CDM/cdm/cdm_shared.lua"))("QUI", ns)
ns._CDMContainersPageModelLoaded = nil
assert(loadfile(os.getenv("QUI_CDM_SETTINGS_SOURCE") or "QUI_CDM/cdm/settings/containers_page.lua"))("QUI", ns)
local model = ns.QUI_CooldownManagerSettingsModel
local surface = ns.QUI_CooldownManagerSettingsSurface
local profile = QUI.QUICore.db.profile
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
for key, value in pairs(ns.defaults.profile) do profile[key] = Copy(value) end
profile.ncdm.containers = {}
local GUI = QUI.GUI
local feature = ns.Settings.Registry:GetFeature("cooldownManagerContainersPage")
local originalCatalog = ns.QUI_OptionsNavigationCatalog
ns.QUI_OptionsNavigationCatalog = {
    cooldownManagerContainersPage = { tabs = {
        { key = "layout", label = "Appearance", sections = {
            { id = "Layout", label = "Layout", contexts = {
                { providerKey = "custom:cooldown:icon" },
            } },
            { id = "Font", label = "Font", contexts = { { providerKey = "custom:cooldown:icon" } } },
            { id = "Border", label = "Border", contexts = { { providerKey = "custom:cooldown:icon" } } },
        } },
    } },
}
local tile = { config = { featureId = "cooldownManagerContainersPage" } }
for _, key in ipairs({ "user-created-123", "imported-container-987" }) do
    profile.ncdm.containers[key] = { containerType = "cooldown", shape = "icon" }
    surface.SetActiveContainer(key)
    local pages = GUI:GetTileNavigationPages(tile)
    assert(#pages == 3 and pages[1].sectionId == "Layout",
        "unopened CDM shortcuts must match schema shape rather than a generated sample container ID")
    assert(not tile._subPageBodies, "reading a custom container menu must not construct its settings")
    assert(feature.getNavigationContext().providerKey == "custom:cooldown:icon")
end
for _, key in ipairs({ "essential", "utility", "buff", "trackedBar" }) do
    assert(model.GetNavigationContext(key).providerKey == key,
        "built-in-specific section contexts must keep their exact identities")
end
for _, kind in ipairs({ "cooldown", "customBar", "aura", "auraBar" }) do
    for _, shape in ipairs({ "icon", "bar" }) do
        profile.ncdm.containers.arbitrary = { containerType = kind, shape = shape }
        assert(model.GetNavigationContext("arbitrary").providerKey == "custom:" .. kind .. ":" .. shape,
            "custom navigation must distinguish schema type and shape")
    end
end
assert(model.GetNavigationContext("deleted-container").providerKey == "essential",
    "deleted selections must use the same fallback as the settings editor")
ns.QUI_OptionsNavigationCatalog = originalCatalog
assert(loadfile(os.getenv("QUI_CDM_NAVIGATION_CACHE") or "QUI_Options/search_cache.lua"))("QUI", ns)
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
local renderedSections, renderedOrder
local accentLabel = ns.QUI_Options.CreateAccentDotLabel
ns.QUI_Options.CreateAccentDotLabel = function(parent, label, offset, skip)
    if not skip and not renderedSections[label] then
        renderedSections[label] = true
        renderedOrder[#renderedOrder + 1] = label
    end
    return accentLabel(parent, label, offset, skip)
end
local tabs = {
    { key = "layout", method = "RenderLayoutTab" },
    { key = "filters", method = "RenderFiltersTab" },
    { key = "perspec", method = "RenderPerSpecTab" },
    { key = "effects", method = "RenderEffectsTab" },
    { key = "keybinds", method = "RenderKeybindsTab" },
}
local function VerifyContainer(key)
    surface.SetActiveContainer(key)
    local coldTile = { config = { featureId = "cooldownManagerContainersPage" } }
    local cold = GUI:GetTileNavigationPages(coldTile)
    for _, tab in ipairs(tabs) do
        renderedSections, renderedOrder = {}, {}
        local host = CreateFrame("Frame")
        host:SetSize(760, 1)
        ns.QUI_CooldownManagerSettingsSchema[tab.method](host, key)
        local links = {}
        for _, page in ipairs(cold) do
            if page.key == tab.key and page.sectionId then links[#links + 1] = page.sectionId end
        end
        local expected = #renderedOrder >= 3 and renderedOrder or {}
        assert(table.concat(links, "|") == table.concat(expected, "|"),
            key .. "/" .. tab.key .. " cold headings must match rendered order: "
                .. table.concat(links, "|") .. " ~= " .. table.concat(expected, "|"))
    end
    assert(not coldTile._subPageBodies, "cold section discovery must not construct editor bodies")
end
for _, key in ipairs({ "essential", "utility", "buff", "trackedBar" }) do VerifyContainer(key) end
for _, kind in ipairs({ "cooldown", "customBar", "aura", "auraBar" }) do
    for _, shape in ipairs({ "icon", "bar" }) do
        local key = "user-import-" .. kind .. "-" .. shape
        local base = kind == "aura" and "buff" or (kind == "auraBar" and "trackedBar" or "essential")
        local db = Copy(ns.defaults.profile.ncdm[base])
        db.containerType, db.shape, db.builtIn = kind, shape, false
        profile.ncdm.containers[key] = db
        VerifyContainer(key)
    end
end
print("OK: CDM cold navigation matches rendered schema sections and order")
