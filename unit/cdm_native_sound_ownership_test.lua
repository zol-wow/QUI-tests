local function loadNativeMethod(file, name)
    local path = "tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/" .. file
    local handle = assert(io.open(path, "rb"))
    local source = handle:read("*a"):gsub("\r\n", "\n")
    handle:close()
    local first = assert(source:find("function " .. name .. "(", 1, true))
    local last = assert(source:find("\nend", first, true))
    assert(loadstring(source:sub(first, last + 3), "@" .. path))()
end

function wipe(t) for key in pairs(t) do t[key] = nil end end
function assertsafe(value, ...) assert(value, ...) end
function tCompare(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
Enum = {
    CooldownViewerAlertType = { Sound = 0, Visual = 1 },
    CooldownViewerAlertEventType = { Available = 0, PandemicTime = 1, OnCooldown = 2,
        ChargeGained = 3, OnAuraApplied = 4, OnAuraRemoved = 5 },
    CooldownViewerAlertEventTypeMeta = { MinValue = 0, MaxValue = 5 },
    CooldownViewerAddAlertStatus = { Success = 0, InvalidAlertType = 1, InvalidEventType = 2, AlertAlreadyExists = 3 },
    CooldownLayoutStatus = { Success = 0, TooManyAlerts = 4 },
    CooldownViewerSound = { TextToSpeech = 0 },
    CDMLayoutMode = { AccessOnly = 0, AllowCreate = 1 },
    UnitAuraSoundTrigger = { Added = 0, Removed = 2 },
}
InCombatLockdown = function() return false end
C_Timer = { After = function() end }
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
local notifications, serializationReads = 0, 0
EventRegistry = {
    RegisterCallback = function() end,
    TriggerEvent = function(_, event)
        if event == "CooldownViewerSettings.OnDataChanged" then notifications = notifications + 1 end
    end,
}
C_CooldownViewer = { GetValidAlertTypes = function() return { 4, 5 } end }
CooldownViewerSoundData = { { { soundEnum = 3, soundKitID = 33, text = "Bell" } } }
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerAlert.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsLayoutManager.lua"))()
CooldownViewerDataStoreSerializationMixin = {}
CooldownViewerSettingsDataProviderMixin = {}
CooldownViewerSettingsMixin = {}
for _, method in ipairs({ "IsLoaded", "GetSerializedData" }) do
    loadNativeMethod("CooldownViewerSettingsDataStoreSerialization.lua", "CooldownViewerDataStoreSerializationMixin:" .. method)
end
loadNativeMethod("CooldownViewerSettingsDataProvider.lua", "CooldownViewerSettingsDataProviderMixin:GetLayoutManager")
for _, method in ipairs({ "GetDataProvider", "GetLayoutManager" }) do
    loadNativeMethod("CooldownViewerSettings.lua", "CooldownViewerSettingsMixin:" .. method)
end

local serializer = setmetatable({ persistenceObject = { GetSerializedData = function()
    serializationReads = serializationReads + 1
    return "native saved layouts"
end } }, { __index = _G.CooldownViewerDataStoreSerializationMixin })
local layout = { layoutID = 1 }
local manager = setmetatable({ layouts = { [1] = layout }, activeLayoutID = 1, serializer = serializer },
    { __index = _G.CooldownViewerLayoutManagerMixin })
local provider = setmetatable({ layoutManager = manager }, { __index = _G.CooldownViewerSettingsDataProviderMixin })
CooldownViewerSettings = setmetatable({ dataProvider = provider, layoutManager = manager },
    { __index = _G.CooldownViewerSettingsMixin })
local containers = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Addon = { db = { profile = { ncdm = {} }, char = {} } },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    CDMContainers = { GetContainers = function() return containers end },
    CDMCustomAuraRuns = { ResolveAuraConfig = function(entry)
        return { unit = "player", includeSpellIDs = { [entry.id] = true } }
    end },
}
local function reload()
    assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI_CDM", ns)
    return ns.CDMAlerts
end
local failures = {}
local function check(value, message)
    if not value then failures[#failures + 1] = message end
end
local alerts = reload()
alerts.ReconcileNativeSounds()
check(serializer.cachedSerializedData == nil and serializationReads == 0,
    "Cold reconciliation must not populate the native serializer cache")

local kit = { id = 123, cooldownID = 123, quiAlerts = {
    auraApplied = { enabled = true, mode = "sound", sound = "kit:3" },
} }
local tts = { id = 124, cooldownID = 124, quiAlerts = {
    auraApplied = { enabled = true, mode = "tts", text = "Custom words" },
} }
containers = { { key = "buff", settings = { ownedSpells = { kit, tts } } } }
provider.displayData = { cooldownInfoByID = {}, orderedCooldownIDs = {} }
provider.displayDataDirty = false
serializer.cachedSerializedData = nil
serializationReads, notifications = 0, 0
alerts.ReconcileNativeSounds()
check(layout.cooldownInfo == nil, "Sound selection must not create native cooldown blocks or alerts")
check(not manager.hasPendingChanges and notifications == 0,
    "Sound selection must not dirty native layouts or notify native viewer rebuilds")
check(serializer.cachedSerializedData == nil and serializationReads == 0,
    "Ready reconciliation must not populate the native serializer cache")
check(not alerts.IsNativeSoundRegistered(kit, "auraApplied") and not alerts.IsNativeSoundRegistered(tts, "auraApplied"),
    "Missing native kit and TTS alerts must remain unregistered")
check(type(alerts.GetNativeSoundStatus("buff", kit, "auraApplied")) == "string",
    "Missing native alerts must explain that Blizzard settings need configuration")

local kitAlert, ttsAlert = { 0, 4, 3 }, { 0, 4, 0 }
layout.cooldownInfo = { [123] = { alerts = { kitAlert } }, [124] = { alerts = { ttsAlert } } }
ns.Addon.db.char.cdmNativeSoundAlerts = {
    legacy = { layoutID = 1, cooldownID = 123, event = 4, payload = 3 },
}
manager.hasPendingChanges = nil
serializer.cachedSerializedData = nil
serializationReads, notifications = 0, 0
alerts = reload()
alerts.ReconcileNativeSounds()
check(alerts.IsNativeSoundRegistered(kit, "auraApplied") and alerts.IsNativeSoundRegistered(tts, "auraApplied"),
    "Preexisting native kit and TTS alerts must be recognized from ready snapshots")
alerts.ReconcileNativeSounds(true)
check(layout.cooldownInfo[123].alerts[1] == kitAlert and layout.cooldownInfo[124].alerts[1] == ttsAlert,
    "Disabling QUI alerts must preserve native records including legacy QUI ownership metadata")
check(not manager.hasPendingChanges and notifications == 0,
    "Disabling QUI alerts must not dirty layouts or notify native viewer rebuilds")
check(serializer.cachedSerializedData == nil and serializationReads == 0,
    "Matching and disabling sounds must leave the serializer cache untouched")

layout.cooldownInfo = { [123] = { alerts = { kitAlert } }, [124] = { alerts = { ttsAlert } } }
provider.displayDataDirty = true
alerts = reload()
alerts.ReconcileNativeSounds()
check(not alerts.IsNativeSoundRegistered(kit, "auraApplied"), "Dirty provider snapshots must not register native alerts")
provider.displayDataDirty = false
alerts.ReconcileNativeSounds()
check(alerts.IsNativeSoundRegistered(kit, "auraApplied"), "Native matching must recover when the snapshot is ready")
manager.layouts[2] = { layoutID = 2 }
manager.activeLayoutID = 2
alerts.ReconcileNativeSounds()
check(manager.layouts[2].cooldownInfo == nil and layout.cooldownInfo[123].alerts[1] == kitAlert,
    "Layout switching must neither move nor create native alerts")

serializer.cachedSerializedData = nil
local beforeReads = serializationReads
assert(provider:GetLayoutManager() == manager and serializationReads == beforeReads + 1
    and serializer.cachedSerializedData == "native saved layouts",
    "Native provider readiness must exercise the real serializer cache write")
local beforeNotifications = notifications
assert(manager:AddAlert(125, { 0, 4, 3 }) == Enum.CooldownViewerAddAlertStatus.Success)
assert(manager.layouts[2].cooldownInfo[125].alerts[1][3] == 3 and manager.hasPendingChanges
    and notifications == beforeNotifications + 1,
    "Native AddAlert must exercise real layout writes and viewer notifications")
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: cdm_native_sound_ownership_test")
