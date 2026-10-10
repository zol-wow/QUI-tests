local handle = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = handle:read("*a")
handle:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI = QUI.GUI
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
for _, path in ipairs({
    "QUI_ActionBars/actionbars/actionbars_env.lua", "QUI_ActionBars/actionbars/actionbars.lua",
    "QUI_ActionBars/actionbars/actionbars_helpers.lua", "QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
local profile = QUI.QUICore.db.profile
for _, key in ipairs({ "actionBars", "general", "bags", "alts", "infobar" }) do
    profile[key] = Copy(ns.defaults.profile[key])
end
profile.general.optionsMotion = false
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    local originalIndex = getmetatable(frame).__index
    setmetatable(frame, { __index = function(self, key)
        if key == "RegisterSection" then return nil end
        return originalIndex(self, key)
    end })
    frame._scripts = {}
    frame.SetScript = function(self, key, callback) self._scripts[key] = callback end
    frame.HookScript = function(self, key, callback)
        local previous = self._scripts[key]
        self._scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    frame.GetVerticalScroll = function(self) return self._verticalScroll or 0 end
    frame.SetVerticalScroll = function(self, offset) self._verticalScroll = offset end
    if kind == "ScrollFrame" then
        frame.GetVerticalScrollRange = function(self)
            local body = self:GetScrollChild()
            return math.max(0, (body and body:GetHeight() or 0) - self:GetHeight())
        end
    end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
ns.QUI_Options.CreateScrollableContent = function(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    return scroll, body
end
local pending = {}
_G.C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
local function Flush()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1
        assert(passes < 100, "deferred provider updates must settle")
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
end
_G.geterrorhandler = function() return function(err) error(err, 0) end end
local frame = CreateFrame("Frame")
frame:SetWidth(1000)
frame:SetHeight(850)
frame._tiles = {}
frame.sidebar = CreateFrame("Frame", nil, frame)
frame.sidebar:SetWidth(211)
frame.contentArea = CreateFrame("Frame", nil, frame)
GUI.AddFeatureTile = function(_, owner, config)
    local tile = CreateFrame("Button", nil, owner)
    tile.id, tile.index, tile.config = config.id, #owner._tiles + 1, config
    tile.text = tile:CreateFontString()
    tile.indicator, tile.hoverBg = tile:CreateTexture(), tile:CreateTexture()
    owner._tiles[#owner._tiles + 1] = tile
    GUI:AttachTileNavigation(owner, tile)
end
GUI.MainFrame = frame
local renderField = ns.Settings.Fields.Render
local selector
ns.Settings.Fields.Render = function(field, ctx, parent)
    local widget = renderField(field, ctx, parent)
    if ctx.feature.id == "actionBarsPerBar" and field.kind == "dropdown" then
        selector = widget
        local setPoint = widget.SetPoint
        widget.SetPoint = function(self, point, relative, ...)
            self._testResolvedAnchor = relative:GetNumPoints() > 0 and relative:GetWidth() > 0
            return setPoint(self, point, relative, ...)
        end
    end
    return widget
end
ns.QUI_ActionBarsTile.Register(frame)
GUI:SelectFeatureTile(frame, 1, { subPageIndex = 2 })
Flush()
assert(selector and selector._testResolvedAnchor,
    "Per-Bar selector must refresh its anchor after the page host receives live bounds")
ns.Settings.Fields.Render = renderField
local actionBars = frame._tiles[1]
local perBar = actionBars._subPageBodies[2]._contentBody
assert(actionBars._activeSubPageIndex == 2 and perBar:GetHeight() > 300, "Per-Bar mounts its native settings on the selected subpage")
assert(#perBar._sections >= 5, "Per-Bar includes the native layout, visual and text sections")
local bindings = {}
for _, entry in ipairs(GUI.SettingsRegistry) do
    if entry.featureId == "actionBarsPerBar" then bindings[entry.label] = true end
end
for _, label in ipairs({ "Bar", "Buttons Per Row", "Button Size", "Show Keybinds", "Show Counts", "Show Duration Text" }) do
    assert(bindings[label], "native Per-Bar settings must render: " .. label)
end
local function FindBoundWidget(owner, key, settings)
    if rawget(owner, "_syncDBKey") == key and rawget(owner, "_syncDBTable") == settings then return owner end
    for _, child in ipairs({ owner:GetChildren() }) do
        local widget = FindBoundWidget(child, key, settings)
        if widget then return widget end
    end
end
local function FindRuntime(owner)
    local runtime = rawget(owner, "_quiSettingsRuntime")
    if runtime and runtime.feature.id == "actionBarsPerBar" then return runtime end
    for _, child in ipairs({ owner:GetChildren() }) do
        local found = FindRuntime(child)
        if found then return found end
    end
end
for _, key in ipairs({ "bar2", "bar3", "bar8", "petBar", "microMenu" }) do
    ns.QUI_ActionBarsOptions.SetSelectedBar(key, "perBar")
    Flush()
    local runtime = assert(FindRuntime(perBar))
    local settingsHost = runtime.sectionHosts.settings
    assert((rawget(settingsHost, "_width") or 0) > 0,
        "rebuilding " .. key .. " must restore an explicit nonzero settings section width")
    assert(math.abs(settingsHost:GetWidth() - math.max(300, runtime.ctx.width - 20)) < 1,
        "rebuilding " .. key .. " must use the page's available width")
    ns.QUI_ActionBarsOptions.SetSelectedBar("bar1", "perBar")
    Flush()
    assert(ns.QUI_ActionBarsOptions.GetSelectedBar() == "bar1" and perBar:GetHeight() > 300,
        "returning from " .. key .. " keeps Bar 1's mounted settings body")
    local boundCounts = assert(FindBoundWidget(perBar, "showCounts", profile.actionBars.bars.bar1),
        "returning from " .. key .. " binds the actual Bar 1 settings")
    assert(boundCounts:IsShown(), "returning from " .. key .. " keeps the Bar 1 counts control shown")
end
for _, name in ipairs({ "QUI_BagsTile", "QUI_AltsTile", "QUI_InfoBarTile" }) do
    ns[name].Register(frame)
    local tile = frame._tiles[#frame._tiles]
    local previous = frame._lastTileIndex
    assert(GUI:OpenNavigationFlyout(frame, tile), tile.id .. " opens its section flyout on first hover")
    assert(frame._lastTileIndex == previous, "warming a provider does not select its module")
    local body = tile._subPageBodies[1]._contentBody
    local pages = GUI:GetTileNavigationPages(tile)
    if tile.id == "bags" or tile.id == "alts" then
        assert(#pages == (tile.id == "bags" and 6 or 5) and tile._navArrow:IsShown(),
            "focused provider pages must keep their native flyout inventory")
        assert(#body._sections == 2, "General must build only its two related sections")
        for _, page in ipairs(pages) do assert(not page.section, "focused pages must not duplicate section-scroll targets") end
        local button = frame._pageFlyout._buttons[3]
        button._scripts.OnClick(button)
        Flush()
        assert(frame._lastTileIndex == tile.index and tile._activeSubPageIndex == 3,
            "focused flyout selection must mount the requested page")
        local selected = tile._subPageBodies[3]._contentBody
        assert(#selected._sections >= 1, "focused page must mount its actual provider settings")
        assert(not frame._pageFlyout:IsShown(), "page selection closes the flyout")
        GUI:OpenNavigationFlyout(frame, tile)
        assert(#GUI:GetTileNavigationPages(tile) == #pages, "cached pages retain the complete flyout")
    else
        assert(#body._sections >= 3 and #pages > 1 and tile._navArrow:IsShown(), tile.id .. " keeps its chevron and native section inventory")
        local visibleSections = 0
        for _, section in ipairs(body._sections) do
            if section.frame and section.frame:IsShown() then
                visibleSections = visibleSections + 1
                local listed = assert(pages[visibleSections])
                assert(listed.section == section.frame and listed.label == (section.label or section.id) and not listed.indent,
                    tile.id .. " lists real sections directly without an indented module wrapper")
            end
        end
        assert(#pages == visibleSections, tile.id .. " has no duplicate clickable module-name row")
        local page = assert(pages[3])
        assert(page.section and page.section:GetParent(), "section flyout targets a real mounted heading")
        local scroll = assert(GUI:_findAncestorScroll(page.section))
        scroll.GetScrollChild = function() return body end
        body.GetTop = function() return 800 end
        page.section.GetTop = function() return 500 end
        local range = scroll:GetVerticalScrollRange()
        local nextTop = pages[4] and pages[4].section:GetTop()
        local expected = math.min(range, 300)
        if nextTop then expected = math.min(expected, math.max(0, 800 - nextTop - 9) * range / (range + scroll:GetHeight())) end
        local button = frame._pageFlyout._buttons[3]
        button._scripts.OnClick(button)
        Flush()
        assert(frame._lastTileIndex == tile.index and tile._activeSubPageIndex == 1, "section selection opens the correct module")
        assert(math.abs(scroll:GetVerticalScroll() - expected) < 1, "section selection uses the scroll progress destination for the mounted section")
        assert(not frame._pageFlyout:IsShown(), "section selection closes the flyout")
        GUI:OpenNavigationFlyout(frame, tile)
        assert(#GUI:GetTileNavigationPages(tile) == #pages, "cached provider pages retain their section flyout")
    end
    GUI:CloseNavigationFlyout(frame)
end
local cacheNS = {}
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", cacheNS)
GUI:ApplyGeneratedSearchCache(assert(loadstring("return " .. cacheNS.QUI_SearchCachePacked))(), cacheNS.QUI_SearchCacheSchema)
local foundQuality = false
for _, entry in ipairs(GUI.StaticSettingsRegistry) do
    if entry.label == "Quality-Colored Text" and entry.featureId == "bags" then
        local route = assert(GUI:ResolveSearchNavigation(entry))
        assert(route.tileId == "bags" and route.subPageIndex == 2,
            "the actual cached Quality-Colored Text result must reach Icon Corners")
        assert(table.concat(GUI:GetSearchBreadcrumb(entry), " > ") == "Bags > Icon Corners",
            "search breadcrumbs must not repeat the page as its section")
        foundQuality = true
    end
end
assert(foundQuality, "the actual search cache must retain the moved bag setting")
print("options_provider_flyout_integration_test: ok")
