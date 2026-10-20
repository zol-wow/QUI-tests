local ns = {
    Client = { isForever = false },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}

local function load(path)
    assert(loadfile(path))("QUI", ns)
end

load("core/settings/util.lua")
load("core/settings/registry.lua")
load("core/settings/schema.lua")
load("core/settings/renderer.lua")
load("modules/qol/settings/swing_timers_content.lua")
assert(ns.Settings.Registry:GetFeature("swingTimersPage") == nil, "Retail must not register swing settings")

local controls, profile = {}, { swingTimers = {} }
local enabled, refreshes = false, 0
ns.Client.isForever = true
ns.SwingTimers = {
    entries = {},
    GetSettings = function(key) return profile.swingTimers[key] end,
    Refresh = function() refreshes = refreshes + 1 end,
    IsEnabled = function() return enabled end,
    SetEnabled = function(value) enabled = value end,
}
for _, suffix in ipairs({ "MainHand", "OffHand", "Ranged" }) do
    local key = "swingTimer" .. suffix
    ns.SwingTimers.entries[#ns.SwingTimers.entries + 1] = { key = key, label = suffix }
    profile.swingTimers[key] = { width = 250, height = 20 }
end

local frame = { height = 80 }
function frame:GetHeight() return self.height end
local layout = {
    sections = {},
    headerAt = function() end,
    closeSection = function() end,
    finish = function() return 80 end,
    relayoutSections = function() frame.height = 240 end,
    sectionAt = function() return { frame = frame, AddRow = function() end } end,
}
ns.QUI_SettingsLayoutShared = { MakeLayout = function() return layout end }
ns.QUI_Options = {
    BuildSettingRow = function(_, _, widget) return widget end,
    GetTextureList = function() return {} end,
}
QUI = { GUI = { SetSearchSection = function() end } }
local function CaptureControl(key, db, spec)
    spec.db = db
    controls[key] = spec
    controls[db] = controls[db] or {}
    controls[db][key] = spec
    return {}
end
function QUI.GUI:CreateFormCheckbox(_, _, key, db, apply)
    return CaptureControl(key, db, { apply = apply })
end
function QUI.GUI:CreateFormSlider(_, _, min, max, _, key, db, apply)
    return CaptureControl(key, db, { apply = apply, min = min, max = max })
end
function QUI.GUI:CreateFormDropdown(_, _, choices, key, db, apply)
    return CaptureControl(key, db, { apply = apply, choices = choices })
end

local positionKey, sizeOptions, fullSettingsKey
ns.QUI_LayoutMode_Utils = {
    _layoutModePositionOnly = true,
    BuildPositionCollapsible = function(_, key) positionKey = key end,
    BuildSizeCollapsible = function(_, options)
        assert(not ns.QUI_LayoutMode_Utils._layoutModePositionOnly, "size controls must escape position-only filtering")
        sizeOptions = options
    end,
    BuildOpenFullSettingsLink = function(_, key) fullSettingsKey = key end,
}
load("modules/qol/settings/swing_timers_content.lua")

local registry = ns.Settings.Registry
local page = assert(registry:GetFeature("swingTimersPage"))
assert(page.nav.tileId == "gameplay" and page.nav.subPageIndex == 9)
local function CheckPage()
    controls = {}
    page.sectionsById.settings.build(frame)
    for _, entry in ipairs(ns.SwingTimers.entries) do
        local db = profile.swingTimers[entry.key]
        local bar = assert(controls[db], "main settings must expose every bar in the active profile")
        assert(bar.width.min == 80 and bar.width.max == 800)
        assert(bar.height.min == 8 and bar.height.max == 80)
        assert(bar.fontSize.min == 6 and bar.fontSize.max == 32)
        assert(bar.showTitle and bar.showTime and bar.texture and bar.visibility)
        for index, choice in ipairs(bar.visibility.choices) do
            assert(choice.value == index - 1, "visibility values must match native Forever enum")
        end
        for _, key in ipairs({ "width", "height", "fontSize", "showTitle", "showTime", "texture", "visibility" }) do
            assert(bar[key].db == db, "main settings must edit the active profile's selected bar")
            local before = refreshes
            bar[key].apply()
            assert(refreshes == before + 1, "main settings changes must refresh native bars immediately")
        end
    end
    controls.enabled.apply(true)
    assert(enabled, "enable control must call the shared native CVar adapter")
end
CheckPage()

for _, entry in ipairs(ns.SwingTimers.entries) do
    local feature = assert(registry:GetFeatureByMoverKey(entry.key), "each mover must resolve through the real settings registry")
    assert(feature.nav.tileId == "gameplay" and feature.nav.subPageIndex == 9, "each mover must route to the Swing Timers page")
    assert(feature.nav.scrollToLabel == ns.L[entry.label], "each mover must jump to its own swing timer section")
    assert(feature.getDB(profile) == profile.swingTimers[entry.key])
    controls = {}
    positionKey, sizeOptions, fullSettingsKey = nil, nil, nil
    local height = ns.Settings.Renderer:RenderFeature(feature, frame, { surface = "layout", providerKey = entry.key })
    assert(height == 240 and positionKey == entry.key)
    assert(ns.QUI_LayoutMode_Utils._layoutModePositionOnly, "drawer must restore inherited rendering state")
    assert(next(controls) == nil, "mover drawers must keep feature controls in the main Swing Timers settings")
    assert(fullSettingsKey == entry.key, "each mover must link to its full Swing Timers settings")
    assert(sizeOptions.minW == 80 and sizeOptions.maxW == 800 and sizeOptions.minH == 8 and sizeOptions.maxH == 80)
    local before = refreshes
    sizeOptions.setSize(400, 30)
    assert(profile.swingTimers[entry.key].width == 400 and profile.swingTimers[entry.key].height == 30)
    assert(refreshes == before + 1, "resizing must refresh native bars immediately")
end

profile = { swingTimers = {
    swingTimerMainHand = { width = 320, height = 28 },
    swingTimerOffHand = { width = 220, height = 18 },
    swingTimerRanged = { width = 520, height = 38 },
} }
CheckPage()
controls = {}
ns.Settings.Renderer:RenderFeature("swingTimerMainHand", frame, { surface = "layout" })
assert(next(controls) == nil, "reopened mover must keep feature controls in the main settings")
assert(sizeOptions.getSize() == 320, "size drawer must read the active profile")

local tile
ns.QUI_Options.RegisterFeatureTile = function(_, spec) tile = spec end
load("QUI_Options/tiles/gameplay.lua")
local swingTimers = ns.SwingTimers
for _, forever in ipairs({ false, true }) do
    ns.Client.isForever = forever
    ns.SwingTimers = forever and swingTimers or nil
    ns.QUI_GameplayTile.Register(frame)
    assert(#tile.subPages == (forever and 9 or 8), "append swing page only on Forever without reindexing existing pages")
end
assert(tile.subPages[9].featureId == page.id)

print("OK: Forever swing timer movers expose only layout controls; main settings retain all bar controls and follow profiles")
