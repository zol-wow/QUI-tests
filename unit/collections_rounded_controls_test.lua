local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinCollections = true
_G.CollectionsJournal = env.NewFrame("Frame")
_G.MountJournal = env.NewFrame("Frame", nil, _G.CollectionsJournal)
_G.MountJournal.searchBox = env.NewFrame("EditBox", nil, _G.MountJournal)
_G.MountJournal.searchBox.searchIcon = _G.MountJournal.searchBox:CreateTexture()
_G.MountJournal.FilterDropdown = env.NewFrame("Button", nil, _G.MountJournal)
_G.MountJournal.FilterDropdown.DisabledTexture = false
_G.MountJournal.MountButton = env.NewFrame("Button", nil, _G.MountJournal)
_G.MountJournal.MountButton.DisabledTexture = false
_G.MountJournal.MountButton.Text = _G.MountJournal.MountButton:CreateFontString()
local change = function() end
_G.MountJournal.searchBox:SetScript("OnTextChanged", change)
_G.WardrobeCollectionFrame = env.NewFrame("Frame", nil, _G.CollectionsJournal)
local wardrobe = _G.WardrobeCollectionFrame
wardrobe.SetsCollectionFrame = false
wardrobe.ItemsTab = env.NewFrame("Button", nil, wardrobe)
wardrobe.SetsTab = env.NewFrame("Button", nil, wardrobe)
wardrobe.ItemsCollectionFrame = env.NewFrame("Frame", nil, wardrobe)
local items = wardrobe.ItemsCollectionFrame
items.BackgroundTile = items:CreateTexture()
items.BackgroundTile:SetAtlas("collections-background-tile")
wardrobe.ClassDropdown = env.NewFrame("Button", nil, wardrobe)
wardrobe.ClassDropdown.DisabledTexture = false
items.PagingFrame = env.NewFrame("Frame", nil, items)
items.PagingFrame.PrevPageButton = env.NewFrame("Button", nil, items.PagingFrame)
items.PagingFrame.NextPageButton = env.NewFrame("Button", nil, items.PagingFrame)
local nextPage = function() end
items.PagingFrame.NextPageButton:SetScript("OnClick", nextPage)
items.PagingFrame.NextPageButton.DisabledTexture = false
items.PagingFrame.PrevPageButton.DisabledTexture = false
items.ModelR1C1 = env.NewFrame("PlayerModel", nil, items)
local model = items.ModelR1C1
model.previewArt = model:CreateTexture()
model.previewArt:SetAtlas("appearance-preview")
items.Models = { model }
model.visualInfo = { isCollected = true, isUsable = true }
model.Border = model:CreateTexture()
function model.Border:GetDrawLayer() return "OVERLAY" end
function model.previewArt:GetDrawLayer() return "ARTWORK" end
local viewportBackground = model:CreateTexture()
viewportBackground:SetColorTexture(0, 0, 0, 1)
function viewportBackground:GetDrawLayer() return "BACKGROUND" end
local modelClick = function() end
model:SetScript("OnMouseUp", modelClick)

_G.WarbandSceneEntryMixin = {
    UpdateWarbandSceneData = function(self) self.Border:Show() end,
    Init = function(self) self:UpdateWarbandSceneData() end,
}
local capturedSceneInit = _G.WarbandSceneEntryMixin.Init
_G.HeirloomsMixin = {
    RefreshView = function() end,
    UpdateButton = function(_, button) button.name:SetTextColor(0.4, 0.3, 0, 1) end,
}
_G.HeirloomsJournal = env.NewFrame("Frame", nil, _G.CollectionsJournal)
_G.HeirloomsJournal.RefreshView = _G.HeirloomsMixin.RefreshView
_G.HeirloomsJournal.UpdateButton = _G.HeirloomsMixin.UpdateButton
_G.HeirloomsJournal.heirloomEntryFrames = {}
_G.HeirloomsJournal.heirloomHeaderFrames = {}
_G.WarbandSceneJournal = env.NewFrame("Frame", nil, _G.CollectionsJournal)
local sceneGrid = env.NewFrame("Frame", nil, _G.WarbandSceneJournal)
_G.WarbandSceneJournal.IconsFrame = env.NewFrame("Frame", nil, _G.WarbandSceneJournal)
_G.WarbandSceneJournal.IconsFrame.Icons = sceneGrid
local pooledScene = env.NewFrame("Button", nil, sceneGrid)
pooledScene.Border = pooledScene:CreateTexture()
pooledScene.HighlightTexture = pooledScene:CreateTexture()
pooledScene.Icon = pooledScene:CreateTexture()
pooledScene.Name = pooledScene:CreateFontString()
sceneGrid.EnumerateFrames = function() return ipairs({ pooledScene }) end
_G.CollectionsJournal.TitleText = _G.CollectionsJournal:CreateFontString()
_G.CollectionsJournal.GetTitleText = function(self) return self.TitleText end
_G.CollectionsJournal.SetTitle = function(self, title)
    self.TitleText:SetText(title)
    self.TitleText:SetTextColor(1, .8, 0, 1)
end
_G.MountJournal_InitMountButton = function(row)
    row.selectedTexture:Show()
    row.selectedTexture:SetAlpha(1)
end
_G.ToyBox = env.NewFrame("Frame", nil, _G.CollectionsJournal)
_G.ToyBox.iconsFrame = env.NewFrame("Frame", nil, _G.ToyBox)
local toy = env.NewFrame("CheckButton", nil, _G.ToyBox.iconsFrame)
_G.ToyBox.iconsFrame.spellButton1 = toy
toy.name = toy:CreateFontString()
toy.iconTexture = toy:CreateTexture()
toy.iconTextureUncollected = toy:CreateTexture()
toy.iconTextureUncollected:Show()
local toyClick = function() end
toy:SetScript("OnClick", toyClick)
_G.ToySpellButton_UpdateButton = function(button)
    local v = button.iconTextureUncollected:IsShown() and .33 or 1
    button.name:SetTextColor(v, v * .8, 0, 1)
end
_G.ToyBox_UpdateButtons = function() _G.ToySpellButton_UpdateButton(toy) end
_G.MountJournal.BottomLeftInset = env.NewFrame("Frame", nil, _G.MountJournal)
local equipment = env.NewFrame("Button", nil, _G.MountJournal.BottomLeftInset)
_G.MountJournal.BottomLeftInset.SlotButton = equipment
equipment.ItemIcon = equipment:CreateTexture()
equipment.ItemIcon:SetTexture("native-equipment-art")
function equipment.ItemIcon:GetTexture() return self.texture end
equipment.ItemBorder = equipment:CreateTexture()
equipment.SlotBorder = equipment:CreateTexture()
equipment.SlotBorderOpen = equipment:CreateTexture()
local equipmentBG = equipment:CreateTexture()
equipmentBG:SetAtlas("mountequipment-slot-background")
function equipmentBG:GetAtlas() return self.atlas end
equipment.DragTargetHighlight = equipment:CreateTexture()
local equipmentClick, equipmentDrag = function() end, function() end
equipment:SetScript("OnClick", equipmentClick)
equipment:SetScript("OnReceiveDrag", equipmentDrag)
equipment.Initialize = function(self) self.ItemBorder:Show(); self.ItemBorder:SetAlpha(1) end
_G.MountJournal.MountDisplay = env.NewFrame("Frame", nil, _G.MountJournal)
local display = _G.MountJournal.MountDisplay
display.ShadowOverlay = env.NewFrame("Frame", nil, display)
display.ModelScene = env.NewFrame("ModelScene", nil, display)
display.ModelScene.ControlFrame = env.NewFrame("Frame", nil, display.ModelScene)
display.ModelScene.TogglePlayer = env.NewFrame("CheckButton", nil, display.ModelScene)
local toggle = display.ModelScene.TogglePlayer
toggle.TogglePlayerText = toggle:CreateFontString()
toggle.TogglePlayerText:SetText("Show Character")
_G.MountJournal.FilterDropdown.Text = _G.MountJournal.FilterDropdown:CreateFontString()
local flight = env.NewFrame("Button", nil, _G.MountJournal)
_G.MountJournal.ToggleDynamicFlightFlyoutButton = flight
flight.Border = flight:CreateTexture()
local flightArt = flight:CreateTexture()
flightArt:SetTexture("native-flight-art")
function flightArt:GetDrawLayer() return "ARTWORK" end
local flightClick = function() end
flight:SetScript("OnClick", flightClick)
_G.MountJournal.SummonRandomFavoriteSpellFrame = env.NewFrame("Frame", nil, _G.MountJournal)
local summon = env.NewFrame("Button", nil, _G.MountJournal.SummonRandomFavoriteSpellFrame)
_G.MountJournal.SummonRandomFavoriteSpellFrame.Button = summon
summon.Border = summon:CreateTexture()
summon.Icon = summon:CreateTexture()
summon.BlackCover = summon:CreateTexture()
summon.LockIcon = summon:CreateTexture()
local summonClick = function() end
summon:SetScript("OnClick", summonClick)
_G.MountJournal.ScrollBox = env.NewFrame("Frame", nil, _G.MountJournal)
local collectionRegistrations = 0
local hookAcquired = env.SkinBase.HookScrollBoxAcquired
env.SkinBase.HookScrollBoxAcquired = function(scroll, callback, opts)
    if scroll == _G.MountJournal.ScrollBox then collectionRegistrations = collectionRegistrations + 1 end
    return hookAcquired(scroll, callback, opts)
end
env.SkinBase.HookScrollBoxRowFonts = function() end
env.SkinBase.OnAddOnLoaded = function(_, fn) fn() end
assert(loadfile(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))("QUI", env.ns)
for _, control in ipairs({_G.MountJournal.searchBox, _G.MountJournal.FilterDropdown, _G.MountJournal.MountButton}) do
    local backdrop = env.SkinBase.GetBackdrop(control)
    assert(backdrop and backdrop._quiRoundedSurface, "collection search, filters, and actions must use shared rounded controls")
end
assert(_G.MountJournal.searchBox.searchIcon:GetAlpha() == 1, "search magnifier must remain visible")
assert(_G.MountJournal.searchBox:GetScript("OnTextChanged") == change, "collection searching must remain Blizzard-owned")
assert(items.BackgroundTile:GetAlpha() == 0, "appearance panel must suppress native tiled chrome")
assert(env.SkinBase.GetBackdrop(items)._quiRoundedSurface, "appearance panel must use rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(wardrobe.ClassDropdown)._quiRoundedSurface, "class selector must use QUI chrome")
assert(env.SkinBase.GetFrameData(items.PagingFrame.NextPageButton, "nextPrevStyled"), "appearance paging must use QUI arrows")
assert(items.PagingFrame.NextPageButton:GetScript("OnClick") == nextPage, "appearance paging behavior must remain native")
assert(model.previewArt:GetAlpha() == 1, "appearance preview art must remain visible")
assert(pooledScene.Border:GetAlpha() == 0, "indexed campsite enumeration must style the card")
local scene = env.NewFrame("Button")
scene.Border = scene:CreateTexture()
scene.HighlightTexture = scene:CreateTexture()
scene.Icon = scene:CreateTexture()
scene.Name = scene:CreateFontString()
scene.UpdateWarbandSceneData = _G.WarbandSceneEntryMixin.UpdateWarbandSceneData
capturedSceneInit(scene)
assert(scene.Border:GetAlpha() == 0, "captured campsite initializer must still receive QUI chrome")
local heirloom = env.NewFrame("Button")
heirloom.name = heirloom:CreateFontString()
heirloom.special = heirloom:CreateFontString()
heirloom.iconTexture = heirloom:CreateTexture()
heirloom.iconTextureUncollected = heirloom:CreateTexture()
heirloom.iconTextureUncollected:Show()
heirloom.slotFrameCollected = heirloom:CreateTexture()
heirloom.slotFrameUncollected = heirloom:CreateTexture()
heirloom.slotFrameUncollectedInnerGlow = heirloom:CreateTexture()
_G.HeirloomsJournal:UpdateButton(heirloom)
local r, g, b = heirloom.name:GetTextColor()
assert(r == 0.7 and g == 0.7 and b == 0.7, "late heirloom updates must retain readable dark-surface text")
local mount = env.NewFrame("Button")
mount.selectedTexture = mount:CreateTexture()
mount.selectedTexture:Hide()
_G.MountJournal_InitMountButton(mount)
assert(mount.selectedTexture:IsShown() and mount.selectedTexture:GetAlpha() == 0, "native mount selection must remain identifiable without its blue gradient")
mount.selectedTexture:SetAlpha(1)
assert(mount.selectedTexture:GetAlpha() == 0, "recycled mount selection must not restore native blue chrome")
_G.CollectionsJournal:SetTitle("Mounts")
_G.CollectionsJournal.TitleText:SetTextColor(1, .8, 0, 1)
local r, g, b = _G.CollectionsJournal.TitleText:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "tab changes must retain neutral Collections title")
print("OK: collections_rounded_controls_test")

assert(viewportBackground:GetAlpha() == 0, "appearance viewport must suppress the native square black background")
local viewportSurface = env.SkinBase.GetBackdrop(model)
assert(viewportSurface and viewportSurface._quiRoundedSurface, "actual appearance model array must receive a rounded surface")
assert(viewportSurface:GetFrameLevel() < model:GetFrameLevel(), "viewport surface must remain behind the visible 3D model")
assert(model:GetScript("OnMouseUp") == modelClick, "appearance preview interaction remains native")


_G.ToyBox_UpdateButtons()
local tr, tg, tb = toy.name:GetTextColor()
assert(tr == .7 and tg == .7 and tb == .7, "PTR toy refresh must retain readable uncollected captions")
toy.name:SetTextColor(.33, .27, .2, 1)
assert(select(1, toy.name:GetTextColor()) == .7, "later native toy color writes must remain readable")
toy.iconTextureUncollected:Hide()
_G.ToySpellButton_UpdateButton(toy)
assert(select(1, toy.name:GetTextColor()) == 1, "collected toy captions must return to white")
assert(toy:GetScript("OnClick") == toyClick, "toy activation stays native")
equipment:Initialize()
assert(equipment.ItemBorder:GetAlpha() == 0 and equipmentBG:GetAlpha() == 0, "equipment refresh must suppress ornate slot chrome")
assert(equipment._quiRoundedSurface, "equipment slot must use rounded chrome")
assert(equipment.ItemIcon:GetTexture() == "native-equipment-art" and equipment.ItemIcon:GetAlpha() == 1, "mount equipment art stays visible")
assert(equipment.DragTargetHighlight:GetAlpha() == 1, "equipment drag state stays native")
assert(equipment:GetScript("OnClick") == equipmentClick and equipment:GetScript("OnReceiveDrag") == equipmentDrag, "equipment actions stay native")
assert(display.ShadowOverlay:GetAlpha() == 0, "mount model viewport must suppress decorative vignette")
toggle.TogglePlayerText:SetTextColor(1, .8, 0, 1)
assert(select(1, toggle.TogglePlayerText:GetTextColor()) == .9, "model preview toggle caption must remain neutral")
_G.MountJournal.FilterDropdown.Text:SetTextColor(1, .8, 0, 1)
assert(select(1, _G.MountJournal.FilterDropdown.Text:GetTextColor()) == .9, "collection filter caption must remain neutral")


assert(flight.Border:GetAlpha() == 0 and summon.Border:GetAlpha() == 0, "mount header icon buttons must suppress native square frames")
assert(flightArt.texture == "native-flight-art" and flightArt:GetAlpha() == 1, "flight mode artwork stays visible")
assert(flight:GetScript("OnClick") == flightClick and summon:GetScript("OnClick") == summonClick, "flight and summon actions stay native")
assert(summon.BlackCover:GetAlpha() == 1 and summon.LockIcon:GetAlpha() == 1, "summon lock and disabled semantics stay native")


local previewCheckSurface = env.SkinBase.GetBackdrop(toggle)
assert(previewCheckSurface._quiRoundedSurface and previewCheckSurface.points[1][4] == 6
    and previewCheckSurface.points[2][4] == -6, "preview checkbox chrome must be compact while retaining its native hit area")
assert(env.SkinBase.GetFrameData(flightArt, "iconBorder")._quiRoundedSurface,
    "flight icon must use a rounded border rather than a square outline")
assert(env.SkinBase.GetFrameData(toy.iconTexture, "iconBorder")._quiRoundedSurface,
    "toy icons must use rounded borders in both collection states")

local registered = collectionRegistrations
for _ = 1, 3 do
    _G.CollectionsJournal:Fire("OnShow")
    _G.MountJournal:Fire("OnShow")
    _G.QUI_RefreshCollectionsColors()
end
assert(collectionRegistrations == registered,
    "collection root/page show and theme refresh must reuse acquired callbacks")
