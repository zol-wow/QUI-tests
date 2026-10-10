local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local weekly = env.NewFrame("Frame")
_G.WeeklyRewardsFrame = weekly
env.profile.general.skinWeeklyRewards = true
skin.OnAddOnLoaded = function(_, fn) fn() end
assert(loadfile(os.getenv("QUI_WEEKLY_SOURCE") or "modules/skinning/frames/weeklyrewards.lua"))("QUI", env.ns)
assert(skin.GetBackdrop(weekly)._quiRoundedSurface, "Great Vault shell must use rounded chrome")
local popup = env.NewFrame("Frame")
_G.StaticPopup1 = popup
_G.STATICPOPUP_NUMDIALOGS = 1
_G.UIDROPDOWNMENU_MAXLEVELS = 1
local button = env.NewFrame("Button", nil, popup)
button.Text = button:CreateFontString()
popup.button1 = button
local edit = env.NewFrame("EditBox", nil, popup)
popup.editBox = edit
local menu = env.NewFrame("Frame")
local art = menu:CreateTexture()
_G.DropDownList1 = menu
_G.Menu = nil
env.ns.WhenLoggedIn = function(fn) fn() end
assert(loadfile(os.getenv("QUI_POPUP_SOURCE") or "modules/skinning/system/popups.lua"))("QUI", env.ns)
_G.QUI_RefreshSystemPopupSkins()
for _, frame in ipairs({popup, button, edit, menu}) do
    assert(skin.GetBackdrop(frame)._quiRoundedSurface, "popup shells and controls must render rounded chrome")
end
assert(art:GetAlpha() == 0, "native square menu fill must not cover rounded corners")
local count = #env.textures
_G.QUI_RefreshSystemPopupSkins()
assert(#env.textures == count, "refreshing open popups must reuse chrome")
print("OK: skinning_specialized_rounded_shells_test")
