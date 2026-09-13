local function noop() end
local function forbidden() error("secret value must reach a native sink unchanged") end
local secretMeta = { __lt = forbidden, __le = forbidden, __add = forbidden, __sub = forbidden,
    __mul = forbidden, __div = forbidden, __tostring = forbidden, __index = forbidden }
local remainingAlpha = setmetatable({}, secretMeta)
local zeroResult = setmetatable({}, secretMeta)
local zeroAlpha = setmetatable({}, secretMeta)

function issecretvalue(value)
    return rawequal(value, remainingAlpha) or rawequal(value, zeroResult) or rawequal(value, zeroAlpha)
end
function InCombatLockdown() return false end
function wipe(values) for key in pairs(values) do values[key] = nil end end

function CreateFrame(_, _, parent)
    return {
        parent = parent, shown = true, alpha = 1,
        RegisterEvent = noop, UnregisterAllEvents = noop, SetAllPoints = noop,
        SetPoint = noop, ClearAllPoints = noop,
        SetScript = function(self, event, fn) self[event] = fn end,
        SetAlpha = function(self, value) self.alpha = value; self.alphaWrites = (self.alphaWrites or 0) + 1 end,
        GetFrameLevel = function() return 2 end, SetFrameLevel = noop,
        GetSize = function() return 48, 36 end,
        GetWidth = function() return 48 end, GetHeight = function() return 36 end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
        CreateTexture = function()
            return {
                SetTexture = function(self, value) self.texture = value end,
                SetTexCoord = noop, SetBlendMode = noop, SetAllPoints = noop,
                SetVertexColor = function(self, ...) self.color = { ... } end,
                SetShown = function(self, shown) self.shown = shown end,
                SetAlpha = function(self, value) self.alpha = value end,
                Show = noop, Hide = noop,
            }
        end,
    }
end

C_Timer = { NewTicker = function() return { Cancel = noop } end }
Enum = { LuaCurveType = { Step = 1 } }
local curve
C_CurveUtil = {
    CreateCurve = function()
        curve = { points = {}, SetType = noop,
            AddPoint = function(self, x, y) self.points[#self.points + 1] = { x, y } end }
        return curve
    end,
    EvaluateColorValueFromBoolean = function(value, whenTrue, whenFalse)
        assert(rawequal(value, zeroResult), "IsZero result must reach boolean sink")
        assert(whenTrue == 0 and whenFalse == 1, "zero-duration auras must be hidden")
        return zeroAlpha
    end,
}

local settings = {
    essentialEnabled = true, essentialGlowType = "Pixel Glow",
    essentialColor = { 0.2, 0.4, 0.6, 0.8 }, essentialLines = 11,
    essentialThickness = 3, essentialFrequency = 0.4, essentialScale = 1.3,
    essentialXOffset = 4, essentialYOffset = 5,
}
local spellOverride
local runtimeEnabled = true
local calls = {}
local ns = {
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        GetModuleSettings = function(_, defaults) return defaults end,
    },
    CDMShared = { IsRuntimeEnabled = function() return runtimeEnabled end },
    CDMSpellData = { GetSpellOverride = function() return spellOverride end },
    CDMCustomAuraRuns = {
        StyleNativeEffects = function(frame, profile, key)
            calls[#calls + 1] = { frame = frame, profile = profile, key = key }
            frame._quiCDMNativeEffectHost = frame._quiCDMNativeEffectHost or CreateFrame("Frame", nil, frame)
            local effects = frame[key] or { { playing = false, group = { Stop = noop, Play = noop } } }
            frame[key] = effects
            effects[1].playing = profile.cdmActiveGlow ~= nil
            return effects
        end,
    },
}
assert(loadfile(arg[1] or "QUI_CDM/cdm/cdm_effects.lua"))("QUI", ns)
local glows = assert(ns._OwnedGlows)
local icon = CreateFrame("Frame")
icon._spellEntry = { spellID = 100, viewerType = "essential" }
icon._auraActive = true
icon._auraIsHarmful = true
icon._lastAuraDurObj = {
    EvaluateRemainingPercent = function(_, suppliedCurve)
        assert(suppliedCurve == curve, "owned pandemic must use the duration curve")
        return remainingAlpha
    end,
    IsZero = function() return zeroResult end,
}
local proc = {}
icon._PixelGlow_QUICustomGlow = proc
glows.UpdatePandemicGlow(icon)
local call = calls[#calls]
assert(call and call.profile.cdmActiveGlow.glowType == "Pixel Glow",
    "owned pandemic must render selected Pixel Glow instead of a fixed highlight")
assert(call.frame == icon.PandemicGlow and call.frame ~= icon, "pandemic owns a separate effect host")
assert(call.profile.iconWidth == 48 and call.profile.iconHeight == 36, "use actual icon dimensions")
local glow = call.profile.cdmActiveGlow
assert(glow.lines == 11 and glow.thickness == 3 and glow.frequency == 0.4, "preserve pixel settings")
assert(glow.color == settings.essentialColor and glow.scale == 1.3, "preserve color and scale")
assert(glow.xOffset == 4 and glow.yOffset == 5, "preserve configured offsets")
assert(rawequal(icon.PandemicGlow.alpha, remainingAlpha), "secret curve alpha must reach frame unchanged")
assert(rawequal(icon.PandemicGlow._quiCDMNativeEffectHost.alpha, zeroAlpha), "secret zero-duration gate must reach child unchanged")
assert(#curve.points == 3 and curve.points[3][1] == 0.3, "pandemic threshold stays 30 percent")

local styleCalls = #calls
for _ = 1, 100 do glows.UpdatePandemicGlow(icon) end
assert(#calls == styleCalls, "unchanged aura updates must reuse pandemic styling before allocating profiles")
local originalEntry = icon._spellEntry
icon._spellEntry = { spellID = 101, viewerType = "essential" }
glows.UpdatePandemicGlow(icon)
assert(#calls == styleCalls + 1, "a replacement entry must invalidate pandemic styling")
icon._spellEntry.spellID = 102
glows.UpdatePandemicGlow(icon)
assert(#calls == styleCalls + 2, "an entry identity edited in place must invalidate pandemic styling")
icon.GetSize = function() return 52, 40 end
glows.UpdatePandemicGlow(icon)
assert(calls[#calls].profile.iconWidth == 52 and calls[#calls].profile.iconHeight == 40,
    "resized icons must invalidate pandemic dimensions")
icon._spellEntry = originalEntry

settings.essentialGlowType = "Autocast Shine"
spellOverride = { glowColor = { 1, 0, 0, 1 }, glowEnabled = false }
glows.RefreshAllGlows()
glows.UpdatePandemicGlow(icon)
glow = calls[#calls].profile.cdmActiveGlow
assert(glow.glowType == "Autocast Shine" and glow.color == spellOverride.glowColor,
    "live edits and spell color apply independently of proc suppression")

glows.activeGlowIcons[icon] = true
settings.essentialPandemicDebuffEnabled = false
glows.UpdatePandemicGlow(icon)
assert(icon.PandemicGlow.alpha == 0, "disabled pandemic must be hidden")
assert(calls[#calls].profile.cdmActiveGlow == nil, "disabled pandemic must stop animations")
assert(icon._PixelGlow_QUICustomGlow == proc and glows.activeGlowIcons[icon], "pandemic must not stop the proc glow")

settings.essentialPandemicDebuffEnabled = true
settings.essentialEnabled = false
glows.UpdatePandemicGlow(icon)
glow = calls[#calls].profile.cdmActiveGlow
assert(glow == nil, "disabled custom glow must retain a steady highlight, not an animated Flash")
local fallback = icon.PandemicGlow.texture
assert(fallback and fallback.shown and fallback.texture:match("iconskin[/\\]Flash$"),
    "fallback retains the original Flash texture")
assert(fallback.color[1] == 1 and fallback.color[2] == 0.85 and fallback.color[3] == 0.2,
    "fallback stays yellow")
assert(rawequal(fallback.alpha, zeroAlpha), "fallback keeps the zero-duration gate")
icon._auraActive = false
glows.UpdatePandemicGlow(icon)
assert(icon.PandemicGlow.alpha == 0 and calls[#calls].profile.cdmActiveGlow == nil, "aura removal clears effects")

settings.essentialEnabled = true
settings.essentialGlowType = "Pixel Glow"
local overlay = CreateFrame("Frame")
glows.ApplyPandemicToOverlay(overlay, icon._spellEntry)
call = calls[#calls]
assert(call.frame == overlay.PandemicGlow and call.profile.cdmActiveGlow.glowType == "Pixel Glow",
    "reanchored pandemic must use the selected style on its own host")
assert(overlay.PandemicGlow.alpha == 1, "native pandemic show enables the host")
glows.ClearPandemicFromOverlay(overlay)
assert(overlay.PandemicGlow.alpha == 0 and calls[#calls].profile.cdmActiveGlow == nil,
    "native pandemic hide must stop and hide effects")

glows.activeGlowIcons[icon] = nil
icon._auraActive = true
glows.UpdatePandemicGlow(icon)
glows.ApplyPandemicToOverlay(overlay, icon._spellEntry)
local ownedWrites = icon.PandemicGlow.alphaWrites
local overlayWrites = overlay.PandemicGlow.alphaWrites
settings.essentialGlowType = "Button Glow"
settings.essentialLines = 18
glows.RefreshAllGlows()
local ownedProfile, overlayProfile
for _, styled in ipairs(calls) do
    if styled.frame == icon.PandemicGlow then ownedProfile = styled.profile end
    if styled.frame == overlay.PandemicGlow then overlayProfile = styled.profile end
end
assert(ownedProfile.cdmActiveGlow.glowType == "Button Glow" and overlayProfile.cdmActiveGlow.glowType == "Button Glow",
    "settings refresh restyles owned and latched native pandemic")
assert(overlayProfile.cdmActiveGlow.lines == 18, "settings refresh propagates updated parameters")
assert(icon.PandemicGlow.alphaWrites == ownedWrites and overlay.PandemicGlow.alphaWrites == overlayWrites,
    "restyling must preserve native visibility and secret curve alpha")
assert(rawequal(icon.PandemicGlow.alpha, remainingAlpha), "refresh preserves secret curve alpha unchanged")

assert(loadfile("QUI_CDM/cdm/cdm_reanchor_hooks.lua"))("QUI", ns)
local nativeFrame = { entry = icon._spellEntry }
local bridge = ns.CDMReanchorPandemic.New({
    getEntryForFrame = function(frame) return frame.entry end,
    ensureOverlay = function() return overlay end,
    isPandemicEnabled = glows.IsPandemicEnabledForEntry,
    startPandemic = glows.ApplyPandemicToOverlay,
    stopPandemic = glows.ClearPandemicFromOverlay,
})
bridge:_OnShowPandemic(nativeFrame)
settings.essentialPandemicDebuffEnabled = false
settings.essentialPandemicBuffEnabled = false
glows.RefreshAllGlows()
assert(overlay.PandemicGlow.alpha == 0 and not overlay.PandemicGlow._quiPandemicEffects[1].playing,
    "settings disable must hide and stop an active native pandemic window")
settings.essentialPandemicDebuffEnabled = true
glows.RefreshAllGlows()
bridge:_OnShowPandemic(nativeFrame)
assert(overlay.PandemicGlow.alpha == 1 and overlay.PandemicGlow._quiPandemicEffects[1].playing,
    "re-enabling within the same latched native window must restore pandemic glow")
settings.essentialPandemicDebuffEnabled = false
glows.RefreshAllGlows()
bridge:_OnHidePandemic(nativeFrame)
settings.essentialPandemicDebuffEnabled = true
glows.RefreshAllGlows()
assert(overlay.PandemicGlow.alpha == 0 and not overlay.PandemicGlow._quiPandemicEffects[1].playing,
    "a native window hidden while disabled must not reappear when enabled")
bridge:_OnShowPandemic(nativeFrame)

glows.DisableRuntime()
assert(icon.PandemicGlow.alpha == 0 and overlay.PandemicGlow.alpha == 0, "runtime disable hides pandemic-only hosts")
assert(not icon.PandemicGlow._quiPandemicEffects[1].playing and not overlay.PandemicGlow._quiPandemicEffects[1].playing,
    "runtime disable stops pandemic-only animations")

glows.ApplyPandemicToOverlay(overlay, icon._spellEntry)
runtimeEnabled = false
glows.RefreshAllGlows()
assert(overlay.PandemicGlow.alpha == 0 and not overlay.PandemicGlow._quiPandemicEffects[1].playing,
    "refresh while runtime is disabled clears pandemic-only effects")

print("OK: cdm_effects_pandemic_style_test")
