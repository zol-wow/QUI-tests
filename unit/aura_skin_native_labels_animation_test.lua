local function noop() end

Enum = {
    SecretAspect = { Text = "Text", Shown = "Shown" },
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3, CustomAsset = 4 },
}
InCombatLockdown = function() return false end
assertf = function(condition, message, ...)
    assert(condition, string.format(message, ...))
end
securecopy = function(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = _G.securecopy(item) end
    return copy
end
CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({ ... }) do
        for key, value in pairs(mixin) do result[key] = value end
    end
    return result
end
AuraButtonPrivateMixin = {}
C_AuraContainerUtil = { ProcessCustomAuraButtonCasterNameOptions = function(options) return options end }
AuraContainerUtil = {
    ValidateInboundScriptObject = noop,
    RequireObjectType = function() return noop end,
    InitializeInboundScriptObject = function(object) return object end,
    InitializeInboundAnimationGroup = function(group)
        group.adopted = true
        return group
    end,
}

local function Region(parent)
    local region = { parent = parent, secrets = {} }
    for _, method in ipairs({
        "SetAllPoints", "SetSize", "ClearAllPoints", "SetColorTexture", "SetTexture",
        "SetTexCoord", "SetBlendMode", "DisablePixelSnap", "SetHideCountdownNumbers",
        "SetDrawSwipe", "SetDrawEdge", "SetDrawBling", "SetReverse", "SetStatusBarTexture",
        "SetOrientation", "SetStatusBarColor", "SetWordWrap", "SetWidth", "SetJustifyH",
    }) do region[method] = noop end
    function region:SetPoint(...) self.point = { ... } end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:SetVertexColor(...) self.vertexColor = { ... } end
    function region:SetTextColor(...) self.textColor = { ... } end
    function region:SetFont(...) self.font = { ... } end
    function region:AddSecretAspect(aspect) self.secrets[aspect] = true end
    function region:GetDebugName() return "test region" end
    function region:SetText(text)
        assert(not self.secrets.Text, "QUI must not overwrite native caster text")
        self.text = text
    end
    function region:GetText()
        assert(not self.secrets.Text, "QUI must not read native caster text")
        return self.text
    end
    function region:SetShown(shown)
        assert(not self.secrets.Shown, "QUI must leave native visibility alone")
        self.shown = shown
    end
    function region:Show() self:SetShown(true) end
    function region:Hide() self:SetShown(false) end
    function region:IsShown()
        assert(not self.secrets.Shown, "QUI must not query native visibility")
        return self.shown
    end
    function region:CreateTexture() return Region(self) end
    function region:CreateFontString() return Region(self) end
    function region:CreateAnimationGroup()
        local group = { parent = self, animations = {}, playCount = 0, stopCount = 0 }
        function group:GetDebugName() return "test animation group" end
        function group:SetLooping(mode) self.looping = mode end
        function group:SetToFinalAlpha(value) self.finalAlpha = value end
        function group:Play() self.playCount = self.playCount + 1; self.playing = true end
        function group:Stop() self.stopCount = self.stopCount + 1; self.playing = false end
        function group:SetScript(name, fn) self[name] = fn end
        function group:CreateAnimation(kind)
            assert(not self.adopted, "cannot add animations after native adoption")
            local animation = { kind = kind }
            for _, name in ipairs({ "SetOrder", "SetDuration", "SetFromAlpha", "SetToAlpha", "SetSmoothing", "SetStartDelay", "SetEndDelay" }) do
                animation[name] = function(self, value) self[name] = value end
            end
            self.animations[#self.animations + 1] = animation
            return animation
        end
        for _, name in ipairs({ "IsPlaying", "GetProgress", "GetElapsed", "IsDone", "IsPaused" }) do
            group[name] = function(self)
                assert(not self.adopted, "cannot query animation state after native adoption")
                return self.playing
            end
        end
        return group
    end
    return region
end

CreateFrame = function(_kind, _name, parent) return Region(parent) end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua"))("Blizzard_AuraContainer", {})
local nativeMixin = _G.CustomAuraButtonSharedMixin
local nativePrivateMixin = _G.CustomAuraButtonPrivateMixin
_G.CustomAuraButtonSharedMixin = nil

local function Button(native)
    local button = Region()
    if native then
        for _, method in ipairs({
            "AddPandemicRegion", "RemovePandemicRegion", "SetCasterName", "ClearCasterName",
            "AddPandemicActiveAnimation", "RemovePandemicActiveAnimation",
            "AddPandemicEnterAnimation", "RemovePandemicEnterAnimation",
        }) do button[method] = nativeMixin[method] end
        button.pandemicRegions = {}
        button.pandemicActiveAnimations = {}
        button.pandemicEnterAnimations = {}
        button.pandemicLeaveAnimations = {}
        button.UpdateAuraDisplay = noop
    end
    return button
end

local ns = {
    Helpers = {
        GetGeneralFont = function() return "font.ttf" end,
        GetGeneralFontOutline = function() return "OUTLINE" end,
    },
}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
local Skin = ns.AuraSkin
local button = Button(true)
local container = { _quiButtons = { button } }
Skin.WireButton(button, {})
assert(button.casterName == nil, "caster labels must remain disabled by default")
assert(#button.pandemicRegions == 1, "existing native pandemic region must remain registered once")

local caster = {
    fontSize = 10, anchor = "BOTTOM", offsetX = 3, offsetY = 2,
    color = { 0.2, 0.3, 0.4, 0.5 }, showRealmName = true, useClassColors = true,
}
local glow = { color = { 0.1, 0.2, 0.3, 0.7 } }
local profile = { casterName = caster, pandemicGlow = glow }
Skin.Restyle(container, profile)
assert(button.casterName and button.casterName.element == button._quiCaster,
    "enabled caster label must reach the real native setter")
assert(button.casterName.options.showRealmName and button.casterName.options.useClassColors,
    "realm and class-color options must reach the native label")
assert(button._quiCaster.font[2] == 10 and button._quiCaster.point[1] == "BOTTOM"
    and button._quiCaster.point[4] == 3 and button._quiCaster.point[5] == 2,
    "caster font and positioning must follow the profile")
assert(button._quiCaster.textColor[4] == 0.5, "caster color alpha must be preserved")
assert(#button.pandemicActiveAnimations == 0 and #button.pandemicEnterAnimations == 0
    and button._quiPandemic.alpha == 0.7, "omitted pandemic style must retain steady glow")

glow.style = "pulse"
Skin.Restyle(container, profile)
assert(#button.pandemicActiveAnimations == 1 and #button.pandemicEnterAnimations == 0,
    "pulse must register only as an active-window animation")
local pulse = button.pandemicActiveAnimations[1].element
assert(pulse.parent == button._quiPandemic and pulse.adopted and #pulse.animations > 0,
    "pulse must animate the existing native pandemic region")
assert(pulse.playCount == 1, "enabling pulse must also cover an already-active native window")
nativePrivateMixin.EnterPandemicWindow(button)
assert(pulse.playing and pulse.playCount == 2, "native pandemic entry must start the registered pulse")
Skin.Restyle(container, profile)
assert(#button.pandemicActiveAnimations == 1 and button.pandemicActiveAnimations[1].element == pulse
    and pulse.playCount == 2, "repeated restyle must not duplicate, recreate or restart the pulse")

glow.style = "flash"
Skin.Restyle(container, profile)
assert(#button.pandemicActiveAnimations == 0 and #button.pandemicEnterAnimations == 1 and not pulse.playing,
    "switching to flash must unregister and stop the previous pulse")
local flash = button.pandemicEnterAnimations[1].element
assert(flash ~= pulse and flash.parent == button._quiPandemic, "flash requires its own cached animation")
nativePrivateMixin.EnterPandemicWindow(button)
assert(flash.playing, "native pandemic entry must start the flash")
local flashPlays = flash.playCount
Skin.Restyle(container, profile)
assert(flash.playCount == flashPlays and #button.pandemicEnterAnimations == 1,
    "ordinary restyles must not replay or duplicate the flash")
Skin.Restyle(container, {})
assert(button.casterName == nil and button._quiCaster.alpha == 0,
    "disabling caster label must clear its native registration and alpha")
assert(#button.pandemicEnterAnimations == 0 and #button.pandemicActiveAnimations == 0
    and not flash.playing and button._quiPandemic.alpha == 0,
    "disabling glow must stop and unregister animations and clear alpha")
glow.style = "pulse"
Skin.Restyle(container, profile)
assert(button.pandemicActiveAnimations[1].element == pulse,
    "re-enabling pulse must reuse its already-adopted group without querying it")
glow.style = "steady"
Skin.Restyle(container, profile)
assert(#button.pandemicActiveAnimations == 0 and not pulse.playing and button._quiPandemic.alpha == 0.7,
    "steady style must restore constant alpha and remove the pulse")

local legacy = Button(true)
legacy.SetCasterName, legacy.ClearCasterName = nil, nil
legacy.AddPandemicActiveAnimation, legacy.RemovePandemicActiveAnimation = nil, nil
legacy.AddPandemicEnterAnimation, legacy.RemovePandemicEnterAnimation = nil, nil
glow.style = "pulse"
Skin.WireButton(legacy, profile)
assert(not legacy._quiCaster or legacy._quiCaster.alpha == 0,
    "unsupported native caster labels must stay invisible")
assert(legacy._quiPandemic.alpha == 0.7 and #legacy.pandemicActiveAnimations == 0,
    "unsupported animations must fall back to the existing steady glow")

local defaults = Button(true)
Skin.WireButton(defaults, { casterName = {} })
assert(defaults.casterName.options.showRealmName == false and defaults.casterName.options.useClassColors == false,
    "omitted native caster options must default to false")
assert(defaults._quiCaster.font[2] == 10 and defaults._quiCaster.point[1] == "BOTTOM"
    and defaults._quiCaster.point[4] == 0 and defaults._quiCaster.point[5] == 1,
    "caster labels must have the agreed default font and position")

local preview = Button(false)
Skin.WirePreviewButton(preview, profile)
assert(preview._quiCaster and preview._quiCaster.text == "Caster-Realm",
    "plain preview must show a sample caster and enabled realm without native APIs")
local previewPulse = preview._quiPandemicAnimations and preview._quiPandemicAnimations.pulse
assert(previewPulse and previewPulse.playing and not previewPulse.adopted,
    "plain preview must play its own unrestricted pulse")
Skin.WirePreviewButton(preview, {})
assert(preview._quiCaster.alpha == 0 and not previewPulse.playing,
    "disabling preview labels and glow must clear their visual state")
caster.showRealmName = false
Skin.WirePreviewButton(preview, profile)
assert(preview._quiCaster.text == "Caster" and previewPulse.playing,
    "preview must reflect realm changes and restart the cached pulse")
Skin.ReleasePreviewButton(preview)
assert(not previewPulse.playing and preview._quiCaster.alpha == 0,
    "releasing a preview must stop its animations and hide its caster label")
Skin.WirePreviewButton(preview, profile)
assert(previewPulse.playing, "reusing a released preview must restart its animation")

print("OK: aura_skin_native_labels_animation_test")
