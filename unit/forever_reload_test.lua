local inCombat = false
local calls = { settings = 0, reload = 0 }
local popup
local core = {}
local ns = {
    Client = { isForever = true },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}
_G.QUI = {
    NewModule = function() return core end,
    db = { profile = { general = {} } },
    GUI = { ShowConfirmation = function(_, options) popup = options end },
}
_G.LibStub = function() end
_G.InCombatLockdown = function() return inCombat end
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback) self.onEvent = callback end,
    }
end
_G.UIReload = function() calls.settings = calls.settings + 1 end
_G.ReloadUI = function() calls.reload = calls.reload + 1 end
assert(loadfile("core/main.lua"))("QUI", ns)

QUI:SafeReload()
assert(calls.settings == 1 and calls.reload == 0,
    "Forever reload must use the working settings API instead of blocked Reload()")

inCombat = true
QUI:SafeReload()
local eventFrame = core.__reloadEventFrame
QUI:SafeReload()
assert(core.__pendingReload and core.__reloadEventFrame == eventFrame)
assert(calls.settings == 1, "combat must queue reload without invoking either API")
inCombat = false
eventFrame.onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(popup and not core.__pendingReload and calls.settings == 1)
popup.onAccept()
assert(calls.settings == 2 and calls.reload == 0,
    "combat-ended confirmation must use the same Forever API")

inCombat = true
popup.onAccept()
assert(core.__pendingReload and calls.settings == 2,
    "confirmation must recheck combat when accepted")
QUI.db.profile.general.allowReloadInCombat = true
QUI:SafeReload()
assert(calls.settings == 3, "explicit combat reload preference must be honored")
inCombat = false

QUI.QUICore = nil
QUI:SafeReload()
assert(calls.settings == 4 and calls.reload == 0,
    "reload before the core is available must use the same Forever API")
QUI.QUICore = core

local button = { scripts = {}, over = true, enabled = true }
function button:GetScript(event) return self.scripts[event] end
function button:SetScript(event, callback) self.scripts[event] = callback end
function button:HookScript(event, callback) self.scripts[event] = callback end
function button:IsMouseOver() return self.over end
function button:IsEnabled() return self.enabled end
local actionCalls = 0
local mouseDownCalls, mouseUpCalls = 0, 0
local function action(self, mouseButton)
    assert(self == button and mouseButton == "LeftButton")
    actionCalls = actionCalls + 1
    QUI:SafeReload()
end
button:SetScript("OnClick", action)
button:SetScript("OnMouseDown", function() mouseDownCalls = mouseDownCalls + 1 end)
button:SetScript("OnMouseUp", function() mouseUpCalls = mouseUpCalls + 1 end)
assert(type(QUI.BindReloadButton) == "function",
    "Forever reload buttons need the live-verified mouse-release binding")
QUI:BindReloadButton(button)
assert(not button:GetScript("OnClick"), "do not dispatch twice from click and release")
local function dispatch(event, key)
    local callback = button:GetScript(event)
    if callback then callback(button, key) end
end
dispatch("OnMouseUp", "LeftButton")
assert(actionCalls == 0, "release without a press must not activate")
dispatch("OnMouseDown", "RightButton")
dispatch("OnMouseUp", "RightButton")
assert(actionCalls == 0, "right click must not activate")
dispatch("OnMouseDown", "LeftButton")
button.over = false
dispatch("OnMouseUp", "LeftButton")
assert(actionCalls == 0, "dragging away must cancel activation")
button.over = true
dispatch("OnMouseDown", "LeftButton")
button.enabled = false
dispatch("OnMouseUp", "LeftButton")
assert(actionCalls == 0, "disabled buttons must not activate")
button.enabled = true
dispatch("OnMouseDown", "LeftButton")
dispatch("OnHide")
dispatch("OnMouseUp", "LeftButton")
assert(actionCalls == 0, "hiding the button must cancel a pending press")
dispatch("OnMouseDown", "LeftButton")
dispatch("OnMouseUp", "LeftButton")
dispatch("OnClick", "LeftButton")
dispatch("OnMouseUp", "LeftButton")
assert(actionCalls == 1 and calls.settings == 5,
    "eligible mouse release must invoke the original action and reload exactly once")
assert(mouseDownCalls == 5 and mouseUpCalls == 7,
    "binding must preserve existing pressed-state visual handlers")

ns.Client.isForever = false
button:SetScript("OnMouseDown", nil)
button:SetScript("OnMouseUp", nil)
button:SetScript("OnClick", action)
QUI:BindReloadButton(button)
assert(button:GetScript("OnClick") == action and not button:GetScript("OnMouseUp"),
    "Retail button clicks must remain unchanged")
QUI:SafeReload()
assert(calls.settings == 5 and calls.reload == 1, "Retail must keep its reload API")
ns.Client.isForever = true
_G.UIReload = nil
QUI:SafeReload()
assert(calls.reload == 2, "missing settings API must retain the existing fallback")

print("OK: Forever reload routing and combat queue")
