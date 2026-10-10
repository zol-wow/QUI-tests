local function noop() end
local function forbidden() error("utility bars must not execute secure snippets") end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"

local function run(showKeyring)
    local world = setmetatable({}, { __index = _G })
    world._G = world
    world.QUI_RefreshActionBarFade = noop
    world.setfenv = setfenv
    local combat, timers = false, {}
    local visibilityDrivers = {}
    local storeAvailable = true
    local methods = {}
    local function frame(name, parent)
        local f = setmetatable({ name = name, parent = parent, points = {}, scripts = {}, events = {},
            attributes = {}, width = 30, height = 30, scale = 1, shown = true }, { __index = methods })
        if name then world[name] = f end
        return f
    end
    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:SetParent(parent) assert(not combat, "reparenting must wait for combat"); self.parent = parent end
    function methods:GetPoint(i) return unpack(self.points[i or 1] or {}) end
    function methods:ClearAllPoints() assert(not combat); self.points = {} end
    function methods:SetPoint(...) assert(not combat); self.points[1] = { ... } end
    function methods:SetAllPoints(target) self.allPoints = target end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:GetScale() return self.scale end
    function methods:GetEffectiveScale() return self.scale end
    function methods:GetCenter() return 100, 100 end
    function methods:GetLeft() return 85 end
    function methods:GetRight() return 115 end
    function methods:SetScale(value) assert(not combat); self.scale = value end
    function methods:SetSize(w, h) assert(not combat); self.width, self.height = w, h end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetShown(value) self.shown = value end
    function methods:IsShown() return self.shown end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:GetAlpha() return self.alpha or 1 end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:SetScript(key, callback) self.scripts[key] = callback end
    function methods:HookScript(key, callback)
        local prior = self.scripts[key]
        self.scripts[key] = function(...) if prior then prior(...) end callback(...) end
    end
    function methods:SetAttribute(key, value)
        assert(not key:match("^_on"), "plain utility containers must not install snippets")
        self.attributes[key] = value
    end
    function methods:GetAttribute(key) return self.attributes[key] end
    function methods:RegisterEvent(key, callback) self.events[key] = callback or true end
    function methods:UnregisterEvent(key) self.events[key] = nil end
    function methods:UnregisterAllEvents() self.events = {} end
    methods.SetClampedToScreen, methods.MarkDirty, methods.PostAddButtonCallback = noop, noop, noop
    methods.Execute, methods.SetFrameRef = forbidden, forbidden
    world.UIParent = frame("UIParent")
    world.CreateFrame = function(_, name, parent, template)
        assert(not template or not template:find("SecureHandler", 1, true), "plain utility containers required")
        return frame(name, parent)
    end
    world.InCombatLockdown = function() return combat end
    world.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
    world.hooksecurefunc = function(target, key, callback)
        if type(target) == "string" then target, key, callback = world, target, key end
        local prior = assert(target[key], key)
        target[key] = function(...) prior(...) callback(...) end
    end
    world.SecureHandlerExecute, world.SecureHandlerWrapScript = forbidden, forbidden
    world.RegisterStateDriver = function(target, state, condition)
        assert(not combat, "visibility registration must wait for combat")
        assert(state == "visibility", "custom state snippets forbidden")
        visibilityDrivers[target] = condition
        target:SetShown(condition ~= "hide")
    end
    world.UnregisterStateDriver = noop
    world.tContains = function(list, value) for _, entry in ipairs(list) do if entry == value then return true end end return false end
    world.CopyTable = function(input) local output = {}; for k, v in pairs(input) do output[k] = v end return output end
    world.table = setmetatable({ wipe = function(value) for k in pairs(value) do value[k] = nil end end }, { __index = table })
    world.C_ActionBar = { ShouldShowKeyring = function() return showKeyring end }
    world.C_GameRules = { IsGameRuleActive = function(rule) return rule == "HousingDashboardDisabled" or (rule == "StoreDisabled" and not showKeyring) end }
    world.EventRegistry = { TriggerEvent = noop, RegisterFrameEventAndCallback = noop, UnregisterFrameEventAndCallback = noop, UnregisterCallback = noop }
    world.Enum = { UICursorType = { Item = 1, Merchant = 2, GuildBank = 3 }, GameRule = setmetatable({}, { __index = function(_, key) return key end }) }
    world.GameRulesUtil = { EJIsDisabled = function() return true end }
    local function load(path, ns)
        local chunk = assert(loadfile(path)); setfenv(chunk, world); chunk("QUI_ActionBars", ns)
    end
    load(corpus .. "Blizzard_MicroMenu/Shared/MicroMenuUtil.lua")
    load(corpus .. "Blizzard_MicroMenu/Shared/MicroMenuContainer.lua")
    load(corpus .. "Blizzard_MicroMenu/Camelot/MicroMenuContainerOverrides.lua")
    load(corpus .. "Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagManager.lua")
    local microNames = { "Character", "Profession", "Spellbook", "Talent", "Legacy", "QuestLog", "Housing", "Guild", "LFD", "Collections", "EJ", "Help", "Store", "MainMenu", "PlayerSpells", "Achievement" }
    local clicks = {}
    world.MicroMenuContainer = frame("MicroMenuContainer", world.UIParent)
    world.MicroMenu = frame("MicroMenu", world.MicroMenuContainer)
    for name, callback in pairs(world.MicroMenuMixin) do world.MicroMenu[name] = callback end
    world.MicroMenu.BorderArt, world.MicroMenu.BackgroundArt = frame(), frame()
    world.MicroMenu.Layout = noop
    world.MicroMenuContainer.Layout = noop
    for _, prefix in ipairs(microNames) do
        local button = frame(prefix .. "MicroButton", world.MicroMenu)
        button.scripts.OnClick = function() clicks[#clicks + 1] = prefix end
        button:SetPoint("CENTER", world.MicroMenu, "CENTER", 0, 0)
    end
    local storeFile = assert(io.open(corpus .. "Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua"))
    local storeSource = storeFile:read("*a"); storeFile:close()
    world.StoreMicroButtonMixin = {}
    local storeChunk = assert(loadstring(assert(storeSource:match("(function StoreMicroButtonMixin:UpdateMicroButton%b().-\nend)"))))
    setfenv(storeChunk, world); storeChunk()
    world.Kiosk = { IsEnabled = function() return false end }
    world.C_CatalogShop = { IsShop2Enabled = function() return false end, HasNewProducts = function() return false end }
    world.C_StorePublic = { IsEnabled = function() return storeAvailable end }
    world.C_PlayerInfo = { IsPlayerNPERestricted = function() return false end }
    world.GetCurrentRegionName = function() return "CN" end
    world.StoreFrame_IsShown = function() return false end
    world.EnableMicroButtons, world.DisableMicroButtons = noop, noop
    methods.SetNormal, methods.SetPushed, methods.SetHasNotification, methods.Enable, methods.Disable = noop, noop, noop, noop, noop
    world.StoreMicroButton.UpdateMicroButton = world.StoreMicroButtonMixin.UpdateMicroButton
    world.UpdateMicroButtons = function() world.StoreMicroButton:UpdateMicroButton() end
    world.MicroMenu:InitializeButtons()
    assert(world.SpellbookMicroButton.layoutIndex and world.TalentMicroButton.layoutIndex and world.LegacyMicroButton.layoutIndex)
    assert(not world.HousingMicroButton.layoutIndex and not world.EJMicroButton.layoutIndex)
    world.BagsBar = frame("BagsBar", world.UIParent)
    world.BagsBar.Layout = noop
    world.MainMenuBarBagManager.allBagButtons = {}
    local bagNames = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }
    for _, name in ipairs(bagNames) do
        local button = frame(name, world.BagsBar)
        button.scripts.OnClick = function() clicks[#clicks + 1] = name end
        world.MainMenuBarBagManager:RegisterBagButton(button)
    end
    if not showKeyring then world.KeyRingButton:Hide() end
    local settings = { enabled = true, clickthrough = true, iconSize = 36, buttonSpacing = 2,
        ownedLayout = { columns = 3, iconCount = 20, buttonSize = 40, buttonSpacing = 4 } }
    local db = { global = { iconSize = 36, buttonSpacing = 2 }, bars = { microbar = settings, bags = settings } }
    local core = { db = { profile = { actionBars = db } } }
    local ns = {
        Client = { isForever = true, restrictedExecutionUnavailable = true },
        Addon = frame(),
        Helpers = { GetCore = function() return core end, CreateDBGetter = function() return function() return db end end,
            SafeToNumber = function(v, default) return tonumber(v) or default end,
            CreateStateTable = function() local states = {}; return states, function(f) states[f] = states[f] or {}; return states[f] end end },
        SafeCallMethod = function(_, object, key, ...) return pcall(object[key], object, ...) end,
    }
    for _, name in ipairs({ "env", "", "helpers", "builder", "layout", "native" }) do
        load("QUI_ActionBars/actionbars/actionbars" .. (name == "" and "" or "_" .. name) .. ".lua", ns)
    end
    local env, owned = ns.ActionBarsEnv, ns.ActionBarsOwned
    owned.InitializeTooltipSuppression = noop
    env.ApplyAllFlyoutDirections = noop
    env.SetupOwnedBarMouseover = noop
    env.HideManagedBlizzardBarFrame = function(f) f:Hide() end
    owned:InitializeNativeBars()
    assert(owned.nativeEventFrame.events.PET_BATTLE_CLOSE, "context exit must refresh utility bars")
    local micro, bags = assert(owned.containers.microbar), assert(owned.containers.bags)
    local contextDriver = "[overridebar][vehicleui][possessbar][petbattle] hide; show"
    assert(visibilityDrivers[micro] == contextDriver and visibilityDrivers[bags] == contextDriver,
        "native visibility driver must hide utility controls during override/vehicle/possess/pet contexts")
    assert(world.MicroMenu.BorderArt.alpha == 0 and world.MicroMenu.BackgroundArt.alpha == 0)
    local activeMicro, activeBags = assert(owned.nativeButtons.microbar), assert(owned.nativeButtons.bags)
    local function includes(list, button) return world.tContains(list, button) end
    for _, prefix in ipairs({ "Spellbook", "Talent", "Legacy" }) do
        local button = world[prefix .. "MicroButton"]
        assert(includes(activeMicro, button) and button:GetParent() == micro, "Forever micro controls must be reclaimed")
        assert(button.mouse == false, "QUI clickthrough applies")
    end
    for _, prefix in ipairs({ "PlayerSpells", "Achievement", "Housing", "EJ" }) do
        assert(not includes(activeMicro, world[prefix .. "MicroButton"]), "dormant or disabled native controls must stay excluded: " .. prefix)
    end
    assert(includes(activeMicro, world.StoreMicroButton) == showKeyring, "Store membership follows native initialization")
    assert(includes(activeMicro, world.HelpMicroButton) == (not showKeyring), "Help occupies its own slot when Store is disabled")
    if not showKeyring then assert(world.HelpMicroButton:IsShown() and world.HelpMicroButton:GetParent() == micro) end
    assert(includes(activeBags, world.KeyRingButton) == showKeyring, "keyring capability must match native bag inventory")
    assert(#activeBags == (showKeyring and 7 or 6), "native bags must include every active slot")
    for _, button in ipairs(activeBags) do
        assert(button:GetParent() == bags and not button.mouse, "saved bag clickthrough applies")
        button.scripts.OnClick()
    end
    assert(#clicks == #activeBags, "native bag click handlers survive takeover")
    assert(micro.width == 128 and bags.width == 128, "QUI columns, button size and spacing control utility geometry")
    assert(owned.cachedLayouts.microbar.numCols == 3 and owned.cachedLayouts.bags.numCols == 3)
    if showKeyring then
        storeAvailable = false
        world.UpdateMicroButtons()
        assert(not world.StoreMicroButton:IsShown() and world.HelpMicroButton:IsShown(),
            "native runtime Store unavailability must expose Help instead of forcing Store visible")
        assert(world.HelpMicroButton.mouse == false, "Help fallback obeys QUI clickthrough")
        owned:RefreshNativeBars()
        assert(not world.StoreMicroButton:IsShown() and world.HelpMicroButton:IsShown(), "refresh preserves native Store visibility")
        storeAvailable = true
        world.UpdateMicroButtons()
        assert(world.StoreMicroButton:IsShown() and not world.HelpMicroButton:IsShown(), "native Store recovery hides Help fallback")
    end
    local context = frame("NativeContext", world.UIParent)
    world.MicroMenu:SetParent(context)
    assert(world.MicroMenu.BorderArt.alpha == 1 and world.MicroMenu.BackgroundArt.alpha == 1)
    assert(world.HelpMicroButton.mouse, "native context must restore Help mouse input even when it shares the Store slot")
    for _, button in ipairs(activeMicro) do assert(button:GetParent() == world.MicroMenu and button.mouse, "native context must regain micro controls") end
    world.MicroMenu:SetParent(world.UIParent)
    assert(world.MicroMenu.BorderArt.alpha == 0 and world.MicroMenu.BackgroundArt.alpha == 0)
    for _, button in ipairs(activeMicro) do assert(button:GetParent() == micro and not button.mouse, "QUI must reclaim controls after context ends") end
    world.SpellbookMicroButton.parent = world.MicroMenu
    combat = true
    world.MicroMenu:Layout()
    assert(world.SpellbookMicroButton:GetParent() == world.MicroMenu, "micro reparent waits for combat")
    combat = false
    local regen = ns.Addon.events.PLAYER_REGEN_ENABLED
    assert(type(regen) == "function", "micro recovery must register regen callback")
    regen()
    if owned._microLayoutFrame and owned._microLayoutFrame.scripts.OnEvent then
        owned._microLayoutFrame.scripts.OnEvent(owned._microLayoutFrame, "PLAYER_REGEN_ENABLED")
    end
    assert(world.SpellbookMicroButton:GetParent() == micro, "regen callback reclaims native micro parent")
    world.CharacterBag0Slot.parent = world.BagsBar
    world.BagsBar:Layout()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
    assert(world.CharacterBag0Slot:GetParent() == bags, "native bag relayout must restore QUI parent")
    settings.enabled = false
    owned:RefreshNativeBars()
    assert(visibilityDrivers[micro] == "hide" and visibilityDrivers[bags] == "hide", "disabled utility bars must stay hidden")
    settings.enabled = true
    combat = true
    settings.ownedLayout.columns = 2
    owned:RefreshNativeBars()
    assert(owned.pendingRefresh and micro.width == 128, "settings refresh defers geometry during combat")
    combat = false
    owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
    pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
    assert(not owned.pendingRefresh and micro.width == 84 and bags.width == 84, "regen applies utility layout changes")
    assert(visibilityDrivers[micro] == contextDriver and visibilityDrivers[bags] == contextDriver)
    world.MicroMenu:SetParent(context)
    assert(select(2, world.TalentMicroButton:GetPoint()) == world.MicroMenu
        and select(4, world.TalentMicroButton:GetPoint()) == 0,
        "repeated refresh must preserve native anchors for context handoff")
    world.MicroMenu:SetParent(world.UIParent)
    world.CharacterBag0Slot.parent = world.BagsBar
    combat = true
    world.BagsBar:Layout()
    assert(owned.pendingBagsReclaim and world.CharacterBag0Slot:GetParent() == world.BagsBar)
    combat = false
    owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
    pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
    assert(not owned.pendingBagsReclaim and world.CharacterBag0Slot:GetParent() == bags, "regen restores deferred bag takeover")
    settings.ownedLayout.iconCount = 0
    owned:RefreshNativeBars()
    for _, buttons in ipairs({ activeMicro, activeBags }) do
        for _, button in ipairs(buttons) do
            assert(not button:IsShown(), "zero-count utility layout hides native controls")
            assert(not visibilityDrivers[button], "utility buttons must not acquire persistent visibility drivers")
        end
    end
    assert(not world.HelpMicroButton:IsShown(), "zero-count layout hides Help fallback")
    settings.ownedLayout.iconCount = 20
    owned:RefreshNativeBars()
    for _, button in ipairs(activeBags) do assert(button:IsShown(), "restoring count restores native bag controls") end
    assert(world.SpellbookMicroButton:IsShown() and world.TalentMicroButton:IsShown(), "restoring count restores native micro controls")
    settings.clickthrough = false
    owned:RefreshNativeBars()
    for _, buttons in ipairs({ activeMicro, activeBags }) do
        for _, button in ipairs(buttons) do assert(button.mouse, "refresh restores mouse input when clickthrough is disabled") end
    end
    core.db.profile.layoutMode = { hiddenHandles = { microMenu = true, bagBar = true } }
    owned:RefreshNativeBars()
    assert(visibilityDrivers[micro] == "hide" and visibilityDrivers[bags] == "hide", "native utility layout keys respect hidden handles")
end

run(true)
run(false)
print("OK forever_utility_bars_test")
