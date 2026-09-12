local function Noop() end
local Frame = {}
Frame.__index = Frame
local function NewFrame(parent)
    return setmetatable({ parent = parent, scripts = {} }, Frame)
end
for _, method in ipairs({
    "ClearAllPoints", "SetPoint", "SetSize", "SetWidth", "SetHitRectInsets",
    "SetAllPoints", "SetTexture", "SetVertexColor", "SetColorTexture", "SetFrameLevel", "HookScript",
}) do
    Frame[method] = Noop
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:CreateTexture() return NewFrame(self) end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(shown) self.shown = shown end
function Frame:SetAlpha(alpha) self.alpha = alpha end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = DeepCopy(child) end
    return result
end

_G.CreateFrame = function(_, _, parent) return NewFrame(parent) end
local db = {
    profile = { general = { enabled = true, opacity = 0.7, theme = "dark", color = { 1, 0.5, 0, 1 } } },
    global = {},
    GetCurrentProfile = function() return "Current" end,
}
_G.QUI = { db = db }
local ns = {
    Helpers = { DeepCopy = DeepCopy, AssetPath = "assets/" },
    SafeCall = function(_, callback, ...) return true, callback(...) end,
    SafeCallMethod = function(_, object, method, ...) return true, object[method](object, ...) end,
}
(dofile("tests/helpers/locale.lua"))(ns)
for _, file in ipairs({ "core/registry.lua", "core/settings/pins.lua", "core/settings/pins_ui.lua" }) do
    assert(loadfile(file))("QUI", ns)
end

local refreshes = 0
ns.Registry:Register("unrelated", { refresh = function() refreshes = refreshes + 1 end })
local pins = ns.Settings.Pins
local notifications = 0
pins:Subscribe("*", function() notifications = notifications + 1 end)
local widgets = {}
for _, setting in ipairs({
    { "enabled", "checkbox" }, { "opacity", "slider" }, { "theme", "dropdown" }, { "color", "color" },
}) do
    local key, kind = setting[1], setting[2]
    local path = "general." .. key
    local widget = NewFrame(NewFrame())
    assert(pins:BindWidget(widget, { path = path, kind = kind, dbTable = db.profile.general, dbKey = key }))
    assert(pins:AttachWidgetChrome(widget, widget, widget))
    assert(not widget._quiPinAccent.shown, "unpinned settings must start without the pin accent")
    local button = widget._quiPinButton
    button.scripts.OnClick(button)
    local entry = assert(pins:GetEntry(path), "click must persist the pin")
    if kind == "color" then
        assert(entry.value ~= db.profile.general[key] and entry.value[2] == 0.5,
            "color pin must copy the current value")
    else
        assert(entry.value == db.profile.general[key], "pin must capture the current setting")
        assert(entry.shadowed.Current == db.profile.general[key], "pin must retain the original profile value")
    end
    assert(widget._quiPinAccent.shown and button.alpha == 1, "pin indicator must update immediately")
    widgets[key] = widget
end
assert(pins:GetCount() == 4 and notifications == 4, "pin subscribers and count must update for every click")
assert(refreshes == 0, "pinning current values must not refresh unrelated addon modules")

db.profile.general.enabled = false
pins:PrepareActiveProfileForApply(db)
assert(pins:ApplyAllForDB(db))
assert(db.profile.general.enabled == true, "saved pins must still override a changed profile value")
db.profile.general.enabled = false
assert(pins:UpdatePinnedValue("general.enabled", false))
local button = widgets.enabled._quiPinButton
button.scripts.OnClick(button)
assert(not pins:GetEntry("general.enabled"), "second click must remove the pin")
assert(db.profile.general.enabled == true, "unpin must restore the original profile value")
assert(refreshes == 1, "unpin must still refresh modules to apply restored settings")
assert(not widgets.enabled._quiPinAccent.shown, "unpin must clear the indicator")
assert(pins:UnpinAll() == 3 and refreshes == 1, "clearing unchanged values must not refresh modules")

for key, widget in pairs(widgets) do
    local pinButton = widget._quiPinButton
    pinButton.scripts.OnClick(pinButton)
    pinButton.scripts.OnClick(pinButton)
    assert(not pins:GetEntry("general." .. key), "unchanged pin must still be removed")
    assert(not widget._quiPinAccent.shown, "unchanged unpin must clear its indicator")
    assert(refreshes == 1, "unchanged " .. key .. " unpin must not refresh modules")
end

db.sv = { profiles = { Other = { general = { enabled = false } } } }
assert(pins:Pin("general.enabled", { kind = "checkbox", value = true }))
pins:GetEntry("general.enabled").shadowed.Other = true
assert(pins:Unpin("general.enabled"))
assert(db.sv.profiles.Other.general.enabled == true, "inactive profiles must still have their shadows restored")
assert(refreshes == 1, "inactive profile restoration must not refresh the active runtime")

assert(pins:Pin("general.enabled", { kind = "checkbox", value = true }))
local entry = pins:GetEntry("general.enabled")
entry.shadowed.Current = nil
entry.shadowed.Other = false
assert(pins:Unpin("general.enabled"))
assert(db.sv.profiles.Other.general.enabled == false, "inactive-only shadows must still restore")
assert(refreshes == 1, "unpin without an active shadow must not refresh the runtime")

widgets.color._quiPinButton.scripts.OnClick(widgets.color._quiPinButton)
db.profile.general.color[2] = 0.9
assert(pins:Unpin("general.color"))
assert(db.profile.general.color[2] == 0.5 and refreshes == 2,
    "changed colors must restore their components and refresh")

for _, widget in pairs(widgets) do
    widget._quiPinButton.scripts.OnClick(widget._quiPinButton)
end
db.profile.general.opacity = 0.2
db.profile.general.theme = "light"
assert(pins:UnpinAll() == 4 and refreshes == 3, "clear all must batch changed values into one refresh")
assert(db.profile.general.opacity == 0.7 and db.profile.general.theme == "dark",
    "clear all must restore every changed active value")
assert(pins:UnpinAll() == 0 and refreshes == 3, "empty clear all must not refresh")

db.profile.general.enabled = false
assert(pins:Pin("general.enabled", { kind = "checkbox", value = false }))
assert(pins:Unpin("general.enabled") and refreshes == 3, "unchanged false must not be treated as a missing value")
assert(pins:Pin("general.enabled", { kind = "checkbox", value = false }))
db.profile.general.enabled = true
assert(pins:Unpin("general.enabled"))
assert(db.profile.general.enabled == false and refreshes == 4, "restoring false must still refresh")
print("settings_pin_click_refresh_test: ok")
