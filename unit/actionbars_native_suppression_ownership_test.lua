local function loadFunction(path, signature, env)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function " .. signature .. "(", 1, true))
    local last = assert(source:find("\nend", first, true))
    local chunk = assert(loadstring(source:sub(first, last + 3), "@" .. path))
    setfenv(chunk, env)
    chunk()
end

local function noop() end
local nativeUpdates, attributeWrites, visibilityWrites = 0, 0, 0
local Frame = {}
Frame.__index = Frame
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetParent() return self.parent end
function Frame:Hide() self.shown = false; visibilityWrites = visibilityWrites + 1 end
Frame.HideBase = Frame.Hide
function Frame:Show() self.shown = true end
function Frame:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:GetAttribute(name) return self.attributes[name] end
function Frame:SetAttribute(name, value)
    self.attributes[name] = value
    attributeWrites = attributeWrites + 1
    if self.OnAttributeChanged then self:OnAttributeChanged(name, value) end
end
function Frame:SetShown(shown) self.shown = shown; visibilityWrites = visibilityWrites + 1 end
function Frame:GetID() return self.index end
function Frame:GetShowGrid() return true end
function Frame:HasAction() return true end
function Frame:Update() nativeUpdates = nativeUpdates + 1 end
Frame.UpdateFlyout = noop
Frame.UnregisterActionBarButtonCheckFrames = noop
Frame.RegisterActionBarButtonCheckFrames = noop
Frame.UpdateAssistedCombatRotationFrame = noop
Frame.UpdatePingAttributes = noop

local function newFrame(parent)
    return setmetatable({ parent = parent, shown = true, attributes = {}, events = { TEST = true } }, Frame)
end

local env = setmetatable({
    _G = {},
    hiddenBarParent = newFrame(),
    UIParent = newFrame(),
    PurgeShownExternalTaint = noop,
    ActionBarActionButtonMixin = {},
    BaseActionButtonMixin = {},
    SecureActionButtonMixin = {},
    ActionBarMixin = {},
    NUM_ACTIONBAR_BUTTONS = 12,
    C_ActionBar = { GetActionBarPage = function() return 1 end, RegisterActionUIButton = noop },
    EventRegistry = { TriggerEvent = noop },
    SecureButton_GetEffectiveButton = function() return "LeftButton" end,
    SecureButton_GetModifiedAttribute = function(button, name)
        return button:GetAttribute(name) or button:GetParent():GetAttribute(name)
    end,
}, { __index = _G })
env.hiddenBarParent.shown = false
table.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local nativeRoot = "tests/framexml/Interface/AddOns/"
local nativeButton = nativeRoot .. "Blizzard_ActionBar/Shared/ActionButton.lua"
loadFunction(nativeButton, "BaseActionButtonMixin:BaseActionButtonMixin_OnAttributeChanged", env)
loadFunction(nativeButton, "ActionBarActionButtonMixin:OnAttributeChanged", env)
loadFunction(nativeButton, "ActionBarActionButtonMixin:UpdateAction", env)
loadFunction(nativeRoot .. "Blizzard_FrameXML/SecureTemplates.lua", "SecureActionButtonMixin:CalculateAction", env)
loadFunction(nativeRoot .. "Blizzard_ActionBar/Shared/ActionBar.lua", "ActionBarMixin:UpdateShownButtons", env)
Frame.OnAttributeChanged = env.ActionBarActionButtonMixin.OnAttributeChanged
Frame.UpdateAction = env.ActionBarActionButtonMixin.UpdateAction
Frame.CalculateAction = env.SecureActionButtonMixin.CalculateAction
Frame.UpdateShownButtons = env.ActionBarMixin.UpdateShownButtons

local sourceRoot = "QUI_ActionBars/actionbars/"
loadFunction(arg[1] or sourceRoot .. "actionbars.lua", "HideManagedBlizzardBarFrame", env)
loadFunction(arg[1] or sourceRoot .. "actionbars.lua", "SuppressBlizzardButton", env)
loadFunction(arg[2] or sourceRoot .. "actionbars_builder.lua", "SuppressOriginalStandardBar", env)

for barIndex = 1, 8 do
    local bar = newFrame(env.UIParent)
    bar.attributes.actionpage = 7
    bar.actionButtons = {}
    bar.shownButtonContainers = {}
    bar.numButtonsShowable = 12
    for i = 1, 12 do
        local button = newFrame(bar)
        button.index, button.bar = i, bar
        button.container = newFrame(bar)
        button.action = button:CalculateAction()
        bar.actionButtons[i] = button
    end
    env.GetOriginalBlizzButtons = function() return bar.actionButtons end
    env.SuppressOriginalStandardBar(bar, "bar" .. barIndex)
    assert(attributeWrites == 0, "suppression must not write native attributes or enter their handlers")
    assert(nativeUpdates == 0, "suppression must not enter native action updates")
    assert(visibilityWrites == 0, "hidden ancestry must suppress bars without native shown-state writes")
    assert(not bar:IsVisible(), "native bar must be invisible")
    for _, button in ipairs(bar.actionButtons) do
        assert(button:GetParent() == bar, "native buttons must retain their action-page parent")
        assert(button:CalculateAction() == button.action, "native action-page resolution must survive suppression")
        assert(not button:IsVisible(), "native buttons must remain invisible")
        assert(next(button.events) == nil, "direct native button events must remain suppressed")
    end
    bar:Show()
    bar:UpdateShownButtons()
    assert(not bar:IsVisible(), "native Show must not escape hidden ancestry")
    for _, button in ipairs(bar.actionButtons) do
        assert(not button:IsVisible(), "native shown-button refresh must remain invisible")
    end
    visibilityWrites = 0
end

print("OK: actionbars_native_suppression_ownership_test")
