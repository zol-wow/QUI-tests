local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
env.profile.general.skinItemUpgrade = true
_G.UIPanelWindows = {}
_G.Enum = {ItemRedundancySlot = {Trinket = 1, Finger = 2, Twohand = 3, OnehandWeapon = 4, MainhandWeapon = 5, Offhand = 6}}
_G.Enum.ItemQuality = {Rare = 3, Epic = 4}
_G.SOUNDKIT = {}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_ItemUpgradeUI/Mainline/Blizzard_ItemUpgradeUI.lua"))()
local frame = env.NewFrame("Frame", "ItemUpgradeFrame")
_G.ItemUpgradeFrame = frame
for method, fn in pairs(_G.ItemUpgradeMixin) do frame[method] = fn end
for _, key in ipairs({"TopBG", "BottomBG", "BottomBGShadow", "IdleGlow", "MicaFleckSheen", "Ring", "BottomPanel_Flash"}) do
    frame[key] = frame:CreateTexture()
end
frame.MissingDescription, frame.FrameErrorText = frame:CreateFontString(), frame:CreateFontString()
frame.FrameErrorText:SetTextColor(1, 0, 0, 1)
frame.FrameErrorText:SetText("Native warning")
local slot = env.NewFrame("ItemButton", nil, frame)
frame.UpgradeItemButton = slot
slot:SetFrameLevel(6)
slot.icon, slot.IconBorder, slot.ButtonFrame, slot.EmptySlotGlow =
    slot:CreateTexture(), slot:CreateTexture(), slot:CreateTexture(), slot:CreateTexture()
slot.CreateMaskTexture = slot.CreateTexture
local maskCount = 0
function slot.icon:AddMaskTexture() maskCount = maskCount + 1 end
slot.PulseEmptySlotGlow = {Restart = function(self) self.running = true end, Stop = function(self) self.running = false end}
slot:SetScript("OnClick", _G.ItemUpgradeSlotMixin.OnClick)
slot:SetScript("OnDragStart", _G.ItemUpgradeSlotMixin.OnDrag)
frame.UpgradeButton = env.NewFrame("Button", nil, frame)
frame.UpgradeButton.DisabledTexture = false
frame.UpgradeButton:SetScript("OnClick", _G.ItemUpgradeButtonMixin.OnClick)
frame.UpgradeButton.SetDisabledTooltip = function(self, text) self.disabledTooltip = text end
frame.ItemInfo = env.NewFrame("Frame", nil, frame)
local info = frame.ItemInfo
for method, fn in pairs(_G.ItemUpgradeItemInfoMixin) do info[method] = fn end
for _, key in ipairs({"MissingItemText", "ItemName", "UpgradeProgress", "UpgradeTo"}) do info[key] = info:CreateFontString() end
info.Dropdown = env.NewFrame("DropdownButton", nil, info)
info.Dropdown.DisabledTexture = false
info.Layout = function() end
frame.UpgradeCostFrame = env.NewFrame("Frame", nil, frame)
frame.UpgradeCostFrame.BGTex = frame.UpgradeCostFrame:CreateTexture()
frame.UpgradeCostFrame.quantity = frame.UpgradeCostFrame:CreateFontString()
frame.UpgradeCostFrame.quantity:SetTextColor(1, 0, 0, 1)
frame.UpgradeCostFrame.quantity:SetText("12")
frame.PlayerCurrenciesBorder = env.NewFrame("Frame", nil, frame)
local gold = frame.PlayerCurrenciesBorder:CreateTexture()
frame.PlayerCurrencies = env.NewFrame("Frame", nil, frame)
frame.PlayerCurrencies.quantity = frame.PlayerCurrencies:CreateFontString()
frame.PlayerCurrencies.quantity:SetText("23")
local previews = 0
for _, key in ipairs({"LeftItemPreviewFrame", "RightItemPreviewFrame", "ItemHoverPreviewFrame"}) do
    local preview = env.NewFrame("GameTooltip", nil, frame)
    frame[key] = preview
    preview.Bg = preview:CreateTexture()
    preview.GlowNineSlice = env.NewFrame("Frame", nil, preview)
    preview.GlowAnimatedPieces = env.NewFrame("Frame", nil, preview)
    preview.UpgradedAnim = {Restart = function(self) self.restarted = true end}
    preview.ReappearAnim = {Stop = function() end}
    preview.line = preview:CreateFontString()
    preview.line:SetTextColor(0.5, 0.2, 1, 1)
    preview.GeneratePreviewTooltip = function(self)
        previews = previews + 1
        self.Bg:Show()
        self.line:SetText("|cff8000ffNative preview|r")
    end
end
frame.Arrow = env.NewFrame("Frame", nil, frame)
frame.AnimationHolder = {UpgradedFlash = {Restart = function(self) self.restarted = true end}}
frame.UpdateButtonAndArrowStates = function(self, disabled) self.UpgradeButton.enabled = not disabled end
frame.CalculateTotalCostTable = function() end
frame.PopulatePreviewFrames = function(self) self.ItemInfo:Setup(self.upgradeInfo, true) end
frame.InitDropdown = function() end
local qualityColors = {[3] = {0, 0.4, 1}, [4] = {0.6, 0.2, 1}}
_G.C_Item.GetItemQualityColor = function(quality) return unpack(qualityColors[quality]) end
_G.ColorManager = {GetColorDataForItemQuality = function(quality)
    return {color = {WrapTextInColorCode = function(_, text) return "|c" .. quality .. text .. "|r" end}}
end}
local nativeInfo
_G.C_ItemUpgrade = {GetItemUpgradeItemInfo = function() return nativeInfo end, GetItemUpgradeCurrentLevel = function() return 100 end}
_G.ITEM_UPGRADE_PROGRESS_LEVEL_FORMAT = "%d/%d %d %d-%d"
_G.SetItemButtonTexture = function(owner, texture) owner.icon:SetTexture(texture) end
_G.SetItemButtonQuality = function(owner, quality) owner.nativeQuality = quality end
_G.PlaySound = function() end
_G.GenerateClosure = function(fn, self) return function() fn(self) end end
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_ItemUpgradeUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinItemUpgrade" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callback()
assert(frame.TopBG:GetAlpha() == 0 and gold:GetAlpha() == 0, "native inner panel and gold currency decoration must be suppressed")
assert(skin.GetBackdrop(slot)._quiRoundedSurface.radius == 4, "native item slot must use rounded chrome")
for _, quality in ipairs({3, 4, 3}) do
    nativeInfo = {displayQuality = quality, iconID = 900 + quality, currUpgrade = 1, maxUpgrade = 3,
        name = "Native item", minItemLevel = 100, maxItemLevel = 120,
        upgradeLevelInfos = {{displayQuality = quality}, {displayQuality = 4}}}
    frame.upgradeAnimationsInProgress = false
    frame:UpdateUpgradeItemInfo()
    local color = qualityColors[quality]
    assert(skin.GetBackdrop(slot)._quiBorderR == color[1] and skin.GetBackdrop(slot)._quiBorderB == color[3],
        "reused rounded slot border must follow current item quality")
    assert(slot.icon.texture == 900 + quality and info.ItemName:GetText() == "|c" .. quality .. "Native item|r",
        "native item art and inline quality markup must survive")
    frame.LeftItemPreviewFrame:GeneratePreviewTooltip()
    assert(not frame.LeftItemPreviewFrame.Bg:IsShown() and skin.GetBackdrop(frame.LeftItemPreviewFrame)._quiRoundedSurface.radius == 4,
        "native regenerated preview must regain rounded chrome")
end
frame:PlayUpgradedCelebration()
assert(skin.GetBackdrop(slot)._quiBorderR == qualityColors[4][1] and slot.nativeQuality == 4,
    "celebration border must reflect the native target quality")
assert(frame.LeftItemPreviewFrame.UpgradedAnim.restarted and frame.AnimationHolder.UpgradedFlash.restarted
    and frame.Ring:GetAlpha() == 1 and frame.BottomPanel_Flash:GetAlpha() == 1, "native success effects must survive")
nativeInfo = nil
frame:UpdateUpgradeItemInfo()
local sr = skin.GetWindowColors()
assert(skin.GetBackdrop(slot)._quiBorderR == sr and info.MissingItemText:IsShown() and not info.ItemName:IsShown()
    and slot.EmptySlotGlow:IsShown() and slot.PulseEmptySlotGlow.running and not frame.UpgradeButton:IsEnabled(),
    "native empty-slot state must survive and clear stale quality")
assert(frame.UpgradeCostFrame.quantity:GetText() == "12" and frame.PlayerCurrencies.quantity:GetText() == "23"
    and frame.UpgradeCostFrame.quantity.textColor[1] == 1 and frame.UpgradeCostFrame.quantity.textColor[2] == 0
    and frame.FrameErrorText:GetText() == "Native warning", "native cost quantities and warning colors/text must survive")
local backdrop = skin.GetBackdrop(slot)
backdrop._quiBorderR = -1
refresh()
assert(backdrop._quiBorderR ~= -1 and skin.GetBackdrop(slot) == backdrop and maskCount == 1 and previews == 4,
    "theme refresh must reuse chrome/masks without generating native previews")
assert(slot:GetScript("OnClick") == _G.ItemUpgradeSlotMixin.OnClick
    and slot:GetScript("OnDragStart") == _G.ItemUpgradeSlotMixin.OnDrag
    and frame.UpgradeButton:GetScript("OnClick") == _G.ItemUpgradeButtonMixin.OnClick,
    "native item and upgrade action handlers must survive")
print("OK: item_upgrade_surfaces_test")
