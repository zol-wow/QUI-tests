function wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end

local sounds = {}
local speech = {}
local soundKits = {}
local inCombat = false
local soundKitFrame

Enum = { TtsVoiceType = { Standard = 0 } }
InCombatLockdown = function() return inCombat end
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(name, fn) self[name] = fn end
    soundKitFrame = frame
    return frame
end
PlaySoundFile = function(path, channel)
    sounds[#sounds + 1] = { path = path, channel = channel }
end
C_TTSSettings = {
    GetVoiceOptionID = function() return 7 end,
    GetSpeechRate = function() return 2 end,
    GetSpeechVolume = function() return 80 end,
}
C_VoiceChat = {
    SpeakText = function(voiceID, spokenText, rate, volume, overlap)
        speech[#speech + 1] = {
            voiceID = voiceID,
            text = spokenText,
            rate = rate,
            volume = volume,
            overlap = overlap,
        }
    end,
}
C_Sound = {
    PlaySoundWithOptions = function(options)
        soundKits[#soundKits + 1] = options
    end,
}
CooldownViewerSoundData = nil

local ns = {
    SafeCall = function(_, fn, ...)
        return pcall(fn, ...)
    end,
    LSM = {
        Fetch = function(_, mediaType, name)
            if mediaType == "sound" and name == "Test Sound" then return "Sounds/Test.ogg" end
        end,
    },
}

assert(loadfile("QUI_CDM/cdm/cdm_alerts.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_runtime_store.lua"))("QUI", ns)

local store = ns.CDMRuntimeStore
CooldownViewerSoundData = { { { soundEnum = 3, soundKitID = 99, text = "Test Bell" } } }
inCombat = true
soundKitFrame.OnEvent(soundKitFrame, "ADDON_LOADED", "Blizzard_CooldownViewer")
assert(#ns.CDMAlerts.GetSoundKitOptions() == 0,
    "sound-kit loading should stay deferred while combat blocks catalog access")
inCombat = false
soundKitFrame.OnEvent(soundKitFrame, "PLAYER_REGEN_ENABLED")
local kitOptions = ns.CDMAlerts.GetSoundKitOptions()
assert(kitOptions[1].value == "kit:3", "Blizzard's sound catalog should be copied into QUI options")
assert(next(soundKitFrame.events) == nil, "successful sound-kit preload should stop retry events")
ns.CDMAlerts.Preview({ mode = "sound", sound = "kit:3" })
assert(soundKits[1].soundKitID == 99, "Blizzard catalog sounds should play through their SoundKit ID")
local icon = {
    _spellEntry = {
        viewerType = "essential",
        type = "spell",
        id = 12345,
        name = "Test Ability",
        quiAlerts = {
            available = { enabled = true, mode = "tts", text = "Ready now" },
            onCooldown = { enabled = true, mode = "sound", sound = "Test Sound" },
            auraApplied = { enabled = true, mode = "sound", sound = "Test Sound" },
            auraRemoved = { enabled = true, mode = "sound", sound = "Test Sound" },
        },
    },
}

store.SetIconState(icon, { isOnCooldown = false, auraActive = false })
assert(#sounds == 0 and #speech == 0, "first render should not alert")

store.SetIconState(icon, { isOnCooldown = true, auraActive = false })
assert(#sounds == 1 and sounds[1].channel == "Master", "cooldown start should play its sound")
store.SetIconState(icon, { isOnCooldown = true, auraActive = false })
assert(#sounds == 1, "unchanged state should not repeat an alert")

store.SetIconState(icon, { isOnCooldown = false, auraActive = false })
assert(#speech == 1 and speech[1].text == "Ready now", "cooldown completion should speak configured text")

store.SetIconState(icon, { isOnCooldown = false, auraActive = true })
store.SetIconState(icon, { isOnCooldown = false, auraActive = false })
assert(#sounds == 3, "aura application and removal should each play once")

local bar = { _spellEntry = icon._spellEntry }
store.SetBarState(bar, { isOnCooldown = false, auraActive = false })
store.SetBarState(bar, { isOnCooldown = true, auraActive = false })
store.SetBarState(bar, { isOnCooldown = false, auraActive = false })
assert(#sounds == 4 and #speech == 2,
    "bar cooldown transitions should use the same alert path as icons")

icon._spellEntry.id = 67890
local soundsBeforeEntryChange = #sounds
local speechBeforeEntryChange = #speech
store.SetIconState(icon, { isOnCooldown = true, auraActive = true })
assert(#sounds == soundsBeforeEntryChange and #speech == speechBeforeEntryChange,
    "changing entries should establish a new baseline without alerting")

store.ClearFrame(icon)
assert(icon._quiAlertState == nil, "clearing a frame should clear its alert baseline")

print("OK: cdm_alerts_runtime_test")
