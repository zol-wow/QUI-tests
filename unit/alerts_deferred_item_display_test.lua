local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
local colors = {[2] = {0.12, 1, 0}, [3] = {0, 0.44, 0.87}, [4] = {0.64, 0.21, 0.93}}
local atlases = {[2] = "loottoast-itemborder-green", [3] = "loottoast-itemborder-blue", [4] = "loottoast-itemborder-purple"}
_G.Enum = {ItemQuality = {Uncommon = 2, Rare = 3, Epic = 4}}
_G.C_Item.GetItemQualityByID = function() return nil end
_G.C_Item.GetItemQualityColor = function(quality) return unpack(colors[quality]) end
_G.ColorManager = {GetAtlasDataForLootBorderItemQuality = function(quality) return atlases[quality] end}
local frame = env.NewFrame("Button")
frame.Icon = frame:CreateTexture()
frame.IconBorder = frame:CreateTexture()
function frame.IconBorder:GetAtlas() return self.atlas end
frame.IconOverlay = frame:CreateTexture()
frame.Name = frame:CreateFontString()
frame.Label = frame:CreateFontString()
local calls = 0
function frame:SetUpDisplay(icon, quality, name, label, overlayAtlas)
    calls = calls + 1
    self.Icon:SetTexture(icon)
    self.IconBorder:SetAtlas(atlases[quality])
    self.Name:SetText("|cff0070dd" .. name .. "|r")
    self.Label:SetText(label)
    self.IconOverlay:SetAtlas(overlayAtlas)
    self.IconOverlay:Show()
end
local nativeClick, nativeEnter = function() end, function() end
frame:SetScript("OnClick", nativeClick)
frame:SetScript("OnEnter", nativeEnter)
_G.NewCosmeticAlertFrameSystem = {
    setUpFunction = function(owner, id)
        owner.itemModifiedAppearanceID = id
        owner:SetUpDisplay("pending-art", 4, "", "Collected", "CosmeticIconFrame")
    end,
    alertFramePool = {EnumerateActive = function() return next, {[frame] = true} end},
}
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
_G.NewCosmeticAlertFrameSystem.setUpFunction(frame, 100)
env.RunTimers()
local border = skin.GetFrameData(frame, "iconBorder")
assert(border._quiBorderR == 0.64, "initial fallback rarity must skin normally")
frame:SetUpDisplay("loaded-cosmetic-art", 3, "Loaded cosmetic", "Collected", "CosmeticIconFrame")
assert(border._quiBorderR == 0 and border._quiBorderB == 0.87,
    "later native display update must replace fallback quality immediately")
assert(frame.IconBorder:GetAlpha() == 0, "deferred native border must remain suppressed")
assert(frame.Name:GetText() == "|cff0070ddLoaded cosmetic|r" and frame.Icon.texture == "loaded-cosmetic-art",
    "native loaded name markup and artwork must survive")
assert(frame.IconOverlay.atlas == "CosmeticIconFrame" and frame.IconOverlay:IsShown(),
    "native cosmetic overlay must survive the deferred update")
_G.NewCosmeticAlertFrameSystem.setUpFunction(frame, 101)
env.RunTimers()
frame:SetUpDisplay("second-loaded-art", 2, "Second cosmetic", "Collected", "CosmeticIconFrame")
assert(border == skin.GetFrameData(frame, "iconBorder") and border._quiBorderR == 0.12 and border._quiBorderB == 0,
    "reused toast must reuse its border and accept the next deferred quality")
assert(calls == 4, "styling must not invoke or recursively repeat native display updates")
assert(frame:GetScript("OnClick") == nativeClick and frame:GetScript("OnEnter") == nativeEnter,
    "native cosmetic navigation and tooltip handlers must survive")
border._quiBorderR = 0.33
_G.QUI_RefreshAlertColors()
assert(border._quiBorderR == 0.12, "theme refresh must retain final loaded quality")
print("OK: alerts_deferred_item_display_test")
