local function noop() end
local function runClient(client)
    local env = (dofile("tests/helpers/load_minimap_runtime.lua"))()
    local module = env.ns.Addon.Minimap
    local updateButtons = assert(env.findUpvalue(module.Initialize, "UpdateButtonVisibility"))
    local checkHud = assert(env.findUpvalue(module.Initialize, "CheckExternalHud"))
    local settings = assert(env.findUpvalue(updateButtons, "GetSettings"))()
    env.ns.Helpers.GetModuleDB = function() return settings end
    local frame = getmetatable(Minimap).__index
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:SetShown(shown) self.shown = shown end
    function frame:IsShown() return self.shown ~= false end
    function frame:IsVisible() return self.shown ~= false and (not self.parent or self.parent:IsVisible()) end
    function frame:IsEnabled() return true end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:GetPoint() return unpack(self.point or {}) end
    function frame:GetScale() return self.scale or 1 end
    function frame:GetEffectiveAlpha() return 1 end
    function frame:GetRect() end
    frame.EnableMouse, frame.SetFrameLevel = noop, noop
    frame.SetFixedFrameStrata, frame.SetFixedFrameLevel = noop, noop
    MinimapCluster.Layout = noop
    local now = 100
    GetTime = function() return now end
    settings.enabled, settings.size = true, 160
    settings.buttonDrawer.enabled = false

    local function replace(func, name, value)
        for i = 1, math.huge do
            local key = debug.getupvalue(func, i)
            assert(key, name)
            if key == name then debug.setupvalue(func, i, value); return end
        end
    end
    for _, name in ipairs({
        "SetMinimapShape", "CreateBackdrop", "UpdateBackdrop", "SetupMinimapDragging", "UpdateMinimapSize",
        "CreateClock", "UpdateClock", "UpdateClockTime", "CreateCoords", "UpdateCoords", "UpdateCoordsPosition",
        "CreateZoneText", "UpdateZoneText", "CreateDatatextPanel", "UpdateDatatextPanel", "SetupAddonButtonHiding",
        "SetupButtonDrawer", "UpdateDungeonEyePosition", "SetupZoomPersistence", "SetupMouseWheelZoom",
        "SetupMiddleClickMenu", "SetupAutoZoom", "StartUpdateTickers",
    }) do replace(module.Initialize, name, noop) end
    for _, name in ipairs({ "ApplyZoomLevel", "RefreshButtonDrawer", "UpdateMiddleClickMenuOverlayState" }) do
        replace(module.Refresh, name, noop)
    end

    local native = setmetatable({ ButtonStateBehaviorMixin = { OnLoad = noop }, CreateFromMixins = function() return {} end }, { __index = _G })
    local callbacks, hookCount, insetPoint = {}, 0
    native.EventRegistry = {
        RegisterCallback = function(_, event, callback, owner) callbacks[event] = { callback, owner } end,
    }
    native.C_Minimap = {
        SetMinimapInsetInfo = function() insetPoint = { MinimapBackdrop.ExternalEventURLButton:GetPoint() } end,
        ClearMinimapInsetInfo = noop,
    }
    native.Enum = { MinimapTrackingFilter = { AccountCompletedQuests = 1, TrivialQuests = 2 } }
    if client == "ptr" then
        setfenv(assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/MinimapUtil.lua")), native)()
    end
    local sourceRoot = client == "ptr" and "tests/framexml" or "tests/clients/forever/framexml"
    local hasURL, canShow, launches, effects = true, true, 0, {}
    native.C_ExternalEventURL = {
        CanShow = function() return canShow end,
        HasURL = function() return hasURL end,
        IsNew = function() return true end,
        LaunchURL = function() launches = launches + 1 end,
    }
    setfenv(assert(loadfile(sourceRoot .. "/Interface/AddOns/Blizzard_Minimap/Shared/ExternalEventURLMinimapButton.lua")), native)()
    local button = env.newFrame(nil, "Button", MinimapBackdrop)
    for key, value in pairs(native.ExternalEventURLMinimapButtonMixin) do button[key] = value end
    button.SpellEffectModelScene = {
        GetActorByTag = function() end,
        SetSize = noop,
        TransitionToModelSceneID = noop,
        SetShown = function(_, shown) effects[#effects + 1] = shown end,
    }
    MinimapBackdrop.ExternalEventURLButton = button
    local click, refresh = button.OnClick, button.Refresh
    local source = assert(io.open(sourceRoot .. "/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua"))
    local minimapSource = source:read("*a")
    source:close()
    native.MinimapClusterMixin = {}
    setfenv(assert(loadstring(assert(minimapSource:match("(function MinimapClusterMixin:ApplyExternalEventURLButtonAnchor%(%).-\nend)")))), native)()
    MinimapCluster.ApplyExternalEventURLButtonAnchor = native.MinimapClusterMixin.ApplyExternalEventURLButtonAnchor
    hooksecurefunc = function(owner, method, callback)
        if owner ~= MinimapCluster or method ~= "ApplyExternalEventURLButtonAnchor" then return end
        hookCount = hookCount + 1
        local original = owner[method]
        owner[method] = function(...)
            original(...)
            callback(...)
        end
    end
    native.ExternalEventURLMinimapButtonStyle = { borderAtlas = "border", borderWidth = 32, borderHeight = 32 }
    button.Border = { SetAtlas = noop, SetSize = noop, ClearAllPoints = noop, SetPoint = noop }
    MinimapCluster.MinimapContainer = env.newFrame()
    function frame:GetCenter() return 80, 80 end
    function frame:GetEffectiveScale() return 1 end
    function button:GetLeft() return self.point[1] == "LEFT" and -5 or -7 end
    function button:GetRight() return self:GetLeft() + 32 end
    function button:GetTop() return self.point[1] == "LEFT" and 56 or 64 end
    function button:GetBottom() return self:GetTop() - 32 end
    button:OnLoad()
    local function assertQUIAnchor(point, message)
        assert(point and point[1] == "LEFT" and point[2] == Minimap
            and point[3] == "LEFT" and point[4] == -5 and point[5] == -40, message)
    end
    module:Initialize()
    assert(button:GetParent() == Minimap and button:IsVisible() and MinimapBackdrop.shown == false,
        "native external-event shortcut must remain visible after QUI hides its decorative parent")
    assert(button.point and button.point[2] == Minimap and button.point[5] < 0,
        "external-event shortcut must anchor to the visible minimap below its mission button")
    assert(button.OnClick == click and button.Refresh == refresh and effects[#effects],
        "native click, availability and new-event effects must remain owned by Blizzard")
    if client == "ptr" then
        assertQUIAnchor(insetPoint, "initial QUI ownership must refresh the native inset for the final position")
        button:OnEvent("EXTERNAL_EVENT_URL_CHANGED")
        assertQUIAnchor(button.point, "native PTR URL refresh must preserve QUI placement")
        assertQUIAnchor(insetPoint, "native PTR URL refresh must calculate its inset after QUI placement")
        local scaleCallback = assert(callbacks["Minimap.OnScaleUpdated"])
        scaleCallback[1](scaleCallback[2], 1.5)
        assertQUIAnchor(button.point, "native PTR scale refresh must preserve QUI placement")
        assertQUIAnchor(insetPoint, "native PTR scale refresh must calculate its inset after QUI placement")
        InCombatLockdown = function() return true end
        button:OnEvent("EXTERNAL_EVENT_URL_CHANGED")
        assert(button.point[1] == "TOPLEFT", "QUI must defer protected positioning in combat")
        assert(env.findUpvalue(module.Refresh, "pendingMinimapRefresh"), "combat anchor refresh must queue recovery")
        InCombatLockdown = function() return false end
        module:Refresh()
        assertQUIAnchor(button.point, "deferred PTR anchor must recover outside combat")
        assertQUIAnchor(insetPoint, "deferred PTR inset must recover outside combat")
    end
    button:OnClick()
    assert(launches == 1, "native external-event click must launch its URL")
    hasURL = false
    button:OnEvent("EXTERNAL_EVENT_URL_CHANGED")
    updateButtons()
    assert(not button:IsVisible(), "QUI refresh must not force-show an unavailable native shortcut")
    hasURL, canShow = true, false
    button:Refresh()
    updateButtons()
    assert(not button:IsVisible(), "native CanShow gate must survive QUI layout")
    canShow = true
    button:Refresh()
    assert(button:IsVisible())
    Minimap:Hide()
    assert(not button:IsVisible(), "native shortcut must follow minimap visibility during pet battles")
    Minimap:Show()

    now = 102
    Minimap:SetParent(env.newFrame("ExternalHUD", "Frame", UIParent))
    checkHud(); checkHud()
    assert(button:GetParent() == MinimapBackdrop and not button:IsVisible() and button.shown,
        "external HUD takeover must restore the native parent without changing native shown state")
    assert(button.point[1] == "TOPLEFT" and button.point[2] == -7,
        "external HUD takeover must restore Blizzard's shortcut anchor")
    if client == "ptr" then
        assert(insetPoint[1] == "TOPLEFT", "external HUD release must restore the native inset position")
        button:OnEvent("EXTERNAL_EVENT_URL_CHANGED")
        assert(button.point[1] == "TOPLEFT", "native refresh must retain external HUD ownership")
    end
    Minimap:SetParent(UIParent)
    checkHud()
    assert(button:GetParent() == Minimap and button:IsVisible(), "leaving an external HUD must recover the shortcut")

    settings.enabled = false
    updateButtons()
    assert(button:GetParent() == MinimapBackdrop and button.shown,
        "disabling QUI minimap layout must return shortcut ownership without forcing visibility")
    assert(button.point[1] == "TOPLEFT", "disabling QUI must restore the native anchor without hook recursion")
    if client == "ptr" then
        button:OnEvent("EXTERNAL_EVENT_URL_CHANGED")
        assert(button.point[1] == "TOPLEFT" and insetPoint[1] == "TOPLEFT",
            "disabled QUI must preserve native refresh and inset placement")
    end
    MinimapBackdrop:Show()
    assert(button:IsVisible(), "restored native minimap must retain the available shortcut")
    settings.enabled = true
    updateButtons()
    MinimapBackdrop:Hide()
    InCombatLockdown = function() return true end
    Minimap:SetParent(env.newFrame("CombatHUD", "Frame", UIParent))
    now = 104
    checkHud(); checkHud()
    assert(button:GetParent() == Minimap, "external HUD parent changes must wait until combat ends")
    InCombatLockdown = function() return false end
    module:Refresh()
    assert(button:GetParent() == MinimapBackdrop, "deferred HUD ownership must restore outside combat")

    assert(hookCount == 1, "layout refreshes must not install duplicate external-event anchor hooks")
    MinimapBackdrop.ExternalEventURLButton = nil
    updateButtons()
end
runClient("ptr")
runClient("forever")
print("OK: native PTR and Forever external-event shortcuts preserve placement, insets and lifecycle")
