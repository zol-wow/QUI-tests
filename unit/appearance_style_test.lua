local env = dofile("tools/_addon_env.lua")
local h = env.LoadHarness(nil, { noSeed = true })
local Helpers = h.ns.Helpers
local general = { visualStyle = "Satin" }
h.db.profile.general = general
h.QUI.GetSkinColor = function() return 0.8, 0.7, 0.5, 1 end
h.QUI.GetSkinBgColor = function()
    local c = general.skinBgColor or { 0.05, 0.05, 0.05, 0.95 }
    return c[1], c[2], c[3], c[4]
end
Helpers.GetPlayerClassColor = function() return 0.2, 0.4, 0.9 end

local satin = Helpers.AssetPath .. "appearance\\Satin.tga"
for _, path in ipairs({
    "Interface\\Buttons\\WHITE8x8", "Interface\\TargetingFrame\\UI-StatusBar",
    Helpers.AssetPath .. "Square.tga", Helpers.AssetPath .. "Quazii.tga",
    Helpers.AssetPath .. "Quazii_v5_Inverse.tga", satin,
}) do
    assert(Helpers.GetStyledBarTexture(path) == satin, path)
end
for _, path in ipairs({ "Interface\\AddOns\\Other\\custom.tga", "Quazii", 12345 }) do
    assert(Helpers.GetStyledBarTexture(path) == path, "custom media must stay literal")
end
local bar = {
    SetStatusBarTexture = function(self, ...)
        assert(select("#", ...) == 1, "texture sink must receive one argument")
        self.path = ...
    end,
    GetValue = function() error("appearance must not inspect a combat value") end,
    GetWidth = function() error("appearance must not infer fill geometry") end,
    CreateTexture = function() error("bar finish must use its native masked fill") end,
}
Helpers.ApplyBarStyle(bar, "Interface\\Buttons\\WHITE8x8")
assert(bar.path == satin)
general.visualStyle = "Legacy"
Helpers.ApplyBarStyle(bar, Helpers.AssetPath .. "Quazii_v5.tga")
assert(bar.path == Helpers.AssetPath .. "Quazii_v5.tga")
general.visualStyle = "Satin"

local function near(a, b) return math.abs(a - b) < 0.00001 end
local r, g, b, a, br, bg, bb, ba = Helpers.GetWindowColors()
assert(near(r, 0.2824) and near(g, 0.3294) and near(b, 0.3098) and a == 1)
assert(near(br, 0.0745) and near(bg, 0.1059) and near(bb, 0.1176) and ba == 0.95)
assert(Helpers.GetSkinAccentColor() == 0.8, "semantic accent must stay unchanged")
general.hideSkinBorders = true
local _, _, _, hidden = Helpers.GetWindowColors()
assert(hidden == 0)
general.hideSkinBorders = nil
general.skinBorderColorSource = "class"
r, g, b = Helpers.GetWindowColors()
assert(r == 0.2 and g == 0.4 and b == 0.9)
general.skinBorderColorSource = "custom"
general.skinBorderColor = { 0.1, 0.3, 0.6, 0.25 }
r, g, b, a = Helpers.GetWindowColors()
assert(r == 0.1 and g == 0.3 and b == 0.6 and a == 0.25)
general.skinBorderColorSource = nil
r, g, b, a = Helpers.GetWindowColors({ borderColorSource = "theme" })
assert(r == 0.8 and g == 0.7 and b == 0.5 and a == 1)
general.skinBgColor = { 0.02, 0.04, 0.06, 0.3 }
_, _, _, _, br, bg, bb, ba = Helpers.GetWindowColors()
assert(br == 0.02 and bg == 0.04 and bb == 0.06 and ba == 0.3)
general.skinBgColor = nil
_, _, _, _, br, bg, bb, ba = Helpers.GetWindowColors({ bgOverride = true, backgroundColor = { 0.6, 0.4, 0.2, 0.5 } })
assert(br == 0.6 and bg == 0.4 and bb == 0.2 and ba == 0.5)
general.visualStyle = "Legacy"
r, g, b = Helpers.GetWindowColors()
assert(r == 0.8 and g == 0.7 and b == 0.5)
general.visualStyle = "Satin"

_G.hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local function texture()
    return {
        masks = {}, shown = true, alpha = 0.7, layer = "OVERLAY", level = 3,
        SetTexture = function(self, path) self.path = path end,
        SetAllPoints = function(self, source) self.source = source end,
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        SetShown = function(self, value)
            assert(self.nativeSecretVisibility or not Helpers.IsSecretValue(value), "tainted SetShown must not receive secret visibility")
            self.shown = value
        end,
        IsShown = function(self) return self.shown end,
        SetAlpha = function(self, value) self.alpha = value end,
        GetAlpha = function(self) return self.alpha end,
        SetAlphaFromBoolean = function(self, shown, alpha, hiddenAlpha)
            assert(Helpers.IsSecretValue(shown), "secret visibility must use its native boolean sink")
            self.nativeVisibility = { shown, alpha, hiddenAlpha }
        end,
        SetDrawLayer = function(self, layer, level)
            assert(not Helpers.HasSecretValue(layer, level), "native draw-layer sink must not receive secret metadata")
            self.layer, self.level = layer, level
        end,
        GetDrawLayer = function(self) return self.layer, self.level end,
        AddMaskTexture = function(self, mask)
            for _, existing in ipairs(self.masks) do assert(existing ~= mask, "duplicate native mask") end
            self.masks[#self.masks + 1] = mask
        end,
        RemoveMaskTexture = function(self, mask)
            for i, existing in ipairs(self.masks) do
                if existing == mask then table.remove(self.masks, i) return end
            end
        end,
        GetNumMaskTextures = function(self) return #self.masks end,
        GetMaskTexture = function(self, index) return self.masks[index] end,
    }
end
local overlays = {}
local parent = { CreateTexture = function()
    local overlay = texture()
    overlays[#overlays + 1] = overlay
    return overlay
end }
local icon = texture()
icon.nativeSecretVisibility = true
local mask = {}
icon:AddMaskTexture(mask)
Helpers.ApplyIconStyle(parent, icon, "Default")
local finish = assert(overlays[1])
assert(finish.source == icon and finish.layer == "OVERLAY" and finish.level == 4)
assert(finish.alpha == 0.7 and finish.shown and finish.masks[1] == mask)
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(#overlays == 1 and #finish.masks == 1, "finish must be reused without duplicate masks")
local normalDrawLayer = icon.GetDrawLayer
for _, restricted in ipairs({
    { env.MakeSecret(), 3 }, { "OVERLAY", env.MakeSecret() },
    { env.MakeSecret(), env.MakeSecret() },
}) do
    icon.GetDrawLayer = function() return restricted[1], restricted[2] end
    Helpers.ApplyIconStyle(parent, icon, "Default")
    assert(finish.layer == "ARTWORK" and finish.level == 2,
        "restricted aura draw metadata must use the known finish layer")
    assert(#overlays == 1 and finish.shown, "restricted restyle must reuse and retain the Satin finish")
end
icon.GetDrawLayer = normalDrawLayer
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.layer == "OVERLAY" and finish.level == 4, "readable metadata must resume normal layer ordering")
local secretShown, secretAlpha = env.MakeSecret(), env.MakeSecret()
local freshIcon, freshFinish = texture()
freshIcon.layer, freshIcon.level = env.MakeSecret(), env.MakeSecret()
freshIcon.shown, freshIcon.alpha = secretShown, secretAlpha
freshIcon.nativeSecretVisibility = true
local freshParent = { CreateTexture = function()
    freshFinish = texture()
    return freshFinish
end }
Helpers.ApplyIconStyle(freshParent, freshIcon, "Default")
assert(freshFinish.layer == "ARTWORK" and freshFinish.level == 2 and freshFinish.source == freshIcon
    and freshFinish.nativeVisibility[1] == secretShown and freshFinish.nativeVisibility[2] == secretAlpha,
    "first-time restricted aura creation must support secret draw, shown and alpha metadata")
icon.shown, icon.alpha = secretShown, secretAlpha
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.nativeVisibility[1] == secretShown and finish.nativeVisibility[2] == secretAlpha
    and finish.nativeVisibility[3] == 0 and finish.shown,
    "initial secret visibility and alpha must reach the permitted native sink")
icon:SetAlpha(0.6)
assert(finish.nativeVisibility[1] == secretShown and finish.nativeVisibility[2] == 0.6,
    "alpha changes must preserve secret visibility gating")
local nextShown = env.MakeSecret()
icon:SetShown(nextShown)
assert(finish.nativeVisibility[1] == nextShown and finish.nativeVisibility[2] == 0.6,
    "hooked secret visibility must avoid SetShown")
Helpers.ApplyIconStyle(parent, icon, "External")
icon:SetAlpha(secretAlpha)
icon:SetShown(secretShown)
assert(not finish.shown, "external ownership must keep a secret-driven finish suppressed")
icon:Show()
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.shown and finish.alpha == secretAlpha and #overlays == 1,
    "readable visibility must recover without creating another finish")
icon:Hide()
assert(not finish.shown)
icon:Show()
assert(finish.shown)
local nativeOnly = {}
icon:SetAlpha(nativeOnly)
icon:SetShown(nativeOnly)
assert(finish.alpha == nativeOnly and finish.shown == nativeOnly, "native properties must pass through without inspection")
icon:SetAlpha(0.4)
icon:SetShown(false)
assert(finish.alpha == 0.4 and not finish.shown)
local secondMask = {}
icon:AddMaskTexture(secondMask)
assert(#finish.masks == 2)
icon:RemoveMaskTexture(mask)
assert(#finish.masks == 1 and finish.masks[1] == secondMask)
for _, style in ipairs({ "Flat", "Minimal", "Gloss", "External", "Empty" }) do
    Helpers.ApplyIconStyle(parent, icon, style)
    icon:Show()
    assert(not finish.shown, style .. " must retain its chosen skin ownership")
end
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.shown)
local normalCount = icon.GetNumMaskTextures
local unreadableMask = env.MakeSecret()
icon.GetNumMaskTextures = function() return unreadableMask end
Helpers.ApplyIconStyle(parent, icon, "Default")
icon:Show()
assert(not finish.shown, "unreadable mask hierarchy must not escape its mask")
icon.GetNumMaskTextures = normalCount
local normalMask = icon.GetMaskTexture
icon.GetMaskTexture = function() return unreadableMask end
Helpers.ApplyIconStyle(parent, icon, "Default")
icon:Show()
assert(not finish.shown, "unreadable mask must not enter an addon-owned table")
icon.GetMaskTexture = normalMask
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.shown)
icon:AddMaskTexture(unreadableMask)
assert(not finish.shown, "a newly unreadable mask must suppress the finish")
icon:RemoveMaskTexture(unreadableMask)
Helpers.ApplyIconStyle(parent, icon, "Default")
assert(finish.shown)
general.visualStyle = "Legacy"
Helpers.ApplyIconStyle(parent, icon, "Default")
icon:Show()
assert(not finish.shown)
general.visualStyle = "Satin"

assert(loadfile("core/theme.lua"))("QUI", h.ns)
local GUI = h.QUI.GUI
local token = GUI.Colors.bg
local goldR, goldG, goldB = GUI:ResolveThemePreset("Satin Gold")
assert(goldR == 0.8353 and goldG == 0.7412 and goldB == 0.5529)
GUI:ApplyAccentColor(0.12, 0.34, 0.56)
assert(GUI.Colors.bg == token and token[1] == 0.0745)
assert(GUI.Colors.accent[1] == 0.12 and GUI.Colors.selectedWash[4] == 0.10)
general.visualStyle = "Legacy"
GUI:ApplyAccentColor(0.12, 0.34, 0.56)
assert(token[1] == 0.051 and GUI.Colors.textMuted[4] == 0.45)
general.visualStyle = "Satin"

local IconSkin = assert(loadfile("core/icon_skin.lua"))("QUI", h.ns)
local gloss = texture()
IconSkin.ApplySkin(parent, { Icon = icon, Gloss = gloss }, "Default")
assert(not gloss.shown and finish.shown, "Default must not stack the legacy gloss and Satin finish")
IconSkin.ApplySkin(parent, { Icon = icon, Gloss = gloss }, "Gloss")
assert(gloss.shown and gloss.alpha == 0.9 and not finish.shown)
general.visualStyle = "Legacy"
IconSkin.ApplySkin(parent, { Icon = icon, Gloss = gloss }, "Default")
assert(gloss.shown and gloss.alpha == 0.5 and not finish.shown)

for _, name in ipairs({ "Satin", "SatinIcon" }) do
    local file = assert(io.open("assets/appearance/" .. name .. ".tga", "rb"))
    local bytes = file:read("*a")
    file:close()
    assert(bytes:byte(3) == 2 and bytes:byte(13) == 32 and bytes:byte(15) == 64)
    assert(bytes:byte(17) == 32 and bytes:byte(18) == 0x28 and #bytes == 18 + 32 * 64 * 4)
    local top, bottom = 19, 19 + 32 * 63 * 4
    assert(bytes:byte(top) > bytes:byte(bottom), "finish gradient must shade the lower edge")
    if name == "Satin" then
        for offset = 22, #bytes, 4 do assert(bytes:byte(offset) == 255, "bar fill must stay opaque") end
    else
        assert(bytes:byte(top + 3) < 64 and bytes:byte(bottom + 3) < 64, "icon artwork must stay visible")
    end
end
print("appearance_style_test: OK")
