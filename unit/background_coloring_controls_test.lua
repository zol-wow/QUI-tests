local env = dofile("tools/_addon_env.lua")
local h = env.BuildHarness()
local ns, profile = h.ns, h.db.profile
local widgets, headings, registered, cards = {}, {}, {}, {}
local refreshes = { bags = 0, chat = 0, unit = 0, skin = 0 }
local GUI = {}
QUI.GUI = GUI
ns.QUI_Options = {
    GetDB = function() return profile end,
    BuildSettingRow = function(_, label, widget) widget.label = label; return widget end,
}
ns.QUI_SettingsLayoutShared = { MakeLayout = function()
    return {
        headerAt = function(label) headings[#headings + 1] = label end,
        sectionAt = function()
            local card = { frame = {}, title = headings[#headings], rows = {} }
            card.AddRow = function(...)
                local cells = { ... }
                card.rows[#card.rows + 1] = cells
                for _, widget in ipairs(cells) do widget.card = card end
            end
            cards[#cards + 1] = card
            return card
        end,
        closeSection = function(card) card.closed = true end,
        finish = function() end,
    }
end }
ns.Settings = {
    Registry = { RegisterFeature = function(_, feature) registered[feature.id] = feature end },
    Schema = { Feature = function(value) return value end, Section = function(value) return value end },
}
ns.Registry = { RefreshAll = function(_, group)
    assert(group == "skinning")
    refreshes.skin = refreshes.skin + 1
end }
function GUI:SetSearchContext(context) self.context = context end
local function Widget(key, db, callback)
    local widget = { key = key, db = db, callback = callback, enabled = true }
    function widget:SetEnabled(enabled) self.enabled = not not enabled end
    widget.UpdateVisual = function(value) widget.visual = value end
    function widget:Change(value)
        self.db[self.key] = value
        if self.callback then self.callback(value) end
    end
    widgets[#widgets + 1] = widget
    return widget
end
function GUI:CreateFormCheckbox(_, _, key, db, callback) return Widget(key, db, callback) end
function GUI:CreateFormColorPicker(_, _, key, db, callback, options)
    local widget = Widget(key, db, callback)
    widget.options = options
    return widget
end
function GUI:CreateFormSlider(_, _, _, _, _, key, db, callback) return Widget(key, db, callback) end
function GUI:CreateFormDropdown(_, _, _, key, db, callback) return Widget(key, db, callback) end
_G.QUI_RefreshBags = function() refreshes.bags = refreshes.bags + 1 end
_G.QUI_RefreshChat = function() refreshes.chat = refreshes.chat + 1 end
_G.QUI_RefreshUnitFrames = function() refreshes.unit = refreshes.unit + 1 end
local resourceRefreshes, layoutKeys = 0, {}
h.QUICore.UpdatePowerBar = function() resourceRefreshes = resourceRefreshes + 1 end
h.QUICore.UpdateSecondaryPowerBar = function() resourceRefreshes = resourceRefreshes + 1 end
_G.QUI_ForceLayoutContainer = function(key) layoutKeys[#layoutKeys + 1] = key end
profile.ncdm.containers.backgroundTest = { name = "Test Aura Bar", containerType = "auraBar", bgColor = { 0, 0, 0, 1 } }
profile.ncdm.containers.backgroundIcons = { name = "Test Icons", containerType = "aura" }
profile.ncdm.containers.trackedBar = { name = "Legacy Buff Bars", containerType = "auraBar", bgColor = { 0.2, 0.2, 0.2, 1 } }
local function Find(db, key)
    for _, widget in ipairs(widgets) do
        if widget.db == db and widget.key == key then return widget end
    end
    error("missing background control: " .. key)
end
local source = io.open("modules/skinning/settings/background_coloring_content.lua", "rb")
if source then
    source:close()
    assert(loadfile("modules/skinning/settings/background_coloring_content.lua"))("QUI", ns)
end
assert(registered.backgroundColoringPage, "Appearance must expose a Background Coloring page")
registered.backgroundColoringPage.sections[1].build({})
assert(#cards == 7, "background controls must share one card per category, not one card per feature")
for _, card in ipairs(cards) do assert(card.closed, "every category card must be finalized") end
assert(table.concat(headings, "|") == "Global Background|Skinning|Frames|Resource Bars|Trackers|HUD|CDM",
    "background navigation must group related features into seven broad sections")
assert(GUI.context.subPageIndex == 12, "background colors must have their own Appearance route")
local appearance = profile.bags.appearance
local bagOverride = Find(appearance, "bgOverride")
local bagColor = Find(appearance, "backgroundColor")
assert(bagColor.card == Find(profile.minimap.buttonDrawer, "bgColor").card,
    "Bags and the Minimap Button Drawer must share the HUD card")
assert(Find(profile.powerBar, "bgColor").card == Find(profile.secondaryPowerBar, "bgColor").card,
    "both resource bars must share the Resource Bars card")
assert(bagColor.label == "Bags Color" and Find(profile.minimap.buttonDrawer, "bgColor").label == "Minimap Button Drawer Color",
    "rows inside a shared card must identify their feature")
local power = Find(profile.powerBar, "bgColor").card
assert(#power.rows == 1 and #power.rows[1] == 2,
    "the resource card must pair its feature color controls like Border Coloring")
assert(not bagColor.enabled, "inherited bag background must disable its custom picker")
assert(type(bagColor.visual) == "table" and type(bagColor.visual[1]) == "number",
    "an inherited picker must display a color through the real plain-function UpdateVisual API")
bagOverride:Change(true)
assert(bagColor.enabled, "enabling the override must enable its custom picker")
assert(type(appearance.backgroundColor) == "table" and type(appearance.backgroundColor[1]) == "number",
    "enabling an override must seed the native picker with the inherited color")
local color = { 0.12, 0.23, 0.34, 0 }
bagColor:Change(color)
assert(appearance.backgroundColor == color, "central controls must write the local bag settings")
Find(appearance, "hideBackground"):Change(true)
assert(not bagColor.enabled, "hidden backgrounds must disable the custom picker")
assert(refreshes.bags == 3, "bag background changes must repaint existing windows")
local glass = profile.chat.glass
Find(glass, "bgAlpha"):Change(0.42)
assert(glass.bgAlpha == 0.42 and refreshes.chat == 1, "chat opacity must use its existing local field and refresh")
local player = profile.quiUnitFrames.player.castbar
local target = profile.quiUnitFrames.target.castbar
local oldTarget = target.bgColor
Find(player, "bgColor"):Change(color)
assert(player.bgColor == color and target.bgColor == oldTarget,
    "editing one castbar background must preserve other units' backgrounds")
assert(refreshes.unit == 1, "unit background changes must refresh unit frames")
assert(Find(profile.general.actionTracker, "backdropColor"), "Action Tracker must use its general subtree")
Find(profile.powerBar, "bgColor"):Change(color)
assert(resourceRefreshes == 2, "resource backgrounds must update bars, not only repaint borders")
Find(profile.ncdm.containers.backgroundTest, "bgColor"):Change(color)
assert(#layoutKeys == 1 and layoutKeys[1] == "backgroundTest", "custom aura bar edits must refresh their own container")
for _, widget in ipairs(widgets) do
    assert(widget.db ~= profile.ncdm.containers.backgroundIcons, "icon containers must not expose unsupported background controls")
    assert(widget.db ~= profile.ncdm.containers.trackedBar, "legacy built-in aliases must not expose controls for an unused settings table")
end
assert(Find(profile.ncdm.trackedBar, "bgColor"), "built-in buff bars must bind the canonical runtime settings")
local meter = profile.damageMeter.native.appearance.global
assert(not Find(meter.colors, "bg").options.noAlpha,
    "damage meter edits must preserve RGBA alpha used as the persisted opacity fallback")
Find(profile.general, "skinBgColor"):Change(color)
assert(profile.general.skinBgColor == color and refreshes.skin == 1,
    "global background must share Theme & Colors storage and refresh skinned surfaces")
appearance.backgroundColor = { 0.9, 0.8, 0.7, 0.6 }
widgets = {}
registered.backgroundColoringPage.sections[1].build({})
assert(Find(appearance, "backgroundColor").db.backgroundColor[1] == 0.9,
    "reopening the page must reflect changes made through feature settings")
print("OK: background_coloring_controls_test")
