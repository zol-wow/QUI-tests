-- Independent route contract: actual surface models and mounted hub constructors
-- are the oracle; neither generator capture tables nor generated catalog define it.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1), "@settings-route-runtime"))()
local GUI, ns = QUI.GUI
for i = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, i)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local shownFrames = {}
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    local hook = frame.HookScript
    frame.HookScript = function(self, event, callback)
        if event == "OnShow" then
            shownFrames[self] = true
            local previous = rawget(self, "_testOnShow")
            self._testOnShow = function(owner)
                if previous then previous(owner) end
                callback(owner)
            end
        end
        return hook(self, event, callback)
    end
    return frame
end
_G.geterrorhandler = function() return function(err) error(err, 0) end end
local cachePath = os.getenv("QUI_SETTINGS_CACHE") or "QUI_Options/search_cache.lua"
local cache = dofile("tests/helpers/search_cache.lua")(cachePath)
local generated = {}
assert(loadfile(cachePath))("QUI", generated)
local catalog = generated.QUI_OptionsNavigationCatalog
assert(type(catalog) == "table")
local supported, required = {}, {}
local modelFeatures = 0
for id, feature in ns.Settings.Registry:IterateFeatures() do
    if type(feature.model) == "function" then
        local model = feature.model()
        supported[id], required[id] = {}, {}
        for _, tab in ipairs(model.GetTabDefinitions()) do
            assert(type(tab.render) == "function", "declared surface tabs must render: " .. id .. "/" .. tab.key)
            supported[id][tab.key] = true
        end
        for _, row in ipairs(ns.Settings.ModelKit.EnumerateSearchTabs(model)) do
            required[id][row.tab.key] = true
        end
        modelFeatures = modelFeatures + 1
    end
end
assert(modelFeatures > 0, "registered model-backed surfaces must participate")
-- Reminder tabs are conditional on the actual reminder, and have no static
-- TAB_DEFINITIONS table. Use its real selector with the supported PI variant.
local reminders = assert(ns.SpellReminderOptions)
supported.spellRemindersPage, required.spellRemindersPage = {}, {}
for _, tab in ipairs(reminders.GetTabs({ pi = true })) do
    assert(type(reminders.builders[tab.key]) == "function", "reminder tab has a real builder: " .. tab.key)
    supported.spellRemindersPage[tab.key], required.spellRemindersPage[tab.key] = true, true
end
-- Hub routes inherit schema surface keys, but are not a union of all owning
-- module tabs. Observe only the keys emitted by actual mounted hub providers.
local frame = { _tiles = {} }
GUI.AddFeatureTile = function(_, owner, config)
    owner._tiles[#owner._tiles + 1] = { id = config.id, config = config }
end
ns.QUI_Options.RegisterAllFeatureTiles(frame)
local mountedProviders = {}
for _, tile in ipairs(frame._tiles) do
    for _, page in ipairs(tile.config.subPages or {}) do
        if page.featureId then mountedProviders[page.featureId] = page.buildFunc end
    end
end
-- Root navigation is a separate descriptor contract, not a child tab.
local registerSurface = GUI.RegisterTileSurfacePages
local reminderDescriptor
GUI.RegisterTileSurfacePages = function(_, _, descriptor)
    reminderDescriptor = descriptor
    return true
end
local reminderHost = CreateFrame("Frame"); reminderHost:SetSize(760, 720)
assert(mountedProviders.spellRemindersPage)(reminderHost)
GUI.RegisterTileSurfacePages = registerSurface
assert(reminderDescriptor and reminderDescriptor.selectRoot and reminderDescriptor.rootKey,
    "actual Reminder editor declares root navigation")
local _, rootAccepted = reminderDescriptor.selectRoot()
assert(rootAccepted and reminderDescriptor.getActiveTab() == reminderDescriptor.rootKey,
    "declared Reminder root is reachable through its actual selection callback")
supported.spellRemindersPage[reminderDescriptor.rootKey] = true
required.spellRemindersPage[reminderDescriptor.rootKey] = true
local originalContext = GUI.SetSearchContext
local observing
GUI.SetSearchContext = function(self, context)
    local result = originalContext(self, context)
    local current = self._searchContext
    if observing and current and current.featureId == observing and current.surfaceTabKey then
        supported[observing][current.surfaceTabKey] = true
        required[observing][current.surfaceTabKey] = true
    end
    return result
end
local editor = ns.QUI_AuraElementsEditor
local renderAuras = editor.RenderAuras
local editorDB, editorContext, editorCalls
editor.RenderAuras = function(host, db, ...)
    editorDB, editorContext = db, {}
    for key, value in pairs(GUI._searchContext or {}) do editorContext[key] = value end
    editorCalls = (editorCalls or 0) + 1
    return renderAuras(host, db, ...)
end
local profile = ns.Helpers.GetProfile()
local requiredContexts = {}
local function ExpectedAuraDB(id, state)
    if id == "aurasGroupPage" then return profile.quiGroupFrames[state.contextMode].auras end
    if id == "aurasUnitPage" then return profile.quiUnitFrames[state.selectedUnit].auras end
    return profile.nameplates.types[state.selectedType].auras
end
for _, id in ipairs({ "aurasGroupPage", "aurasUnitPage", "aurasNameplatePage" }) do
    supported[id], required[id] = {}, {}
    observing = id
    local host = CreateFrame("Frame"); host:SetSize(760, 1)
    assert(mountedProviders[id], "hub feature has a real registered host: " .. id)(host)
    assert(next(supported[id]), "real hub provider must expose its editor routes: " .. id)
    local feature = ns.Settings.Registry:GetFeature(id)
    local previous, initialDB = feature.getNavigationContext(), editorDB
    local contexts = feature.getSearchContexts()
    assert(#contexts > 1, "hub selectors must expose all real model variants: " .. id)
    requiredContexts[id] = {}
    for _, variant in ipairs(contexts) do
        assert(feature.searchNavigate(variant.searchContext, { opts = {} }), "hub accepts its supported context")
        assert(editorDB == ExpectedAuraDB(id, variant.state), "mounted hub editor must bind selected variant: " .. id)
        assert(editorContext.featureId == id and editorContext.tileId == "auras",
            "mounted hub rerender must preserve actual host route: " .. id)
        for key, value in pairs(variant.searchContext) do
            assert(editorContext[key] == value, "hub rerender preserves variant identity: " .. id .. "/" .. key)
            requiredContexts[id][key .. ":" .. value] = true
        end
        local count = editorCalls
        assert(feature.searchNavigate(variant.searchContext, { opts = {} }))
        assert(editorCalls == count, "same-value hub navigation must preserve mounted editor")
        assert(ns.Settings.SearchRoute.Depth() == 0, "hub navigation must restore route scope")
    end
    assert(feature.searchNavigate(previous, { opts = {} }))
    assert(editorDB == initialDB, "restoring selector must restore the original editor binding")
    -- A cached hub can lag behind a selector changed on its owning module.
    -- Go must compare the mounted binding, not just the shared selected value.
    local external = contexts[2]
    if id == "aurasGroupPage" then ns.QUI_GroupFramesSettingsSurface.SetContextMode(external.state.contextMode)
    elseif id == "aurasUnitPage" then ns.QUI_UnitFramesSettingsSurface.SetSelectedUnit(external.state.selectedUnit)
    else ns.QUI_NameplatesSettingsSurface.SetSelectedType(external.state.selectedType) end
    local beforeExternalGo = editorCalls
    assert(feature.searchNavigate(external.searchContext, { opts = {} }))
    assert(editorCalls > beforeExternalGo and editorDB == ExpectedAuraDB(id, external.state),
        "cached hub must rebind after owning-module selector changes: " .. id)
    assert(feature.searchNavigate(previous, { opts = {} }))
    assert(editorDB == initialDB)
    -- A normal sidebar return must also rebind a cached editor, without Go.
    if id == "aurasGroupPage" then ns.QUI_GroupFramesSettingsSurface.SetContextMode(external.state.contextMode)
    elseif id == "aurasUnitPage" then ns.QUI_UnitFramesSettingsSurface.SetSelectedUnit(external.state.selectedUnit)
    else ns.QUI_NameplatesSettingsSurface.SetSelectedType(external.state.selectedType) end
    local sectionHost
    for candidate in pairs(shownFrames) do
        local owner = candidate:GetParent()
        local runtime = owner and rawget(owner, "_quiSettingsRuntime")
        if runtime and runtime.feature.id == id and runtime.sectionHosts.settings == candidate then
            sectionHost = candidate
            break
        end
    end
    local beforeShow = editorCalls
    local onShow = sectionHost and rawget(sectionHost, "_testOnShow")
    if onShow then onShow(sectionHost) end
    assert(editorCalls == beforeShow + 1 and editorDB == ExpectedAuraDB(id, external.state),
        "sidebar return must rebind a cached hub after its owner changes context: " .. id)
    onShow(sectionHost)
    assert(editorCalls == beforeShow + 1, "unchanged hub return preserves its mounted editor: " .. id)
    assert(editorContext.featureId == id and editorContext.tileId == "auras",
        "sidebar context refresh preserves the real host route: " .. id)
    assert(feature.searchNavigate(previous, { opts = {} }))
    assert(editorDB == initialDB)
    assert(ns.Settings.SearchRoute.Depth() == 0)
end
observing, GUI.SetSearchContext = nil, originalContext
editor.RenderAuras = renderAuras
local function Validate(cache, catalog)
local seen, seenContexts, checked = {}, {}, 0
for _, group in ipairs({ cache.settings, cache.navigation }) do
    for _, entry in ipairs(group) do
        local id, key = entry.featureId, entry.surfaceTabKey
        if type(key) == "string" and key ~= "" then
            assert(supported[id], "surface route has no independent runtime coverage: " .. tostring(id))
            assert(supported[id][key], "cache route is not supported by the real provider: " .. id .. "/" .. key)
            seen[id] = seen[id] or {}; seen[id][key] = true
            if requiredContexts[id] then
                seenContexts[id] = seenContexts[id] or {}
                for _, field in ipairs({ "providerKey", "surfaceUnitKey", "surfaceTypeKey" }) do
                    if entry[field] then seenContexts[id][field .. ":" .. entry[field]] = true end
                end
            end
            checked = checked + 1
        end
    end
end
-- The generated navigation catalog must also contain each currently visible
-- model tab, including tabs without persistent setting controls (CDM Entries).
for id, record in pairs(catalog) do
    if supported[id] then
        for _, tab in ipairs(record.tabs or {}) do
            assert(supported[id][tab.key], "catalog route is not supported by the real provider: " .. id .. "/" .. tab.key)
            seen[id] = seen[id] or {}; seen[id][tab.key] = true
        end
    end
end
for id, keys in pairs(required) do
    for key in pairs(keys) do
        assert(seen[id] and seen[id][key], "actual provider route is absent from search: " .. id .. "/" .. key)
    end
end
for id, contexts in pairs(requiredContexts) do
    for key in pairs(contexts) do
        assert(seenContexts[id] and seenContexts[id][key], "mounted hub selector context absent from search: " .. id .. "/" .. key)
    end
end
assert(checked > 0)
return checked
end
local checked = Validate(cache, catalog)
local function RejectRoute(featureId, key)
    cache.navigation[#cache.navigation + 1] = { featureId = featureId, surfaceTabKey = key }
    local ok = pcall(Validate, cache, catalog)
    table.remove(cache.navigation)
    assert(not ok, "independent audit must reject injected unsupported route: " .. featureId .. "/" .. key)
end
RejectRoute("spellRemindersPage", "deleted_tab")
RejectRoute("aurasUnitPage", "frame")
local missing = { settings = {}, navigation = {} }
for _, name in ipairs({ "settings", "navigation" }) do
    for _, entry in ipairs(cache[name]) do
        if entry.featureId ~= "spellRemindersPage" or entry.surfaceTabKey ~= "timing" then
            missing[name][#missing[name] + 1] = entry
        end
    end
end
local missingCatalog = {}
for id, record in pairs(catalog) do
    if id ~= "spellRemindersPage" then missingCatalog[id] = record end
end
assert(not pcall(Validate, missing, missingCatalog), "independent audit must detect an omitted live Reminder tab")
-- These negative cases distinguish exact hub/provider coverage from a broad
-- union-of-model-tabs allowlist and from trusting the generated catalog.
assert(not supported.aurasUnitPage.frame and not supported.aurasGroupPage.health)
assert(not supported.spellRemindersPage.deleted_tab)
-- The default selector context must be just as searchable and identifiable as
-- later contexts. Capturing the unlabeled default page first used to win dedupe.
assert(loadfile("core/pack.lua"))("QUI", ns)
assert(loadfile(cachePath))("QUI", ns)
GUI:EnsureSearchCacheLoaded()
GUI.MainFrame = frame
for id, feature in ns.Settings.Registry:IterateFeatures() do
    if type(feature.model) == "function" then
        local variants = {}
        for _, variant in ipairs(ns.Settings.ModelKit.EnumerateSearchTabs(feature.model())) do
            if variant.label then
                local keyParts = {}
                for _, key in ipairs({ "providerKey", "surfaceUnitKey", "surfaceTypeKey" }) do
                    if variant.searchContext[key] then keyParts[#keyParts + 1] = key .. ":" .. variant.searchContext[key] end
                end
                variants[table.concat(keyParts, "|")] = variant
            end
        end
        for key, variant in pairs(variants) do
            local sample
            for _, entry in ipairs(cache.settings) do
                local matches = entry.featureId == id and entry.widgetDescriptor and entry.widgetDescriptor.dbPath
                for _, field in ipairs({ "providerKey", "surfaceUnitKey", "surfaceTypeKey" }) do
                    if variant.searchContext[field] and entry[field] ~= variant.searchContext[field] then matches = false end
                end
                if matches then
                    local tab = assert(ns.Settings.ModelKit.GetTabDefinition(feature.model(), entry.surfaceTabKey))
                    assert(entry.subTabName == tab.label,
                        "model control identifies its actual tab: " .. id .. "/" .. entry.label .. "/" .. tostring(entry.subTabName))
                    assert(entry.contextLabel == variant.label,
                        "all model bindings retain selector label, including default: " .. id .. "/" .. key .. "/" .. entry.label)
                    sample = sample or entry
                end
            end
            assert(sample, "real model context has persistent searchable bindings: " .. id .. "/" .. key)
            local found
            for _, hit in ipairs(GUI:ExecuteSearch(variant.label .. " " .. sample.label)) do
                local entry = hit.data
                if entry.featureId == id and entry.widgetDescriptor
                    and entry.widgetDescriptor.dbPath == sample.widgetDescriptor.dbPath
                    and entry.widgetDescriptor.dbKey == sample.widgetDescriptor.dbKey then
                    found = entry; break
                end
            end
            assert(found, "actual GUI query finds context-specific binding: " .. id .. "/" .. key)
            assert(table.concat(GUI:GetSearchBreadcrumb(found) or {}, " > "):find(variant.label, 1, true),
                "actual breadcrumb identifies model context: " .. id .. "/" .. key)
        end
    end
end
print("OK: settings_search_runtime_routes_test (" .. checked .. " actual provider routes)")
