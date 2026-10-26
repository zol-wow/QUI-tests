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
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", ns)
local runWhenSettingsLayoutReady = GUI.RunWhenSettingsLayoutReady
function GUI:RunWhenSettingsLayoutReady(_, _, callback, isCurrent)
    C_Timer.After(0, function() if not isCurrent or isCurrent() then callback() end end)
end
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
for key, value in pairs(ns.defaults.profile) do
    profile[key] = Copy(value)
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
local function VisibleButton(panel, destination)
    local function Find()
        for _, button in ipairs(panel._buttons) do
            local page = button._page
            if button:IsShown() and not page._group and page.pageIndex == destination.pageIndex
                and page.key == destination.key and page.sectionId == destination.sectionId then
                return button
            end
        end
    end
    local button = Find()
    if button then return button end
    for _ = 1, 2 do
        for _, header in ipairs(panel._buttons) do
            local page = header._page
            if header:IsShown() and page._group and page.pageIndex == destination.pageIndex
                and (not page.key or page.key == destination.key)
                and not panel._tile._navigationExpanded[page._groupId] then
                local before = frame._lastTileIndex
                local built = panel._tile._built
                header._chevron._scripts.OnClick(header._chevron)
                assert(frame._lastTileIndex == before and panel._tile._built == built,
                    "expanding a cold page must preserve the editor and avoid constructing settings")
                break
            end
        end
        button = Find()
        if button then return button end
    end
    return assert(Find(), "expanded navigation must expose " .. destination.label)
end
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
local coldPerBar = {}
for _, page in ipairs(GUI:GetTileNavigationPages(frame._tiles[1])) do
    if page.pageIndex == 2 then coldPerBar[#coldPerBar + 1] = page end
end
assert(#coldPerBar >= 3 and not frame._tiles[1]._built,
    "Action Bars must list Per Bar section links on first load before opening the editor")
GUI:SelectFeatureTile(frame, 1, { subPageIndex = 2 })
Flush()
assert(selector and selector._testResolvedAnchor,
    "Per-Bar selector must refresh its anchor after the page host receives live bounds")
ns.Settings.Fields.Render = renderField
local actionBars = frame._tiles[1]
local perBar = actionBars._subPageBodies[2]._contentBody
assert(actionBars._activeSubPageIndex == 2 and perBar:GetHeight() > 300, "Per-Bar mounts its native settings on the selected subpage")
assert(#perBar._sections >= 5, "Per-Bar includes the native layout, visual and text sections")
assert(#coldPerBar == #perBar._sections, "opening Per Bar must preserve its initial section links")
for index, section in ipairs(perBar._sections) do
    assert(coldPerBar[index].sectionId == section.id and coldPerBar[index].label == section.label,
        "initial Per Bar links must match the editor's actual heading identifiers and order")
end
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
    assert(not tile._built, "hovering must preserve the unbuilt provider")
    local coldPages = GUI:GetTileNavigationPages(tile)
    if tile.id == "bags" or tile.id == "alts" then
        assert(#coldPages == #tile.config.subPages,
            "small provider pages must expose one plain destination each before mounting")
        for index, page in ipairs(coldPages) do
            assert(page.pageIndex == index and page.label == tile.config.subPages[index].name
                and not page.group and not page.sectionId,
                "cold small provider pages must not add section sub-tabs")
        end
    end
    GUI:SelectFeatureTile(frame, tile.index)
    GUI:CloseNavigationFlyout(frame)
    GUI:OpenNavigationFlyout(frame, tile)
    local body = tile._subPageBodies[1]._contentBody
    local pages = GUI:GetTileNavigationPages(tile)
    if tile.id == "bags" or tile.id == "alts" then
        assert(#pages == #tile.config.subPages and tile._navArrow:IsShown(),
            "focused provider pages must retain one destination per page")
        assert(#body._sections == 2, "General must build only its two related sections")
        local destination, represented = nil, {}
        for index, page in ipairs(pages) do
            local config = tile.config.subPages[page.pageIndex]
            assert(page.label == config.name and not page.group and not page.sectionId,
                "built small provider pages must remain plain destinations")
            represented[page.pageIndex] = true
            if page.pageIndex == 3 and not destination then destination = index end
        end
        for index in ipairs(tile.config.subPages) do assert(represented[index], "every provider page stays reachable") end
        local button = VisibleButton(frame._pageFlyout, pages[assert(destination)])
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
        for index, entry in ipairs(pages) do
            entry.section.GetTop = function() return 800 - index * 100 end
        end
        local range = scroll:GetVerticalScrollRange()
        local nextTop = pages[4] and pages[4].section:GetTop()
        local expected = math.min(range, 300)
        if nextTop then expected = math.min(expected, math.max(0, 800 - nextTop - 9) * range / (range + scroll:GetHeight())) end
        local button = VisibleButton(frame._pageFlyout, page)
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
for _, spec in ipairs({
    { tile = "QUI_GameplayTile", page = 5 },
    { tile = "QUI_GameplayTile", page = 6 },
    { tile = "QUI_GlobalTile", page = 7 },
}) do
    ns[spec.tile].Register(frame)
    local tile = frame._tiles[#frame._tiles]
    local config = tile.config.subPages[spec.page]
    assert(config.featureIds, "regression fixture must select a composite page")
    local coldPages = GUI:GetTileNavigationPages(tile)
    local coldSections = {}
    for _, page in ipairs(coldPages) do
        if page.pageIndex == spec.page then coldSections[#coldSections + 1] = page end
    end
    local grouped = #config.featureIds >= (config.sectionNav == true and 2 or 3)
    if grouped then
        assert(#coldSections == #config.featureIds,
            "larger composite menus must list feature titles rather than internal settings headings")
        for index, id in ipairs(config.featureIds) do
            assert(coldSections[index].sectionId == id,
                "cold composite links must use the feature IDs registered by the built page")
        end
    else
        assert(#coldSections == 1 and coldSections[1].label == config.name
            and not coldSections[1].group and not coldSections[1].sectionId,
            "small composite pages must have one plain destination")
    end
    local destination
    local ready = GUI.RunWhenSettingsLayoutReady
    GUI.RunWhenSettingsLayoutReady = function(_, _, target) destination = target end
    GUI:OpenNavigationFlyout(frame, tile, true)
    for _, page in ipairs(frame._pageFlyout._pages) do
        if page.pageIndex == spec.page and (not grouped or page.sectionId == config.featureIds[2]) then
            local button = VisibleButton(frame._pageFlyout, page)
            button._scripts.OnClick(button)
            break
        end
    end
    Flush()
    GUI.RunWhenSettingsLayoutReady = ready
    local sections = tile._subPageBodies[spec.page]._contentBody._sections
    assert(tile._activeSubPageIndex == spec.page and #sections == #config.featureIds,
        "composite page selection must mount all its settings")
    if grouped then
        assert(destination == sections[2].frame,
            "first composite click must resolve the actual mounted feature heading")
        for index, section in ipairs(sections) do
            assert(coldSections[index].label == section.label,
                "cold and built composite menus must use identical feature title labels")
        end
    else
        assert(not destination, "small composite pages must open without a section jump")
        local builtPages = {}
        for _, page in ipairs(GUI:GetTileNavigationPages(tile)) do
            if page.pageIndex == spec.page then builtPages[#builtPages + 1] = page end
        end
        assert(#builtPages == 1 and builtPages[1].label == config.name
            and not builtPages[1].group and not builtPages[1].sectionId,
            "small composite pages must stay plain after mounting")
    end
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
ns.QUI_GroupFramesTile.Register(frame)
local groupTile = frame._tiles[#frame._tiles]
local groupSurface = ns.QUI_GroupFramesSettingsSurface
local function HasSpotlight()
    for _, page in ipairs(GUI:GetTileNavigationPages(groupTile)) do
        if page.key == "layout" and page.sectionId == "Spotlight" then return true end
    end
    return false
end
groupSurface.SetContextMode("party")
assert(not HasSpotlight(), "cold Party navigation must omit the raid-only Spotlight section")
groupSurface.SetContextMode("raid")
assert(HasSpotlight() and not groupTile._built,
    "cold Raid navigation must expose Spotlight without constructing its settings page")
local ready = GUI.RunWhenSettingsLayoutReady
local jumpOwner, jumpTarget
GUI.RunWhenSettingsLayoutReady = function(self, owner, target, callback, isCurrent)
    jumpOwner, jumpTarget = owner, target
    local body, scroll = assert(owner._contentBody), assert(owner._scrollFrame)
    owner:SetWidth(800)
    owner:SetHeight(600)
    scroll:SetHeight(600)
    body:SetHeight(2600)
    body.GetTop = function() return 1000 end
    local afterTarget = false
    for _, section in ipairs(body._sections) do
        if section.frame == target then
            section.frame.GetTop = function() return 200 end
            afterTarget = true
        elseif afterTarget then
            section.frame.GetTop = function() return -2000 end
        else
            section.frame.GetTop = function() return 990 end
        end
    end
    scroll:SetVerticalScroll(0)
    runWhenSettingsLayoutReady(self, owner, target, callback, isCurrent)
end
GUI:OpenNavigationFlyout(frame, groupTile, true)
for _, page in ipairs(frame._pageFlyout._pages) do
    if page.key == "layout" and page.sectionId == "Spotlight" then
        local button = VisibleButton(frame._pageFlyout, page)
        button._scripts.OnClick(button)
        break
    end
end
Flush()
local groupNavigation = assert(groupTile._surfacePagesByPage[1])
assert(groupNavigation.getActiveTab() == "layout" and jumpOwner == groupNavigation.getPage("layout"),
    "the first cold Spotlight click must select Layout and resolve its actual inner scrolling owner")
assert(jumpTarget and jumpOwner._scrollFrame and #jumpOwner._contentBody._sections > 1,
    "actual Group Frames layout must expose its rendered section heading as the scroll target")

local function FinishJump(tile)
    assert(rawget(tile, "_activeSubPageIndex") == nil,
        tile.id .. " must exercise the real single-page tile without an explicit outer page index")
    local driver = assert(jumpOwner._quiLayoutReadyDriver)
    for _ = 1, 3 do
        local update = driver._scripts.OnUpdate
        if update then update(driver, 0.1) end
    end
    assert(jumpOwner._scrollFrame:GetVerticalScroll() == 800,
        tile.id .. " section click must actually scroll its inner body after the layout settles")
end
FinishJump(groupTile)
ns.QUI_NameplatesTile.Register(frame)
local nameplateTile = frame._tiles[#frame._tiles]
for pass = 1, 2 do
    local destination
    GUI:OpenNavigationFlyout(frame, nameplateTile, true)
    for index, page in ipairs(frame._pageFlyout._pages) do
        if page.key and page.sectionId then
            local nextPage = frame._pageFlyout._pages[index + 1]
            if not nextPage or nextPage.key ~= page.key or not nextPage.sectionId then
                destination = page
                local button = VisibleButton(frame._pageFlyout, page)
                button._scripts.OnClick(button)
                break
            end
        end
    end
    assert(destination, "Nameplates must expose a cold and cached section destination")
    Flush()
    local navigation = assert(nameplateTile._surfacePagesByPage[1])
    assert(navigation.getActiveTab() == destination.key and jumpOwner == navigation.getPage(destination.key),
        "Nameplates section click must resolve its actual inner scrolling owner")
    FinishJump(nameplateTile)
end
GUI.RunWhenSettingsLayoutReady = ready

print("options_provider_flyout_integration_test: ok")

profile.spellReminders.reminders = {}
for _, id in ipairs({10060, 29166, 6940, 1022, 1044}) do
    profile.spellReminders.reminders[id] = ns.SpellReminderModel.New(id)
end
ns.QUI_RemindersTile.Register(frame)
local remindersTile = frame._tiles[#frame._tiles]
GUI:OpenNavigationFlyout(frame, remindersTile, true)
local reminderPanel = frame._pageFlyout
local function ReminderRow(key, sectionId, isGroup, contextId)
    for _, button in ipairs(reminderPanel._buttons) do
        local row = button._page
        if button:IsShown() and row.pageIndex == 2 and row.key == key and row.sectionId == sectionId
            and row.contextId == contextId and (not not row._group) == (not not isGroup) then return button end
    end
end
local function ContextRow(id)
    for _, button in ipairs(reminderPanel._buttons) do
        if button:IsShown() and button._page._groupId == "2:context:" .. id then return button end
    end
end
local outer = assert(ReminderRow(nil, nil, true))
assert(not ns.SpellReminderPresentation and outer._page.label == "Spell Reminders (5)" and outer._page._depth == 0,
    "cold navigation must preserve the collection before spell names load")
outer._chevron._scripts.OnClick(outer._chevron)
assert(ReminderRow("general")._page.label == "Add Reminder" and ContextRow(10060)._page.label == "10060",
    "cold collection must expose creation and use spell ID fallbacks")
ns.SpellReminderPresentation = { Name = function(config)
    return config.spellID == 10060 and "Power Infusion" or "Spell " .. config.spellID
end }
GUI:OpenNavigationFlyout(frame, remindersTile, true)
outer = assert(ReminderRow(nil, nil, true))
assert(outer._page.label == "Spell Reminders (5)", "spell names must not replace the collection root")
if not ContextRow(10060) then outer._chevron._scripts.OnClick(outer._chevron) end
for _, id in ipairs({10060, 29166, 6940, 1022, 1044}) do
    assert(ContextRow(id) and ContextRow(id)._page._depth == 1, "all five reminders must be separate visible rows")
end
local pi = ContextRow(10060)
assert(pi._page.label == "Power Infusion")
pi._chevron._scripts.OnClick(pi._chevron)
local appearance = assert(ReminderRow("appearance", nil, true, 10060))
assert(appearance._page.label == "Appearance" and appearance._page._depth == 2,
    "Appearance must belong to the named reminder")
assert(ReminderRow("timing", nil, false, 10060)._page._depth == 2
    and ReminderRow("sounds", nil, false, 10060)._page._depth == 2, "short tabs must remain siblings")
appearance._chevron._scripts.OnClick(appearance._chevron)
for _, label in ipairs({ "Icon and Text", "Glow and Animation", "Position" }) do
    assert(ReminderRow("appearance", label, false, 10060)._page._depth == 3,
        "actual reminder sections must retain their tab and reminder ancestry")
end
assert(not remindersTile._built, "inspecting every reminder must not build its editor")
outer = ReminderRow(nil, nil, true)
outer._chevron._scripts.OnClick(outer._chevron)
assert(not ContextRow(10060) and not ReminderRow("general"), "collapsing the collection hides all descendants")
profile.spellReminders.reminders = {}
GUI:OpenNavigationFlyout(frame, remindersTile, true)
outer = assert(ReminderRow(nil, nil, true))
assert(outer._page.label == "Spell Reminders (0)", "deleting all reminders retains the collection root")
outer._chevron._scripts.OnClick(outer._chevron)
assert(ReminderRow("general") and not ContextRow(10060), "empty cold navigation still exposes Add Reminder")
print("options actual Spell Reminders collection hierarchy: ok")
