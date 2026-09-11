local queued, frames, callbacks = {}, {}, {}
local added, removed, playback = {}, {}, {}
local inCombat, secretAuras, runtimeEnabled = false, false, true
local rejectRegistration = false
local profile = { ncdm = {} }
local containers, specEntries = {}, {}

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
InCombatLockdown = function() return inCombat end
C_Secrets = { ShouldAurasBeSecret = function() return secretAuras end }
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, fn) self[script] = fn end
    frames[#frames + 1] = frame
    return frame
end
EventRegistry = {
    RegisterCallback = function(_, event, fn, owner)
        callbacks[event] = { fn = fn, owner = owner }
    end,
    TriggerEvent = function(_, event, ...)
        local cb = callbacks[event]
        if cb then cb.fn(cb.owner, ...) end
    end,
}
C_UnitAuras = setmetatable({
    AddAuraSound = function(trigger, info)
        assert(not inCombat and not secretAuras)
        if rejectRegistration then return nil end
        added[#added + 1] = { trigger = trigger, info = info }
        return #added
    end,
    RemoveAuraSound = function(id)
        assert(not inCombat and not secretAuras)
        removed[id] = (removed[id] or 0) + 1
    end,
}, { __index = function(_, name) error("Aura data access forbidden: " .. name) end })
C_CooldownViewer = {
    GetValidAlertTypes = function(id)
        return id == 99 and { 0, 2 } or { 4, 5 }
    end,
}
CooldownViewerSoundData = { { { soundEnum = 3, soundKitID = 33, text = "Bell" } } }
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerAlert.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsLayoutManager.lua"))()
local manager = setmetatable({ layouts = { [1] = { layoutID = 1 }, [2] = { layoutID = 2 } }, activeID = 1 },
    { __index = _G.CooldownViewerLayoutManagerMixin })
function manager:IsLoaded() return true end
function manager:GetActiveLayout() return self.layouts[self.activeID] end
function manager:IsUsingDefaultLayout() return false end
function manager:SaveLayouts() error("Must not persist unrelated native settings changes") end
CooldownViewerSettings = { GetLayoutManager = function() return manager end }

local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Addon = { db = { profile = profile } },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    CDMShared = { IsRuntimeEnabled = function() return runtimeEnabled end },
    CDMContainers = { GetContainers = function() return containers end },
    CDMSpellData = { GetSpecEntries = function(_, key) return specEntries[key] end },
    CDMCustomAuraRuns = { ResolveAuraConfig = function(entry)
        return { unit = entry.auraUnit or "player", includeSpellIDs = entry.auraIDs or { [entry.id] = true } }
    end },
    CDMIndex = { Get = function(id) if id < 1000 then return { cooldownID = id } end end },
    LSM = { Fetch = function(_, _, key) if key == "Bell" then return 765432 end end },
    Announce = { PlaySound = function(key) playback[#playback + 1] = key end },
}
assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
local Alerts = ns.CDMAlerts
local function flush()
    local pending = queued
    queued = {}
    for _, fn in ipairs(pending) do fn() end
    assert(#queued == 0, "Native settings notifications must not recursively schedule reconciliation")
end
local function entry(id, sound, mode)
    return { type = "spell", kind = "aura", id = id, name = "Test Aura",
        quiAlerts = { auraApplied = { enabled = true, mode = mode or "sound", sound = sound } } }
end
local function nativeAlerts(id, layoutID)
    return manager:GetAlertsForLayout(manager.layouts[layoutID or manager.activeID], id, Enum.CDMLayoutMode.AccessOnly) or {}
end

local arbitrary = entry(1307927, "Bell")
arbitrary.auraIDs = { [1307927] = true, [1237205] = true }
arbitrary.auraUnit = "pet"
arbitrary.quiAlerts.auraRemoved = { enabled = true, mode = "sound", sound = "Sounds/Removed.ogg" }
containers = { { key = "custom1", settings = { containerType = "customBar", entries = { arbitrary },
    ownedSpells = { entry(123, "kit:3") } } } }
Alerts.RequestNativeSoundRefresh()
Alerts.RequestNativeSoundRefresh()
assert(#queued == 1)
flush()
assert(#added == 4 and #nativeAlerts(123) == 0, "Custom entries must use their active list and bind every aura ID")
for _, registration in ipairs(added) do
    assert(registration.info.unitToken == "pet" and registration.info.outputChannel == "Master")
    assert(registration.info.spellID == 1307927 or registration.info.spellID == 1237205)
    assert(registration.trigger == 0 and registration.info.soundFileID == 765432
        or registration.trigger == 2 and registration.info.soundFileName == "Sounds/Removed.ogg")
end
assert(Alerts.GetNativeSoundStatus("custom1", arbitrary, "auraApplied") == nil)
containers[2] = { key = "duplicate", settings = { containerType = "customBar", entries = { arbitrary } } }
Alerts.ReconcileNativeSounds()
assert(#added == 4, "Duplicate configured entries must not duplicate native sounds")
local icon = { _spellEntry = arbitrary }
Alerts.OnStateChanged(icon, { key = "same", auraActive = false })
Alerts.OnStateChanged(icon, { key = "same", auraActive = true })
assert(#playback == 0, "Lua transitions must not duplicate registered native aura sounds")
arbitrary.quiAlerts.onCooldown = { enabled = true, mode = "sound", sound = "Bell" }
Alerts.OnStateChanged(icon, { key = "same", auraActive = true, isOnCooldown = true })
assert(#playback == 1, "Ordinary cooldown sounds must remain active")

inCombat = true
containers = {}
Alerts.RequestNativeSoundRefresh()
flush()
assert(next(removed) == nil)
inCombat = false
frames[1].OnEvent(frames[1], "PLAYER_REGEN_ENABLED")
for i = 1, 4 do assert(removed[i] == 1) end

local kit, tts = entry(123, "kit:3"), entry(124, nil, "tts")
tts.quiAlerts.auraApplied.text = "Custom words"
local userAlert = { 1, 0, 9 }
table.insert(manager:GetAlerts(123, 1), userAlert)
containers = { { key = "buff", settings = { ownedSpells = { kit, tts } } } }
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(123) == 2 and nativeAlerts(123)[1] == userAlert)
assert(nativeAlerts(123)[2][2] == 4 and nativeAlerts(123)[2][3] == 3)
assert(nativeAlerts(124)[1][3] == 0)
assert(next(ns.Addon.db.char.cdmNativeSoundAlerts), "Owned native alert metadata must survive reload")
assert(profile.ncdm.nativeSoundAlerts == nil, "Native ownership must not enter exportable profile settings")
assert(Alerts.GetNativeSoundStatus("buff", tts, "auraApplied"):find("spell name", 1, true))
local kitNative = nativeAlerts(123)[2]
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(123) == 2 and nativeAlerts(123)[2] == kitNative)
manager:RemoveAlert(123, kitNative)
flush()
assert(#nativeAlerts(123) == 2, "External native settings changes must reconcile configured QUI sounds")

assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
Alerts = ns.CDMAlerts
containers = {}
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(123) == 1 and nativeAlerts(123)[1] == userAlert and #nativeAlerts(124) == 0,
    "After reload, disabling QUI sounds must remove only saved QUI-owned native records")
assert(next(ns.Addon.db.char.cdmNativeSoundAlerts),
    "Removal must retain ownership until a future load confirms the native saved record is absent")
table.insert(manager:GetAlerts(124, 1), { 0, 4, 0 })
assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
Alerts = ns.CDMAlerts
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(124) == 0, "An older native save resurrected on reload must still be cleaned through ownership")
assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
Alerts = ns.CDMAlerts
Alerts.ReconcileNativeSounds()
assert(next(ns.Addon.db.char.cdmNativeSoundAlerts) == nil,
    "A fresh load with no native record should prune ownership tombstones")

local preexisting = { 0, 4, 3 }
table.insert(manager:GetAlerts(123, 1), preexisting)
containers = { { key = "buff", settings = { ownedSpells = { kit } } } }
Alerts.ReconcileNativeSounds()
assert(next(ns.Addon.db.char.cdmNativeSoundAlerts) == nil, "A matching user alert must remain unowned")
Alerts.ReconcileNativeSounds(true)
assert(#nativeAlerts(123) == 2 and nativeAlerts(123)[2] == preexisting)

containers = { { key = "buff", settings = { ownedSpells = { tts } } } }
Alerts.RequestNativeSoundRefresh()
flush()
assert(#nativeAlerts(124) == 1, "Re-enabling must restore native sounds")
manager.activeID = 2
EventRegistry:TriggerEvent("CooldownViewerSettings.OnDataChanged")
flush()
assert(#nativeAlerts(124, 1) == 0 and #nativeAlerts(124, 2) == 1,
    "Layout switching must move only QUI-owned alerts to the active native layout")
ns.Addon.db.profile = { ncdm = {} }
containers = {}
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(124, 2) == 0 and next(ns.Addon.db.char.cdmNativeSoundAlerts),
    "Profile switching must clear previous registrations through character-scoped ownership")
ns.Addon.db.profile.ncdm.nativeSoundAlerts = {
    imported = { layoutID = 1, cooldownID = 123, event = 4, payload = 3 },
}
Alerts.ReconcileNativeSounds()
assert(nativeAlerts(123, 1)[2] == preexisting, "Imported profile data must never claim ownership of native alerts")
containers = { { key = "buff", settings = { ownedSpells = { tts } } } }
Alerts.ReconcileNativeSounds()
runtimeEnabled = false
frames[#frames].OnEvent(frames[#frames], "PLAYER_ENTERING_WORLD")
flush()
assert(#nativeAlerts(124, 2) == 0, "Lifecycle events must honor the CDM master toggle")
runtimeEnabled = true

local full = entry(125, "kit:3")
for i = 1, 3 do table.insert(manager:GetAlerts(125, 1), { 1, i, i }) end
local unsupported = entry(99999, nil, "tts")
local wrongEvent = entry(99, "kit:3")
containers = { { key = "custom1", settings = { containerType = "customBar", specSpecific = true,
    entries = { arbitrary } } } }
specEntries.custom1 = { full, unsupported, wrongEvent }
Alerts.ReconcileNativeSounds()
assert(#nativeAlerts(125) == 3 and not Alerts.IsNativeSoundRegistered(full, "auraApplied"))
assert(Alerts.GetNativeSoundStatus("custom1", full, "auraApplied"):find("three", 1, true))
assert(Alerts.GetNativeSoundStatus("custom1", unsupported, "auraApplied"):find("Blizzard cooldown entry", 1, true))
assert(Alerts.GetNativeSoundStatus("custom1", wrongEvent, "auraApplied"):find("does not support", 1, true))
assert(unsupported.quiAlerts.auraApplied.enabled, "Unsupported native choices must remain configured")

specEntries.custom1 = { arbitrary }
secretAuras = true
local before = #added
Alerts.ReconcileNativeSounds()
assert(#added == before)
secretAuras = false
rejectRegistration = true
Alerts.ReconcileNativeSounds()
assert(Alerts.GetNativeSoundStatus("custom1", arbitrary, "auraApplied"):find("could not register", 1, true))
rejectRegistration = false
Alerts.ReconcileNativeSounds()
assert(#added == before + 4)
containers[1].settings.enabled = false
Alerts.ReconcileNativeSounds()
for i = before + 1, #added do assert(removed[i] == 1) end

for _, disableBeforeReplacement in ipairs({ true, false }) do
    local replacementEntry = entry(disableBeforeReplacement and 126 or 127, "kit:3")
    containers = { { key = "buff", settings = { ownedSpells = { replacementEntry } } } }
    Alerts.ReconcileNativeSounds()
    local owned = nativeAlerts(replacementEntry.id)[1]
    assert(owned)
    if disableBeforeReplacement then
        Alerts.ReconcileNativeSounds(true)
    else
        table.remove(manager:GetAlerts(replacementEntry.id, 1), 1)
    end
    local replacement = { 0, 4, 3 }
    table.insert(manager:GetAlerts(replacementEntry.id, 1), replacement)
    Alerts.ReconcileNativeSounds()
    Alerts.ReconcileNativeSounds(true)
    assert(nativeAlerts(replacementEntry.id)[1] == replacement,
        "A user replacement must not inherit removed or missing QUI alert ownership")
    assert(ns.Addon.db.char.cdmNativeSoundAlerts[table.concat({ manager.activeID,
        replacementEntry.id, 4, 3 }, ":")] == nil,
        "A user replacement must clear the old ownership tombstone")
    containers = {}
    assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
    Alerts = ns.CDMAlerts
    Alerts.ReconcileNativeSounds()
    assert(nativeAlerts(replacementEntry.id)[1] == replacement,
        "A user replacement must remain unowned after reload")
end

assert(loadfile("QUI_CDM/cdm/cdm_custom_aura_runs.lua"))("QUI", ns)
for _, selfAura in ipairs({ true, false }) do
    local filtered = entry(selfAura and 128 or 129, "Bell")
    containers = { { key = "buff", settings = { ownedSpells = { filtered } } } }
    Alerts.ReconcileNativeSounds()
    local registrationID = #added
    assert(Alerts.IsNativeSoundRegistered(filtered, "auraApplied"))
    filtered._selfAura = selfAura
    Alerts.ReconcileNativeSounds()
    assert(#added == registrationID and removed[registrationID] == 1
        and not Alerts.IsNativeSoundRegistered(filtered, "auraApplied"),
        "Player-cast aura filters must not register file sounds for every caster")
    assert(Alerts.GetNativeSoundStatus("buff", filtered, "auraApplied"):find("own casts", 1, true))
    local config = filtered.quiAlerts.auraApplied
    assert(config.enabled and config.sound == "Bell", "Unsupported file alerts must retain their configuration")
    local previewCount = #playback
    Alerts.Preview(config, filtered, "auraApplied")
    assert(#playback == previewCount + 1, "Unsupported native file alerts must remain previewable")
    config.sound = "kit:3"
    Alerts.ReconcileNativeSounds()
    assert(Alerts.IsNativeSoundRegistered(filtered, "auraApplied") and #nativeAlerts(filtered.id) == 1,
        "Player-cast auras must retain supported Blizzard viewer sound alerts")
end

print("OK: cdm_native_sound_registration_test")
