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
-- Observe real provider constructors and row labels; no capture overrides run.
assert(loadfile("modules/datatexts/datatexts.lua"))("QUI", ns)
assert(loadfile("modules/datatexts/providers_extra.lua"))("QUI", ns)
local cache = dofile("tests/helpers/search_cache.lua")()
local expected, widgets, currentFeature, section = {}, {}, nil, nil
local function FindPath(target, value, path)
    if target == value then return path end
    for key, child in pairs(value) do
        if type(child) == "table" then
            local found = FindPath(target, child, path .. "." .. tostring(key))
            if found then return found end
        end
    end
end
local function Identity(entry)
    local d = entry.widgetDescriptor or {}
    return table.concat({entry.featureId, entry.sectionName or "", entry.label,
        d.dbPath or "", tostring(d.dbKey or "")}, "|")
end
local depth = 0
for name, spec in pairs({
    CreateFormCheckbox = { "checkbox", 3, 4 }, CreateFormCheckboxInverted = { "checkbox_inverted", 3, 4 },
    CreateFormToggle = { "toggle", 3, 4 }, CreateFormToggleInverted = { "toggle_inverted", 3, 4 },
    CreateFormSlider = { "slider", 6, 7 }, CreateFormDropdown = { "dropdown", 4, 5 },
    CreateFormColorPicker = { "colorpicker", 3, 4 }, CreateFormEditBox = { "editbox", 3, 4 },
}) do
    local original = GUI[name]
    GUI[name] = function(self, ...)
        local args = {...}
        depth = depth + 1
        local widget = original(self, ...)
        depth = depth - 1
        if depth == 0 and currentFeature then
            local db, key = args[spec[3]], args[spec[2]]
            local path = db and FindPath(db, profile, "profile")
            local descriptor = path and { kind = spec[1], dbPath = path, dbKey = key } or nil
            if descriptor and spec[1] == "slider" then
                descriptor.min, descriptor.max, descriptor.step = args[3], args[4], args[5]
            elseif descriptor and spec[1] == "dropdown" then descriptor.options = args[3] end
            widgets[widget] = { widgetType = spec[1], widgetDescriptor = descriptor }
        end
        return widget
    end
end
local accent = ns.QUI_Options.CreateAccentDotLabel
ns.QUI_Options.CreateAccentDotLabel = function(parent, label, ...)
    if currentFeature then section = label end
    return accent(parent, label, ...)
end
local buildRow = ns.QUI_Options.BuildSettingRow
ns.QUI_Options.BuildSettingRow = function(parent, label, widget, ...)
    local observed = widgets[widget]
    if currentFeature and observed and type(label) == "string" and label ~= "" then
        local entry = { featureId = currentFeature.id, providerKey = currentFeature.providerKey,
            tileId = currentFeature.nav.tileId, subPageIndex = currentFeature.nav.subPageIndex,
            sectionName = section, label = label, widgetType = observed.widgetType,
            widgetDescriptor = observed.widgetDescriptor }
        expected[Identity(entry)] = entry
    end
    return buildRow(parent, label, widget, ...)
end
local function Render(id)
    currentFeature = assert(ns.Settings.Registry:GetFeature(id))
    section = nil
    local host = CreateFrame("Frame")
    host:SetSize(760, 1)
    ns.Settings.Renderer:RenderFeature(currentFeature, host, {
        surface = "tile", width = 760, tileLayout = true, includePosition = true,
        providerKey = currentFeature.providerKey,
    })
    Flush()
    currentFeature = nil
end
Render("minimap")
local slots = profile.datatext.slots
Render("datatextPanel")
local definitions = ns.Addon.Datatexts:GetAll()
for first = 1, #definitions, 3 do
    profile.datatext.slots = {}
    for index = first, math.min(first + 2, #definitions) do
        profile.datatext.slots[index - first + 1] = definitions[index].id
    end
    Render("datatextPanel")
end
profile.datatext.slots = slots
local function Options(options)
    local result = {}
    for _, option in ipairs(options or {}) do result[#result + 1] = tostring(option.value) .. ":" .. tostring(option.text) end
    return table.concat(result, "|")
end
local actual, failures, matched = {}, {}, 0
local function Check(value, message) if not value then failures[#failures + 1] = message end end
for _, entry in ipairs(cache.settings) do
    if entry.featureId == "minimap" or entry.featureId == "datatextPanel" then
        if entry.widgetType ~= "action_button" then
            local id = Identity(entry)
            Check(not actual[id], "generated row duplicated: " .. id)
            actual[id] = entry
        end
    end
end
for id, want in pairs(expected) do
    local got = actual[id]
    Check(got, "actual provider control missing: " .. id)
    if got then
        matched = matched + 1
        Check(got.providerKey == want.providerKey and got.tileId == want.tileId
            and got.subPageIndex == want.subPageIndex, "actual route differs: " .. id)
        Check(got.widgetType == want.widgetType, "actual control kind differs: " .. id)
        local wd, gd = want.widgetDescriptor, got.widgetDescriptor
        if wd then
            for _, field in ipairs({"kind", "min", "max", "step"}) do
                Check(gd and gd[field] == wd[field], "actual " .. field .. " differs: " .. id)
            end
            if wd.kind == "dropdown" then Check(Options(gd.options) == Options(wd.options), "actual dropdown options differ: " .. id) end
        else
            Check(not gd or not gd.dbPath, "callback-only control must not acquire a static binding: " .. id)
        end
    end
end
for id in pairs(actual) do Check(expected[id], "generated control absent from actual provider: " .. id) end
for _, key in ipairs({"profile.minimap.trackingConfig|anchor", "profile.minimap.mailConfig|scale",
    "profile.minimap.buttonDrawer|borderColorSource", "profile.datatext|specDisplayMode",
    "profile.datatext|use24Hour", "profile.datatext|altsMode"}) do
    local found
    for id in pairs(expected) do if id:find(key, 1, true) then found = true end end
    Check(found, "actual builders must exercise regression binding " .. key)
end
for _, entry in pairs(actual) do
    Check(entry.label ~= "Class Color Border" and entry.label ~= "Accent Color Border",
        "obsolete border toggle must not remain searchable: " .. entry.label)
end
table.sort(failures)
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: " .. matched .. " actual Minimap/Datatext controls match search in both directions")
