local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinWeeklyRewards = true
local frame = env.NewFrame("Frame")
_G.WeeklyRewardsFrame = frame
frame.RaidFrame = env.NewFrame("Frame", nil, frame)
frame.RaidFrame.RegisterForWidgetSet = false
frame.RaidFrame.widgetType = false
frame.RaidFrame.Background = frame.RaidFrame:CreateTexture()
frame.RaidFrame.Name = frame.RaidFrame:CreateFontString()
frame.RaidFrame.Name:SetTextColor(1, .8, 0, 1)
local tile = env.NewFrame("Frame", nil, frame)
tile.Background = tile:CreateTexture()
tile.Border = tile:CreateTexture()
tile.SelectedTexture = tile:CreateTexture()
tile.SelectedTexture:Hide()
tile.Threshold = tile:CreateFontString()
tile.Progress = tile:CreateFontString()
tile.CompletedIcon = tile:CreateTexture()
tile.CompletedIcon:Hide()
tile.unlocked = false
tile.hasRewards = false
local nativeRefresh = function(self)
    self.Background:SetAlpha(1)
    self.Background:Show()
    self.unlocked = true
    self.CompletedIcon:Show()
    self.Progress:SetTextColor(0, 1, 0, 1)
end
tile.Refresh = nativeRefresh
tile.SetSelectionState = function(self, selected) self.SelectedTexture:SetShown(selected) end
local nativeAction = function() end
tile:SetScript("OnMouseDown", nativeAction)
frame.Activities = { tile }
local capturedRefresh = function(self)
    self.RaidFrame.Name:SetTextColor(1, .8, 0, 1)
    self.Activities[1]:Refresh()
end
frame.Refresh = capturedRefresh
_G.WeeklyRewardsMixin = { Refresh = capturedRefresh }
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_WEEKLY_SOURCE") or "modules/skinning/frames/weeklyrewards.lua"))("QUI", env.ns)
assert(tile.Background:GetAlpha() == 0, "native beveled tile must disappear")
assert(env.SkinBase.GetBackdrop(tile)._quiRoundedSurface.radius == 6, "Great Vault tile must use QUI rounded chrome")
assert(tile.qVaultLock:IsShown(), "locked reward must remain identifiable")
assert(frame.RaidFrame.Background:GetAlpha() == 1, "category artwork must remain visible")
assert(tile:GetScript("OnMouseDown") == nativeAction, "reward selection action must remain native")
tile:Refresh()
assert(tile.Background:GetAlpha() == 0, "copied tile refresh must not restore native border")
assert(not tile.qVaultLock:IsShown() and tile.CompletedIcon:IsShown(), "unlocked state must retain completion semantics")
local r, g = tile.Progress:GetTextColor()
assert(r == 0 and g == 1, "completion progress must retain semantic green")
tile:SetSelectionState(true)
assert(tile.SelectedTexture:IsShown() and tile.SelectedTexture:GetAlpha() == 0, "selection state must survive native texture suppression")
frame:Refresh()
local r, g = frame.RaidFrame.Name:GetTextColor()
assert(r == g and r > .8, "copied frame refresh must restore neutral headings")
print("OK: weekly_rewards_inner_controls_test")
