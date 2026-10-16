local function noop() end
local settings, editMode, combat, enter, exit = { hideMinimapBorder = true }, false, false
local callbacks = {}
local core = {
    RegisterEditModeEnter = function(_, callback) enter = callback end,
    RegisterEditModeExit = function(_, callback) exit = callback end,
}
local env = setmetatable({
    QUI = {},
    InCombatLockdown = function() return combat end,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end,
    C_Timer = { After = function(_, callback) callbacks[#callbacks + 1] = callback end },
    TextureKitConstants = { UseAtlasSize = true },
    MinimapZoneTextButtonMixin = { OnLoad = noop },
}, { __index = _G })
env._G = env
env.hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local ns = { Helpers = {
    CreateStateTable = function() return {} end,
    GetModuleSettings = function() return settings end,
    IsEditModeShown = function() return editMode end,
    GetCore = function() return core end,
    GetProfile = function() return {} end,
} }
local function texture()
    return {
        alpha = 1, shown = true,
        GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        SetAtlas = noop,
        SetShown = function(self, shown) self.shown = shown end,
    }
end
setfenv(assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_Minimap/Camelot/MinimapZoneTextButton.lua")), env)()
local zone = {
    StateTexture = texture(), AddTexture = texture(),
    mouseoverAddAlpha = .1, mousedownAddAlpha = .2,
    IsDownOver = function(self) return self.down and self.over end,
    IsDown = function(self) return self.down end,
    IsOver = function(self) return self.over end,
    text = "Stormwind", shown = true, click = function() return "world map" end,
}
zone.OnButtonStateChanged = env.MinimapZoneTextButtonMixin.OnButtonStateChanged
zone:OnButtonStateChanged()
env.MinimapCluster = { ZoneTextButton = zone }
local click = zone.click
setfenv(assert(loadfile(arg[1] or "modules/ui/uihider.lua")), env)("QUI", ns)
for _, callback in ipairs(callbacks) do callback() end
assert(enter and exit)
env.QUI.UIHider.ApplySettings()
assert(zone.StateTexture.alpha == 0 and zone.AddTexture.alpha == 0,
    "Hide Border (Top) must suppress the new native header art")
zone.over = true
zone:OnButtonStateChanged()
assert(zone.AddTexture.shown and zone.AddTexture.alpha == 0,
    "native hover must keep its shown state without resurrecting hidden header artwork")
assert(zone.shown and zone.text == "Stormwind" and zone.click == click and zone:click() == "world map",
    "hiding header artwork must retain zone text and map clicks")
zone.down = true
zone:OnButtonStateChanged()
assert(zone.AddTexture.alpha == 0)
settings.hideMinimapBorder = false
env.QUI.UIHider.ApplySettings()
assert(zone.StateTexture.alpha == 1 and zone.AddTexture.alpha == .2,
    "disabling border hiding must restore the latest native pressed alpha")
zone.over, zone.down = false, false
zone:OnButtonStateChanged()
assert(not zone.AddTexture.shown and zone.AddTexture.alpha == 0,
    "restoring the border must retain native idle visibility")
settings.hideMinimapBorder = true
env.QUI.UIHider.ApplySettings()
zone.over = true
zone:OnButtonStateChanged()
editMode = true
enter()
assert(zone.StateTexture.alpha == 1 and zone.AddTexture.alpha == .1,
    "Edit Mode must restore native header art without inventing a hover state")
zone.down = true
zone:OnButtonStateChanged()
assert(zone.AddTexture.alpha == .2, "native header states must remain live inside Edit Mode")
editMode = false
exit()
assert(zone.StateTexture.alpha == 0 and zone.AddTexture.alpha == 0)
combat = true
settings.hideMinimapBorder = false
env.QUI.UIHider.ApplySettings()
assert(zone.StateTexture.alpha == 0, "combat must defer border visibility changes")
combat = false
env.QUI.UIHider.ApplySettings()
assert(zone.StateTexture.alpha == 1 and zone.AddTexture.alpha == .2)

local border = { shown = true, Hide = function(self) self.shown = false end,
    Show = function(self) self.shown = true end }
env.MinimapCluster = { BorderTop = border }
settings.hideMinimapBorder = true
env.QUI.UIHider.ApplySettings()
assert(not border.shown, "older client header border must keep its existing hide path")
editMode = true
enter()
assert(border.shown, "older client header border must remain available in Edit Mode")
editMode = false
exit()
assert(not border.shown)
settings.hideMinimapBorder = false
env.QUI.UIHider.ApplySettings()
assert(border.shown, "older client header border must restore when disabled")
print("OK: native minimap header artwork hides while native states, text and clicks survive")
