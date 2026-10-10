local function noop() end
local widgets = {}
local function widget(name)
    local self = { scripts = {}, shown = true }
    function self:SetScript(event, callback) self.scripts[event] = callback end
    function self:GetScript(event) return self.scripts[event] end
    function self:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(frame, ...)
            if previous then previous(frame, ...) end
            callback(frame, ...)
        end
    end
    function self:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function self:Show() self.shown = true end
    function self:IsShown() return self.shown end
    function self:IsEnabled() return true end
    function self:IsMouseOver() return true end
    function self:GetStringHeight() return 14 end
    function self:CreateFontString() return widget() end
    setmetatable(self, { __index = function(_, key)
        if key:sub(1, 1) ~= "_" then return noop end
    end })
    if name then widgets[name] = self end
    return self
end

local ns = {
    Client = { isForever = true },
    Helpers = { ApplyFontWithFallback = noop },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}
local reloads, retailReloads, deletions = 0, 0, 0
_G.QUI = {
    NewModule = function() return {} end,
    db = { profile = { general = {} } },
}
_G.LibStub = noop
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function(_, name) return widget(name) end
_G.UIReload = function()
    assert(widgets.QUI_ConfirmDialog:IsShown(),
        "Forever must request reload while its mouse-release dialog is still visible")
    reloads = reloads + 1
end
_G.ReloadUI = function()
    assert(not widgets.QUI_ConfirmDialog:IsShown(), "Retail must keep hiding before acceptance")
    retailReloads = retailReloads + 1
end
assert(loadfile("core/main.lua"))("QUI", ns)

local file = assert(io.open("QUI_Options/framework.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local confirmDialog = nil", 1, true))
local last = assert(source:find("function GUI:CreateSectionHeader", first, true))
local GUI = {}
local colors = setmetatable({}, { __index = function() return { 1, 1, 1 } end })
local loadConfirmation = assert((loadstring or load)(
    "local GUI, ns, C, SetFont, GetFontPath = ...\n" .. source:sub(first, last - 1),
    "@QUI_Options/framework.lua:ShowConfirmation"))
loadConfirmation(GUI, ns, colors, noop, function() return "font" end)
QUI.GUI = GUI

local function dispatch(button, event)
    local callback = button:GetScript(event)
    if callback then callback(button, "LeftButton") end
end
local function click(button)
    dispatch(button, "OnMouseDown")
    dispatch(button, "OnMouseUp")
    dispatch(button, "OnClick")
end
local function showReload()
    GUI:ShowConfirmation({ reload = true, onAccept = function() QUI:SafeReload() end })
end

showReload()
local dialog = assert(widgets.QUI_ConfirmDialog)
local accept = dialog.acceptBtn
assert(accept:GetScript("OnMouseUp") and not accept:GetScript("OnClick"),
    "Forever reload confirmation must use the mouse-release binding")
click(accept)
assert(reloads == 1 and not dialog:IsShown(),
    "accepting the real confirmation must reload exactly once and close it")

showReload()
dispatch(accept, "OnMouseDown")
GUI:ShowConfirmation({ isDestructive = true, onAccept = function()
    assert(not dialog:IsShown(), "ordinary confirmations must keep hiding before acceptance")
    deletions = deletions + 1
end })
assert(widgets.QUI_ConfirmDialog.acceptBtn == accept, "exercise the reused accept widget")
dispatch(accept, "OnMouseUp")
assert(reloads == 1 and deletions == 0,
    "reused destructive confirmation must discard the previous reload release handler")
assert(not accept:GetScript("OnMouseDown") and not accept:GetScript("OnMouseUp"),
    "ordinary confirmations must remove both reload mouse handlers")
dispatch(accept, "OnClick")
assert(deletions == 1 and reloads == 1, "ordinary confirmation must invoke only its own action")

showReload()
click(accept)
assert(reloads == 2 and deletions == 1, "binding must work again after an ordinary dialog")
local replacementAccepted = false
GUI:ShowConfirmation({ reload = true, onAccept = function()
    GUI:ShowConfirmation({ onAccept = function() replacementAccepted = true end })
end })
dispatch(accept, "OnMouseDown")
dispatch(accept, "OnMouseUp")
assert(dialog:IsShown() and not replacementAccepted,
    "accepting a reload dialog must not hide a replacement confirmation opened by its callback")
dispatch(accept, "OnClick")
assert(replacementAccepted and not dialog:IsShown())
ns.Client.isForever = false
showReload()
assert(accept:GetScript("OnClick") and not accept:GetScript("OnMouseUp"),
    "Retail reload confirmations must retain normal click handling")
click(accept)
assert(retailReloads == 1 and reloads == 2 and deletions == 1)

print("OK: real reload confirmation dispatch and reused dialog cleanup")
