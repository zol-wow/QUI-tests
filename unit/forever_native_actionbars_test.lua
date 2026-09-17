local combat = false
local timers, styles, textStyles, original, states = {}, {}, {}, {}, {}
local protectedWrites, bindingWrites = 0, 0
local function noop() end
local function forbidden() error("native presentation must not execute snippets or replace secure actions") end
local world = setmetatable({}, { __index = _G })
world._G = world
world.setfenv = setfenv
local methods = {}
local function frame(name, parent, id)
    local value = setmetatable({
        name = name, parent = parent, id = id or 0, attributes = {}, scripts = {}, events = {},
        width = 45, height = 45, scale = 1, shown = true, points = {},
    }, { __index = methods })
    if name then world[name] = value end
    return value
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:GetID() return self.id end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetSize() return self.width, self.height end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index or 1] or {}) end
local fractions = { CENTER = { 0.5, 0.5 }, BOTTOMLEFT = { 0, 0 }, TOPLEFT = { 0, 1 }, BOTTOMRIGHT = { 1, 0 }, BOTTOM = { 0.5, 0 } }
function methods:GetCenter()
    if self == world.UIParent then return self.width / 2, self.height / 2 end
    local point = self.points[1]
    if not point then return self.width / 2, self.height / 2 end
    local target = point[2]
    local x, y = target:GetCenter()
    local sourceFrac, targetFrac = assert(fractions[point[1]]), assert(fractions[point[3]])
    return x + (targetFrac[1] - 0.5) * target.width + (point[4] or 0) - (sourceFrac[1] - 0.5) * self.width,
        y + (targetFrac[2] - 0.5) * target.height + (point[5] or 0) - (sourceFrac[2] - 0.5) * self.height
end
function methods:GetLeft() local x = self:GetCenter(); return x - self.width / 2 end
function methods:GetRight() local x = self:GetCenter(); return x + self.width / 2 end
function methods:GetTop() local _, y = self:GetCenter(); return y + self.height / 2 end
function methods:GetBottom() local _, y = self:GetCenter(); return y - self.height / 2 end
function methods:SetScale(value)
    assert(not combat, "QUI geometry must wait for combat to end")
    self.scale = value
end
function methods:SetSize(width, height)
    assert(not combat, "QUI size changes must wait for combat to end")
    self.width, self.height = width, height
end
function methods:ClearAllPoints()
    assert(not combat, "QUI anchors must wait for combat to end")
    self.anchorClears = (self.anchorClears or 0) + 1
    self.points = {}
end
function methods:SetPoint(...)
    assert(not combat, "QUI anchors must wait for combat to end")
    local point, target = ...
    local function dependsOnSelf(value, visited)
        if value == self then return true end
        if not value or visited[value] then return false end
        visited[value] = true
        for _, anchor in ipairs(value.points) do
            if dependsOnSelf(anchor[2], visited) then return true end
        end
        return false
    end
    assert(not dependsOnSelf(target, {}), "cannot anchor to a dependent region")
    for i = #self.points, 1, -1 do if self.points[i][1] == point then table.remove(self.points, i) end end
    self.points[#self.points + 1] = { ... }
end
function methods:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetAlpha(value) self.alpha = value end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback)
    local prior = self.scripts[name]
    self.scripts[name] = function(...) if prior then prior(...) end callback(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetAttribute(name, value)
    if self.isActionButton then
        assert(name == "statehidden", "QUI must preserve native secure action attributes")
        protectedWrites = protectedWrites + 1
    end
    self.attributes[name] = value
    if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, name, value) end
end
function methods:GetAttribute(prefix, name)
    return self.attributes[name or prefix]
end
methods.SetParent, methods.SetID, methods.Execute, methods.SetFrameRef, methods.RunAttribute = forbidden, forbidden, forbidden, forbidden, forbidden
world.UIParent = frame("UIParent")
world.UIParent.width, world.UIParent.height = 1920, 1080
world.CreateFrame = function(_, name, parent, template)
    assert(not template or not template:find("SecureHandler", 1, true), "must not create a snippet handler")
    return frame(name, parent)
end
world.InCombatLockdown = function() return combat end
world.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
world.C_PetBattles = { IsInBattle = function() return false end }
world.hooksecurefunc = function(target, key, callback)
    local prior = assert(target[key])
    target[key] = function(...) prior(...) callback(...) end
end
world.SecureHandlerExecute, world.SecureHandlerWrapScript = forbidden, forbidden
world.SetOverrideBindingClick = function() bindingWrites = bindingWrites + 1; forbidden() end
world.ClearOverrideBindings = forbidden
world.strmatch = string.match
world.table = setmetatable({ wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end end }, { __index = table })
world.tInvert = function(tbl) local result = {}; for _, value in ipairs(tbl) do result[value] = true end return result end
world.CopyTable = function(tbl) local result = {}; for key, value in pairs(tbl) do result[key] = value end return result end
world.GetFrameMetatable = function() return { __index = methods } end
world.IsShiftKeyDown, world.IsControlKeyDown, world.IsAltKeyDown = function() return false end, function() return false end, function() return false end
world.NUM_ACTIONBAR_BUTTONS, world.NUM_OVERRIDE_BUTTONS = 12, 6
world.C_ActionBar = { GetActionBarPage = function() return 1 end }
world.SecureCmdOptionParse = function(condition)
    assert(condition == "show" or condition == "hide", "count visibility uses native literal drivers")
    return condition
end
local function load(path, ns)
    local chunk = assert(loadfile(path))
    setfenv(chunk, world)
    chunk("QUI_ActionBars", ns)
end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
load(corpus .. "Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua")
load(corpus .. "Blizzard_FrameXML/SecureTemplates.lua")
load(corpus .. "Blizzard_ActionBar/Shared/ActionBar.lua")
local file = assert(io.open(corpus .. "Blizzard_ActionBar/Shared/ActionButton.lua", "r"))
local source = file:read("*a"); file:close()
local getActionButton = assert(loadstring(assert(source:match("(function GetActionButtonForID%b().-\nend)"))))
setfenv(getActionButton, world); getActionButton()

local registeredSettings, settingWrites = {}, 0
world.Settings = {}
world.SettingsPanel = { GetSetting = function(_, key) return registeredSettings[key] end }
local settingsFile = assert(io.open(corpus .. "Blizzard_Settings_Shared/Blizzard_Settings.lua", "r"))
local settingsSource = settingsFile:read("*a"); settingsFile:close()
for _, method in ipairs({ "GetSetting", "GetValue", "SetValue" }) do
    local body = assert(settingsSource:match("(function Settings%." .. method .. "%b().-\nend)"))
    local chunk = assert(loadstring(body))
    setfenv(chunk, world); chunk()
end

local bar = frame("MainActionBar", world.UIParent)
bar:SetPoint("BOTTOMLEFT", world.UIParent, "BOTTOMLEFT", 500, 100)
bar.actionButtons, bar.shownButtonContainers, bar.numButtonsShowable = {}, {}, 12
bar.attributes.actionpage = 1
bar.noSpacers = true
bar.UpdateGridLayout, bar.ApplySystemAnchor = noop, noop
bar.EndCaps, bar.BorderArt, bar.Background = frame(), frame(), frame()
bar.ActionBarPageNumber = frame(nil, bar)
bar.ActionBarPageNumber:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -4, 9)
bar.ActionBarPageNumber.Text = { SetText = function(self, text) self.text = text end }
bar.ActionBarPageNumber.UpButton = frame(nil, bar.ActionBarPageNumber)
bar.ActionBarPageNumber.DownButton = frame(nil, bar.ActionBarPageNumber)
bar.ActionBarPageNumber.UpButton:SetPoint("CENTER", bar.ActionBarPageNumber, "CENTER", 0, 10)
bar.ActionBarPageNumber.DownButton:SetPoint("CENTER", bar.ActionBarPageNumber, "CENTER", 0, -10)
load(corpus .. "Blizzard_ActionBar/Shared/MainActionBar.lua")
for i = 1, 12 do
    local container = frame(nil, bar)
    local button = frame("ActionButton" .. i, container, i)
    button.bar, button.container, button.index, button.isActionButton = bar, container, i, true
    button.attributes.type, button.attributes["useparent-actionpage"] = "action", true
    button.attributes.typerelease, button.attributes.pressAndHoldAction = "actionrelease", i == 2
    button.scripts.OnClick, button.scripts.OnDragStart, button.scripts.OnReceiveDrag = noop, noop, noop
    button.GetShowGrid, button.HasAction = function() return true end, function() return true end
    button.CalculateAction = world.SecureActionButtonMixin.CalculateAction
    button.UpdateHotkeys = noop
    bar.actionButtons[i] = button
    original[i] = { parent = container, attributes = world.CopyTable(button.attributes), scripts = world.CopyTable(button.scripts) }
end
world.ActionBarButtonEventsFrame = { frames = world.CopyTable(bar.actionButtons) }
world.ActionBarActionEventsFrame = { frames = { [bar.actionButtons[1]] = true } }
world.OverrideActionBar = frame("OverrideActionBar", world.UIParent)
world.OverrideActionBar:Hide()
world.OverrideActionBarButton1 = frame("OverrideActionBarButton1", world.OverrideActionBar, 1)
local settings = { enabled = true, iconSize = 36, buttonSpacing = 2, ownedLayout = { columns = 2, iconCount = 4 } }
local core = { db = { profile = {} } }
local ns = {
    Client = { restrictedExecutionUnavailable = true },
    Helpers = {
        GetCore = function() return core end,
        CreateStateTable = function()
            return states, function(button) states[button] = states[button] or {}; return states[button] end
        end,
    },
}
local utilsFile = assert(io.open("core/utils.lua", "r"))
local utilsSource = utilsFile:read("*a"); utilsFile:close()
local pinSource = assert(utilsSource:match("(function Helpers%.BaseClearAllPoints.-)\nfunction Helpers%.FrameIsProtected"))
local pinChunk = assert(loadstring("local Helpers = ...\n" .. pinSource))
setfenv(pinChunk, world); pinChunk(ns.Helpers)
for _, name in ipairs({ "env", "", "builder", "layout", "native" }) do
    load("QUI_ActionBars/actionbars/actionbars" .. (name == "" and "" or "_" .. name) .. ".lua", ns)
end
local env, owned = ns.ActionBarsEnv, ns.ActionBarsOwned
local bars = { bar1 = bar }
for number = 2, 8 do
    local key = "bar" .. number
    local secondary = frame("NativeTestBar" .. number, world.UIParent)
    secondary.numButtonsShowable = 12
    secondary:SetPoint("BOTTOMLEFT", world.UIParent, "BOTTOMLEFT", 100 * number, 300)
    local parent = frame(nil, secondary)
    local button = frame(string.format(env.BUTTON_PATTERNS[key], 1), parent, 1)
    button.bar, button.container, button.index = secondary, parent, 1
    bars[key] = secondary
end
world.EditModeManagerFrameMixin = {}
local managerFile = assert(io.open(corpus .. "Blizzard_EditMode/Shared/EditModeManager.lua", "r"))
local managerSource = managerFile:read("*a"); managerFile:close()
local nativeLayoutChunk = assert(loadstring(assert(managerSource:match("(function EditModeManagerFrameMixin:UpdateBottomActionBarPositions%b().-\nend)"))))
setfenv(nativeLayoutChunk, world); nativeLayoutChunk()
world.ACTION_BARS_RELATIVE_TO_BASE_POSITIONING, world.BOTTOM_ACTION_BARS_SPACER_Y = true, 4
world.EditModeUtil = { GetBottomActionBars = function() return { bar, bars.bar3 } end }
world.ManageFramePositions = noop
world.EditModeManagerFrame = {
    IsInitialized = function() return true end,
    GetDefaultAnchor = function() return { bottomBarOffsetX = 606 } end,
    SetToLayoutAnchor = function(_, value) value:SetPoint("BOTTOMLEFT", world.UIParent, "BOTTOMLEFT", 500, 100) end,
    UpdateBottomActionBarPositions = world.EditModeManagerFrameMixin.UpdateBottomActionBarPositions,
}
bar.IsInDefaultPosition, bars.bar3.IsInDefaultPosition = function() return true end, function() return true end
world.EditModeManagerFrame:UpdateBottomActionBarPositions()
assert(bars.bar3:GetPoint(1) == "BOTTOMLEFT" and select(2, bars.bar3:GetPoint(1)) == bar)
local okCycle, cycleError = pcall(bar.SetPoint, bar, "TOPLEFT", bars.bar3, "BOTTOMLEFT", 0, -10)
assert(not okCycle and tostring(cycleError):find("cannot anchor to a dependent region", 1, true), "harness must reproduce live native anchor cycle")
local anchorHidden, anchorVisibility = false, nil
world.QUI_IsFrameHiddenByAnchor = function(key) return key == "bar1" and anchorHidden end
world.QUI_HasFrameAnchor = function(key) return key == "bar1" end
world.QUI_ApplyFrameAnchor = function(key)
    local holder, target = owned.containers[key], owned.containers.bar3
    if not holder or not target then return end
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -10)
    if anchorVisibility == "hide" then
        holder:Hide()
        anchorHidden = true
    elseif anchorVisibility == "show" then
        holder:Show()
        anchorHidden = false
    end
end
env.GetBarFrame = function(key) return bars[key] end
env.GetBarSettings, env.GetEffectiveSettings, env.GetGlobalSettings = function() return settings end, function() return settings end, function() return settings end
env.InvalidateEffectiveSettingsCache = noop
env.SkinButton = function(button, value) assert(not combat); styles[button] = value end
env.UpdateButtonText = function(button, value) assert(not combat); textStyles[button] = value end
local function flush()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
end
owned:InitializeNativeBars()
flush()
assert(settingWrites == 0 and owned.containers.bar8 and owned.containers.bar8 ~= bars.bar8, "missing settings must not abort presentation holder initialization")
for number = 2, 8 do
    local setting = { value = false }
    function setting:GetValue() return self.value end
    function setting:SetValue(value)
        assert(not combat, "native bar toggles must wait for combat to end")
        self.value = value
        settingWrites = settingWrites + 1
    end
    registeredSettings["PROXY_SHOW_ACTIONBAR_" .. number] = setting
end
assert(owned.nativeEventFrame.events.SETTINGS_LOADED, "deferred settings must be retried after registration")
combat = true
owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "SETTINGS_LOADED")
flush()
assert(settingWrites == 0 and owned.pendingRefresh, "settings registration in combat must defer toggles")
combat = false
owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
flush()
assert(settingWrites == 7, "all seven deferred native toggles must apply after combat")
owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "SETTINGS_LOADED")
flush()
assert(settingWrites == 7, "matching registered toggles must not be written again")
local holder = owned.containers.bar1
assert(holder ~= bar and holder:GetParent() == world.UIParent and owned.nativeButtons.bar1[1] == bar.actionButtons[1], "presentation holder must preserve original native controls")
assert(select(2, bar:GetPoint(1)) == holder, "native bar follows independent presentation holder")
assert(holder.width == 74 and holder.height == 74, "QUI two-column layout must size presentation holder")
assert(select(2, owned.containers.bar3:GetPoint(1)) == world.UIParent, "unconfigured target holder keeps independent initial screen anchor")
local stableX, stableY = holder:GetCenter()
local targetX, targetY = owned.containers.bar3:GetCenter()
local pageX, pageY = bar.ActionBarPageNumber:GetCenter()
local pageAnchorClears = bar.ActionBarPageNumber.anchorClears
local page = 1
world.C_ActionBar.GetActionBarPage = function() return page end
world.KeybindFrames_InQuickKeybindMode = function() return false end
world.PlaySound = noop
world.SOUNDKIT = { U_CHAT_SCROLL_BUTTON = 1 }
local function changePage(delta)
    page = page + delta
    bar.attributes.actionpage = page
    world.MainActionBarMixin.OnEvent(bar, "ACTIONBAR_PAGE_CHANGED")
    world.EditModeManagerFrame:UpdateBottomActionBarPositions()
    owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "ACTIONBAR_PAGE_CHANGED")
end
world.ActionBar_PageUp = function() changePage(1) end
world.ActionBar_PageDown = function() changePage(-1) end
for _, mixin in ipairs({ world.MainActionBarUpButtonMixin, world.MainActionBarDownButtonMixin }) do
    mixin.OnClick()
    local x, y = bar.ActionBarPageNumber:GetCenter()
    assert(x == pageX and y == pageY, "paging arrows must stay fixed before QUI's deferred refresh")
    assert(bar.ActionBarPageNumber.Text.text == page, "native page label must update")
    assert(bar.actionButtons[1]:CalculateAction() == (page - 1) * 12 + 1, "native page actions must update")
    flush()
    assert(bar.ActionBarPageNumber:GetParent() == bar, "native page control ownership must remain intact")
    assert(bar.ActionBarPageNumber.anchorClears == pageAnchorClears, "paging refresh must not invalidate the page-control rect again")
end
for _ = 1, 4 do
    world.EditModeManagerFrame:UpdateBottomActionBarPositions()
    owned:RefreshNativeBars()
    flush()
    local x, y = holder:GetCenter()
    local tx, ty = owned.containers.bar3:GetCenter()
    assert(x == stableX and y == stableY and tx == targetX and ty == targetY, "native relayout must not recapture moving positions or drift QUI anchors")
    assert(select(2, bar:GetPoint(1)) == holder and select(2, bars.bar3:GetPoint(1)) == owned.containers.bar3,
        "native relayout must reattach bars to independent QUI holders")
end
assert(bar.actionButtons[1].scale == 0.8, "QUI icon scale must apply")
assert(bar.actionButtons[2].points[1][4] == 47.5, "QUI spacing must apply")
assert(bar.EndCaps.alpha == 0 and bar.BorderArt.alpha == 0, "QUI appearance suppresses native artwork")
for i, button in ipairs(bar.actionButtons) do
    assert(styles[button] == settings and textStyles[button] == settings, "native buttons must receive QUI skins and text")
    assert(button:GetID() == i and button:GetParent() == original[i].parent and button.bar == bar and button.container == original[i].parent)
    for key, value in pairs(original[i].attributes) do assert(button.attributes[key] == value, "native action attribute changed: " .. key) end
    for key, value in pairs(original[i].scripts) do assert(button.scripts[key] == value, "native script changed: " .. key) end
    assert(world.ActionBarButtonEventsFrame.frames[i] == button, "native dispatch membership changed")
end
assert(bindingWrites == 0 and world.ActionBarActionEventsFrame.frames[bar.actionButtons[1]], "native binding/dispatch paths must remain intact")
assert(world.GetActionButtonForID(1) == bar.actionButtons[1])
combat = true
bar.attributes.actionpage = 7
assert(bar.actionButtons[1]:CalculateAction() == 73, "native bonus paging must remain effective")
world.OverrideActionBar:Show()
assert(world.GetActionButtonForID(1) == world.OverrideActionBarButton1, "native override binding dispatch must survive")
world.ActionBarMixin.UpdateShownButtons(bar)
for i = 5, 12 do assert(not bar.actionButtons[i]:IsShown() and bar.actionButtons[i]:GetAttribute("statehidden"), "native combat visibility must respect QUI count") end
local oldWrites, oldWidth = protectedWrites, holder.width
settings.ownedLayout.iconCount = 8
owned:RefreshNativeBars()
env.BuildNativeBar("bar1")
env.SecureLayoutBar("bar1", bar.actionButtons, 8, "TOPLEFT", 1, {}, 500, 500)
assert(owned.pendingRefresh and protectedWrites == oldWrites and holder.width == oldWidth, "combat refresh must defer every mutation")
combat = false
owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
flush()
for i = 5, 8 do
    assert(bar.actionButtons[i]:IsShown() and not bar.actionButtons[i]:GetAttribute("statehidden"), "increased count restores native visibility")
    assert(bar.actionButtons[i].container:IsShown(), "increased count restores native parent containers")
end
combat = true
world.ActionBarMixin.UpdateShownButtons(bar)
assert(bar.actionButtons[8]:IsShown() and not bar.actionButtons[9]:IsShown())
combat = false
settings.ownedLayout.iconCount = 0
owned:RefreshNativeBars()
combat = true
world.ActionBarMixin.UpdateShownButtons(bar)
for _, button in ipairs(bar.actionButtons) do assert(not button:IsShown(), "zero count survives native combat refresh") end
combat = false
settings.ownedLayout.iconCount = 12
owned:RefreshNativeBars()
settings.enabled = false
owned:RefreshNativeBars()
assert(registeredSettings.PROXY_SHOW_ACTIONBAR_2:GetValue() == false, "registered false values must remain valid settings")
world.ActionBarMixin.UpdateShownButtons(bar)
for _, button in ipairs(bar.actionButtons) do assert(not button:IsShown(), "disabled QUI bar hides its native buttons") end
settings.enabled = true
owned:RefreshNativeBars()
for _, button in ipairs(bar.actionButtons) do assert(not button:GetAttribute("statehidden"), "reenabling bar restores native controls") end
assert(bar.numButtonsShowable == 12, "native layout settings must not be overwritten")
bar.numButtonsShowable = 6
owned:RefreshNativeBars()
assert(owned._visibleButtonCounts.bar1 == 6, "QUI layout respects native Edit Mode maximum")
assert(settings.ownedLayout.iconCount == 12, "native maximum must not overwrite saved QUI count")
for i = 7, 12 do assert(bar.actionButtons[i]:GetAttribute("statehidden"), "buttons beyond native maximum remain hidden") end
for _, nativeBar in pairs(bars) do assert(nativeBar:GetParent() == world.UIParent, "native bar parents must remain unchanged") end
holder:Hide()
assert(not holder:IsShown() and bar:IsShown(), "QUI holder hiding must not replace native bar visibility ownership")
for _, button in ipairs(bar.actionButtons) do assert(button:GetAttribute("statehidden"), "holder hide must hide native controls through visibility drivers") end
holder:Show()
assert(holder:IsShown() and env.IsNativeBarEnabled("bar1"), "holder show must clear explicit QUI hide")
for i = 1, 6 do assert(not bar.actionButtons[i]:GetAttribute("statehidden"), "holder show restores visible native controls") end
for _ = 1, 2 do
    bar:Hide()
    flush()
    assert(not holder:IsShown() and env.IsNativeBarEnabled("bar1"), "native hide mirrors holder without latching QUI hide state")
    bar:Show()
    flush()
    assert(holder:IsShown() and env.IsNativeBarEnabled("bar1"), "native show restores holder after queued refresh")
    for i = 1, 6 do assert(not bar.actionButtons[i]:GetAttribute("statehidden"), "native hide/show must not latch button exclusion") end
end
combat = true
bar:Hide()
assert(owned.pendingRefresh and holder:IsShown(), "native visibility changes during combat defer holder synchronization")
combat = false
owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
flush()
assert(not holder:IsShown() and env.IsNativeBarEnabled("bar1"), "regen mirrors native hiding without a sticky QUI hide")
bar:Show()
flush()
assert(holder:IsShown(), "native controls remain recoverable after combat visibility changes")
anchorVisibility = "hide"
owned:RefreshNativeBars()
assert(not holder:IsShown() and not env.IsNativeBarEnabled("bar1"), "hide-with-parent applies during active refresh")
for _, button in ipairs(bar.actionButtons) do assert(button:GetAttribute("statehidden"), "anchor hiding excludes native buttons immediately") end
anchorVisibility = "show"
owned:RefreshNativeBars()
assert(holder:IsShown() and env.IsNativeBarEnabled("bar1"), "show-with-parent clears state after callback ordering")
for i = 1, 6 do assert(not bar.actionButtons[i]:GetAttribute("statehidden"), "anchor showing restores native buttons immediately") end
anchorVisibility = nil
bar:Hide()
flush()
assert(not holder:IsShown(), "native-hidden holder starts without another hide transition")
anchorVisibility = "hide"
owned:RefreshNativeBars()
for _, button in ipairs(bar.actionButtons) do assert(button:GetAttribute("statehidden"), "already-hidden holder still propagates anchor-hidden state") end
bar:Show()
flush()
assert(not holder:IsShown() and not env.IsNativeBarEnabled("bar1"), "native reappearance must respect anchor hiding without an OnHide callback")
anchorVisibility = "show"
owned:RefreshNativeBars()
assert(holder:IsShown() and env.IsNativeBarEnabled("bar1"), "explicit anchor reappearance restores holder")
for i = 1, 6 do assert(not bar.actionButtons[i]:GetAttribute("statehidden"), "explicit anchor reappearance restores native controls") end
print("OK forever_native_actionbars_test")
