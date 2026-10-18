local function noop() end
Enum = {
    SecretAspect = { Text = 1, Alpha = 2, VertexColor = 3 },
    NumericRuleFormatRounding = { Up = 1 },
    CustomAuraButtonUpdateMode = { Assignment = 1, Update = 2 },
}
CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({ ... }) do
        for key, value in pairs(mixin) do result[key] = value end
    end
    return result
end
AuraButtonPrivateMixin = {}
securecopy = function(value)
    local copy = {}
    for key, item in pairs(value or {}) do copy[key] = item end
    return copy
end
AuraContainerUtil = {
    ValidateInboundScriptObject = noop,
    RequireObjectType = function() return noop end,
    InitializeInboundScriptObject = function(object) return object end,
}
C_AuraContainerUtil = { ProcessCustomAuraButtonDurationTextOptions = function(options) return options end }
C_StringUtil = { CreateNumericRuleFormatter = function() return { SetBreakpoints = noop } end }
local secret, combat, timers = false, false, {}
C_Secrets = { ShouldAurasBeSecret = function() return secret end }
InCombatLockdown = function() return combat end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local defaultFormatter = {}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua"))(
    "Blizzard_AuraContainer", { DefaultAuraDurationFormatter = defaultFormatter })
local native, private = _G.CustomAuraButtonSharedMixin, _G.CustomAuraButtonPrivateMixin
local font, failures = "first.ttf", 0
local ns = {
    Helpers = { GetGeneralFont = function() return font end, GetGeneralFontOutline = function() return "OUTLINE" end },
    SafeCall = function(_, callback, ...)
        local ok = pcall(callback, ...)
        if not ok then failures = failures + 1 end
        return ok
    end,
}
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
local skin = ns.AuraSkin
local function text()
    return {
        AddSecretAspect = noop, ClearAllPoints = noop, SetPoint = noop,
        SetFont = function(self, ...) self.font = { ... } end,
        SetTextColor = function(self, ...) self.color = { ... } end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
    }
end
local function duration(zero) return { IsZero = function() return zero end } end
local function button()
    local b = { _quiWired = true, _quiDuration = text(), duration = duration(false), SetSize = noop, SetAlpha = noop }
    local binding = { resets = 0 }
    function binding:SetToDefaults()
        self.resets = self.resets + 1
        self.fontString, self.duration, self.formatter = nil, nil, nil
    end
    function binding:SetFormatter(value) self.formatter = value end
    function binding:SetFontString(value)
        if self.reject then error("binding rejected") end
        self.fontString = value
    end
    function binding:SetDuration(value) self.duration = value end
    function binding:SetEnabled(value) self.enabled = value end
    b.GetDurationTextBinding = function() return binding end
    b.GetAuraDuration = function(self) return self.duration end
    b.SetDurationText = native.SetDurationText
    b.ApplyDurationText = private.ApplyDurationText
    b.ApplyAuraInstance = function(self, unit, aura) self:ApplyDurationText(unit, aura, self.duration) end
    b.UpdateAuraDisplay = function(self) self:ApplyAuraInstance("raid1", {}) end
    return b, binding
end
local b, binding = button()
local container = { _quiButtons = { b } }
local profile = { duration = {} }
skin.WireButton(b, profile)
assert(binding.resets == 1 and binding.formatter == defaultFormatter)
for _ = 1, 100 do skin.Restyle(container, profile) end
assert(binding.resets == 1, "100 unchanged restyles must not reset the native binding; got " .. binding.resets)
font = "second.ttf"
profile.duration.fontSize, profile.duration.color, profile.duration.show = 17, { 0.2, 0.3, 0.4, 0.5 }, false
skin.Restyle(container, profile)
assert(binding.resets == 1 and b._quiDuration.font[1] == font and b._quiDuration.font[2] == 17
    and b._quiDuration.color[4] == 0.5 and b._quiDuration.alpha == 0,
    "font, color and visibility styling must still run without rebinding")
profile.duration.decimals = true
skin.Restyle(container, profile)
local decimals = binding.formatter
assert(binding.resets == 2 and decimals ~= defaultFormatter)
profile.duration.hideUnit = true
skin.Restyle(container, profile)
assert(binding.resets == 3 and binding.formatter ~= decimals)
profile.duration.decimals, profile.duration.hideUnit = false, false
skin.Restyle(container, profile)
assert(binding.resets == 4 and binding.formatter == defaultFormatter, "returning to nil formatter must restore native defaults")
b._quiDuration = text()
skin.Restyle(container, profile)
assert(binding.resets == 5 and binding.fontString == b._quiDuration, "a replacement font string must be bound")

for _, method in ipairs({ "OnAuraInstanceAssigned", "OnAuraInstanceUpdated", "OnAuraInstanceCleared" }) do
    b.duration = duration(method == "OnAuraInstanceCleared")
    private[method](b, "raid2", {})
    assert(binding.duration == b.duration and binding.enabled == (method ~= "OnAuraInstanceCleared"),
        "native assignment/update/clear must maintain the duration and enabled state")
end
b.duration = duration(false)
private.OnAuraInstanceAssigned(b, "raid3", {})
assert(binding.duration == b.duration and binding.enabled, "reassignment after a zero duration must resume native updates")
skin.Restyle(container, profile)
assert(binding.resets == 5, "native aura lifecycle must preserve the binding configuration")

profile.duration.decimals = true
binding.reject = true
skin.Restyle(container, profile)
assert(failures == 1 and binding.resets == 6)
binding.reject = false
skin.Restyle(container, profile)
assert(binding.resets == 7 and binding.formatter == decimals, "failed binding application must retry")
profile.duration.hideUnit = true
binding.reject = true
skin.Restyle(container, profile)
binding.reject = false
profile.duration.hideUnit = false
skin.Restyle(container, profile)
assert(binding.resets == 9 and binding.fontString == b._quiDuration and binding.formatter == decimals,
    "a partially failed change must not leave the previous configuration falsely cached")

secret = true
profile.duration.hideUnit = true
skin.Restyle(container, profile)
assert(binding.resets == 9 and #timers == 1, "restricted restyles must keep the existing deferred replay")
secret, combat = false, true
timers[1]()
assert(binding.resets == 9 and #timers == 2)
combat = false
timers[2]()
assert(binding.resets == 10 and binding.formatter ~= decimals, "deferred replay must apply changed binding options")
local other, otherBinding = button()
skin.WireButton(other, profile)
assert(otherBinding.resets == 1 and otherBinding.fontString == other._quiDuration,
    "binding caches must belong to individual buttons")
print("PASS aura_skin_duration_binding_test")
