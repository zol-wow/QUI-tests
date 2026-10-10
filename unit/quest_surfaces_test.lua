local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua"))()
local frame = env.NewFrame("Frame", "QuestFrame")
_G.QuestFrame = frame
frame.FriendshipStatusBar = false
_G.QuestTextContrast = {GetDefaultBackgroundAtlas = function() return "QuestBG-Parchment" end}
local panels, scrolls = {}, {}
for _, name in ipairs({"QuestFrameRewardPanel", "QuestFrameProgressPanel", "QuestFrameDetailPanel", "QuestFrameGreetingPanel"}) do
    local panel = env.NewFrame("Frame", name, frame)
    _G[name] = panel
    for _, key in ipairs({"Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG"}) do
        panel[key] = panel:CreateTexture()
    end
    panels[#panels + 1] = panel
end
for index, name in ipairs({"QuestRewardScrollFrame", "QuestProgressScrollFrame", "QuestDetailScrollFrame", "QuestGreetingScrollFrame"}) do
    local scroll = env.NewFrame("ScrollFrame", name, panels[index])
    _G[name] = scroll
    scroll.ScrollBar = env.NewFrame("Slider", nil, scroll)
    scroll.ScrollBar.ThumbTexture = scroll.ScrollBar:CreateTexture()
    scroll.ScrollBar.Track, scroll.ScrollBar.ScrollUpButton, scroll.ScrollBar.ScrollDownButton = false, false, false
    scroll:SetScript("OnMouseWheel", function(self, delta) self.nativeScroll = delta end)
    scrolls[#scrolls + 1] = scroll
end
local actions = {}
for _, name in ipairs({"QuestFrameCompleteQuestButton", "QuestFrameGoodbyeButton", "QuestFrameCompleteButton",
    "QuestFrameDeclineButton", "QuestFrameAcceptButton", "QuestFrameGreetingGoodbyeButton"}) do
    local button = env.NewFrame("Button", name, frame)
    _G[name] = button
    button.DisabledTexture = false
    local click = function() error("styling must not accept, complete or close a quest") end
    button:SetScript("OnClick", click)
    actions[button] = click
end
local title = scrolls[3]:CreateFontString()
_G.QuestInfoTitleHeader = title
title:SetText("Native story")
title:SetTextColor(0, 0, 0, 1)
local rewards = env.NewFrame("Frame", nil, scrolls[1])
local button = env.NewFrame("Button", nil, rewards)
button.DisabledTexture = false
button.Icon, button.IconBorder = button:CreateTexture(), button:CreateTexture()
button.Name, button.Count = button:CreateFontString(), button:CreateFontString()
button.Name:SetText("Native reward")
button.Name:SetTextColor(0.8, 0.3, 1, 1)
button.Count:SetTextColor(1, 0.2, 0.1, 1)
button.Icon:SetTexture("native-reward")
button.Icon:SetVertexColor(0.9, 0, 0, 1)
function button.IconBorder:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
button.IconBorder:SetVertexColor(0.8, 0.3, 1, 1)
local masks = 0
function button:CreateMaskTexture()
    local mask = self:CreateTexture(); mask.kind = "MaskTexture"; return mask
end
function button.Icon:AddMaskTexture() masks = masks + 1 end
button:SetScript("OnClick", _G.QuestTitleButton_OnClick)
local click = button:GetScript("OnClick")
rewards.RewardButtons = {button}
_G.QuestInfoFrame = {rewardsFrame = rewards}
local displays = 0
_G.QuestInfo_Display = function() displays = displays + 1; title:SetTextColor(0, 0, 0, 1) end
_G.QuestInfo_GetRewardButton = function(_, index) button:SetID(index); return button end
local scene = env.NewFrame("ModelScene", "QuestModelScene", frame)
_G.QuestModelScene = scene
for _, key in ipairs({"ModelBackground", "ModelNameDivider", "ModelNameBackground", "ShadowOverlay"}) do
    scene[key] = scene:CreateTexture()
end
scene.ModelTextFrame = env.NewFrame("Frame", nil, scene)
scene.ModelTextFrame.TextBackground = scene.ModelTextFrame:CreateTexture()
_G.QuestNPCModelNameText, _G.QuestNPCModelText = scene:CreateFontString(), scene.ModelTextFrame:CreateFontString()
_G.QuestNPCModelText:SetHeight(20)
_G.QuestNPCModelTextScrollChildFrame = env.NewFrame("Frame", nil, scene.ModelTextFrame)
local transitions, playerModels = 0, 0
function scene:ClearScene() self.cleared = (self.cleared or 0) + 1 end
function scene:TransitionToModelSceneID(id) self.sceneID = id; transitions = transitions + 1 end
function scene:GetPlayerActor() return {SetModelByUnit = function() playerModels = playerModels + 1 end} end
_G.CAMERA_TRANSITION_TYPE_IMMEDIATE, _G.CAMERA_MODIFICATION_TYPE_DISCARD = 0, 0
_G.QuestTextContrast.IsEnabled, _G.QuestTextContrast.UseLightText = function() return false end, function() return false end
_G.GetQuestBackgroundMaterial = function() return "Stone" end
_G.GetMaterialTextColors = function() return {0, 0, 0}, {0, 0, 0} end
for _, name in ipairs({"GreetingText", "CurrentQuestsText", "AvailableQuestsText", "QuestProgressRequiredItemsText",
    "QuestProgressRequiredMoneyText"}) do _G[name] = frame:CreateFontString() end
_G.QuestGreetingFrameHorizontalBreak = frame:CreateTexture()
_G.TRIVIAL_QUEST_DISPLAY, _G.NORMAL_QUEST_DISPLAY = "|cff414141%s|r", "|cff000000%s|r"
local greetRows, acquiredIndex = {}, 0
for index = 1, 2 do
    local row = env.NewFrame("Button", nil, panels[4])
    row.DisabledTexture = false
    row.Text, row.Icon = row:CreateFontString(), row:CreateTexture()
    row.Icon:SetHeight(16)
    function row:SetText(text) self.text = text; self.Text:SetText(text) end
    function row:GetText() return self.text end
    function row:SetFormattedText(format, text) self:SetText(string.format(format, text)) end
    function row:GetTextHeight() return 12 end
    row:SetScript("OnClick", _G.QuestTitleButton_OnClick)
    greetRows[index] = row
end
panels[4].titleButtonPool = {
    ReleaseAll = function() acquiredIndex = 0 end,
    Acquire = function() acquiredIndex = acquiredIndex + 1; return greetRows[acquiredIndex] end,
    EnumerateActive = function() local index = 0; return function()
        index = index + 1; if index <= acquiredIndex then return greetRows[index] end end end,
}
_G.GetGreetingText = function() return "Native greeting" end
_G.GetNumActiveQuests, _G.GetNumAvailableQuests = function() return 1 end, function() return 1 end
local completed, trivial = true, true
_G.GetActiveTitle = function() return "Active quest", completed end
_G.IsActiveQuestTrivial = function() return trivial end
_G.GetActiveQuestID = function() return 456 end
_G.GetAvailableQuestInfo = function() return trivial, 0, false, false, 789 end
_G.GetAvailableTitle = function() return "Available quest" end
_G.QuestUtil = {
    ApplyQuestIconActiveToTextureForQuestID = function(icon, id, complete) icon:SetTexture(complete and "completed" or "active"); icon.questID = id end,
    ApplyQuestIconOfferToTextureForQuestID = function(icon, id) icon:SetTexture("available"); icon.questID = id end,
}
local requiredCount, currencies, due, owned = 2, 1, 100, 50
_G.GetNumQuestItems, _G.GetNumQuestCurrencies = function() return requiredCount end, function() return currencies end
_G.GetQuestMoneyToGet, _G.GetMoney = function() return due end, function() return owned end
_G.C_QuestOffer = {
    GetHideRequiredItems = function() return false end,
    GetQuestRequiredCurrencyInfo = function() return {requiredAmount = 10, texture = "currency-art", name = "Native currency"} end,
}
_G.IsQuestItemHidden = function(index) return index == 2 and 1 or 0 end
_G.GetQuestItemInfo = function() return "Required item", "required-art", 4 end
_G.SetItemButtonCount = function(widget, value) widget.nativeCount = value end
_G.SetItemButtonTexture = function(widget, value) widget.Icon:SetTexture(value) end
_G.QuestProgressRequiredMoneyFrame = env.NewFrame("Frame", nil, frame)
_G.MoneyFrame_Update = function(_, value) _G.QuestProgressRequiredMoneyFrame.amount = value end
_G.SetMoneyFrameColor = function(_, color) _G.QuestProgressRequiredMoneyFrame.nativeColor = color end
for index = 1, 6 do
    local widget = env.NewFrame("Button", nil, panels[2])
    widget.DisabledTexture = false
    widget.Icon, widget.Name = widget:CreateTexture(), widget:CreateFontString()
    widget:SetScript("OnEnter", function() end)
    _G["QuestProgressItem" .. index] = widget
    _G["QuestProgressItem" .. index .. "Name"] = widget.Name
end
scrolls[2].ScrollBar.ScrollToBegin = function(self) self.nativeAtStart = true end

local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_UIPanels_Game" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinQuest" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
assert(panels[1].Bg:GetAlpha() == 0, "quest inner parchment must be suppressed")
for _, panel in ipairs(panels) do
    _G.QuestFrame_SetMaterial(panel, "Stone")
    for _, key in ipairs({"Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG"}) do
        assert(panel[key]:GetAlpha() == 0, "native material reuse must not restore scenery")
    end
end
for _, scroll in ipairs(scrolls) do
    assert(scroll.ScrollBar.ThumbTexture.color and scroll.ScrollBar.ThumbTexture.width > 0,
        "each native legacy scroll thumb must remain visible")
    scroll:Fire("OnMouseWheel", -1)
    assert(scroll.nativeScroll == -1, "native scrolling ownership must survive")
end
assert(skin.GetBackdrop(button)._quiRoundedSurface.radius == 4, "quest rewards must use rounded row surfaces")
assert(button.Icon.texture == "native-reward" and button.Icon.vertex[1] == 0.9
    and button.Name.textColor[1] == 0.8 and button.Count.textColor[2] == 0.2,
    "reward art, unusable tint, name rarity and currency/count colors must survive")
assert(button:GetScript("OnClick") == click and masks == 1, "native reward selection and single icon mask must survive")
for action, native in pairs(actions) do assert(action:GetScript("OnClick") == native and skin.IsStyled(action)) end
_G.QuestInfo_Display()
assert(displays == 1 and title.textColor[1] == 1 and title:GetText() == "Native story",
    "NPC display must reapply neutral narrative text without changing content")
local map = env.NewFrame("Frame")
title.parent = map
rewards:SetParent(map)
_G.QuestInfo_Display()
assert(title.textColor[1] == 0, "shared map display must retain its own text presentation")
local outside = env.NewFrame("Button", nil, map)
outside.DisabledTexture = false
_G.QuestInfoFrame.rewardsFrame = {RewardButtons = {outside}}
refresh()
assert(not skin.IsStyled(outside), "foreign rewards must not receive NPC dialog styling")
rewards:SetParent(scrolls[1])
title.parent = scrolls[3]
_G.QuestInfoFrame.rewardsFrame = rewards
_G.QuestInfo_GetRewardButton(rewards, 8)
button.IconBorder:SetVertexColor(0, 0.5, 1, 1)
refresh()
assert(button:GetID() == 8 and masks == 1, "recycled rewards must retain new identity and reused clipping")
local border = skin.GetFrameData(button.Icon, "iconBorder")
assert(border._quiBorderR == 0 and border._quiBorderG == 0.5 and border._quiBorderB == 1,
    "theme refresh must retain current native quality on recycled rewards")
button.IconBorder:Hide()
local r, g, b, a = skin.GetWindowColors()
assert(border._quiBorderR == r and border._quiBorderG == g and border._quiBorderB == b and border._quiBorderA == a,
    "ordinary reward reuse must clear the previous quality border")
refresh()
assert(border._quiBorderR == r, "hidden native quality border must remain neutral after refresh")
_G.QuestFrameGreetingPanel_OnShow()
assert(skin.IsStyled(greetRows[1]) and skin.IsStyled(greetRows[2]), "pooled greeting rows must use interactive QUI chrome")
assert(greetRows[1].isActive == 1 and greetRows[2].isActive == 0 and greetRows[1]:GetID() == 1
    and greetRows[2]:GetID() == 1 and greetRows[1].Icon.texture == "completed" and greetRows[2].Icon.texture == "available",
    "native active/available identity and completion icons must survive")
assert(greetRows[2]:GetText() == "|cFF7b8489Available quest|r" and greetRows[2].Icon.vertex[1] == 0.5,
    "trivial greeting rows must retain distinct text and native icon tint")
completed, trivial = false, false
_G.QuestFrameGreetingPanel_OnShow()
assert(greetRows[1].Icon.texture == "active" and greetRows[2]:GetText() == "|cFFffffffAvailable quest|r",
    "recycled greeting rows must follow current native quest data")
_G.QuestFrameProgressItems_Update()
assert(skin.IsStyled(_G.QuestProgressItem1) and skin.IsStyled(_G.QuestProgressItem6),
    "all six native required slots must be individually styled")
assert(_G.QuestProgressItem1.objectType == "item" and _G.QuestProgressItem1.Icon.texture == "required-art"
    and _G.QuestProgressItem1.nativeCount == 4 and _G.QuestProgressItem1:GetID() == 1,
    "required item data must remain native")
assert(_G.QuestProgressItem2.objectType == "currency" and _G.QuestProgressItem2.Icon.texture == "currency-art"
    and _G.QuestProgressItem2.nativeCount == 10 and not _G.QuestProgressItem3:IsShown(),
    "hidden-item compaction and currency visibility must remain native")
assert(_G.QuestProgressRequiredMoneyFrame.nativeColor == "red" and _G.QuestProgressRequiredMoneyFrame.amount == 100
    and _G.QuestProgressRequiredMoneyText.textColor[2] == 0.2, "insufficient money must remain visibly distinct")
owned = 200
_G.QuestFrameProgressItems_Update()
assert(_G.QuestProgressRequiredMoneyFrame.nativeColor == "white" and _G.QuestProgressRequiredMoneyText.textColor[2] == 1,
    "sufficient money must use readable neutral text with native money color")
requiredCount, currencies, due = 0, 0, 0
_G.QuestFrameProgressItems_Update()
assert(not _G.QuestProgressItem1:IsShown() and not _G.QuestProgressRequiredMoneyFrame:IsShown(),
    "empty requirement update must hide native slots and money")
for _, compact in ipairs({true, false, true}) do
    _G.QuestFrame_ShowQuestPortrait(frame, -1, 0, 999, "Native portrait description", "Native NPC", 1, -42, compact)
    assert(scene.ModelTextFrame.height == (compact and 165 or 216) and scene.sceneID == 999,
        "native compact/full portrait sizing and scene ownership must survive")
    assert(scene.ModelBackground:GetAlpha() == 0 and scene.ModelTextFrame.TextBackground:GetAlpha() == 0
        and skin.GetBackdrop(scene)._quiRoundedSurface and skin.GetBackdrop(scene.ModelTextFrame)._quiRoundedSurface,
        "portrait and description panels must use QUI surfaces")
    assert(skin.GetBackdrop(scene):GetFrameLevel() < scene:GetFrameLevel()
        and skin.GetBackdrop(scene.ModelTextFrame):GetFrameLevel() < scene.ModelTextFrame:GetFrameLevel(),
        "portrait chrome must stay behind the actor scene and native text")
    assert(_G.QuestNPCModelText:GetText() == "Native portrait description" and _G.QuestNPCModelTextScrollChildFrame.height == 25
        and _G.QuestNPCModelNameText:GetText() == "Native NPC", "native text and descender layout must survive")
end
assert(transitions == 3 and playerModels == 3, "styling must not repeat model transitions or actor setup")
local caption = skin.GetFrameData(scene, "qQuestCaption")
refresh()
assert(skin.GetFrameData(scene, "qQuestCaption") == caption and transitions == 3, "portrait theme refresh must reuse chrome only")
_G.QuestFrame_HideQuestPortrait()
refresh()
assert(not scene:IsShown() and scene:GetParent() == nil, "native offscreen/close portrait visibility must remain authoritative")

print("OK: quest_surfaces_test")
