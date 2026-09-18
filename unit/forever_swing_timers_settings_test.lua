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
function QUI.GUI:CreateFormCheckbox(_, _, key, db, apply)
    controls[key] = { db = db, apply = apply }
    return {}
end
function QUI.GUI:CreateFormSlider(_, _, min, max, _, key, db, apply)
    controls[key] = { db = db, apply = apply, min = min, max = max }
    return {}
end
function QUI.GUI:CreateFormDropdown(_, _, choices, key, db, apply)
    controls[key] = { db = db, apply = apply, choices = choices }
    return {}
end

local positionKey, sizeOptions
ns.QUI_LayoutMode_Utils = {
    _layoutModePositionOnly = true,
    BuildPositionCollapsible = function(_, key) positionKey = key end,
    BuildSizeCollapsible = function(_, options)
        assert(not ns.QUI_LayoutMode_Utils._layoutModePositionOnly, "size controls must escape position-only filtering")
        sizeOptions = options
    end,
    BuildOpenFullSettingsLink = function() end,
}
load("modules/qol/settings/swing_timers_content.lua")

local registry = ns.Settings.Registry
local page = assert(registry:GetFeature("swingTimersPage"))
assert(page.nav.tileId == "gameplay" and page.nav.subPageIndex == 10)
page.sectionsById.settings.build(frame)
assert(controls.width.min == 80 and controls.width.max == 800)
assert(controls.height.min == 8 and controls.height.max == 80)
assert(controls.fontSize.min == 6 and controls.fontSize.max == 32)
assert(controls.showTitle and controls.showTime and controls.texture)
for index, choice in ipairs(controls.visibility.choices) do
    assert(choice.value == index - 1, "visibility values must match native Forever enum")
end
controls.enabled.apply(true)
assert(enabled, "enable control must call the shared native CVar adapter")

for _, entry in ipairs(ns.SwingTimers.entries) do
    local feature = assert(registry:GetFeatureByMoverKey(entry.key), "each mover must resolve through the real settings registry")
    assert(feature.getDB(profile) == profile.swingTimers[entry.key])
    local height = ns.Settings.Renderer:RenderFeature(feature, frame, { surface = "layout", providerKey = entry.key })
    assert(height == 240 and positionKey == entry.key)
    assert(ns.QUI_LayoutMode_Utils._layoutModePositionOnly, "drawer must restore inherited rendering state")
    assert(controls.showTitle.db == profile.swingTimers[entry.key], "appearance controls must edit the selected bar")
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
ns.Settings.Renderer:RenderFeature("swingTimerMainHand", frame, { surface = "layout" })
assert(controls.texture.db == profile.swingTimers.swingTimerMainHand, "reopened settings must read the active profile")
assert(sizeOptions.getSize() == 320, "size drawer must read the active profile")

local tile
ns.QUI_Options.RegisterFeatureTile = function(_, spec) tile = spec end
load("QUI_Options/tiles/gameplay.lua")
local swingTimers = ns.SwingTimers
for _, forever in ipairs({ false, true }) do
    ns.Client.isForever = forever
    ns.SwingTimers = forever and swingTimers or nil
    ns.QUI_GameplayTile.Register(frame)
    assert(#tile.subPages == (forever and 10 or 9), "append swing page only on Forever without reindexing existing pages")
end
assert(tile.subPages[10].featureId == page.id)

print("OK: Forever swing timer settings route all movers, resize native bars, follow profiles, and remain absent on Retail")
