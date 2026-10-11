local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinFriends = true
_G.FriendsFrame = env.NewFrame("Frame")
_G.FriendsListFrame = env.NewFrame("Frame", nil, _G.FriendsFrame)
_G.FriendsListFrame.ScrollBox = env.NewFrame("Frame", nil, _G.FriendsListFrame)
local acquired
local callbacks = {}
env.SkinBase.HookScrollBoxAcquired = function(_, fn) acquired = fn end
env.SkinBase.OnAddOnLoaded = function(name, fn) callbacks[name] = fn end
assert(loadfile(os.getenv("QUI_SOCIAL_SOURCE") or "modules/skinning/frames/social.lua"))("QUI", env.ns)
callbacks.Blizzard_FriendsFrame()
assert(acquired)
local row = env.NewFrame("Button", nil, _G.FriendsListFrame.ScrollBox)
function row:CreateMaskTexture() return self:CreateTexture() end
row.background = row:CreateTexture()
row.highlight = row:CreateTexture()
row.highlight:SetTexture("native-selection")
row.highlight.maskCount = 0
function row.highlight:AddMaskTexture() self.maskCount = self.maskCount + 1 end
row.highlightTexture = row.highlight
row.travelPassButton = env.NewFrame("Button", nil, row)
local invite = row.travelPassButton
invite:SetSize(24, 32)
local createLabel = invite.CreateFontString
function invite:CreateFontString(name, layer, template)
    assert(template == "GameFontNormal", "invite label must have a font before setting text")
    return createLabel(self, name, layer)
end
function invite:SetFontString(label) self.Text = label end
invite.normalTexture = invite:CreateTexture()
invite.normalTexture:SetAtlas("friendslist-invitebutton-horde-normal")
invite.DisabledTexture = false
local actions = 0
local click = function() actions = actions + 1 end
invite:SetScript("OnClick", click)
row.status = row:CreateTexture()
row.status:SetTexture("native-online-status")
acquired(row)
assert(row.highlight.texture == "Interface\\Buttons\\WHITE8x8", "selection must replace native strip")
assert(row.highlight.maskCount == 1, "selection must reuse one rounded mask")
assert(invite:GetFontString() and invite:GetFontString():GetText() == "+", "invite must retain a visible action cue")
assert(env.SkinBase.GetBackdrop(invite)._quiRoundedSurface, "invite must use rounded shared button chrome")
assert(invite.normalTexture:GetAlpha() == 0, "native invite panel must be suppressed")
local label = invite:GetFontString()
invite.enabled = false
invite:Fire("OnDisable")
local disabled = label.textColor
invite.enabled = true
invite:Fire("OnEnable")
assert(label.textColor[1] * label.textColor[4] > disabled[1] * disabled[4], "disabled invite must remain distinguishable")
invite.normalTexture:SetAtlas("friendslist-invitebutton-alliance-normal")
acquired(row)
assert(row.highlight.maskCount == 1 and invite:GetFontString() == label, "pooled refresh must not duplicate masks or labels")
assert(invite.normalTexture:GetAlpha() == 0 and row.status.texture == "native-online-status", "reuse must preserve status art while suppressing button panel")
assert(invite:GetScript("OnClick") == click and actions == 0, "styling must preserve native action ownership without invoking it")
local quickRow = env.NewFrame("Button", nil, _G.FriendsListFrame.ScrollBox)
function quickRow:CreateMaskTexture() return self:CreateTexture() end
quickRow.Background = quickRow:CreateTexture()
quickRow.Highlight = quickRow:CreateTexture()
quickRow.Selected = quickRow:CreateTexture()
quickRow.Icon = quickRow:CreateTexture()
quickRow.Icon:SetTexture("native-quickjoin-icon")
for _, texture in ipairs({ quickRow.Highlight, quickRow.Selected }) do
    texture:SetTexture("native-blue-quickjoin-selection")
    texture.maskCount = 0
    function texture:AddMaskTexture() self.maskCount = self.maskCount + 1 end
end
quickRow.Highlight:Hide()
quickRow.Selected:Show()
quickRow:SetScript("OnClick", click)
acquired(quickRow)
for _, texture in ipairs({ quickRow.Highlight, quickRow.Selected }) do
    assert(texture.texture == "Interface\\Buttons\\WHITE8x8" and texture.maskCount == 1,
        "Quick Join uppercase hover and selection must use rounded neutral chrome")
end
assert(not quickRow.Highlight:IsShown() and quickRow.Selected:IsShown(),
    "Quick Join native hover and selection visibility must be preserved")
assert(quickRow.Icon.texture == "native-quickjoin-icon" and quickRow:GetScript("OnClick") == click and actions == 0,
    "Quick Join semantic icon and native click must be preserved without invoking it")
acquired(quickRow)
assert(quickRow.Highlight.maskCount == 1 and quickRow.Selected.maskCount == 1,
    "Quick Join reuse must not duplicate rounded masks")
local recruit = env.NewFrame("Frame", nil, _G.FriendsFrame)
_G.RecruitAFriendFrame = recruit
recruit.RewardClaiming = env.NewFrame("Frame", nil, recruit)
local reward = recruit.RewardClaiming
reward.Background = reward:CreateTexture()
reward.Background:SetAtlas("native-parchment")
reward.MonthCount = env.NewFrame("Frame", nil, reward)
reward.MonthCount.Text = reward.MonthCount:CreateFontString()
reward.MonthCount.Text:SetText("0 Months")
reward.NextRewardName = env.NewFrame("Frame", nil, reward)
reward.NextRewardName.Text = reward.NextRewardName:CreateFontString()
reward.NextRewardName.Text:SetTextColor(0.64, 0.21, 0.93, 1)
reward.NextRewardButton = env.NewFrame("Button", nil, reward)
reward.NextRewardButton.Icon = reward.NextRewardButton:CreateTexture()
reward.NextRewardButton.Icon:SetTexture("native-reward-icon")
reward.ClaimOrViewRewardButton = env.NewFrame("Button", nil, reward)
local view = reward.ClaimOrViewRewardButton
view.DisabledTexture = false
view.Text = view:CreateFontString()
view.Text:SetText("View All Rewards")
view:SetScript("OnClick", click)
recruit.RecruitList = env.NewFrame("Frame", nil, recruit)
local list = recruit.RecruitList
list.ScrollBox = env.NewFrame("Frame", nil, list)
list.ScrollFrameInset = env.NewFrame("Frame", nil, list)
local gallery = env.NewFrame("Frame")
_G.RecruitAFriendRewardsFrame = gallery
gallery.Title = env.NewFrame("Frame", nil, gallery)
gallery.Title.Text = gallery.Title:CreateFontString()
gallery.Title.Text:SetText("Recruit A Friend Rewards")
gallery.Background = gallery:CreateTexture()
gallery.Background:SetAtlas("native-rewards-parchment")
gallery.CloseButton = env.NewFrame("Button", nil, gallery)
gallery.CloseButton.DisabledTexture = false
gallery.CloseButton:SetScript("OnClick", click)
local rewardEntry = env.NewFrame("Frame", nil, gallery)
rewardEntry.Months = env.NewFrame("Frame", nil, rewardEntry)
rewardEntry.Months.Text = rewardEntry.Months:CreateFontString()
rewardEntry.Months.Text:SetTextColor(0.5, 0.5, 0.5, 1)
gallery.rewardPool = { EnumerateActive = function() return ipairs({rewardEntry}) end }
function gallery.rewardPool:EnumerateActive()
    local returned = false
    return function() if not returned then returned = true; return rewardEntry end end
end
function gallery:UpdateRewards() end
callbacks.Blizzard_RecruitAFriend()
local recruitAcquired = acquired
local recruitRow = env.NewFrame("Button", nil, list.ScrollBox)
recruitRow.Background = recruitRow:CreateTexture()
recruitRow.Name = recruitRow:CreateFontString()
recruitRow.Name:SetTextColor(0.5, 0.5, 0.5, 1)
recruitRow.InfoText = recruitRow:CreateFontString()
recruitRow.Icon = recruitRow:CreateTexture()
recruitRow.Icon:SetTexture("native-status")
recruitAcquired(recruitRow)
assert(reward.Background:GetAlpha() == 0, "recruitment parchment must be suppressed")
assert(env.SkinBase.GetBackdrop(reward)._quiRoundedSurface, "reward header must use shared rounded surface")
assert(env.SkinBase.GetBackdrop(view)._quiRoundedSurface, "view action must use shared button chrome")
assert(reward.NextRewardName.Text.textColor[1] == 0.64 and reward.NextRewardButton.Icon.texture == "native-reward-icon", "reward quality and art must remain native")
assert(recruitRow.Name.textColor[1] == 0.5 and recruitRow.Icon.texture == "native-status", "offline status and row art must remain native")
recruitRow.Background:SetAtlas("recycled-native-background")
recruitAcquired(recruitRow)
assert(recruitRow.Background:GetAlpha() == 0, "pooled row reuse must keep native background suppressed")
recruit:Fire("OnShow")
gallery:UpdateRewards()
gallery:Fire("OnShow")
assert(gallery.Background:GetAlpha() == 0 and env.SkinBase.GetBackdrop(gallery)._quiRoundedSurface, "gallery must use shared window chrome")
assert(gallery.Title.Text.textColor[1] == 1 and rewardEntry.Months.Text.textColor[1] == 0.5, "gallery title must be white while earned state stays native")
assert(gallery.CloseButton:GetScript("OnClick") == click, "gallery close behavior must remain native")
assert(view:GetScript("OnClick") == click and actions == 0, "recruitment styling must not invoke or replace actions")
print("OK: social_row_controls_test")

local inviteBackdrop = env.SkinBase.GetBackdrop(invite)
assert(inviteBackdrop:GetWidth() == 20 and inviteBackdrop:GetHeight() == 20,
    "contact invite border must be compact rather than filling the tall hit area")
local p, owner, relative = inviteBackdrop:GetPoint()
assert(p == "CENTER" and owner == invite and relative == "CENTER",
    "compact invite border must stay centered inside its native control")
assert(invite:GetWidth() == 24 and invite:GetHeight() == 32 and invite:GetScript("OnClick") == click,
    "compact contact appearance must preserve native hit area and action")
acquired(row)
assert(inviteBackdrop:GetWidth() == 20 and inviteBackdrop:GetHeight() == 20,
    "pooled refresh must retain compact contact geometry")
