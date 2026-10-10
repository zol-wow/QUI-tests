local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true; env.profile.general.skinContextMenus=false
local popup=env.NewFrame("Frame",nil)
popup.RegisterForWidgetSet=false
popup:SetFrameLevel(20)
_G.StaticPopup1=popup; _G.STATICPOPUP_NUMDIALOGS=1
popup.ProgressBarBorder=popup:CreateTexture(nil,"BACKGROUND")
popup.ProgressBarFill=popup:CreateTexture(nil,"BACKGROUND")
popup.ProgressBarSpacer=popup:CreateTexture(nil,"BACKGROUND")
local border,fill=popup.ProgressBarBorder,popup.ProgressBarFill
function border:GetDrawLayer() return "BACKGROUND" end
function fill:GetDrawLayer() return "BACKGROUND" end
function border:GetWidth() return 200 end
function fill:SetWidth(value) self.nativeWidth=value end
function fill:SetTexCoord(...) self.nativeCoords={...} end
fill:SetAtlas("ui-frame-lfg-progressbar-fill-green")
local masks=0
function fill:AddMaskTexture() masks=masks+1 end
local create=_G.CreateFrame
_G.CreateFrame=function(...)
 local f=create(...)
 function f:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
 return f
end
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a");file:close()
_G.GameDialogMixin={}
local setup=assert(source:match("(function GameDialogMixin:SetupProgressBar.-)\nfunction "))
assert(loadstring(setup,"@native-static-progress-setup"))()
popup.SetupProgressBar=_G.GameDialogMixin.SetupProgressBar
file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua"))
source=file:read("*a");file:close()
local update=assert(source:match("(function StaticPopup_UpdateProgressBar.-)\n%-%- This is intended"))
assert(loadstring(update,"@native-static-progress-update"))()
popup:SetupProgressBar({progressBar=true})
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
assert(fill:GetAlpha()==1 and fill:IsShown(),"native progress fill must remain visible through background-decoration styling")
local track=skin.GetFrameData(popup,"systemPopupProgressTrack")
assert(track and track.ignoreInLayout and track:IsShown() and masks==1 and border:GetAlpha()==0 and skin.GetBackdrop(track)._quiRoundedSurface,
 "native progress border must receive rounded track with one fill mask")
for mask in pairs(skin.GetFrameData(fill,"roundedBarMaskAttachments")) do
 assert(mask:GetParent().ignoreInLayout,"mask owner must not participate in native dialog layout")
end
_G.StaticPopup_UpdateProgressBar(popup,.5)
assert(fill:IsShown() and fill.nativeWidth==96 and fill.nativeCoords[2]==.5
 and fill.atlas=="ui-frame-lfg-progressbar-fill-green","native percent width UV crop and semantic atlas must remain")
_G.StaticPopup_UpdateProgressBar(popup,0)
assert(not fill:IsShown() and track:IsShown(),"native zero progress must hide fill while retaining empty track")
_G.QUI_RefreshSystemPopupSkins()
assert(not fill:IsShown() and masks==1,"theme refresh must not show empty native fill or duplicate its mask")
popup:SetupProgressBar({progressBar=false})
assert(not track:IsShown() and not fill:IsShown() and not popup.ProgressBarSpacer:IsShown(),
 "native non-progress reuse must hide track fill and layout spacer")
popup:SetupProgressBar({progressBar=true})
_G.StaticPopup_UpdateProgressBar(popup,1)
assert(track:IsShown() and fill:IsShown() and fill.nativeWidth==192 and fill.nativeCoords[2]==1 and masks==1,
 "native progress restoration must retain full width and reused mask")
print("static popup progress passed")
