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
assert(loadfile(os.getenv("QUI_NAVIGATION_CACHE") or "QUI_Options/search_cache.lua"))("QUI", ns)
local runWhenSettingsLayoutReady = GUI.RunWhenSettingsLayoutReady
function GUI:RunWhenSettingsLayoutReady(_, _, callback, isCurrent)
    C_Timer.After(0, function() if not isCurrent or isCurrent() then callback() end end)
end
for _, path in ipairs({
    "modules/qol/sound_mute_catalog.lua",
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
-- Load the real feature surfaces and schemas. Only WoW host services are stubbed.
local FullSurface = ns.Settings.FullSurface
local buildBody = FullSurface.BuildScrollTabBody
local createModel = FullSurface.CreateTabModel
local activeProvider, mounted, models, renders = nil, {}, {}, 0
FullSurface.CreateTabModel = function(state, options)
    local model = createModel(state, options)
    if activeProvider then models[activeProvider] = model end
    return model
end
FullSurface.BuildScrollTabBody = function(body, options)
    local render = options.render
    options.render = function(...)
        renders = renders + 1
        return render(...)
    end
    local result = buildBody(body, options)
    mounted[activeProvider] = { state = options.state, result = result }
    return result
end
local failures = {}
local function Check(value, message)
    if not value then failures[#failures + 1] = message end
end
local checked = 0
for _, spec in ipairs({
    { name = "GroupFrames", target = "appearance", other = "layout", setter = "SetContextMode",
        context = "party", alternate = "raid", entry = { providerKey = "partyFrames" } },
    { name = "UnitFrames", target = "frame", other = "text", setter = "SetSelectedUnit",
        context = "player", alternate = "target", entry = { surfaceUnitKey = "player" } },
    { name = "Nameplates", target = "frame", other = "text", setter = "SetSelectedType",
        context = "enemyNPC", alternate = "bossElite", entry = { surfaceTypeKey = "enemyNPC" } },
}) do
    activeProvider = spec.name
    local surface = assert(ns["QUI_" .. spec.name .. "SettingsSurface"])
    local function Message(text) return spec.name .. ": " .. text end
    surface[spec.setter](spec.context)
    local before = renders
    Check(surface.SetActiveTab(spec.target), Message("cold public selection must accept a valid tab"))
    Check(renders == before, Message("cold selection must not construct settings"))
    local model = assert(models[spec.name])
    local targetDefinition = model:GetDefinition(spec.target)
    local otherDefinition = model:GetDefinition(spec.other)
    otherDefinition.disabled = true
    Check(surface.SetActiveTab(spec.other) == false and model:GetActiveKey() == spec.target,
        Message("cold public selection must reject disabled destinations"))
    otherDefinition.disabled = nil
    surface.SetActiveTab(spec.target)
    Check(surface.SetActiveTab("missing") == false and model:GetActiveKey() == spec.target,
        Message("cold public selection must reject unknown destinations"))
    surface.SetActiveTab(spec.target)
    ns["QUI_" .. spec.name .. "Tile"].Register(frame)
    local tile = frame._tiles[#frame._tiles]
    GUI:SelectFeatureTile(frame, tile.index)
    Flush()
    local nav = assert(tile._surfacePagesByPage[1])
    local mountedState = assert(mounted[spec.name]).state
    local function Snapshot(key)
        local owner = assert(nav.getPage(key))
        local section = owner._contentBody._sections[1]
        assert(section and section.frame, Message("actual schema must mount section frames"))
        return owner, section.frame
    end
    local firstOwner, firstHeading = Snapshot(spec.target)
    Check(nav.getActiveTab() == spec.target, Message("mount must retain cold destination"))
    Check(nav.selectTab(spec.other), Message("sidebar must select a new destination"))
    Flush()
    before = renders
    Check(nav.selectTab(spec.target), Message("sidebar must revisit the first destination"))
    Flush()
    local owner, heading = Snapshot(spec.target)
    Check(renders == before and owner == firstOwner and heading == firstHeading,
        Message("sidebar revisit must preserve the cached actual controls"))
    local function PreserveSelection(callback, key, label)
        local expectedOwner, expectedHeading = Snapshot(key)
        local count = renders
        Check(callback(), Message(label .. " must accept the destination"))
        Flush()
        local nextOwner, nextHeading = Snapshot(key)
        Check(nav.getActiveTab() == key and renders == count
            and nextOwner == expectedOwner and nextHeading == expectedHeading,
            Message(label .. " must preserve cached controls (+" .. (renders - count) .. " renders)"))
    end
    PreserveSelection(function() return surface.SetActiveTab(spec.other) end, spec.other, "public revisit")
    PreserveSelection(function() return surface.SetActiveTab(spec.other) end, spec.other, "same-current public selection")
    spec.entry.surfaceTabKey = spec.target
    PreserveSelection(function() return surface.NavigateSearchEntry(spec.entry) end, spec.target, "search revisit")
    PreserveSelection(function() return surface.NavigateSearchEntry(spec.entry) end, spec.target, "same-current search selection")
    targetDefinition.disabled = true
    surface.SetActiveTab(spec.other)
    before = renders
    Check(surface.SetActiveTab(spec.target) == false and nav.getActiveTab() == spec.other
        and nav.selectTab(spec.target) == false and renders == before,
        Message("mounted public and sidebar selection must share disabled validation"))
    targetDefinition.disabled = nil
    targetDefinition.visible = false
    Check(surface.SetActiveTab(spec.target) == false and nav.selectTab(spec.target) == false,
        Message("mounted selection must recheck current visibility"))
    targetDefinition.visible = nil
    surface.SetActiveTab(spec.target)
    Flush()
    firstOwner, firstHeading = Snapshot(spec.target)
    surface[spec.setter](spec.alternate)
    Flush()
    local alternateOwner = Snapshot(spec.target)
    Check(alternateOwner ~= firstOwner, Message("contexts must have distinct cached owners"))
    before = renders
    surface[spec.setter](spec.context)
    Flush()
    owner, heading = Snapshot(spec.target)
    Check(renders == before and owner == firstOwner and heading == firstHeading,
        Message("returning to a context must preserve its controls"))
    before = renders
    mountedState.invalidateTabBodies(spec.target)
    mountedState.repaintTabs(false)
    Flush()
    owner, heading = Snapshot(spec.target)
    Check(renders == before + 1 and owner == firstOwner and heading ~= firstHeading,
        Message("explicit structural invalidation must rebuild current controls exactly once"))
    checked = checked + 1
end
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: selection lifecycle preserves actual controls across " .. checked .. " providers")
