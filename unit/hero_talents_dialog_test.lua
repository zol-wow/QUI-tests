local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local file = assert(io.open(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleHeroTalentContent(", 1, true))
local last = assert(source:find("local function StylePlayerSpellsControls(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleHeroTalentsDialog"))
setfenv(chunk, setmetatable({ SkinBase = skin, WHITE_TEXT_STYLE = { color = { 1, 1, 1, 1 } },
    RefreshBackdropColors = skin.RefreshFrameBackdropColors,
    IsSettingEnabled = function() return true end }, { __index = _G }))
local apply = chunk()
local function frame(kind, parent)
    local f = env.NewFrame(kind or "Frame", nil, parent)
    f.RegisterForWidgetSet = false; f.DisabledTexture = false
    return f
end
local owner = frame()
owner.TalentsFrame = frame(nil, owner)
local dialog = frame()
owner.TalentsFrame.heroSpecSelectionDialog = dialog
_G.HeroTalentsSelectionDialog = dialog
 dialog.Background = dialog:CreateTexture()
dialog.NineSlice = frame(nil, dialog); dialog.NineSlice.Art = dialog.NineSlice:CreateTexture()
dialog.CloseButton = frame("Button", dialog)
local nativeClose = function() end
dialog.CloseButton:SetScript("OnClick", nativeClose)
dialog.CoverFrame = frame("Button", dialog)
local nativeCover = function() end
dialog.CoverFrame:SetScript("OnClick", nativeCover)
local content = frame(nil, dialog)
content.SpecImage = content:CreateTexture(); content.SpecImage:SetTexture("native-hero-portrait")
for _, key in ipairs({ "ColumnDivider", "SpecImageBorder", "SpecImageBorderSelected" }) do
    content[key] = content:CreateTexture()
end
content.ActivatedBackFrames = { content:CreateTexture() }
content.ActivatedLeftFrames = {}; content.ActivatedRightFrames = {}
for _, key in ipairs({ "SpecName", "Description", "ActivatedText" }) do content[key] = content:CreateFontString() end
content.ActivatedText:SetTextColor(0, 1, 0, 1)
content.CurrencyFrame = frame(nil, content)
content.CurrencyFrame.AmountText = content:CreateFontString()
content.CurrencyFrame.AmountText:SetTextColor(.5, .5, .5, 1)
content.CurrencyFrame.LabelText = content:CreateFontString()
local nativeAction = function() error("talent action invoked") end
for _, key in ipairs({ "ActivateButton", "ApplyChangesButton" }) do
    content[key] = frame("Button", content)
    content[key]:SetScript("OnClick", nativeAction)
end
-- Protected talent nodes must remain entirely owned by Blizzard.
local node = frame("Button", content)
for _, key in ipairs({ "SetPoint", "SetParent", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight" }) do
    node[key] = function() error("talent node geometry touched") end
end
function content:SetIsActive(active)
    self.isActiveSpec = active
    self.SpecImageBorderSelected:SetAlpha(1)
    self.ActivatedBackFrames[1]:SetAlpha(1)
    self.ActivateButton:SetShown(not active)
    self.ActivatedText:SetShown(active)
end
local active = false
local acquisitions = 0
dialog.SpecContentFramePool = { EnumerateActive = function()
    local pending = active and content or nil
    return function() local result=pending; pending=nil; return result end
end }
apply(owner)
assert(skin.IsSkinned(dialog) and dialog.Background:GetAlpha()==0,
    "hero chooser shell must receive QUI chrome before content acquisition")
active = true; acquisitions = acquisitions + 1
dialog:Fire("OnShow")
assert(skin.GetBackdrop(content)._quiRoundedSurface.radius==6,
    "late-acquired hero options must receive rounded QUI panels")
assert(skin.GetBackdrop(content.ActivateButton)._quiRoundedSurface,
    "hero Activate must use QUI chrome")
assert(skin.GetBackdrop(content.ApplyChangesButton)._quiRoundedSurface,
    "hidden native Apply control must also receive QUI chrome")
content:SetIsActive(true)
assert(content.SpecImageBorderSelected:GetAlpha()==0 and content.ActivatedBackFrames[1]:GetAlpha()==0,
    "native active refresh must not restore ornamental art")
assert(not content.ActivateButton:IsShown() and content.ActivatedText:IsShown(),
    "native active-state visibility must survive styling")
assert(content.SpecImage.texture=="native-hero-portrait" and content.SpecImage:GetAlpha()==1,
    "identifying hero portrait must remain intact")
assert(content.ActivatedText.textColor[2]==1 and content.CurrencyFrame.AmountText.textColor[1]==.5,
    "active and unavailable-currency semantic colors must remain native")
local backdrop = skin.GetBackdrop(content)
apply(owner); dialog:Fire("OnShow")
assert(skin.GetBackdrop(content)==backdrop and acquisitions==1,
    "reopening and theme refresh must reuse QUI chrome")
assert(content.ActivateButton:GetScript("OnClick")==nativeAction
    and content.ApplyChangesButton:GetScript("OnClick")==nativeAction
    and dialog.CloseButton:GetScript("OnClick")==nativeClose
    and dialog.CoverFrame:GetScript("OnClick")==nativeCover,
    "activation, application, dismissal and modal cover handlers must remain native")
print("hero talents dialog passed")
