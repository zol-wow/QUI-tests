local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true; env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local popup=frame()
_G.StaticPopup1=popup;_G.STATICPOPUP_NUMDIALOGS=1
local close=frame("Button",popup)
popup.CloseButton=close
close.normal,close.pushed,close.highlight=close:CreateTexture(),close:CreateTexture(),close:CreateTexture()
function close:GetNormalTexture() return self.normal end
function close:GetPushedTexture() return self.pushed end
function close:GetHighlightTexture() return self.highlight end
function close:SetNormalTexture(value) self.normal:SetTexture(value) end
function close:SetPushedTexture(value) self.pushed:SetTexture(value) end
local masks,writes=0,0
function close:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
for _,t in ipairs({close.normal,close.pushed,close.highlight}) do function t:AddMaskTexture() masks=masks+1 end end
local click=function() writes=writes+1 end
close:SetScript("OnClick",click)
_G.GameDialogBaseMixin={};_G.GameDialogMixin={}
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a");file:close()
local methods={}
for _,key in ipairs({"SetCloseButtonToMinimize","SetCloseButtonToHide"}) do
 methods[#methods+1]=assert(source:match("(function GameDialogBaseMixin:"..key..".-)\nfunction "))
end
methods[#methods]=methods[#methods]:match("(.-)\nGameDialogMixin") or methods[#methods]
methods[#methods+1]=assert(source:match("(function GameDialogMixin:SetupCloseButton.-)\nfunction "))
assert(loadstring(table.concat(methods,"\n"),"@native-static-close-modes"))()
popup.SetCloseButtonToHide=_G.GameDialogBaseMixin.SetCloseButtonToHide
popup.SetCloseButtonToMinimize=_G.GameDialogBaseMixin.SetCloseButtonToMinimize
popup.SetupCloseButton=_G.GameDialogMixin.SetupCloseButton
_G.GameDialogCloseButtonStateNormal,_G.GameDialogCloseButtonStatePressed="native-hide","native-hide-pressed"
_G.GameDialogCloseButtonStateCondensedNormal,_G.GameDialogCloseButtonStateCondensedPressed="native-minimize","native-minimize-pressed"
popup:SetupCloseButton({closeButton=true,closeButtonIsHide=true})
local actions={}
for i=1,4 do
 local f=frame("Button",popup);actions[i]=f
 f.Text=f:CreateFontString()
 function f:GetFontString() return self.Text end
 f.enabled=true
 function f:IsEnabled() return self.enabled end
 function f:Enable() local changed=not self.enabled;self.enabled=true;if changed then self:Fire("OnEnable") end end
 function f:Disable() local changed=self.enabled;self.enabled=false;if changed then self:Fire("OnDisable") end end
 f:SetScript("OnClick",click)
end
function popup:GetButton(i) return actions[i] end
function popup:GetButton4() return actions[4] end
file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua"))
source=file:read("*a");file:close()
local recap=assert(source:match("(dialog.UpdateRecapButton = function%( dialog %).-)\n\t\tend\n\n\t\tdialog:UpdateRecapButton"))
local available=false
_G.C_DeathRecap={HasRecapEvents=function() return available end}
_G.DEATH_RECAP_UNAVAILABLE="Native recap unavailable"
local tooltip={SetOwner=function(self,f) self.owner=f end,SetText=function(self,value) self.text=value end,Show=function(self) self.shown=true end}
_G.GameTooltip=tooltip;_G.GameTooltip_Hide=function() tooltip.shown=false end
assert(loadstring("local dialog=...\n"..recap,"@native-dynamic-recap-install"))(popup)
popup:UpdateRecapButton()
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
assert(skin.GetBackdrop(close) and skin.GetBackdrop(close)._quiRoundedSurface and masks==3,
 "close control must receive rounded chrome and one mask per native texture")
assert(close.normal.texture=="native-hide" and close.pushed.texture=="native-hide-pressed",
 "hide mode must retain native identifying art")
popup:SetupCloseButton({closeButton=true,closeButtonIsHide=false})
assert(close.normal.texture=="native-minimize" and close.pushed.texture=="native-minimize-pressed" and masks==3,
 "native minimize swap must retain art and reuse masks")
popup:SetupCloseButton({closeButton=false})
assert(not close:IsShown(),"native close-control visibility must remain")
local fourth=actions[4]
skin.SetBackdropColors(skin.GetBackdrop(fourth),{.91,.32,.43,1},nil)
fourth.Text:SetTextColor(1,1,1,1)
popup:UpdateRecapButton()
assert(not fourth:IsEnabled() and fourth.Text.textColor[4]==.30 and skin.GetBackdrop(fourth)._quiBorderA==.35,
 "modern getter recap refresh must restore disabled presentation even when state does not change")
fourth:Fire("OnEnter")
assert(tooltip.owner==fourth and tooltip.text=="Native recap unavailable" and tooltip.shown,
 "native unavailable-recap tooltip must coexist with QUI hooks")
fourth:Fire("OnLeave")
assert(not tooltip.shown,"native tooltip leave must remain")
available=true
popup:UpdateRecapButton()
assert(fourth:IsEnabled() and fourth:GetScript("OnEnter")==nil and fourth:GetScript("OnLeave")==nil,
 "available recap must retain native enabling and tooltip-script removal")
_G.QUI_RefreshSystemPopupSkins()
assert(masks==3 and close:GetScript("OnClick")==click and fourth:GetScript("OnClick")==click and writes==0,
 "refresh must preserve close/recap handlers and invoke no action")
print("static close and recap passed")
