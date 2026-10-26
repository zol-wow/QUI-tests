-- Compare generated search with constructors from the actual mounted Action Bars pages.
-- The preamble supplies only headless WoW services; capture overrides are never installed.
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
assert(loadfile("core/pack.lua"))("QUI", ns)
assert(loadfile(os.getenv("QUI_ACTION_BARS_CACHE") or "QUI_Options/search_cache.lua"))("QUI", ns)
GUI:EnsureSearchCacheLoaded()
assert(GUI:HasGeneratedSearchCache(), "real runtime must consume the generated cache")
local realRunWhenSettingsLayoutReady = GUI.RunWhenSettingsLayoutReady
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
_G.C_Timer.After = function(delay, callback) if delay == 0 then pending[#pending + 1] = callback end end
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

tinsert = table.insert
UISpecialFrames = {}
for _, entry in ipairs(ns.SwingTimers.entries) do
    profile.swingTimers[entry.key] = Copy(profile.swingTimers["*"])
end
for _, unit in pairs(profile.quiUnitFrames) do
    if type(unit) == "table" and unit.castbar then
        unit.castbar.empoweredStageColors = unit.castbar.empoweredStageColors or {}
        unit.castbar.empoweredFillColors = unit.castbar.empoweredFillColors or {}
    end
end
local cache = dofile("tests/helpers/search_cache.lua")(os.getenv("QUI_ACTION_BARS_CACHE"))
local expected, current, section, selectorOptions = {}, nil, nil, nil
local function FindPath(target, value, path)
    if target == value then return path end
    for key, child in pairs(value) do
        if type(child) == "table" then
            local found = FindPath(target, child, path .. "." .. tostring(key))
            if found then return found end
        end
    end
end
local function Binding(entry)
    local d = entry.widgetDescriptor or {}
    return table.concat({entry.featureId, d.dbPath or "", tostring(d.dbKey or ""),
        entry.providerKey or "", d.dbPath and "" or entry.label}, "|")
end
local layout = ns.QUI_LayoutMode_Utils
local collapsible = layout.CreateCollapsible
layout.CreateCollapsible = function(parent, title, ...)
    local previous = section
    section = title
    local result = collapsible(parent, title, ...)
    section = previous
    return result
end
local constructorDepth = 0
local lastLayoutWidget, layoutBuilds = nil, 0
for name, spec in pairs({
    CreateFormCheckbox = {"checkbox", 3, 4}, CreateFormToggle = {"toggle", 3, 4},
    CreateFormSlider = {"slider", 6, 7}, CreateFormDropdown = {"dropdown", 4, 5},
    CreateFormColorPicker = {"colorpicker", 3, 4},
}) do
    local original = GUI[name]
    GUI[name] = function(self, ...)
        local args = {...}
        if args[2] == "Bar" and name == "CreateFormDropdown" then selectorOptions = args[3] end
        local db, key = args[spec[3]], args[spec[2]]
        if constructorDepth == 0 and current and ((db and key) or args[2] == "Copy Settings From") then
            local path = db and FindPath(db, profile, "profile")
            if path or args[2] == "Copy Settings From" then
                local d = path and { dbPath = path, dbKey = key, kind = spec[1] } or nil
                if d and spec[1] == "slider" then d.min, d.max, d.step = args[3], args[4], args[5] end
                if d and spec[1] == "dropdown" then d.options = args[3] end
                local entry = { featureId = current.featureId, providerKey = current.providerKey,
                    tileId = "action_bars", subPageIndex = current.pageIndex, sectionName = section,
                    label = args[2], widgetType = spec[1], widgetDescriptor = d }
                expected[Binding(entry)] = entry
            end
        end
        constructorDepth = constructorDepth + 1
        local result = original(self, ...)
        if constructorDepth == 1 and key == "buttonSpacing" and db then
            lastLayoutWidget = result
            layoutBuilds = layoutBuilds + 1
        end
        constructorDepth = constructorDepth - 1
        return result
    end
end

ns.QUI_ActionBarsTile.Register(frame)
local tile = frame._tiles[#frame._tiles]
local function CheckSectionGo(providerKey, navResult, label)
    local entry
    for _, candidate in ipairs(navResult and cache.navigation or cache.settings) do
        if candidate.featureId == "actionBarsPerBar" and candidate.providerKey == providerKey
            and candidate.sectionName == "Cooldown Duration Text"
            and ((navResult and candidate.navType == "section")
                or (candidate.widgetDescriptor and candidate.widgetDescriptor.dbKey == "cooldownTextFontSize")) then
            entry = candidate
            break
        end
    end
    assert(entry, label .. " requires a real generated cooldown destination")
    local ready, waitedOwner, waitedTarget, targetPosition = false
    local shim = GUI.RunWhenSettingsLayoutReady
    GUI.RunWhenSettingsLayoutReady = function(self, owner, target, callback, isCurrent, onFinished)
        waitedOwner, waitedTarget = owner, target
        local body, scroll = owner._contentBody, owner._scrollFrame
        owner.GetWidth = function() return 1000 end
        owner.GetHeight = function() return 500 end
        scroll.GetHeight = function() return 500 end
        scroll.GetVerticalScrollRange = function() return 3000 end
        body.GetHeight = function() return 3500 end
        body.GetTop = function() return ready and (1000 + scroll:GetVerticalScroll()) or nil end
        for index, sectionEntry in ipairs(body._sections or {}) do
            local position = (index - 1) * 400
            sectionEntry.frame.GetTop = function() return ready and (1000 + scroll:GetVerticalScroll() - position) or nil end
            if sectionEntry.frame == target then targetPosition = position end
        end
        return realRunWhenSettingsLayoutReady(self, owner, target, callback, isCurrent, onFinished)
    end
    if navResult then
        GUI:NavigateSearchResult(entry)
    else
        local resultsHost = CreateFrame("Frame")
        resultsHost:SetWidth(1000)
        GUI:RenderSearchResults(resultsHost, {{ data = entry, score = 1 }}, label, {})
        local key = table.concat(GUI:GetSearchBreadcrumb(entry), " > ")
        local go = assert(resultsHost._searchRenderCache.goButtons[key], label .. " must render a real group Go button")
        go._scripts.OnClick(go)
    end
    Flush()
    GUI.RunWhenSettingsLayoutReady = shim
    local owner = tile._subPageBodies[2]
    local target
    for _, sectionEntry in ipairs(owner._contentBody._sections or {}) do
        if sectionEntry.id == entry.sectionName then target = sectionEntry.frame end
    end
    assert(target and waitedOwner == owner and waitedTarget == target,
        label .. " must wait for the actual mounted cooldown heading on its scroll owner")
    local driver = owner._quiLayoutReadyDriver
    local update = assert(driver and driver._scripts.OnUpdate, label .. " must schedule real layout readiness")
    local before = owner._scrollFrame:GetVerticalScroll()
    update(driver, 0.016)
    assert(owner._scrollFrame:GetVerticalScroll() == before, label .. " must wait while native bounds are unavailable")
    ready = true
    for _ = 1, 3 do if driver._scripts.OnUpdate then driver._scripts.OnUpdate(driver, 0.016) end end
    local offset = owner._scrollFrame:GetVerticalScroll()
    assert(targetPosition and targetPosition > 500 and offset >= targetPosition - 500 and offset <= targetPosition,
        label .. " must reveal the actual cooldown heading, not retain the previous scroll position")
end
CheckSectionGo("bar2", false, "cold settings-group Go")
CheckSectionGo("bar3", false, "mounted settings-group Go")
CheckSectionGo("bar4", true, "section search result")
local scopedFeatures = {
    actionBarsPerBar = true, actionBarsTotemBar = true, actionBarsRaidMarkersBar = true,
    actionBarsBagBar = true, actionBarsExtraZone = true,
}
local variants = 0
for pageIndex, page in ipairs(tile.config.subPages) do
    if scopedFeatures[page.featureId] then
        local feature = ns.Settings.Registry:GetFeature(page.featureId)
        current = { featureId = page.featureId, pageIndex = pageIndex,
            providerKey = page.featureId == "actionBarsPerBar" and "bar1"
                or (feature.lookupKeys and #feature.lookupKeys == 1 and feature.lookupKeys[1]) or nil }
        section = nil
        if page.featureId == "actionBarsPerBar" then
            local coldEntry
            for _, entry in ipairs(cache.settings) do
                if entry.featureId == page.featureId and entry.providerKey == "bar2"
                    and entry.widgetDescriptor and entry.widgetDescriptor.dbKey == "buttonSpacing" then
                    coldEntry = entry
                    break
                end
            end
            assert(coldEntry, "cold search must expose Bar 2 before mounting the Per-Bar editor")
            -- Navigation may initially construct the default body before it
            -- selects Bar 2. Observe its final binding without labeling that
            -- intermediate construction as part of the completeness inventory.
            local captureContext = current
            current = nil
            GUI:NavigateSearchResult(coldEntry)
            Flush()
            assert(lastLayoutWidget and lastLayoutWidget._syncDBTable == profile.actionBars.bars.bar2.ownedLayout,
                "cold search must construct the requested Bar 2 bindings, not the default bar")
            current = captureContext
            current.providerKey = "bar1"
            ns.QUI_ActionBarsOptions.SetSelectedBar("bar1", "cold-search-reset")
            Flush()
        else
            GUI:SelectFeatureTile(frame, tile.index, { subPageIndex = pageIndex })
            Flush()
        end
        if page.featureId == "actionBarsPerBar" then
            assert(selectorOptions and #selectorOptions > 0, "actual Per-Bar selector must enumerate supported contexts")
            for _, option in ipairs(selectorOptions) do
                current.providerKey = option.value
                section = nil
                ns.QUI_ActionBarsOptions.SetSelectedBar(option.value, "completeness-test")
                Flush()
                variants = variants + 1
            end
        end
        current = nil
    end
end

local failures, actual, matched = {}, {}, 0
local function Check(ok, message) if not ok then failures[#failures + 1] = message end end
local function Options(options)
    local result = {}
    for _, option in ipairs(options or {}) do
        result[#result + 1] = tostring(option.value) .. "=" .. tostring(option.text)
    end
    return table.concat(result, "|")
end
for _, entry in ipairs(cache.settings) do
    if scopedFeatures[entry.featureId] then
        local d = entry.widgetDescriptor
        if (d and d.dbPath) or entry.label == "Copy Settings From" then
            local id = Binding(entry)
            Check(not actual[id], "duplicate binding/destination/context: " .. id)
            actual[id] = entry
        end
    end
end
for id, want in pairs(expected) do
    local got = actual[id]
    Check(got, "missing actual control: " .. id .. " (" .. want.label .. ")")
    if got then
        matched = matched + 1
        for _, field in ipairs({"label", "widgetType", "tileId", "subPageIndex", "sectionName"}) do
            Check(got[field] == want[field], id .. " must preserve actual " .. field .. ": " .. tostring(want[field])
                .. ", got " .. tostring(got[field]))
        end
        local route = GUI:ResolveSearchNavigation(got)
        Check(route and route.tileId == want.tileId and route.subPageIndex == want.subPageIndex,
            id .. " must resolve to its actual mounted page")
        local gd, wd = got.widgetDescriptor or {}, want.widgetDescriptor or {}
        for _, field in ipairs({"kind", "min", "max", "step"}) do
            Check(gd[field] == wd[field], id .. " must preserve actual " .. field)
        end
        if wd.kind == "dropdown" then Check(Options(gd.options) == Options(wd.options), id .. " must preserve actual dropdown options") end
        if not wd.dbPath then Check(not gd.dbPath, id .. " action-only control must not acquire a static binding") end
    end
end
for id in pairs(actual) do Check(expected[id], "generated control has no actual counterpart: " .. id) end
Check(variants == #selectorOptions, "every actual Per-Bar selector variant must be exercised")
-- Pin the original omissions independently so empty or suppressed captures cannot pass.
for _, key in ipairs({"showCooldownText", "cooldownTextFontSize", "cooldownTextAnchor", "cooldownTextOffsetX",
    "cooldownTextOffsetY", "cooldownTextColor", "showInOpenWorld", "showInDungeons", "showInMythicPlus",
    "showInRaids", "showInMythicRaids", "showOnLuraMythic"}) do
    Check(expected["actionBarsPerBar|profile.actionBars.bars.bar1|" .. key .. "|bar1|"],
        "real Bar 1 builder must construct regression control " .. key)
end
-- Exercise the consumers as well as the cache: display context must not merge
-- different bars, and captured checkbox descriptors must remain inline-editable.
GUI:EnsureSearchCacheLoaded()
local keybindHits = {}
for _, hit in ipairs(GUI:ExecuteSearch("Show Keybinds")) do
    local entry = hit.data
    if entry.featureId == "actionBarsPerBar" and entry.label == "Show Keybinds" then
        keybindHits[entry.providerKey] = entry
    end
end
for _, option in ipairs(selectorOptions) do
    local found
    for _, hit in ipairs(GUI:ExecuteSearch(option.text)) do
        local entry = hit.data
        if entry.featureId == "actionBarsPerBar" and entry.providerKey == option.value
            and entry.label == "Button Spacing" then found = entry; break end
    end
    Check(found, "search by bar name must find its actual controls: " .. option.text)
    if found then
        local crumb = table.concat(GUI:GetSearchBreadcrumb(found) or {}, " > ")
        Check(crumb:find(option.text, 1, true), "breadcrumb must distinguish " .. option.text)
        GUI:NavigateSearchResult(found)
        Flush()
        Check(ns.QUI_ActionBarsOptions.GetSelectedBar() == option.value,
            "search must select its actual bar context: " .. option.text)
        Check(lastLayoutWidget and lastLayoutWidget._syncDBTable == GUI:ResolveSearchDBTable(found.widgetDescriptor.dbPath),
            "search must rebuild the actual controls for " .. option.text .. ", not only update the preview selector")
        local sameWidget, sameBuilds = lastLayoutWidget, layoutBuilds
        GUI:NavigateSearchResult(found)
        Flush()
        Check(lastLayoutWidget == sameWidget and layoutBuilds == sameBuilds,
            "repeating search for the current bar must preserve its mounted controls: " .. option.text)
        local previewKey = option.value == "bar1" and "bar2" or "bar1"
        ns.QUI_ActionBarsOptions.SetSelectedBar(previewKey, "preview-after-search")
        Flush()
        Check(lastLayoutWidget and lastLayoutWidget._syncDBTable == profile.actionBars.bars[previewKey].ownedLayout,
            "preview selection after same-bar search must not reuse its stale pending destination: " .. option.text)
    end
    if option.value ~= "microMenu" then
        Check(keybindHits[option.value], "search must not merge distinct bar bindings: " .. option.text)
    end
end
local labels, sectionHits = {}, {}
for _, option in ipairs(selectorOptions) do labels[option.value] = option.text end
-- Categories & Sections must expose the same actual selector context as settings
-- groups, both in the packed cache and after route labels are refreshed at runtime.
for _, entry in ipairs(cache.navigation) do
    if entry.featureId == "actionBarsPerBar" and entry.navType == "section" and entry.contextLabel then
        local breadcrumb = table.concat(GUI:GetSearchBreadcrumb(entry), " > ")
        Check(entry.label == breadcrumb, "generated section label must distinguish " .. breadcrumb)
    end
end
local function CheckContextualSectionSearch(stage)
    local _, broadHits = GUI:ExecuteSearch("Cooldown Duration Text")
    local displayed = {}
    for _, hit in ipairs(broadHits) do
        local entry = hit.data
        if entry.featureId == "actionBarsPerBar" and entry.navType == "section"
            and entry.sectionName == "Cooldown Duration Text" then
            local breadcrumb = table.concat(GUI:GetSearchBreadcrumb(entry), " > ")
            Check(entry.label == breadcrumb, stage .. " section display must include " .. entry.contextLabel)
            Check(not displayed[entry.label], stage .. " section display must distinguish every bar")
            displayed[entry.label] = true
        end
    end
    for _, option in ipairs(selectorOptions) do
        if option.value ~= "microMenu" then
            local _, hits = GUI:ExecuteSearch(option.text .. " Cooldown Duration Text")
            local found
            for _, hit in ipairs(hits) do
                local entry = hit.data
                if entry.featureId == "actionBarsPerBar" and entry.navType == "section"
                    and entry.providerKey == option.value and entry.sectionName == "Cooldown Duration Text" then
                    found = entry
                end
            end
            Check(found, stage .. " section search must match the actual bar and section: " .. option.text)
        end
    end
end
CheckContextualSectionSearch("loaded cache")
GUI:SeedStaticSearchRoutesFromTiles(frame)
CheckContextualSectionSearch("refreshed routes")
for _, entry in ipairs(cache.navigation) do
    if entry.featureId == "actionBarsPerBar" and entry.navType == "section" and entry.contextLabel then
        Check(entry.providerKey and labels[entry.providerKey] == entry.contextLabel,
            "section result must carry the bar selection advertised by " .. entry.contextLabel)
        ns.QUI_ActionBarsOptions.SetSelectedBar(entry.providerKey == "bar2" and "bar1" or "bar2", "nav-precondition")
        GUI:NavigateSearchResult(entry)
        Flush()
        Check(ns.QUI_ActionBarsOptions.GetSelectedBar() == entry.providerKey,
            "section result must navigate to " .. entry.contextLabel .. " / " .. entry.sectionName)
        if entry.providerKey then sectionHits[entry.providerKey] = true end
    end
    for _, page in ipairs(tile.config.subPages) do
        local feature = ns.Settings.Registry:GetFeature(page.featureId)
        if feature and scopedFeatures[page.featureId] and feature.lookupKeys and #feature.lookupKeys == 1
            and entry.navType == "moduleToggle" and entry.featureId == feature.lookupKeys[1] then
            Check(entry.tileId == "action_bars" and entry.subPageIndex == feature.nav.subPageIndex,
                "dedicated bar toggle must retain its settings destination: " .. entry.featureId)
        end
    end
end
for _, option in ipairs(selectorOptions) do
    Check(sectionHits[option.value], "generated section links must cover " .. option.text)
end
local widgetHost = CreateFrame("Frame")
for id, entry in pairs(actual) do
    if entry.widgetDescriptor and entry.widgetDescriptor.dbPath then
        local widget = GUI:CreateSearchWidgetFromDescriptor(widgetHost, entry)
        Check(widget, "actual captured control must support inline editing: " .. id)
        if widget and entry.widgetDescriptor.dbKey == "showCooldownText" then
            local db = GUI:ResolveSearchDBTable(entry.widgetDescriptor.dbPath)
            local before, sibling = db.showCooldownText, db.showKeybinds
            widget.SetValue(not before, true)
            Check(db.showCooldownText == not before and db.showKeybinds == sibling,
                "inline checkbox must update only its bound cooldown value: " .. id)
            widget.SetValue(before, true)
        end
    end
end
table.sort(failures)
assert(#failures == 0, table.concat(failures, "\n"))
print(("OK: %d actual Action Bars controls across %d selectable variants and four dedicated pages match search in both directions")
    :format(matched, variants))
-- Search may be opened before any bar page has registered its inherited binding.
-- Read current global values without materializing them into per-bar overrides.
local inheritedFailures, inheritedCount = {}, 0
local function InheritedCheck(ok, message)
    if not ok then inheritedFailures[#inheritedFailures + 1] = message end
end
local inheritedValues = {
    showCooldownText = true, cooldownTextFontSize = 19, cooldownTextAnchor = "TOP",
    cooldownTextOffsetX = 3, cooldownTextOffsetY = -4, cooldownTextColor = {0.2, 0.3, 0.4, 0.5},
}
for key, value in pairs(inheritedValues) do profile.actionBars.global[key] = value end
for id, entry in pairs(actual) do
    local d = entry.widgetDescriptor
    if d and inheritedValues[d.dbKey] ~= nil and entry.featureId == "actionBarsPerBar" then
        local db = GUI:ResolveSearchDBTable(d.dbPath)
        db[d.dbKey] = nil
        GUI._formFallbacks = setmetatable({}, { __mode = "k" })
        local widget = GUI:CreateSearchWidgetFromDescriptor(widgetHost, entry)
        local want = inheritedValues[d.dbKey]
        local got = d.kind == "colorpicker" and {widget.GetColor()} or widget.GetValue()
        local same = type(want) == "table" and table.concat(got, ",") == table.concat(want, ",") or got == want
        InheritedCheck(same, id .. " must display the current inherited global value before mounting")
        if d.kind == "dropdown" then
            InheritedCheck(widget.selectedValue == want, id .. " dropdown must highlight its inherited selection")
        end
        InheritedCheck(db[d.dbKey] == nil, id .. " reading search must not create a local override")
        InheritedCheck(d.fallbackDbPath == "profile.actionBars.global", id .. " must preserve inherited binding metadata")
        if d.kind == "colorpicker" then
            widget.SetColor(0.8, 0.7, 0.6, 0.5)
            InheritedCheck(db[d.dbKey][1] == 0.8 and profile.actionBars.global[d.dbKey][1] == 0.2,
                id .. " color edits must not mutate the inherited table")
        else
            local override = 0
            if d.kind == "checkbox" then override = false
            elseif d.kind == "dropdown" then override = "CENTER"
            elseif d.dbKey == "cooldownTextFontSize" then override = 20 end
            widget.SetValue(override, true)
            InheritedCheck(db[d.dbKey] == override and profile.actionBars.global[d.dbKey] == want,
                id .. " edits must stay in the selected bar, including false and zero")
            InheritedCheck(widget.GetValue() == override, id .. " explicit values must win over inheritance")
            db[d.dbKey] = nil
            local nextValue = 17
            if d.kind == "checkbox" then nextValue = false
            elseif d.kind == "dropdown" then nextValue = "BOTTOM" end
            profile.actionBars.global[d.dbKey] = nextValue
            InheritedCheck(widget.GetValue() == nextValue, id .. " must read subsequent global changes")
            profile.actionBars.global[d.dbKey] = want
        end
        db[d.dbKey] = nil
        inheritedCount = inheritedCount + 1
    end
end
assert(inheritedCount == 60, "all six cooldown controls across ten skinnable variants must exercise inheritance")
table.sort(inheritedFailures)
assert(#inheritedFailures == 0, table.concat(inheritedFailures, "\n"))
print("OK: inherited cooldown values and isolated writes across " .. inheritedCount .. " cold search controls")
