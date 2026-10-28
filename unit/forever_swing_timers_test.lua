local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local nativeRoot = "tests/clients/forever/framexml/Interface/AddOns/"
local modulePath = arg[1] or "modules/skinning/gameplay/swing_timers.lua"
local function noop() end
local function build(forever, delayed)
    local frames, timers, movers, resolvers = {}, {}, {}, {}
    local logins = {}
    local state = { enabled = true, combat = false, range = true, offhand = 2, ranged = 3, time = 100,
        anchorChanges = 0, addonStateWrites = {}, executionTainted = false }
    local function hasAddonCaller()
        local level = 2
        while true do
            local info = debug.getinfo(level, "S")
            if not info then return false end
            if info.source == "@" .. modulePath then return true end
            level = level + 1
        end
    end
    local function guardNativeState(frame)
        local fields = { visibility = true, isInEditMode = true, isOutOfRange = true,
            isRangeCheckEnabled = true, swingDuration = true, swingEndTime = true }
        local values, tainted = {}, {}
        for key in pairs(fields) do values[key] = rawget(frame, key); rawset(frame, key, nil) end
        setmetatable(frame, {
            __index = function(_, key)
                if tainted[key] then state.executionTainted = true end
                return values[key]
            end,
            __newindex = function(target, key, value)
                if not fields[key] then rawset(target, key, value); return end
                local addon = hasAddonCaller()
                if addon then state.addonStateWrites[#state.addonStateWrites + 1] = target.name .. "." .. key end
                tainted[key] = addon or state.executionTainted
                values[key] = value
            end,
        })
    end
    local world = setmetatable({}, { __index = _G })
    world._G = world
    local function widget(parent)
        local frame = { parent = parent, shown = true, scripts = {}, events = {}, points = {}, alpha = 1,
            width = 213, height = 20, scale = 1 }
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:GetScript(event) return self.scripts[event] end
        function frame:HookScript(event, callback)
            local previous = self.scripts[event]
            self.scripts[event] = function(self, ...) if previous then previous(self, ...) end; callback(self, ...) end
        end
        function frame:Fire(event, ...) local callback = self.scripts[event]; if callback then callback(self, ...) end end
        function frame:Show() local old = self.shown; self.shown = true; if not old then self:Fire("OnShow") end end
        function frame:Hide() local old = self.shown; self.shown = false; if old then self:Fire("OnHide") end end
        function frame:SetShown(value) if value then self:Show() else self:Hide() end end
        function frame:IsShown() return self.shown end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event) self:RegisterEvent(event) end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:IsEventRegistered(event) return self.events[event] == true end
        function frame:SetParent(value) self.parent = value end
        function frame:GetParent() return self.parent end
        function frame:SetSize(width, height) self.width, self.height = width, height end
        function frame:SetWidth(value) self.width = value end
        function frame:SetHeight(value) self.height = value end
        function frame:GetWidth() return self.width end
        function frame:GetHeight() return self.height end
        function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function frame:GetPoint(index) return unpack(self.points[index or 1] or {}) end
        function frame:ClearAllPoints() self.points = {} end
        function frame:GetNumPoints() return #self.points end
        function frame:SetAllPoints(value) self:ClearAllPoints(); self:SetPoint("TOPLEFT", value or self.parent, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", value or self.parent, "BOTTOMRIGHT", 0, 0) end
        function frame:SetScale(value) self.scale = value end
        function frame:GetScale() return self.scale end
        function frame:GetEffectiveScale() return self.scale end
        function frame:SetAlpha(value) self.alpha = value end
        function frame:GetAlpha() return self.alpha end
        function frame:SetTexture(value) self.texture = value end
        function frame:SetColorTexture(...) self.color = { ... } end
        function frame:SetVertexColor(...) self.vertexColor = { ... } end
        function frame:SetStatusBarColor(...) self.barColor = { ... } end
        function frame:SetStatusBarTexture(value) self.fill = self.fill or widget(self); self.fill:SetTexture(value) end
        function frame:GetStatusBarTexture() return self.fill end
        function frame:SetValue(value) self.value = value end
        function frame:GetValue() return self.value end
        function frame:SetText(value) self.text = value end
        function frame:GetText() return self.text end
        function frame:SetFormattedText(pattern, ...) self.text = string.format(pattern, ...) end
        function frame:SetTextColor(...) self.textColor = { ... } end
        function frame:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags end
        function frame:CreateTexture() return widget(self) end
        function frame:CreateFontString()
            local label = widget(self)
            function label:SetText(value)
                assert(self.font, "preview labels need a font before SetText")
                self.text = value
            end
            return label
        end
        function frame:SetBackdrop(value) self.backdrop = value end
        function frame:SetBackdropColor(...) self.backdropColor = { ... } end
        function frame:SetBackdropBorderColor(...) self.borderColor = { ... } end
        function frame:GetFrameLevel() return self.level or 1 end
        function frame:SetFrameLevel(value) self.level = value end
        function frame:GetFrameStrata() return "MEDIUM" end
        function frame:GetName() return self.name end
        for _, method in ipairs({ "SetFrameStrata", "EnableMouse", "SetMovable", "SetClampedToScreen", "SetJustifyH",
            "SetWordWrap", "SetShadowOffset", "SetDrawLayer", "SetTexCoord", "SetSnapToPixelGrid", "SetTexelSnappingBias",
            "SetMinMaxValues", "Layout", "StopMovingOrSizing", "ClearHighlight", "SetClipsChildren" }) do frame[method] = noop end
        frames[#frames + 1] = frame
        return frame
    end
    world.CreateFrame = function(_, name, parent)
        local frame = widget(parent)
        frame.name = name
        if name then world[name] = frame end
        return frame
    end
    world.UIParent = widget()
    world.OverrideActionBar = widget(world.UIParent)
    world.OverrideActionBar:Hide()
    world.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
    world.InCombatLockdown = function() return state.combat end
    world.IsLoggedIn = function() return false end
    world.GetTime = function() return state.time end
    world.UnitAffectingCombat = function() return state.combat end
    local simulatedSecret = {}
    world.UnitAttackSpeed = function()
        if state.secretSpeeds and (state.executionTainted or hasAddonCaller()) then
            return simulatedSecret, state.offhand and simulatedSecret, state.ranged and simulatedSecret
        end
        return 2, state.offhand, state.ranged
    end
    world.RED_FONT_COLOR = { GetRGB = function() return 1, 0, 0 end }
    world.HIGHLIGHT_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end }
    world.C_SwingTimer = { EnableRangeCheck = noop, IsTargetWithinSwingRange = function() return state.range end }
    world.CVarCallbackRegistry = { SetCVarCachable = noop, callbacks = {} }
    function world.CVarCallbackRegistry:RegisterCallback(_, callback, owner) self.callbacks[#self.callbacks + 1] = { callback, owner } end
    function world.CVarCallbackRegistry:GetCVarValueBool() return state.enabled end
    world.C_CVar = {
        GetCVarBool = function() return state.enabled end,
        SetCVar = function(_, value)
            state.enabled = value == true or value == "1" or value == 1
            for _, callback in ipairs(world.CVarCallbackRegistry.callbacks) do
                timers[#timers + 1] = function()
                    state.executionTainted = false
                    callback[1](callback[2])
                end
            end
        end,
    }
    world.GetCVarBool, world.SetCVar = world.C_CVar.GetCVarBool, world.C_CVar.SetCVar
    world.EventRegistry = { RegisterCallback = noop }
    world.EditModeManagerFrame = { IsEditModeActive = function() return state.nativeEdit == true end,
        OnEditModeSystemAnchorChanged = function() state.anchorChanges = state.anchorChanges + 1 end }
    world.EditModeSystemSettingsDialog = { Hide = noop }
    world.hooksecurefunc = function(target, method, callback)
        if type(target) == "string" then target, method, callback = world, target, method end
        local original = assert(target[method], method)
        target[method] = function(...)
            original(...)
            local tainted = state.executionTainted
            callback(...)
            state.executionTainted = tainted
        end
    end
    world.Enum = { EditModePresetLayouts = { Modern = 0 } }
    world.APIDocumentation = { AddDocumentationTable = function(_, doc)
        for _, definition in ipairs(doc.Tables or {}) do
            if definition.Type == "Enumeration" then
                local values = {}; world.Enum[definition.Name] = values
                for _, field in ipairs(definition.Fields) do values[field.Name] = field.EnumValue end
            end
        end
    end }
    local function load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, world); chunk()
    end
    load("tests/clients/forever/api-docs/blizzard/SwingTimerDocumentation.lua")
    load("tests/clients/forever/api-docs/blizzard/EditModeManagerConstantsDocumentation.lua")
    world.BottomManagedFrameContainer = widget(world.UIParent)
    world.BottomManagedFrameContainer.showingFrames = {}
    world.BottomManagedFrameContainer.UpdateManagedFrames = noop
    world.BottomManagedFrameContainer.BottomManagedLayoutContainer = widget(world.BottomManagedFrameContainer)
    load(nativeRoot .. "Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua")
    for key, value in pairs(world.ManagedFrameContainerMixin) do world.BottomManagedFrameContainer[key] = value end
    world.EditModeSystemMixin = { OnSystemLoad = noop, UpdateSystemSetting = noop }
    local editSource = read(nativeRoot .. "Blizzard_EditMode/Shared/EditModeSystemTemplates.lua")
    for _, method in ipairs({ "OnSystemHide", "GetManagedFrameContainer", "BreakFromFrameManager", "ApplySystemAnchor", "OnEditModeExit",
        "SetScaleOverride", "SetPointOverride" }) do
        local body = assert(editSource:match("(function EditModeSystemMixin:" .. method .. "%b().-\nend)"), method)
        local chunk = assert(loadstring(body)); setfenv(chunk, world); chunk()
    end
    local first = assert(editSource:find("EditModeSwingTimerSystemMixin = {};", 1, true))
    local after = assert(editSource:find("EditModeVehicleSeatIndicatorSystemMixin = {};", first, true))
    local nativeEdit = assert(loadstring(editSource:sub(first, after - 1))); setfenv(nativeEdit, world); nativeEdit()
    world.ManageFramePositions = function() world.BottomManagedFrameContainer:UpdateManagedFrames() end
    load(nativeRoot .. "Blizzard_SharedXMLBase/FrameUtil.lua")
    load(nativeRoot .. "Blizzard_SwingTimer/Blizzard_SwingTimer.lua")
    local manager = world.CreateFrame("Frame", "SwingTimerManagerFrame")
    for key, value in pairs(world.SwingTimerManagerMixin) do manager[key] = value end
    manager:Hide()
    manager:SetScript("OnEvent", manager.OnEvent)
    manager:OnLoad()
    local profile = { swingTimers = {}, general = {} }
    for _, key in ipairs({ "swingTimerMainHand", "swingTimerOffHand", "swingTimerRanged" }) do
        profile.swingTimers[key] = { width = 250, height = 20, texture = "Flat", fontSize = 11,
            showTitle = true, showTime = true, visibility = 0 }
    end
    local core = { db = { profile = profile } }
    world.QUI_LayoutMode = { RegisterElement = function(_, definition) movers[definition.key] = definition end }
    world.QUI_RegisterFrameResolver = function(key, definition) resolvers[key] = definition end
    world.QUI_ApplyFrameAnchor = noop
    world.QUI = core
    local ns = { Client = { isForever = forever }, Addon = core, QUI = core,
        L = setmetatable({}, { __index = function(_, key) return key end }) }
    ns.Helpers = { ApplyBarStyle = function(bar, path) bar:SetStatusBarTexture(path) end, ApplyIconStyle = function() end,
        GetCore = function() return core end, GetProfile = function() return core.db.profile end,
        GetModuleDB = function(key) return core.db.profile[key] end,
        GetGeneralFont = function() return "QUIFont.ttf" end, GetGeneralFontOutline = function() return "OUTLINE" end,
        GetSkinBorderColor = function() return 0, 0, 0, 1 end, GetSkinAccentColor = function() return 0.2, 0.8, 0.6, 1 end,
        GetSkinBgColor = function() return 0.05, 0.05, 0.05, 1 end,
        BaseClearAllPoints = function(frame) (frame.ClearAllPointsBase or frame.ClearAllPoints)(frame) end,
        BaseSetPoint = function(frame, ...) (frame.SetPointBase or frame.SetPoint)(frame, ...) end,
    }
    ns.QUI_LayoutMode = world.QUI_LayoutMode
    ns.WhenLoggedIn = function(callback) logins[#logins + 1] = callback end
    ns.Registry = { Register = noop }
    ns.SkinBase = {
        ApplyChromeBackdrop = function(frame, options) frame.chromeOptions = options end,
        RoundBarTexture = function(owner, texture) texture.maskOwner = owner end,
        GetWindowColors = function() return 0.2, 0.8, 0.6, 1, 0.05, 0.05, 0.05, 1 end,
        GetSkinColors = function() return 0.2, 0.8, 0.6, 1, 0.05, 0.05, 0.05, 1 end,
        GetSkinBarColor = function() return 0.2, 0.8, 0.6 end,
        SetInsetPixelPoints = function(region, relativeTo, pixels)
            local inset = pixels * 0.5
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", inset, -inset)
            region:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", -inset, inset)
        end,
        SkinFontString = function(label, options) label:SetFont("QUIFont.ttf", options.size, "OUTLINE") end }
    ns.Media = { Textures = { Flat = "flat" } }
    ns.LSM = { Fetch = function(_, _, key) return key == "Flat" and "flat" or key end }
    ns.SafeCall = function(_, callback, ...) callback(...); return true end
    ns.SafeCallMethod = function(_, object, method, ...) object[method](object, ...); return true end
    ns.SafeCallMethodIfPresent = function(_, object, method, ...) if object and object[method] then object[method](object, ...) end; return true end
    for index, name in ipairs({ "MainHand", "OffHand", "Ranged" }) do
        local frame = world.CreateFrame("Frame", "SwingTimer" .. name .. "Frame", world.UIParent)
        for _, mixin in ipairs({ world.ManagedFrameMixin, world.EditModeSystemMixin, world.EditModeSwingTimerSystemMixin, world.SwingTimerMixin }) do
            for key, value in pairs(mixin) do frame[key] = value end
        end
        frame.Background, frame.Border, frame.StatusBar = widget(frame), widget(frame), widget(frame)
        local bar = frame.StatusBar
        bar.Pip, bar.TypeLabelShadow, bar.TypeLabel, bar.TimeLabel = widget(bar), widget(bar), widget(bar), widget(bar)
        frame.swingType, frame.typeText, frame.barTexture = index - 1, name, "native-" .. name
        frame.visibility, frame.isManagedFrame, frame.isBottomManagedFrame = 0, true, true
        frame.layoutParent = world.BottomManagedFrameContainer
        frame.nativeSettings = {}
        for _, value in pairs(world.Enum.EditModeSwingTimerSetting) do frame.nativeSettings[value] = 1 end
        frame.nativeSettings[world.Enum.EditModeSwingTimerSetting.Visibility] = 0
        function frame:IsInDefaultPosition() return true end
        function frame:IsSettingDirty() return true end
        function frame:ClearDirtySetting() end
        function frame:HasSetting() return true end
        function frame:GetSettingValue(setting) return self.nativeSettings[setting] end
        function frame:GetSettingValueBool(setting) return self:GetSettingValue(setting) ~= 0 end
        frame.ClearAllPointsBase, frame.SetPointBase, frame.SetScaleBase = frame.ClearAllPoints, frame.SetPoint, frame.SetScale
        frame.SetScale, frame.SetPoint = frame.SetScaleOverride, frame.SetPointOverride
        frame.SetSnappedToFrame = noop
        frame:SetScript("OnHide", frame.OnHide)
        frame:SetScript("OnShow", frame.OnShow)
        guardNativeState(frame)
        frame:OnLoad()
        world.BottomManagedFrameContainer:AddManagedFrame(frame)
        frame:SetScaleBase(1.4)
        frame:SetPointBase("CENTER", world.UIParent, "CENTER", 30, 40)
    end
    local delayedFrames = {}
    if delayed then
        for _, name in ipairs({ "MainHand", "OffHand", "Ranged" }) do
            local key = "SwingTimer" .. name .. "Frame"
            delayedFrames[key], world[key] = world[key], nil
        end
    end
    local runtime = assert(loadfile(modulePath)); setfenv(runtime, world); runtime("QUI", ns)
    local function flush()
        for _ = 1, 20 do
            if #timers == 0 then return end
            local pending = timers; timers = {}
            for _, callback in ipairs(pending) do callback() end
        end
        error("swing timer hooks must settle without an endless refresh loop")
    end
    local function event(name, ...)
        if name == "PLAYER_LOGIN" then for _, callback in ipairs(logins) do callback() end end
        local recipients = {}; for _, frame in ipairs(frames) do if frame.events[name] then recipients[#recipients + 1] = frame end end
        for _, frame in ipairs(recipients) do
            state.executionTainted = false
            frame:Fire("OnEvent", name, ...)
        end
        flush()
    end
    return { world = world, ns = ns, state = state, frames = frames, core = core, movers = movers,
        resolvers = resolvers, delayedFrames = delayedFrames, event = event, flush = flush }
end
local retail = build(false)
retail.event("PLAYER_LOGIN")
assert(next(retail.movers) == nil and next(retail.resolvers) == nil, "Retail must not register Forever swing elements")
for _, speeds in ipairs({ { ranged = 3 }, { offhand = 2, ranged = 3 } }) do
    local regression = build(true)
    regression.event("PLAYER_LOGIN")
    regression.state.offhand, regression.state.ranged = speeds.offhand, speeds.ranged
    regression.state.secretSpeeds, regression.state.combat = true, true
    local ok, failure = pcall(regression.event, "PLAYER_IN_COMBAT_CHANGED")
    assert(ok, "native combat dispatch must stay clean with simulated secret attack speeds: " .. tostring(failure))
    assert(#regression.state.addonStateWrites == 0,
        "QUI must not write native swing gameplay state: " .. table.concat(regression.state.addonStateWrites, ", "))
end
local delayed = build(true, true)
delayed.event("PLAYER_LOGIN")
assert(next(delayed.movers) == nil, "login must tolerate native addon not loaded yet")
for name, frame in pairs(delayed.delayedFrames) do delayed.world[name] = frame end
delayed.event("ADDON_LOADED", "Blizzard_SwingTimer")
assert(delayed.movers.swingTimerMainHand and delayed.movers.swingTimerOffHand and delayed.movers.swingTimerRanged,
    "late native addon load must register all swing timers")
local test = build(true)
local world, state = test.world, test.state
local api = assert(test.ns.SwingTimers, "Forever must expose its swing timer integration")
test.event("PLAYER_LOGIN")
assert(state.anchorChanges == 0, "claiming native scaled bars must not mutate native saved-anchor state")
assert(#api.entries == 3, "all three native swing types require layout support")
for _, entry in ipairs(api.entries) do
    local frame, mover = world[entry.frameName], assert(test.movers[entry.key], entry.key)
    local holder = assert(mover.getFrame())
    assert(holder ~= frame and frame:GetParent() == holder, "layout must use a QUI holder")
    assert(test.resolvers[entry.key], "swing bars must be anchor targets")
    assert(not world.BottomManagedFrameContainer.showingFrames[frame], "claimed bars must leave native managed layout")
    assert(frame:GetWidth() == 250 and frame:GetHeight() == 20 and frame:GetScale() == 1,
        "profile size must reach each native bar without inherited native scaling")
    for _, region in ipairs({ frame.Background, frame.StatusBar }) do
        local top, bottom = region.points[1], region.points[2]
        assert(top and bottom and top[4] == 0.5 and top[5] == -0.5 and bottom[4] == -0.5 and bottom[5] == 0.5,
            "bar and background insets must use physical pixels at non-unit UI scale")
    end
    assert(entry.chrome and entry.chrome.chromeOptions.radius == 3 and entry.chrome.chromeOptions.borderPixels == 1
        and entry.chrome:GetParent() == frame and entry.chrome:GetFrameLevel() < frame.StatusBar:GetFrameLevel(),
        "each swing must use rounded one-pixel chrome behind its native fill")
    assert(frame.Border.texture == nil and frame.Background.texture == nil
        and frame.StatusBar:GetStatusBarTexture().maskOwner == frame.StatusBar and frame.StatusBar.Pip.maskOwner == frame.StatusBar,
        "square native art must be suppressed and fill/pip clipped")
    assert(frame:GetScript("OnEvent") == nil and frame.OnEvent == world.SwingTimerMixin.OnEvent
        and world.SwingTimerManagerFrame:GetScript("OnEvent") == world.SwingTimerManagerMixin.OnEvent
        and frame:GetScript("OnHide") == world.SwingTimerMixin.OnHide, "native timing scripts must remain installed")
    assert(frame.StatusBar:GetStatusBarTexture().texture ~= frame.barTexture, "native bar must receive QUI texture")
end
local main, offhand, ranged = world.SwingTimerMainHandFrame, world.SwingTimerOffHandFrame, world.SwingTimerRangedFrame
local manager = world.SwingTimerManagerFrame
local settings = api.GetSettings("swingTimerMainHand")
settings.visibility = world.Enum.EditModeSwingTimerVisibility.InCombat
api.Refresh(); test.flush()
assert(main:IsShown() and api.entries[1].holder:GetAlpha() == 0
    and main:ShouldHandleSwing() and manager:IsEventRegistered("PLAYER_SWING"),
    "QUI combat visibility must hide its holder while preserving native first-swing registration")
test.event("PLAYER_SWING", 2, world.Enum.PlayerSwingType.MainHand)
assert(main.swingEndTime == 102 and main:GetScript("OnUpdate") == world.SwingTimerMixin.OnUpdate, "native swing event must start native timer")
state.combat = true
test.event("PLAYER_IN_COMBAT_CHANGED")
assert(main:IsShown() and api.entries[1].holder:GetAlpha() == 1 and main.swingEndTime == 102,
    "entering combat must show the QUI holder and retain the first swing")
state.time = 101
main:Fire("OnUpdate", 1)
assert(main.StatusBar:GetValue() == 0.5 and main.StatusBar.TimeLabel.text == "1.0", "native timing must advance untouched")
local previousUpdate = main:GetScript("OnUpdate")
state.combat = false
settings.visibility = world.Enum.EditModeSwingTimerVisibility.Always
api.Refresh(); test.flush()
assert(main.swingEndTime == 102 and main:GetScript("OnUpdate") == previousUpdate and main.StatusBar:GetValue() == 0.5,
    "reskin must not reset an active native swing")
assert(main.StatusBar.Pip:IsShown(), "reskin must retain native active swing pip")
state.time = 102
main:Fire("OnUpdate", 1)
assert(main.swingEndTime == nil and main:GetScript("OnUpdate") == nil and not main.StatusBar.Pip:IsShown()
    and main.StatusBar:GetValue() == 0, "native timer completion must clear fill, update script, and pip")
test.event("PLAYER_SWING", 2, world.Enum.PlayerSwingType.MainHand)
assert(main.StatusBar.Pip:IsShown(), "new native swing must show the skinned pip again")
state.range = false
test.event("PLAYER_TARGET_CHANGED")
assert(api.entries[1].chrome:GetAlpha() == 1 and main.StatusBar.alpha == 1 and main.Background.alpha == 1 and main.StatusBar.TimeLabel.textColor[2] == 1,
    "active native swings must defer range dimming and red labels")
state.time = 104
main:Fire("OnUpdate", 2)
assert(api.entries[1].chrome:GetAlpha() == 0.4 and main.StatusBar.alpha == 0.4 and main.Background.alpha == 0.4 and main.StatusBar.TimeLabel.textColor[2] == 0,
    "native range dimming and red labels must survive skinning")
state.range = nil
test.event("PLAYER_TARGET_CHANGED")
assert(api.entries[1].chrome:GetAlpha() == 1 and main.StatusBar.alpha == 1 and main.StatusBar.TimeLabel.textColor[2] == 1, "unknown range must not be treated as out of range")
state.offhand, state.ranged = nil, nil
test.event("WEAPON_SLOT_CHANGED")
assert(not offhand:IsShown() and not ranged:IsShown() and not offhand:ShouldHandleSwing() and not ranged:ShouldHandleSwing()
    and manager:IsEventRegistered("PLAYER_SWING"), "unavailable weapons must stop handling swings while main hand remains registered")
state.combat = false
settings.visibility = 0
api.Refresh(); test.flush()
main:ApplySystemAnchor(); test.flush()
assert(main:GetParent() == test.movers.swingTimerMainHand.getFrame()
    and not world.BottomManagedFrameContainer.showingFrames[main], "native layout reset must not reclaim QUI bars")
main.nativeSettings[world.Enum.EditModeSwingTimerSetting.Width] = 852
main:UpdateSystemSetting(world.Enum.EditModeSwingTimerSetting.Width, true); test.flush()
assert(main:GetWidth() == settings.width, "native size updates must preserve QUI geometry")
state.combat = true
settings.width = 310
api.Refresh()
assert(main:GetWidth() == 250, "geometry refresh must wait until combat ends")
state.combat = false
test.event("PLAYER_REGEN_ENABLED")
assert(main:GetWidth() == 310, "deferred geometry must apply after combat")
local holder = test.movers.swingTimerMainHand.getFrame()
world.OverrideActionBar:Show()
assert(holder:GetAlpha() == 0, "override action bar must retain native swing-bar suppression")
world.OverrideActionBar:Hide()
assert(holder:GetAlpha() == 1, "leaving override action bar must restore swing-bar visibility")
settings.visibility = world.Enum.EditModeSwingTimerVisibility.Hidden
api.Refresh(); test.flush()
assert(holder:GetAlpha() == 0 and main.visibility == world.Enum.EditModeSwingTimerVisibility.Always
    and main:IsShown(), "QUI hidden visibility must affect only its holder")
settings.visibility = world.Enum.EditModeSwingTimerVisibility.Always
main.visibility = world.Enum.EditModeSwingTimerVisibility.Hidden
main:UpdateShownStateAndRegistration()
api.Refresh(); test.flush()
assert(main.visibility == world.Enum.EditModeSwingTimerVisibility.Hidden and not main:IsShown(),
    "QUI must preserve a native Hidden setting")
main.visibility = world.Enum.EditModeSwingTimerVisibility.InCombat
main:UpdateShownStateAndRegistration()
api.Refresh(); test.flush()
assert(main.visibility == world.Enum.EditModeSwingTimerVisibility.InCombat and not main:IsShown()
    and main:ShouldHandleSwing(), "QUI must preserve native InCombat visibility and first-swing handling")
state.combat = true
test.event("PLAYER_IN_COMBAT_CHANGED")
assert(main:IsShown(), "native InCombat setting must still respond to its combat event")
state.combat = false
main.visibility = world.Enum.EditModeSwingTimerVisibility.Always
main:UpdateShownStateAndRegistration()
local replacement = { swingTimers = {}, general = {} }
for _, entry in ipairs(api.entries) do
    replacement.swingTimers[entry.key] = { width = 333, height = 28, texture = "Flat", fontSize = 13,
        showTitle = false, showTime = false, visibility = 0 }
end
test.core.db.profile = replacement
api.Refresh(); test.flush()
assert(main:GetWidth() == 333 and main:GetHeight() == 28 and not main.StatusBar.TypeLabel:IsShown()
    and not main.StatusBar.TimeLabel:IsShown(), "refresh must reread a replacement profile")
api.SetEnabled(false); test.flush()
assert(not api.IsEnabled() and not main:IsShown() and not manager:IsEventRegistered("PLAYER_SWING"),
    "enable option must use native visibility and registration")
for _, mover in pairs(test.movers) do assert(mover.onOpen and mover.onClose); mover.onOpen() end
test.flush()
assert(not main:IsShown() and not offhand:IsShown() and not ranged:IsShown(),
    "QUI previews must leave disabled native bars hidden")
for _, entry in ipairs(api.entries) do
    local preview = assert(entry.previewBar, "QUI must own each layout preview")
    assert(preview:GetParent() == entry.holder and preview:IsShown() and preview:GetValue() > 0,
        "independent previews must expose all three weapon bars even when disabled or unequipped")
    assert(preview.TypeLabel and preview.TimeLabel and not entry.frame.isInEditMode,
        "preview labels must belong to QUI without changing native edit-mode state")
end
main:SetIsInEditMode(false)
assert(not main.isInEditMode and not main:IsShown() and api.entries[1].previewBar:IsShown(),
    "native edit-mode exit must leave an independent QUI preview visible")
for _, mover in pairs(test.movers) do mover.onClose() end
test.flush()
assert(not main:IsShown() and not offhand:IsShown() and not ranged:IsShown() and not main.isInEditMode,
    "leaving layout must restore disabled native visibility")
for _, entry in ipairs(api.entries) do
    assert(not entry.previewBar:IsShown(), "leaving layout must hide every QUI preview")
end
state.nativeEdit = true
main:SetIsInEditMode(true)
for _, mover in pairs(test.movers) do mover.onOpen() end
for _, mover in pairs(test.movers) do mover.onClose() end
test.flush()
assert(api.entries[1].chrome:GetAlpha() == 1 and main.isInEditMode and main:IsShown(), "QUI preview cleanup must preserve active native edit mode")
assert(#state.addonStateWrites == 0,
    "all refresh, settings, and layout callbacks must preserve native gameplay state: " .. table.concat(state.addonStateWrites, ", "))
local resizing = build(true)
resizing.event("PLAYER_LOGIN")
local resizeWorld, resizeNS = resizing.world, resizing.ns
resizeNS.UIKit = { GetPixelSize = function() return 1 end }
resizeNS.Helpers.SafeToNumber = function(value, fallback) return tonumber(value) or fallback end
local layoutChunk = assert(loadfile("modules/layout/layoutmode.lua"))
setfenv(layoutChunk, resizeWorld)
layoutChunk("QUI", resizeNS)
local layout = resizeNS.QUI_LayoutMode
layout.isActive = true
local anchors = {}
resizing.core.db.profile.frameAnchoring = anchors
resizeWorld.UIParent:SetSize(1000, 800)
function resizeWorld.UIParent:GetCenter() return 500, 400 end
local function pointOffset(frame, point)
    local x, y = 0, 0
    if point:find("LEFT") then x = -frame:GetWidth() / 2
    elseif point:find("RIGHT") then x = frame:GetWidth() / 2 end
    if point:find("TOP") then y = frame:GetHeight() / 2
    elseif point:find("BOTTOM") then y = -frame:GetHeight() / 2 end
    return x, y
end
for _, entry in ipairs(resizeNS.SwingTimers.entries) do
    local holder = entry.holder
    function holder:GetSize() return self:GetWidth(), self:GetHeight() end
    function holder:GetCenter()
        local point, parent, relative, x, y = self:GetPoint()
        local px, py = parent:GetCenter()
        local rx, ry = pointOffset(parent, relative)
        local sx, sy = pointOffset(self, point)
        return px + rx + x - sx, py + ry + y - sy
    end
    local handle = resizeWorld.CreateFrame("Frame", nil, holder)
    handle._isChildOverlay, handle._parentFrame = true, holder
    handle._coords, handle._label = resizeWorld.CreateFrame("Frame"), resizeWorld.CreateFrame("Frame")
    function handle:GetCenter() return holder:GetCenter() end
    function handle:GetSize() return holder:GetSize() end
    layout._elements[entry.key] = resizing.movers[entry.key]
    layout._handles[entry.key] = handle
end
local anchorSource = read("modules/layout/anchoring.lua")
local reassertStart = assert(anchorSource:find("_G.QUI_ReassertAnchorAfterResize = function(key)", 1, true))
local reassertEnd = assert(anchorSource:find("_G.QUI_ReanchorFramePositionOnly", reassertStart, true))
local reassertEnv = setmetatable({
    _G = resizeWorld,
    ns = resizeNS,
    QUICore = resizing.core,
    GetSavedFrameAnchorSettings = function(db, key) return db[key] end,
}, { __index = resizeWorld })
local reassert = assert(loadstring(anchorSource:sub(reassertStart, reassertEnd - 1)))
setfenv(reassert, reassertEnv)
reassert()
resizeWorld.QUI_ForceReapplyFrameAnchor = function(key)
    local settings = assert(anchors[key])
    local holder = layout._elements[key].getFrame()
    holder:ClearAllPoints()
    local parent = layout._elements[settings.parent]
    holder:SetPoint(settings.point, parent and parent.getFrame() or resizeWorld.UIParent,
        settings.relative, settings.offsetX, settings.offsetY)
end
for _, entry in ipairs(resizeNS.SwingTimers.entries) do
    local key, holder = entry.key, entry.holder
    local settings = resizeNS.SwingTimers.GetSettings(key)
    for _, point in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
        anchors[key] = { parent = "screen", point = point, relative = "CENTER", offsetX = 17, offsetY = -29 }
        resizeWorld.QUI_ForceReapplyFrameAnchor(key)
        for _, size in ipairs({ { 330, 50 }, { 180, 12 } }) do
            local cx, cy = holder:GetCenter()
            layout._pendingPositions[key] = { offsetX = cx - 500, offsetY = cy - 400,
                anchorTarget = "screen", anchorPointSelf = point, anchorPointTarget = "CENTER" }
            local untouched = { offsetX = 91, offsetY = 63 }
            local siblingKey = key == "swingTimerMainHand" and "swingTimerOffHand" or "swingTimerMainHand"
            layout._pendingPositions[siblingKey] = untouched
            settings.width, settings.height = size[1], size[2]
            resizeNS.SwingTimers.Refresh()
            local x, y = holder:GetCenter()
            local dx, dy = pointOffset(holder, point)
            assert(x + dx == 517 and y + dy == 371,
                key .. " " .. point .. " must retain its anchor edge and edited offsets while resizing in layout mode")
            assert(layout._pendingPositions[siblingKey] == untouched, "resizing must preserve unchanged sibling pending positions")
            assert(anchors[key].offsetX == 17 and anchors[key].offsetY == -29, "resizing must retain saved anchor offsets")
            assert(holder:GetWidth() == size[1] and holder:GetHeight() == size[2], "holder must use the new dimensions")
        end
    end
    anchors[key] = { parent = "disabled", point = "CENTER", relative = "CENTER", offsetX = 43, offsetY = -61 }
    local pending = { offsetX = 43, offsetY = -61 }
    layout._pendingPositions[key] = pending
    settings.height = 35
    resizeNS.SwingTimers.Refresh()
    local x, y = holder:GetCenter()
    assert(x == 543 and y == 339 and layout._pendingPositions[key] == pending,
        "unanchored resize must preserve the pending free position")
end
local parentKey, childKey = "swingTimerMainHand", "swingTimerOffHand"
local parent = layout._elements[parentKey].getFrame()
local child = layout._elements[childKey].getFrame()
anchors[parentKey] = { parent = "screen", point = "TOP", relative = "CENTER", offsetX = 0, offsetY = 0 }
anchors[childKey] = { parent = parentKey, point = "TOP", relative = "BOTTOM", offsetX = 0, offsetY = -5 }
resizeWorld.QUI_ForceReapplyFrameAnchor(parentKey)
resizeWorld.QUI_ForceReapplyFrameAnchor(childKey)
local cx, cy = child:GetCenter()
layout._pendingPositions[childKey] = { offsetX = cx - 500, offsetY = cy - 400,
    anchorTarget = parentKey, anchorPointSelf = "TOP", anchorPointTarget = "BOTTOM" }
resizeNS.SwingTimers.GetSettings(parentKey).height = 65
resizeNS.SwingTimers.Refresh()
local _, py = parent:GetCenter()
local _, y = child:GetCenter()
assert((y + child:GetHeight() / 2) - (py - parent:GetHeight() / 2) == -5,
    "a moved offhand timer must retain its saved gap when the main-hand timer resizes")
assert(#resizing.state.addonStateWrites == 0, "layout resizing must preserve native gameplay state")
print("OK forever_swing_timers_test")
