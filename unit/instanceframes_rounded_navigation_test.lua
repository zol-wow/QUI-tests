local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinInstanceFrames = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.PVEFrame = env.NewFrame("Frame")
_G.PVEFrame.TitleText = _G.PVEFrame:CreateFontString()
_G.PVEFrame.GetTitleText = function(owner) return owner.TitleText end
_G.PVEFrame.SetTitle = function(owner, title)
    owner.TitleText:SetText(title)
    owner.TitleText:SetTextColor(1, 0.82, 0)
end
_G.GroupFinderFrame = env.NewFrame("Frame", nil, _G.PVEFrame)
local button = env.NewFrame("Button", nil, _G.GroupFinderFrame)
_G.GroupFinderFrame.groupButton1 = button
button.highlightTexture = button:CreateTexture()
button.name = button:CreateFontString()
local clicks = 0
button:SetScript("OnClick", function() clicks = clicks + 1 end)
_G.PVPQueueFrame = env.NewFrame("Frame")
_G.PVPQueueFrame.HonorInset = env.NewFrame("Frame", nil, _G.PVPQueueFrame)
_G.PVPQueueFrame.HonorInset.Background = _G.PVPQueueFrame.HonorInset:CreateTexture()
local notice = env.NewFrame("Frame", nil, _G.PVPQueueFrame)
_G.PVPQueueFrame.NewSeasonPopup = notice
notice.widgetType = false
notice.RegisterForWidgetSet = false
notice.Background = notice:CreateTexture()
notice.Background:SetAtlas("parchmentpopup-background")
notice.NewSeason = notice:CreateFontString()
notice.NewSeason:SetTextColor(0, 0, 0)
local noticeText = notice.NewSeason
notice.Leave = env.NewFrame("Button", nil, notice)
notice.Leave.DisabledTexture = false
notice.SeasonRewardFrame = env.NewFrame("Frame", nil, notice)
notice.SeasonRewardFrame.Icon = notice.SeasonRewardFrame:CreateTexture()
notice.SeasonRewardFrame.Icon:SetTexture("season-mount")
local dismiss = function() end
notice.Leave:SetScript("OnClick", dismiss)
_G.HonorFrame = env.NewFrame("Frame", nil, _G.PVPQueueFrame)
_G.HonorFrame.BonusFrame = env.NewFrame("Frame", nil, _G.HonorFrame)
local activity = env.NewFrame("Button", nil, _G.HonorFrame.BonusFrame)
_G.HonorFrame.BonusFrame.RandomBGButton = activity
activity.Reward = env.NewFrame("Frame", nil, activity)
activity.Reward.Icon = activity.Reward:CreateTexture()
activity.Reward.Icon:SetTexture("reward-icon")
local queue = function() end
activity:SetScript("OnClick", queue)
_G.ChallengesFrame = env.NewFrame("Frame")
_G.ChallengesFrame.WeeklyInfo = env.NewFrame("Frame", nil, _G.ChallengesFrame)
local weeklyChild = env.NewFrame("Frame", nil, _G.ChallengesFrame.WeeklyInfo)
_G.ChallengesFrame.WeeklyInfo.Child = weeklyChild
weeklyChild.WeeklyChest = false
weeklyChild.ThisWeekLabel = false
weeklyChild.AffixesContainer = false
weeklyChild.Description = weeklyChild:CreateFontString()
for _, key in ipairs({ "RuneBG", "RunesLarge", "RunesSmall", "LargeRuneGlow", "SmallRuneGlow" }) do
    weeklyChild[key] = weeklyChild:CreateTexture()
    weeklyChild[key]:SetAtlas("ChallengeMode-" .. key)
end
_G.ChallengesFrame.Background = _G.ChallengesFrame:CreateTexture()
function _G.ChallengesFrame.Background:SetTexture(texture)
    self.texture = texture
    self.alpha = 1
end
_G.ChallengesFrame.Background:SetTexture("mythic-decorative-background")
_G.ChallengesFrame.Update = function(owner) owner.Background:SetAlpha(1) end

local dungeon = env.NewFrame("Button", nil, _G.ChallengesFrame)
local nativeDungeonBorder = dungeon:CreateTexture()
dungeon.Icon = dungeon:CreateTexture()
dungeon.Icon:SetTexture("dungeon-icon")
_G.ChallengesFrame.DungeonIcons = { dungeon }
_G.LFGListFrame = env.NewFrame("Frame")
local searchPanel = env.NewFrame("Frame", nil, _G.LFGListFrame)
_G.LFGListFrame.SearchPanel = searchPanel
_G.LFGListSearchPanel_UpdateButtonStatus = function(panel)
    panel.SignUpButton.Text:SetAlpha(0.3)
    panel.SignUpButton.Text:SetTextColor(1, 1, 1, 0.3)
end
searchPanel.SignUpButton = env.NewFrame("Button", nil, searchPanel)
searchPanel.SignUpButton.Text = searchPanel.SignUpButton:CreateFontString()
function searchPanel.SignUpButton.Text:SetDrawLayer(layer) self.drawLayer = layer end
function searchPanel.SignUpButton.Text:GetDrawLayer() return self.drawLayer end
searchPanel.SignUpButton.GetFontString = function(owner) return owner.Text end
for _, key in ipairs({"Left", "Right", "Middle", "Center", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture"}) do searchPanel.SignUpButton[key] = false end
searchPanel.SignUpButton.enabled = false
searchPanel.FilterButton = env.NewFrame("DropdownButton", nil, searchPanel)
for _, key in ipairs({"Left", "Right", "Middle", "Center", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture", "Arrow"}) do searchPanel.FilterButton[key] = false end
searchPanel.FilterButton.Background = searchPanel.FilterButton:CreateTexture()
searchPanel.ScrollBox = env.NewFrame("Frame", nil, searchPanel)
searchPanel.ScrollBox.StartGroupButton = env.NewFrame("Button", nil, searchPanel.ScrollBox)
local start = searchPanel.ScrollBox.StartGroupButton
for _, key in ipairs({"Left", "Right", "Middle", "Center", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture"}) do start[key] = false end
local nativeStart = function() end
start:SetScript("OnClick", nativeStart)
local mythicNotice = env.NewFrame("Frame", nil, _G.ChallengesFrame)
_G.ChallengesFrame.SeasonChangeNoticeFrame = mythicNotice
mythicNotice.widgetType = false
mythicNotice.RegisterForWidgetSet = false
mythicNotice.NewSeason = mythicNotice:CreateFontString()
mythicNotice.NewSeason:SetTextColor(0, 0, 0)
mythicNotice.Leave = env.NewFrame("Button", nil, mythicNotice)
mythicNotice.Leave.DisabledTexture = false
mythicNotice.Affix = env.NewFrame("Frame", nil, mythicNotice)
mythicNotice.Affix.AffixBorder = mythicNotice.Affix:CreateTexture()
mythicNotice.Affix.AffixBorder:SetAtlas("mythicplus-popup-ring")
mythicNotice.Affix.Portrait = mythicNotice.Affix:CreateTexture()
_G.LFDQueueFrame = env.NewFrame("Frame")
local rewards = env.NewFrame("Frame", "LFDQueueFrameRandomScrollFrameChildFrame", _G.LFDQueueFrame)
_G.LFDQueueFrameRandomScrollFrameChildFrame = rewards
rewards.numRewardFrames = 1
rewards.MoneyReward = false
for _, key in ipairs({ "title", "rewardsLabel", "description", "rewardsDescription", "xpLabel", "xpAmount" }) do
    rewards[key] = rewards:CreateFontString()
end
local rewardItem = env.NewFrame("Button", "LFDQueueFrameRandomScrollFrameChildFrameItem1", rewards)
_G.LFDQueueFrameRandomScrollFrameChildFrameItem1 = rewardItem
for _, key in ipairs({ "Left", "Right", "Middle", "Center", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture" }) do rewardItem[key] = false end
rewardItem.Icon = rewardItem:CreateTexture()
rewardItem.IconBorder = rewardItem:CreateTexture()
rewardItem.IconOverlay = rewardItem:CreateTexture()
rewardItem.Background = rewardItem:CreateTexture()
rewardItem.Name = rewardItem:CreateFontString()
rewardItem.Count = rewardItem:CreateFontString()
rewardItem.Name:SetTextColor(0, 0.44, 0.87)
local nativeRewardClick = function() end
rewardItem:SetScript("OnClick", nativeRewardClick)
_G.LFGRewardsFrame_UpdateFrame = function(parent)
    parent.title:SetTextColor(1, 0.82, 0)
    rewardItem.Background:SetAlpha(1)
    rewardItem.IconBorder:Show()
end
_G.TrainingGroundsFrame = env.NewFrame("Frame")
local trainingList = env.NewFrame("Frame", nil, _G.TrainingGroundsFrame)
_G.TrainingGroundsFrame.BonusTrainingGroundList = trainingList
trainingList.RandomTrainingGroundBGButton = env.NewFrame("Button", nil, trainingList)
trainingList.RandomTrainingGroundArenaButton = env.NewFrame("Button", nil, trainingList)
env.SkinBase.OnAddOnLoaded = function(_, fn) fn() end
assert(loadfile(os.getenv("QUI_INSTANCE_SOURCE") or "modules/skinning/frames/instanceframes.lua"))("QUI", env.ns)
assert(env.SkinBase.GetBackdrop(_G.PVEFrame)._quiRoundedSurface, "Group Finder shell must render rounded chrome")
local backdrop = env.SkinBase.GetFrameData(button, "backdrop")
assert(backdrop._quiRoundedSurface, "Group Finder navigation must render rounded chrome")
assert(button.highlightTexture:GetAlpha() == 0, "native blue hover art must not cover rounded navigation")
button:Fire("OnClick")
assert(clicks == 1, "navigation must retain native click ownership")
assert(env.SkinBase.GetFrameData(activity, "backdrop")._quiRoundedSurface,
    "PvP activity cards must use rounded QUI chrome")
assert(env.SkinBase.GetFrameData(activity.Reward.Icon, "backdrop")._quiRoundedSurface,
    "PvP reward borders must match other QUI icons")
assert(env.SkinBase.GetFrameData(dungeon.Icon, "backdrop")._quiRoundedSurface,
    "Mythic dungeon icon borders must match other QUI icons")
assert(activity.Reward.Icon:GetAlpha() == 1 and dungeon.Icon:GetAlpha() == 1,
    "semantic activity artwork must remain visible")
assert(activity:GetScript("OnClick") == queue, "styling must preserve native queue ownership")
assert(select(1, noticeText:GetTextColor()) == 0.9, "season notice text must remain readable on dark chrome")
assert(notice.Background:GetAlpha() == 0 and env.SkinBase.GetBackdrop(notice)._quiRoundedSurface,
    "new-season notice must replace native parchment with rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(notice.Leave)._quiRoundedSurface,
    "new-season close action must use QUI chrome")
assert(notice.Leave:GetScript("OnClick") == dismiss and notice.SeasonRewardFrame.Icon:GetAlpha() == 1,
    "notice styling must preserve dismissal and reward artwork")

assert(env.SkinBase.GetBackdrop(start), "empty search Start a Group action must receive QUI chrome")
assert(start:GetScript("OnClick") == nativeStart, "empty search action must retain native click ownership")
assert(searchPanel.FilterButton.Background:GetAlpha() == 0, "actual dropdown filter background must be suppressed")

assert(env.SkinBase.GetBackdrop(mythicNotice)._quiRoundedSurface, "Mythic season notice needs an opaque rounded surface")
local mr, mg, mb = mythicNotice.NewSeason:GetTextColor()
assert(mr > 0.8 and mg > 0.8 and mb > 0.8, "Mythic season heading cannot remain black on a dark window")
assert(env.SkinBase.GetBackdrop(mythicNotice.Leave), "Mythic season Close action must use QUI chrome")
for _, key in ipairs({"RandomTrainingGroundBGButton", "RandomTrainingGroundArenaButton"}) do
    assert(env.SkinBase.GetFrameData(trainingList[key], "backdrop")._quiRoundedSurface, "both actual PTR Training Grounds cards must be styled")
end



_G.ChallengesFrame:Update()
assert(_G.ChallengesFrame.Background:GetAlpha() == 0, "native Mythic update cannot restore decorative background")
assert(nativeDungeonBorder:GetAlpha() == 0, "anonymous native dungeon frame must not cover the rounded icon")
assert(dungeon.Icon:GetAlpha() == 1, "dungeon artwork must remain visible")

_G.ChallengesFrame.Background:SetTexture("new-season-background")
assert(_G.ChallengesFrame.Background:GetAlpha() == 0, "native texture assignment cannot restore the Mythic background alpha")

_G.ChallengesFrame.Background.alpha = 1
_G.ChallengesFrame:Fire("OnShow")
assert(_G.ChallengesFrame.Background:GetAlpha() == 0, "late native Mythic initialization must be suppressed after OnShow")

_G.ChallengesFrame.Background:Show()
assert(not _G.ChallengesFrame.Background:IsShown(), "decorative Mythic background cannot become visible during native initialization")

_G.LFGListSearchPanel_UpdateButtonStatus(searchPanel)
assert(searchPanel.SignUpButton.Text:GetAlpha() == 1, "native opacity must not hide the disabled Sign Up label")
assert(not searchPanel.SignUpButton:IsEnabled(), "readable Sign Up label must not enable the native action")

for _, key in ipairs({ "RuneBG", "RunesLarge", "RunesSmall", "LargeRuneGlow", "SmallRuneGlow" }) do
    weeklyChild[key]:SetAlpha(1)
    assert(weeklyChild[key]:GetAlpha() == 0, "native weekly-info rune artwork must stay suppressed: " .. key)
end

local signUpLayer = searchPanel.SignUpButton.Text:GetDrawLayer()
assert(signUpLayer == "OVERLAY", "disabled native Sign Up label must render above the QUI button surface")

assert(env.SkinBase.GetBackdrop(searchPanel.SignUpButton):GetFrameLevel() < searchPanel.SignUpButton:GetFrameLevel(),
    "Sign Up surface must render below its native label")
local signUpPoint = searchPanel.SignUpButton.Text.points[1]
assert(signUpPoint[1] == "CENTER" and signUpPoint[2] == searchPanel.SignUpButton,
    "Sign Up text must anchor to its native button rather than the screen center")

assert(mythicNotice.Affix.AffixBorder:GetAlpha() == 0, "season notice must suppress the empty native gold affix ring")
mythicNotice.Affix.AffixBorder:SetAlpha(1)
assert(mythicNotice.Affix.AffixBorder:GetAlpha() == 0, "native ring refresh must stay suppressed without moving the portrait anchor")

_G.PVEFrame:SetTitle("Mythic+ Dungeons")
local titleR, titleG, titleB = _G.PVEFrame.TitleText:GetTextColor()
assert(titleR == 1 and titleG == 1 and titleB == 1, "native Group Finder page changes must retain neutral title color")
_G.LFGRewardsFrame_UpdateFrame(rewards)
assert(env.SkinBase.GetBackdrop(rewardItem)._quiRoundedSurface,
    "Dungeon Finder rewards must replace native black rectangles with rounded rows")
assert(rewardItem.Background:GetAlpha() == 0 and rewardItem.Icon:GetAlpha() == 1,
    "native reward refresh must keep decorative art suppressed and the item visible")
local itemR, itemG, itemB = rewardItem.Name:GetTextColor()
assert(itemR == 0 and itemG == 0.44 and itemB == 0.87,
    "reward quality text must survive normalization")
assert(rewardItem.IconBorder:IsShown() and rewardItem.IconBorder:GetAlpha() == 1,
    "native reward quality-border visibility must survive skinning")
assert(rewardItem:GetScript("OnClick") == nativeRewardClick,
    "Dungeon Finder reward clicks must remain native")
print("OK: instanceframes_rounded_navigation_test")
