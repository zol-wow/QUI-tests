-- Mounted model tabs retain the actual outer host after initial construction,
-- while model-owned tab labels and selector identities remain independent.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI, ns = QUI.GUI
for i = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, i)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
local profile = QUI.QUICore.db.profile
for key, value in pairs(ns.defaults.profile) do profile[key] = Copy(value) end
profile.general.optionsMotion = false
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
_G.geterrorhandler = function() return function(err) error(err, 0) end end
local frame = { _tiles = {} }
GUI.AddFeatureTile = function(_, owner, config)
    owner._tiles[#owner._tiles + 1] = { id = config.id, config = config }
end
local descriptor, contexts
GUI.RegisterTileSurfacePages = function(_, _, value) descriptor = value; return true end
local setContext = GUI.SetSearchContext
GUI.SetSearchContext = function(self, value)
    local result = setContext(self, value)
    local context = self._searchContext
    if contexts and context then contexts[#contexts + 1] = ns.Settings.Util.ShallowCopy(context) end
    return result
end
local checked, failures = 0, {}
for id, feature in ns.Settings.Registry:IterateFeatures() do
    if type(feature.model) == "function" then
        local model, tileId = feature.model(), "relocated_" .. id
        ns.QUI_Options.RegisterFeatureTile(frame, {
            id = tileId, name = "Relocated Model", featureId = id,
            searchContext = { tabIndex = 91, subTabIndex = 19, subTabName = "Outer Page Label" },
        })
        local host = CreateFrame("Frame"); host:SetSize(980, 720)
        descriptor, contexts = nil, {}
        frame._tiles[#frame._tiles].config.buildFunc(host)
        assert(descriptor and descriptor.selectTab, "real model provider exposes navigation: " .. id)
        local chosen
        for _, tab in ipairs(descriptor.getTabs()) do
            if tab.key ~= descriptor.getActiveTab() and #model.GetSearchContexts(tab.key) > 1 then chosen = tab; break end
        end
        assert(chosen, "real model has another contextual tab: " .. id)
        local definition = assert(ns.Settings.ModelKit.GetTabDefinition(model, chosen.key))
        local oldLabel = definition.label
        definition.label = "Renamed Model Tab"
        local function CheckContext(expected)
            local found, selectorFound
            for _, context in ipairs(contexts) do
                if context.featureId == id and context.surfaceTabKey == chosen.key then
                    assert(context.tileId == tileId and context.subPageIndex == 1,
                        "cached model render must keep actual host: " .. id .. "/" .. tostring(context.tileId))
                    assert(context.subTabName == definition.label,
                        "actual model label must survive outer scope: " .. id .. "/" .. tostring(context.subTabName))
                    if expected then
                        for key, value in pairs(expected) do
                            if context[key] ~= nil then
                                assert(context[key] == value, "actual model selector identity survives host scope: " .. id .. "/" .. key .. "/" .. tostring(context[key]))
                                selectorFound = true
                            end
                        end
                    end
                    found = true
                end
            end
            assert(found, "actual model render emits selected tab context: " .. id)
            assert(not expected or selectorFound, "actual model render emits requested selector identity: " .. id)
            assert(ns.Settings.SearchRoute.Depth() == 0, "deferred tab render restores route scope")
        end
        local ok, err = pcall(function()
            contexts = {}
            descriptor.selectTab(chosen.key)
            CheckContext()
            local variants = model.GetSearchContexts(chosen.key)
            local current = feature.getNavigationContext and feature.getNavigationContext() or {}
            local nextVariant
            for _, variant in ipairs(variants) do
                for key, value in pairs(variant.searchContext) do
                    if current[key] ~= value then nextVariant = variant; break end
                end
                if nextVariant then break end
            end
            assert(nextVariant, "model exposes another selector context")
            contexts = {}
            assert(feature.searchNavigate(nextVariant.searchContext, { opts = {} }), "search accepts canonical selector context")
            CheckContext(nextVariant.searchContext)
        end)
        definition.label = oldLabel
        if not ok then failures[#failures + 1] = id .. ": " .. tostring(err) end
        checked = checked + 1
    end
end
assert(#failures == 0, table.concat(failures, "\n"))
assert(checked > 0)
print("OK: settings_model_host_route_test (" .. checked .. " actual model providers)")
