local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local file = assert(io.open(os.getenv("QUI_CHARACTER_SOURCE") or "modules/skinning/frames/character.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function SkinCurrencyEntry(", 1, true))
local last = assert(source:find("local function SkinNativeSidePaneText", first, true))
local scope = setmetatable({
    SkinBase = skin, ApplyPixelBackdrop = skin.ApplyPixelBackdrop, Helpers = env.ns.Helpers, skinnedEntries = {}, iconBorders = {},
    GetWindowColors = function() return .3, .3, .3, 1, .05, .06, .07, .97 end,
    GetFontPath = function() return "font.ttf" end,
    GetTextAccent = function() return 1, 1, 1, 1 end,
    CJKFont = function() end, SkinToggleCollapseButton = function() end,
    SetExpandedPixelPoints = function(frame, icon) frame:SetAllPoints(icon) end,
    StyleCloseButton = function(button) skin.SkinCloseButton(button) end,
    IsSkinningEnabled = function() return true end,
    StyleThinScrollBar = function() end, RowToken = function() return { 1, 1, 1, 1 } end,
}, { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn SkinCurrencyEntry, SkinReputationDetailFrame, SkinTokenFramePopup, SkinCurrencyTransferLog"))
setfenv(chunk, scope)
local currency, reputation, popup, logSkin = chunk()
local row = env.NewFrame("Frame")
row.Content = env.NewFrame("Frame", nil, row)
row.Content.CreateMaskTexture = row.Content.CreateTexture
row.Content.CurrencyIcon = row.Content:CreateTexture()
row.Content.CurrencyIcon.AddMaskTexture = function(self, mask) self.mask = mask end
currency(row)
local border = scope.iconBorders[row.Content.CurrencyIcon]
assert(border._quiRoundedSurface.radius == 4, "currency icons must have rounded borders matching the row icon")
assert(skin.GetFrameData(row.Content.CurrencyIcon, "roundedIconMask"), "currency icon art must share the rounded mask")
scope.ReputationFrame = { ReputationDetailFrame = env.NewFrame("Frame") }
local detail = scope.ReputationFrame.ReputationDetailFrame
detail.parchment = detail:CreateTexture()
for _, key in ipairs({ "AtWarCheckbox", "MakeInactiveCheckbox", "WatchFactionCheckbox" }) do
    detail[key] = env.NewFrame("CheckButton", nil, detail)
    detail[key].Label = detail[key]:CreateFontString()
    detail[key].Label:SetTextColor(1, .8, 0, 1)
end
detail.Refresh = function(self) self.MakeInactiveCheckbox.Label:SetTextColor(1, .8, 0, 1) end
local capturedRefresh = detail.Refresh
local nativeClick = function() end
detail.MakeInactiveCheckbox:SetScript("OnClick", nativeClick)

scope.TokenFramePopup = env.NewFrame("Frame")
local tokenPopup = scope.TokenFramePopup
tokenPopup["$parent.CloseButton"] = env.NewFrame("Button", nil, tokenPopup)
tokenPopup.CurrencyTransferToggleButton = env.NewFrame("Button", nil, tokenPopup)
tokenPopup.CurrencyTransferToggleButton.DisabledTexture = false
tokenPopup.CurrencyTransferToggleButton:SetText("Transfer")
local transferClick = function() end
tokenPopup.CurrencyTransferToggleButton:SetScript("OnClick", transferClick)
for _, key in ipairs({ "InactiveCheckbox", "BackpackCheckbox" }) do
    tokenPopup[key] = env.NewFrame("CheckButton", nil, tokenPopup)
end
_G.TokenFramePopup = scope.TokenFramePopup
reputation()
popup()
assert(detail.parchment:GetAlpha() == 0, "reputation detail parchment must be suppressed")
assert(skin.GetBackdrop(detail.MakeInactiveCheckbox)._quiRoundedSurface, "reputation detail controls must use QUI chrome")
assert(detail.MakeInactiveCheckbox:GetScript("OnClick") == nativeClick, "reputation checkbox behavior must remain native")
capturedRefresh(detail)
assert(detail.MakeInactiveCheckbox.Label.textColor[3] == 1, "native detail refresh must keep enabled labels readable")

for _, frame in ipairs({ scope.ReputationFrame.ReputationDetailFrame, scope.TokenFramePopup }) do
    assert(skin.GetBackdrop(frame)._quiRoundedSurface.radius == 8, "character detail popups must share the rounded window shell")
end
assert(skin.GetBackdrop(tokenPopup.CurrencyTransferToggleButton)._quiRoundedSurface, "currency transfer action must use QUI chrome")
assert(tokenPopup.CurrencyTransferToggleButton:GetScript("OnClick") == transferClick, "currency transfer action must remain native")
assert(skin.GetBackdrop(tokenPopup.InactiveCheckbox)._quiRoundedSurface.radius == 3, "currency option checks must match reputation details")
assert(skin.GetFrameData(tokenPopup["$parent.CloseButton"], "closeStyled"), "literal PTR close button key must be handled")
scope.TokenFrame = env.NewFrame("Frame")
local toggle = env.NewFrame("Button", nil, scope.TokenFrame)
scope.TokenFrame.CurrencyTransferLogToggleButton = toggle
toggle.DisabledTexture = false
local nativeLogClick = function() end
toggle:SetScript("OnClick", nativeLogClick)
local log = env.NewFrame("Frame")
scope.CurrencyTransferLog = log
_G.CurrencyTransferLog = log
log.Background = log:CreateTexture()
log.Inset = env.NewFrame("Frame", nil, log)
log.TitleText = log:CreateFontString()
log.GetTitleText = function(owner) return owner.TitleText end
log.EmptyLogMessage = log:CreateFontString()
log.Refresh = function(owner) owner.Background:SetAlpha(1) end
log.ScrollBox = env.NewFrame("Frame", nil, log)
log.ScrollBox.HasView = function() return false end
log.ScrollBar = nil
logSkin()
assert(skin.GetBackdrop(log)._quiRoundedSurface.radius == 8,
    "currency log must share the rounded Character side-window shell")
assert(toggle:GetScript("OnClick") == nativeLogClick and skin.GetFrameData(toggle, "qCurrencyLogGlyph"):GetText() == "Log",
    "currency log toggle must retain its native action and a readable caption")
log:Refresh()
assert(log.Background:GetAlpha() == 0, "native log refresh must not restore parchment")
local r, g, b = log.EmptyLogMessage:GetTextColor()
assert(r == 0.85 and g == 0.85 and b == 0.85, "empty transfer history must remain readable on a dark shell")
print("OK: character_inner_rounded_surfaces_test")
