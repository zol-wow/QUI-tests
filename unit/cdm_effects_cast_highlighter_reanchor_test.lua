local function noop() end

local secretValue = {}
function issecretvalue(value) return value == secretValue end

local inCombat = false
function InCombatLockdown() return inCombat end
function wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end

local createdFrames = {}
local createdTextures = {}
local factoryCallbacks = {}
function CreateFrame(_, _, parent, template)
    local frame = {
        parent = parent,
        template = template,
        frameLevel = 1,
        events = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterAllEvents = noop,
        SetScript = function(self, script, handler) self[script] = handler end,
        SetAllPoints = function(self, target) self.allPoints = target end,
        SetAlpha = noop,
        GetFrameLevel = function(self) return self.frameLevel end,
        SetFrameLevel = function(self, value) self.frameLevel = value end,
        IsShown = function() return true end,
        CreateTexture = function(self)
            local texture = {
                parent = self,
                points = {},
                SetAtlas = function(tex, atlas) tex.atlas = atlas end,
                SetTexture = function(tex, path) tex.texture = path end,
                SetTexCoord = function(tex, ...) tex.texCoord = { ... } end,
                ClearAllPoints = function(tex) tex.points = {} end,
                SetAllPoints = function(tex, target) tex.allPoints = target or self end,
                SetPoint = function(tex, ...) tex.points[#tex.points + 1] = { ... } end,
                Show = function(tex) tex.shown = true; tex.showCount = (tex.showCount or 0) + 1 end,
                Hide = function(tex) tex.shown = false end,
            }
            createdTextures[#createdTextures + 1] = texture
            return texture
        end,
    }
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local timers = {}
C_Timer = {
    NewTicker = function() return { Cancel = noop } end,
    NewTimer = function(_, callback)
        local timer = { callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

local starts = {}
local stops = {}
function LibStub()
    return {
        PixelGlow_Start = function(target) starts[#starts + 1] = target end,
        PixelGlow_Stop = function(target) stops[#stops + 1] = target end,
        AutoCastGlow_Stop = noop,
        ButtonGlow_Start = function(target)
            target._ButtonGlow = {
                frameLevel = 20,
                GetFrameLevel = function(self) return self.frameLevel end,
                SetFrameLevel = function(self, value) self.frameLevel = value end,
            }
            starts[#starts + 1] = target
        end,
        ButtonGlow_Stop = function(target)
            target._ButtonGlow = nil
            stops[#stops + 1] = target
        end,
        ProcGlow_Stop = noop,
    }
end

local nativeFrame = {
    IsShown = function() return true end,
}
local nativeEntry = {
    spellID = 1001,
    id = 1001,
    type = "spell",
    kind = "cooldown",
    viewerType = "essential",
}
local sharedOverlay = {}
local customIcon = {
    _quiLayoutRestricted = true,
    Cooldown = { GetFrameLevel = function() return 10 end },
    _spellEntry = {
        spellID = 2002,
        id = 2002,
        type = "spell",
        kind = "cooldown",
        viewerType = "customRotation",
    },
    IsShown = function() return true end,
}
customIcon.CreateTexture = CreateFrame().CreateTexture
local buffIcon = {
    _spellEntry = {
        spellID = 1001,
        id = 1001,
        type = "spell",
        kind = "aura",
        viewerType = "buff",
    },
    IsShown = function() return true end,
}
buffIcon.CreateTexture = CreateFrame().CreateTexture
local lateIcon = {
    _spellEntry = {
        spellID = 3003,
        id = 3003,
        type = "spell",
        kind = "cooldown",
        viewerType = "customRotation",
    },
    IsShown = function() return true end,
}
lateIcon.CreateTexture = CreateFrame().CreateTexture

QUI_GetReanchoredCDMFrames = function(containerKey)
    if containerKey == "essential" then return { nativeFrame } end
    return nil
end
QUI_ResolveCDMFrameEntry = function(frame)
    if frame == nativeFrame then return nativeEntry end
    return nil
end

local highlighterSettings = {
    enabled = true,
    glowType = "Pixel Glow",
    color = { 1, 1, 1, 1 },
    duration = 0.4,
    lines = 8,
    thickness = 1,
    frequency = 0.25,
}
local effectsSettings = {
    hideEssential = false,
    hideUtility = false,
}
local containerSettings = {
    essential = { pressedEffect = "qui" },
    buff = { pressedEffect = "off" },
    customRotation = { pressedEffect = "qui" },
}

local ns = {
    Helpers = {
        AssetPath = "",
        CreateDBGetter = function(key)
            return function()
                if key == "cooldownHighlighter" then return highlighterSettings end
                if key == "cooldownEffects" then return effectsSettings end
                return {}
            end
        end,
        GetModuleSettings = function(_, defaults) return defaults end,
        GetProfile = function() return { ncdm = { glowSource = "QUI" } } end,
        SafeValue = function(value) return value end,
    },
    CDMShared = {
        IsRuntimeEnabled = function() return true end,
        SettingEnabled = function(value, fallback)
            if value == nil then return fallback == true end
            return value == true
        end,
        GetBuiltinContainerKeysByEntryKind = function(entryKind)
            if entryKind == "cooldown" then return { "essential", "utility" } end
            return nil
        end,
        GetBuiltinContainerKeysByShape = function(shape)
            if shape == "icon" then return { "essential", "utility", "buff" } end
            return nil
        end,
        GetContainerDB = function(containerKey) return containerSettings[containerKey] end,
        IsBuiltinAuraContainerKey = function(containerKey)
            return containerKey == "buff" or containerKey == "trackedBar"
        end,
    },
    CDMSources = {
        QueryOverrideSpell = function() return nil end,
        QueryBaseSpell = function() return nil end,
        QuerySpellUsable = function() return false, false end,
    },
    CDMSpellData = {
        IsAuraEntry = function(entry) return entry and entry.kind == "aura" end,
        GetSpellOverride = function() return nil end,
    },
    CDMIconFactory = {
        ForEachIcon = function(_, callback)
            factoryCallbacks[#factoryCallbacks + 1] = callback
            callback(customIcon)
            callback(buffIcon)
            callback(lateIcon)
        end,
        GetIconPool = function() return {} end,
    },
    CDMResolvers = { ResolveAuraActiveState = function() return false end },
    CDMIcons = {},
    CDMRuntimeStore = { GetFrameState = function() return nil end },
    _CDMEnsureReanchorGlowOverlay = function(frame)
        if frame == nativeFrame then return sharedOverlay end
        return nil
    end,
}

local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_frame_writes.lua", "cdm_effects.lua")("QUI", ns)

local highlighter = assert(ns._OwnedHighlighter, "effects module should publish the highlighter")
assert(type(highlighter.PrepareActionButton) == "function"
    and type(highlighter.PrepareReanchoredFrame) == "function"
    and type(highlighter.PrepareIcon) == "function"
    and type(highlighter.DrainPreparedTargets) == "function",
    "effects module should expose out-of-combat pressed-effect preparation")
highlighter.PrepareReanchoredFrame(nativeFrame, "essential")
highlighter.PrepareIcon(customIcon)
highlighter.PrepareIcon(buffIcon)
highlighter.OnPlayerCastSucceeded(1001)

assert(#starts == 1, "reanchored cast should start one highlight")
local nativeTarget = starts[1]
assert(nativeTarget ~= nativeFrame, "highlight must not target the Blizzard frame")
assert(nativeTarget ~= sharedOverlay, "highlight must not share the proc glow overlay")
assert(nativeTarget.parent == sharedOverlay, "highlight target should be owned by the reanchor overlay")
assert(nativeTarget.allPoints == sharedOverlay, "highlight target should cover the reanchor overlay")

assert(type(highlighter.OnReanchoredFrameRelease) == "function", "highlighter should expose reanchor release cleanup")
highlighter.OnReanchoredFrameRelease(nativeFrame)
assert(stops[#stops] == nativeTarget, "reanchor release should stop the active highlight")
assert(timers[1].cancelled == true, "reanchor release should cancel its highlight timer")

highlighterSettings.glowType = "Button Glow"
customIcon._ButtonGlow = { proc = true }
highlighter.OnPlayerCastSucceeded(2002)
local customTarget = starts[#starts]
assert(customTarget ~= customIcon, "custom cast highlights must not target the proc-glow owner")
assert(customTarget.parent == customIcon, "custom cast highlights should use an owned child target")
assert(customTarget.template == "DisableUntrustedLayoutScriptsTemplate"
    and customTarget._quiLayoutRestricted == true,
    "managed-row custom highlights must keep restricted layout ownership")
assert(customTarget._ButtonGlow.frameLevel == 9,
    "custom cast highlights must stay below the source icon's cooldown layer")
highlighter.OnPlayerCastSucceeded(2002)
assert(starts[#starts] == customTarget and timers[2].cancelled == true,
    "a repeated Button Glow cast should cancel and restart the owned highlight")
assert(#timers == 3, "each resolved cast should arm one highlight timer")

local pressedState = assert(highlighter.OnActionButtonState, "effects module should consume cached action-button state")
local nativeButton = {}
highlighter.PrepareReanchoredFrame(nativeFrame, "essential")
highlighter.PrepareActionButton(nativeButton)
local frameCountBeforePress = #createdFrames
local textureCountBeforePress = #createdTextures
inCombat = true
pressedState(nativeButton, { [1001] = true }, true)
assert(#createdFrames == frameCountBeforePress and #createdTextures == textureCountBeforePress,
    "matching combat presses must use prewarmed frames and textures")

local pushedTexture
for _, texture in ipairs(createdTextures) do
    if texture.parent == nativeTarget then pushedTexture = texture end
end
assert(pushedTexture, "native pressed texture should be prewarmed")
assert(pushedTexture.parent == nativeTarget, "pressed effect should use the owned reanchor target")
assert(pushedTexture.texture == "iconskin\\Pushed", "QUI pressed mode should reuse the ActionBars texture")
assert(pushedTexture.shown == true, "pressed effect should show while the key is held")

pressedState(nativeButton, { [1001] = true }, false)
assert(pushedTexture.shown == false, "pressed effect should hide when the key is released")
local noMatchButton = {}
inCombat = false
highlighter.PrepareActionButton(noMatchButton)
inCombat = true
pressedState(noMatchButton, { [9999] = true }, true)
pressedState(noMatchButton, { [9999] = true }, false)
assert(#createdFrames == frameCountBeforePress and #createdTextures == textureCountBeforePress,
    "unmatched combat presses must not allocate visual objects")
inCombat = false

local lateFramesBefore = #createdFrames
local lateTexturesBefore = #createdTextures
inCombat = true
highlighter.PrepareIcon(lateIcon)
assert(#createdFrames == lateFramesBefore and #createdTextures == lateTexturesBefore,
    "combat icon acquisition must defer visual preparation")
inCombat = false
highlighter.DrainPreparedTargets()
assert(#createdFrames == lateFramesBefore + 1 and #createdTextures == lateTexturesBefore + 1,
    "regen must prepare visuals skipped by combat acquisition")
local lateButton = {}
highlighter.PrepareActionButton(lateButton)
local lateFrameCount = #createdFrames
local lateTextureCount = #createdTextures
inCombat = true
pressedState(lateButton, { [3003] = true }, true)
local lateTexture
for _, texture in ipairs(createdTextures) do
    if texture.parent and texture.parent.parent == lateIcon then lateTexture = texture end
end
assert(lateTexture and lateTexture.shown == true
    and #createdFrames == lateFrameCount and #createdTextures == lateTextureCount,
    "post-regen combat presses must use the deferred prewarmed visual")
pressedState(lateButton, { [3003] = true }, false)
inCombat = false

containerSettings.customRotation.pressedEffect = "blizzard"
local customButton = {}
highlighter.PrepareActionButton(customButton)
pressedState(customButton, { [2002] = true }, true)
local blizzardTexture
for _, texture in ipairs(createdTextures) do
    if texture.parent == customTarget then blizzardTexture = texture end
end
assert(blizzardTexture, "custom pressed texture should be prewarmed")
assert(blizzardTexture.parent == customTarget, "custom CDM icons should receive the pressed effect")
assert(blizzardTexture.atlas == "UI-HUD-ActionBar-IconFrame-Down", "Blizzard mode should reuse the stock pushed atlas")
assert(blizzardTexture.shown == true, "Blizzard pressed mode should show while held")
assert(type(highlighter.OnIconRelease) == "function", "highlighter should expose custom icon release cleanup")
highlighter.OnIconRelease(customIcon)
assert(blizzardTexture.shown == false, "custom icon release should hide a held pressed effect")
assert(timers[3].cancelled == true, "custom icon release should cancel its cast-highlight timer")
assert(stops[#stops] == customTarget, "custom icon release should stop its cast highlight")

containerSettings.essential.pressedEffect = "off"
local showCount = pushedTexture.showCount
pressedState(nativeButton, { [1001] = true }, true)
assert(pushedTexture.showCount == showCount, "Off mode should not show a pressed effect")

containerSettings.buff.pressedEffect = "qui"
local buffButton = {}
highlighter.PrepareActionButton(buffButton)
pressedState(buffButton, { [1001] = true }, true)
local buffTexture
for _, texture in ipairs(createdTextures) do
    if texture.parent and texture.parent.parent == buffIcon then buffTexture = texture end
end
assert(buffTexture, "buff pressed texture should be prewarmed")
assert(buffTexture.parent.parent == buffIcon and buffTexture.shown == true,
    "an Off duplicate must not block an enabled Buff Icon pressed effect")
pressedState(buffButton, { [1001] = true }, false)
assert(buffTexture.shown == false, "Buff Icon pressed effects should clear on release")

containerSettings.essential.pressedEffect = "qui"
pressedState(nativeButton, { [secretValue] = true }, true)
assert(pushedTexture.showCount == showCount, "secret action identities should be rejected")

for i = 2, #factoryCallbacks do
    assert(factoryCallbacks[i] == factoryCallbacks[1],
        "CDM icon scans should reuse one stable callback")
end

local source = assert(io.open("QUI_CDM/cdm/cdm_effects.lua", "rb"))
local sourceText = source:read("*a")
source:close()
local hiddenBody = assert(sourceText:match("local function IsPressedEffectHidden%b().-\nend"))
assert(not hiddenBody:find(" .. ", 1, true),
    "pressed-effect visibility lookup must not concatenate on the keypress path")

print("cdm_effects_cast_highlighter_reanchor_test: ok")
