local sourceRoot = os.getenv("QUI_CDM_TEST_SOURCE_ROOT") or "."
local function ReadSource(path)
    local file = assert(io.open(sourceRoot .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local combat, mounted, flying, form = false, false, false, 0
local secure = false
local dungeon = false
local visualRefreshes = 0
local registrations, frames = {}, {}
local formSpells = { 768, 783, 5487, 33943, 40120, 1066 }
local settings = { showInCombat = true, showAlways = false, hideWhenMounted = true }
local profile = { cdmVisibility = settings, ncdm = { enabled = true } }

local function CheckWrite()
    assert(not combat or secure, "protected button mutated by ordinary Lua during combat")
end

local function NewFrame()
    local frame = { attributes = {}, scripts = {}, shown = true, mouse = true, alpha = 1 }
    function frame:SetAttribute(name, value) CheckWrite(); self.attributes[name] = value end
    function frame:GetAttribute(name) return self.attributes[name] end
    function frame:EnableMouse(enabled)
        CheckWrite()
        if enabled and self.expectedRefresh then
            assert(visualRefreshes > self.expectedRefresh, "combat restoration must refresh visible CDM before enabling clicks")
            self.expectedRefresh = nil
        end
        self.mouse = enabled
    end
    function frame:SetMouseClickEnabled(enabled) CheckWrite(); self.mouse = enabled end
    function frame:SetMouseMotionEnabled() CheckWrite() end
    function frame:Show() CheckWrite(); self.shown = true end
    function frame:Hide() CheckWrite(); self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:GetAlpha() return self.alpha end
    function frame:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function frame:GetParent() return self.parent end
    function frame:RegisterEvent() end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    function frame:RunAttribute(name, ...)
        local callback = assert(loadstring("return function(self, ...) " .. self.attributes[name] .. " end"))()
        return callback(self, ...)
    end
    function frame:CallMethod(name, ...)
        local wasSecure = secure
        secure = false
        self[name](self, ...)
        secure = wasSecure
    end
    frames[#frames + 1] = frame
    return frame
end

local function Matches(condition)
    for term in condition:gmatch("[^,]+") do
        local invert = term:sub(1, 2) == "no"
        if invert then term = term:sub(3) end
        local name, argument = term:match("^([^:]+):?(.*)$")
        local value
        if name == "combat" then value = combat
        elseif name == "mounted" then value = mounted
        elseif name == "flying" then value = flying
        elseif name == "form" or name == "stance" then
            value = argument == "" and form ~= 0
            for index in argument:gmatch("%d+") do
                if form == tonumber(index) then value = true end
            end
        else error("unsupported test conditional: " .. term) end
        if invert then value = not value end
        if not value then return false end
    end
    return true
end

local function ParseDriver(driver)
    for clause in driver:gmatch("[^;]+") do
        local result = clause:gsub("%b[]", ""):match("^%s*(.-)%s*$")
        local conditional, matches = false, false
        for condition in clause:gmatch("%[([^%]]+)%]") do
            conditional = true
            matches = matches or Matches(condition)
        end
        if not conditional or matches then return result end
    end
end

local function EvaluateDrivers()
    secure = true
    for button, driver in pairs(registrations) do
        local state = ParseDriver(driver)
        if button:GetAttribute("state-quiclick") ~= state then
            button:SetAttribute("state-quiclick", state)
            if state == "shown" then button.expectedRefresh = visualRefreshes end
            local snippet = assert(button:GetAttribute("_onstate-quiclick"), "secure click state handler missing")
            local handler = assert(loadstring("return function(self, newstate) " .. snippet .. " end"))()
            handler(button, state)
        end
    end
    secure = false
end

InCombatLockdown = function() return combat end
UnitAffectingCombat = function() return combat end
GetNumShapeshiftForms = function() return #formSpells end
GetShapeshiftFormInfo = function(index) return nil, form == index, true, formSpells[index] end
GetShapeshiftForm = function() return form end
IsMounted = function() return mounted end
IsFlying = function() return flying end
issecretvalue = function() return false end
CreateFrame = function() return NewFrame() end
RegisterStateDriver = function(button, state, driver)
    CheckWrite()
    assert(state == "quiclick")
    registrations[button] = driver
    EvaluateDrivers()
end
UnregisterStateDriver = function(button, state)
    CheckWrite()
    assert(state == "quiclick")
    registrations[button] = nil
end

local ns = {
    Addon = { db = { profile = profile } },
    Helpers = {
        GetCore = function() return { db = { profile = profile } } end,
        CreateStateTable = function() return {} end,
        IsEditModeActive = function() return false end,
        IsLayoutModeActive = function() return false end,
        IsPlayerInDungeonOrRaid = function() return dungeon end,
    },
    CDMIconFactory = { GetIconPool = function() return {} end },
    RefreshCDMVisibilityInstant = function()
        assert(not secure, "CallMethod must leave the restricted execution context")
        visualRefreshes = visualRefreshes + 1
    end,
}
ns.RefreshCDMVisibilityForClick = ns.RefreshCDMVisibilityInstant

local container = NewFrame()
container.alpha = 0
local icon = NewFrame()
icon._quiCdmClickSlot = true
icon._quiCdmClickViewerType = "essential"
icon.parent = container
icon.clickButton = NewFrame()
icon.clickButton.parent = icon
function container:GetChildren() return icon end
local containers = { essential = container, utility = container }
ns.CDMContainers = { GetContainer = function(_, key) return containers[key] end }
ns.CDMContainers_API = ns.CDMContainers

local module = loadfile(sourceRoot .. "/QUI_CDM/cdm/cdm_click_visibility.lua")
if module then module("QUI_CDM", ns) end

local source = ReadSource("QUI_CDM/cdm/cdm_containers.lua")
local start = assert(source:find("local function SetFrameMouseDisabled", 1, true))
local finish = assert(source:find("local function SyncContainerBarsForVisibility", start, true))
local loader = assert(loadstring("return function(ns, containers)\n"
    .. source:sub(start, finish - 1)
    .. "return SyncContainerIconsForVisibility end"))()
local syncContainer = loader(ns, containers)
syncContainer("essential", true, false)
assert(icon.clickButton.mouse == false, "alpha-zero native CDM click slot must ignore clicks")
assert(icon.clickButton.shown, "autohide must leave the action button shown so combat can restore input")
assert(type(ns.SyncCDMClickVisibility) == "function")

combat = true
EvaluateDrivers()
assert(icon.clickButton.mouse, "entering combat directly from alpha zero must restore clicks")
mounted = true
EvaluateDrivers()
assert(not icon.clickButton.mouse, "mounted combat must remain nonclickable")
mounted = false
EvaluateDrivers()
assert(icon.clickButton.mouse, "dismounting during combat must restore clicks")
for _, index in ipairs({ 2, 4, 5, 6 }) do
    form = index
    EvaluateDrivers()
    assert(not icon.clickButton.mouse, "travel/flight form must remain nonclickable in combat")
end
form = 1
EvaluateDrivers()
assert(icon.clickButton.mouse, "cat form must not count as mounted")
form = 0
local before = icon.clickButton.mouse
ns.SyncCDMClickVisibility(icon, true)
ns.RefreshCDMClickVisibility()
assert(icon.clickButton.mouse == before, "ordinary combat refresh must not override secure input state")

combat = false
container.alpha = 0
ns.SyncCDMClickVisibility(icon, true)
EvaluateDrivers()
assert(not icon.clickButton.mouse, "leaving combat while alpha zero must suppress clicks again")
container.alpha = 1
ns.SyncCDMClickVisibility(icon, false)
assert(icon.clickButton.mouse, "visible out-of-combat alpha must restore clicks")
assert(not icon.mouse, "click-slot host must not intercept clicks independently of its action button")

local acquired = NewFrame()
acquired._spellEntry = { viewerType = "utility" }
acquired.parent = container
acquired.clickButton = NewFrame()
container.alpha = 0
assert(ns.SyncCDMClickVisibility(acquired), "ordinary utility icons must use the same secure click policy")
assert(not acquired.clickButton.mouse, "a newly acquired button must inherit alpha-zero click suppression")
combat = true
EvaluateDrivers()
assert(acquired.clickButton.mouse, "newly acquired alpha-zero button must recover directly in combat")
combat = false

icon.clickButton:Hide()
ns.SyncCDMClickVisibility(icon, true)
combat = true
EvaluateDrivers()
assert(not icon.clickButton.shown, "secure autohide must not show an invalid or released action button")
combat = false
icon.clickButton:Show()

local restricted = NewFrame()
restricted._quiLayoutRestricted = true
restricted._spellEntry = { viewerType = "essential" }
restricted.clickButton = NewFrame()
assert(ns.SyncCDMClickVisibility(restricted, true) == false, "native restricted icons must remain outside managed clicks")
assert(restricted.clickButton.mouse, "excluded icon must remain untouched")

settings.hideWhenFlying = true
ns.RefreshCDMClickVisibility()
combat, mounted, flying = true, true, true
EvaluateDrivers()
assert(not icon.clickButton.mouse, "Soar's observed mounted/flying state must suppress clicks in combat")
mounted = false
EvaluateDrivers()
assert(not icon.clickButton.mouse, "the flying hide rule must independently suppress clicks")
flying = false
EvaluateDrivers()
assert(icon.clickButton.mouse, "leaving Soar in combat must restore clicks")
combat = false

settings.dontHideInDungeonsRaids = true
dungeon = true
ns.RefreshCDMClickVisibility()
combat, mounted = true, true
EvaluateDrivers()
assert(icon.clickButton.mouse, "dungeon exemption must override mounted hiding")
combat, mounted, dungeon = false, false, false
ns.RefreshCDMClickVisibility()
combat, mounted = true, true
EvaluateDrivers()
assert(not icon.clickButton.mouse, "leaving dungeon must restore mounted hiding")
combat, mounted = false, false
settings.dontHideInDungeonsRaids = false

formSpells = { 783, 768, 5487 }
ns.RefreshCDMClickVisibility()
combat, form = true, 1
EvaluateDrivers()
assert(not icon.clickButton.mouse, "changed travel-form slot must be recompiled on refresh")
form = 2
EvaluateDrivers()
assert(icon.clickButton.mouse, "former travel slot must not hide cat form after reorder")
combat, form = false, 0

settings.fadeOutAlpha = 0.25
container.alpha = 0.25
ns.RefreshCDMClickVisibility()
combat, mounted = true, true
EvaluateDrivers()
assert(icon.clickButton.mouse, "partially visible mounted icons must retain clicks")
combat, mounted = false, false
settings.fadeOutAlpha = 0
profile.ncdm.enabled = false
ns.RefreshCDMClickVisibility()
combat = true
EvaluateDrivers()
assert(not icon.clickButton.mouse, "disabled CDM must remain nonclickable in combat")
combat = false
profile.ncdm.enabled = true

ns.SyncCDMClickVisibility(icon, true)
settings.showWhenHealthBelow100 = true
syncContainer("essential", false, false)
assert(icon.clickButton.mouse, "switching to unsupported visibility settings must not strand a suppressed button")
assert(registrations[icon.clickButton] == nil, "unsupported settings must remove the secure driver")

local renderer = ReadSource("QUI_CDM/cdm/cdm_icon_renderer.lua")
local ensureStart = assert(renderer:find("local function EnsureClickButton(icon)", 1, true))
local ensureFinish = assert(renderer:find("\nlocal function ", ensureStart + 1, true))
local updateStart = assert(renderer:find("UpdateIconSecureAttributes = function", 1, true))
local updateFinish = assert(renderer:find("function CDMIcons.UpdateSecureClickOverlay", updateStart, true))
local restoreStart = assert(renderer:find("function CDMIcons.OnContainerIconInteractionRestored", 1, true))
local restoreFinish = assert(renderer:find("function CustomCDM:GetIcons", restoreStart, true))
local clickable = true
ns.CDMIcons = { EnsureTextOverlayLevel = function() end }
assert(loadstring("return function(ns, CDMIcons, GetTrackerSettings)\n"
    .. "local function SyncClickButtonFrameLevel() end\n"
    .. "local function ClearClickButtonAttributes(button) button:SetAttribute('type', nil) end\n"
    .. "local UpdateIconSecureAttributes\n"
    .. renderer:sub(ensureStart, ensureFinish - 1)
    .. renderer:sub(updateStart, updateFinish - 1)
    .. renderer:sub(restoreStart, restoreFinish - 1)
    .. "end"))()(ns, ns.CDMIcons, function() return { clickableIcons = clickable } end)
local actualRestore = ns.CDMIcons.OnContainerIconInteractionRestored
local restoreCalls = 0
ns.CDMIcons.OnContainerIconInteractionRestored = function(...)
    restoreCalls = restoreCalls + 1
    assert(restoreCalls <= 2, "adopting a legacy suppressed button must not recurse through action restoration")
    return actualRestore(...)
end
icon._spellEntry = { type = "macro", macroName = "Test Click" }
container.alpha = 0
syncContainer("essential", true, false)
assert(not icon.clickButton.shown, "legacy unsupported path must reproduce hidden button state")
local initiallyUnsupported = NewFrame()
initiallyUnsupported._spellEntry = { viewerType = "utility" }
initiallyUnsupported.parent = container
initiallyUnsupported.clickButton = NewFrame()
assert(not ns.SyncCDMClickVisibility(initiallyUnsupported, true))
settings.showWhenHealthBelow100 = false
ns.RefreshCDMClickVisibility()
assert(icon.clickButton.shown, "adopting a legacy suppressed action must restore its shown state")
assert(not icon.clickButton.mouse, "adopted legacy action must remain nonclickable at alpha zero")
assert(restoreCalls == 1, "legacy adoption must restore the action exactly once")
assert(registrations[initiallyUnsupported.clickButton], "config refresh must activate previously unsupported tracked icons")
assert(not initiallyUnsupported.clickButton.mouse, "config activation must preserve alpha-zero suppression")
combat = true
EvaluateDrivers()
assert(icon.clickButton.mouse and icon.clickButton.shown, "adopted action must work when entering combat")
combat = false
clickable = false
ns.CDMIcons.OnContainerIconInteractionRestored(icon, "essential")
assert(not icon.clickButton.shown, "disabled click setting must hide the action button")
ns.RefreshCDMClickVisibility()
combat = true
EvaluateDrivers()
assert(not icon.clickButton.shown, "refresh and combat must not resurrect clicks disabled by configuration")
combat = false

local mountedSource = ReadSource("core/utils.lua")
local mountedStart = assert(mountedSource:find("function Helpers.IsPlayerMounted()", 1, true))
local mountedFinish = assert(mountedSource:find("function Helpers.IsPlayerFlying()", mountedStart, true))
local helpers = { IsPlayerPassenger = function() return false end }
assert(loadstring("return function(Helpers) " .. mountedSource:sub(mountedStart, mountedFinish - 1) .. " end"))()(helpers)
C_UnitAuras = nil
for _, formID in ipairs({ 3, 4, 27, 29 }) do
    GetShapeshiftFormID = function() return formID end
    assert(helpers.IsPlayerMounted(), "visibility rules must recognize travel/aquatic/flight form ID " .. formID)
end
GetShapeshiftFormID = function() return 1 end
assert(not helpers.IsPlayerMounted(), "non-travel shapeshift must not be treated as mounted")

do
    local hudSource = ReadSource("QUI_CDM/cdm/hud_visibility.lua")
    local cacheStart = assert(hudSource:find("local _cdmFramesCache =", 1, true))
    local cacheFinish = assert(hudSource:find("local function GetCustomTrackerFrames", cacheStart, true))
    local snapStart = assert(hudSource:find("function VisibilityController:Snap()", 1, true))
    local snapFinish = assert(hudSource:find("function VisibilityController:MouseoverEnabled()", snapStart, true))
    local refreshStart = assert(hudSource:find("ns.RefreshCDMVisibilityInstant =", 1, true))
    local refreshFinish = assert(hudSource:find("_G.QUI_RefreshCustomTrackersVisibility =", refreshStart, true))
    local refreshes, rebuilds = 0, 0
    local targetAlpha = 1
    local host = NewFrame()
    host.alpha = 0
    local clickNS = {
        Addon = ns.Addon,
        Helpers = ns.Helpers,
        CDMProvider = {
            GetViewerFrames = function()
                rebuilds = rebuilds + 1
                return { host }
            end,
        },
    }
    local controller = {
        isFading = false,
        currentlyHidden = true,
        fadeTargetAlpha = 0,
        applyAlpha = function(targets, alpha)
            for _, frame in ipairs(targets) do frame.alpha = alpha end
        end,
    }
    local invalidate = assert(loadstring("return function(ns, CDMVisibility, UpdateCDMVisibility)\n"
        .. "local QUICore = ns.Addon\n"
        .. "local function wipe(t) for k in pairs(t) do t[k] = nil end end\n"
        .. "local function ReadNumber(value, fallback) return value or fallback end\n"
        .. "local VisibilityController = CDMVisibility\n"
        .. hudSource:sub(cacheStart, cacheFinish - 1)
        .. hudSource:sub(snapStart, snapFinish - 1)
        .. "CDMVisibility.getFrames = GetCDMFrames\n"
        .. "local function SnapCDMFadeToTarget() CDMVisibility:Snap() end\n"
        .. hudSource:sub(refreshStart, refreshFinish - 1)
        .. "return InvalidateCDMFrameCache end"))()(clickNS, controller, function()
            assert(not secure, "global visibility work must run outside restricted execution")
            refreshes = refreshes + 1
            controller.fadeTargetAlpha = targetAlpha
        end)
    assert(loadfile(sourceRoot .. "/QUI_CDM/cdm/cdm_click_visibility.lua"))("QUI_CDM", clickNS)
    registrations = {}
    local buttons = {}
    for i = 1, 20 do
        local hostIcon = NewFrame()
        hostIcon._spellEntry = { viewerType = "utility" }
        hostIcon.parent = host
        local button = NewFrame()
        button.parent = hostIcon
        hostIcon.clickButton = button
        clickNS.SyncCDMClickVisibility(hostIcon, true)
        local enableMouse = button.EnableMouse
        function button:EnableMouse(enabled)
            if enabled then
                assert(host.alpha > 0.001, "CDM must be visible before any secure button enables clicks")
            end
            enableMouse(self, enabled)
        end
        buttons[i] = button
    end
    local function ShowAll()
        combat, secure = true, true
        for _, button in ipairs(buttons) do
            local snippet = button:GetAttribute("_onstate-quiclick")
            assert(loadstring("return function(self, newstate) " .. snippet .. " end"))()(button, "shown")
        end
        combat, secure = false, false
    end
    ShowAll()
    assert(refreshes == 1 and rebuilds == 1, "twenty secure buttons must share one global visibility refresh and frame-cache rebuild")
    host.alpha, controller.fadeTargetAlpha, controller.currentlyHidden = 0, 0, true
    ShowAll()
    assert(refreshes == 2 and rebuilds == 2, "a later hidden-to-shown transition must refresh once again")
    invalidate()
    ShowAll()
    assert(refreshes == 3 and rebuilds == 3, "dirty visible frame cache must refresh exactly once")
    controller.isFading = true
    ShowAll()
    assert(refreshes == 4 and rebuilds == 4 and not controller.isFading, "an active fade must snap once before clicks")
    targetAlpha, host.alpha, controller.fadeTargetAlpha, controller.currentlyHidden = 0.25, 0.25, 0.25, true
    ShowAll()
    assert(refreshes == 4 and rebuilds == 4, "stable partially visible CDM must not trigger repeated refreshes")
    clickNS.RefreshCDMVisibilityInstant()
    clickNS.RefreshCDMVisibilityInstant()
    assert(refreshes == 6 and rebuilds == 6, "ordinary instant-refresh callers must remain unconditional")
end

print("PASS: cdm_secure_click_visibility_test")
