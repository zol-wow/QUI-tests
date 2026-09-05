-- tests/unit/qol_notifications_pin_route_test.lua
-- Death alert settings moved from Automation (QoL subtab 3) to Notifications
-- (QoL subtab 15). Guards two things: the Notifications page owns every
-- death-alert binding with its refresh callback, and a pin stored while the
-- settings still lived under Automation resolves to Notifications via the
-- feature's legacy "deathAlert" lookup key instead of its stale nav metadata.
-- Run: lua tests/unit/qol_notifications_pin_route_test.lua

local function NewFrame()
    return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWordWrap = function() end,
        SetHeight = function(self, height) self.height = height end,
        GetHeight = function(self) return self.height end,
    }
end

_G.CreateFrame = NewFrame
local general = {}
local rows, headers = {}, {}
local gui = { Colors = { textMuted = {} } }
function gui:CreateLabel() return NewFrame() end
function gui:CreateFormCheckbox(_, _, key, db, callback)
    return { key = key, db = db, callback = callback }
end
function gui:CreateFormDropdown(parent, label, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
function gui:CreateFormSlider(parent, label, _, _, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
_G.QUI = { GUI = gui }

local ns = { QUI_Options = {
    GetDB = function() return { general = general } end,
    GetSoundList = function() return {} end,
    CreateAccentDotLabel = function(_, text)
        headers[#headers + 1] = text
        return NewFrame()
    end,
    BuildSettingRow = function(_, label, widget)
        return { label = label, widget = widget }
    end,
    CreateSettingsCardGroup = function()
        local frame = NewFrame()
        return {
            frame = frame,
            AddRow = function(left, right) rows[#rows + 1] = { left, right } end,
            Finalize = function() frame:SetHeight(#rows * 32) end,
        }
    end,
} }
local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DeepCopy(v) end
    return copy
end
ns.Helpers = { DeepCopy = DeepCopy }
local refreshed = 0
ns.RefreshDeathAlert = function() refreshed = refreshed + 1 end

(dofile("tests/helpers/locale.lua"))(ns)
for _, file in ipairs({
    "core/settings/util.lua", "core/settings/schema.lua", "core/settings/registry.lua", "core/settings/nav.lua",
    "core/settings/pins.lua", "core/settings_layout_shared.lua",
    "modules/qol/settings/qol_content.lua",
}) do
    assert(loadfile(file))("QUI", ns)
end

-- 1. The Notifications page owns every death-alert binding.
assert(ns.QUI_QoLOptions.BuildGeneralTab(NewFrame(), nil, "notifications") > 0)
assert(#headers == 1 and headers[1] == "Group Death Alerts", "must build only the death alert page")
local expected = { enabled = true, sound = true, showKillingBlow = true, showKiller = true,
    classColorName = true, instanceOnly = true, duration = true }
local seen = 0
for _, cells in ipairs(rows) do
    for _, cell in ipairs(cells) do
        local widget = cell and cell.widget
        if widget then
            assert(widget.db == general.deathAlert, "binding must target general.deathAlert")
            assert(expected[widget.key], "unexpected or duplicate binding: " .. tostring(widget.key))
            expected[widget.key] = nil
            seen = seen + 1
            if widget.callback then widget.callback() end
        end
    end
end
assert(seen == 7 and next(expected) == nil, "Notifications must own all seven death alert settings")
assert(refreshed == 6, "every death alert control except the sound dropdown refreshes the alert")

-- 2. Pins stored under the old Automation route resolve to Notifications.
local Registry, Nav, Pins = ns.Settings.Registry, ns.Settings.Nav, ns.Settings.Pins
local feature = Registry:GetFeatureByLookupKey("deathAlert")
assert(feature and feature.id == "notifications", "deathAlert lookup key must map to the notifications feature")
local route = Nav:GetLookupTarget("deathAlert")
assert(route and route.tileId == "qol" and route.subPageIndex == 15, "lookup route must point at the QoL Notifications subpage")

local stalePin = {
    kind = "checkbox", label = "Group Death Alert", value = true, pinnedAt = 1,
    tabIndex = 17, tabName = "Quality of Life", subTabIndex = 3, subTabName = "Automation",
    tileId = "qol", subPageIndex = 3, featureId = "automation",
}
local db = {
    profile = { general = general },
    global = { pinnedSettings = { entries = { ["general.deathAlert.enabled"] = stalePin } } },
}
local nav = Pins:GetNavigationEntry("general.deathAlert.enabled", db)
assert(nav, "stale pin must still navigate")
assert(nav.tileId == "qol" and nav.subPageIndex == 15, "stale Automation pin must open the Notifications subpage, got subPageIndex " .. tostring(nav.subPageIndex))
assert(nav.featureId == "notifications", "stale pin must scroll to the notifications feature")
local listed = Pins:List(db)
assert(#listed == 1 and listed[1].subPageIndex == 15 and listed[1].featureId == "notifications",
    "pin list must show the Notifications route for the stale pin")

-- 3. Unrelated general.* pins keep their stored route (no accidental capture).
db.global.pinnedSettings.entries["general.sellJunk"] = {
    kind = "checkbox", label = "Sell Junk", value = true, pinnedAt = 2,
    tabIndex = 17, subTabIndex = 3, tileId = "qol", subPageIndex = 3, featureId = "automation",
}
local other = Pins:GetNavigationEntry("general.sellJunk", db)
assert(other and other.subPageIndex == 3 and other.featureId == "automation", "unrelated pins must keep their Automation route")
print("qol_notifications_pin_route_test: ok")
