local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true
env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false; f.DisabledTexture=false
 return f
end
local popup=frame()
_G.StaticPopup1=popup; _G.STATICPOPUP_NUMDIALOGS=1
popup.Text,popup.SubText=popup:CreateFontString(),popup:CreateFontString()
popup.Text:SetText("Native warning")
popup.Text:SetTextColor(1,.15,.1,1)
popup.SubText:SetText("Native detail"); popup.SubText:SetTextColor(.3,.6,1,1)
popup.MoneyFrame=frame(nil,popup)
popup.MoneyFrame.digits=popup.MoneyFrame:CreateFontString()
popup.MoneyFrame.digits:SetText("1000"); popup.MoneyFrame.digits:SetTextColor(1,.1,.1,1)
popup.MoneyInputFrame=frame(nil,popup)
function popup.MoneyInputFrame:SetIsUserScaled() self.nativeScaleCalls=(self.nativeScaleCalls or 0)+1 end
local writes=0
local enter=function() writes=writes+1 end
_G.StaticPopupEditBoxMixin={OnEnterPressed=enter}
local fields={}
for i,key in ipairs({"gold","silver","copper"}) do
 local f=frame("EditBox",popup.MoneyInputFrame)
 popup.MoneyInputFrame[key]=f; fields[i]=f
 f.Background=f:CreateTexture()
 function f:SetText(value) self.value=value end
 function f:GetText() return self.value end
 function f:SetFont(path,size,flags) self.font={path,size,flags} end
 function f:GetFont() return unpack(self.font or {"native-money-input",10,""}) end
 f:SetText(tostring(i*10)); f:SetScript("OnEnterPressed",enter)
end
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a"); file:close()
_G.GameDialogMixin={}
local setup=assert(source:match("(function GameDialogMixin:SetupMoneyFrame.-)\nfunction "))
assert(loadstring(setup,"@native-static-popup-money-setup"))()
popup.SetupMoneyFrame=_G.GameDialogMixin.SetupMoneyFrame
_G.StaticPopupItemFrameMixin={}
local display=assert(source:match("(function StaticPopupItemFrameMixin:DisplayInfo%(.-)\nfunction StaticPopupItemFrameMixin:DisplayInfoFromStandardCallback"))
assert(loadstring(display,"@native-static-popup-item-display"))()
local itemFrame=frame(nil,popup)
popup.ItemFrame=itemFrame
itemFrame.Text=itemFrame:CreateFontString()
itemFrame.Item=frame("Button",itemFrame)
itemFrame.Item.Count=itemFrame.Item:CreateFontString()
_G.SetItemButtonTexture=function(f,value) f.nativeTexture=value end
_G.SetItemButtonQuality=function(f,q,link) f.nativeQuality,f.nativeLink=q,link end
_G.C_Item={GetItemInfo=function() return "Native item",nil,4 end}
_G.StaticPopupItemFrameMixin.DisplayInfo(itemFrame,"item:22","Native purple item",{.7,.2,1,1},"native-art",3,"native tooltip")
popup.AlertIcon=popup:CreateTexture()
popup.AlertIcon:SetTexture("native-warning-art")
local dark=frame(nil,popup); popup.DarkOverlay=dark; dark.Background=dark:CreateTexture()
dark:Hide()
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
assert(popup.MoneyFrame.digits.textColor[2]==.1 and popup.Text.textColor[2]==.15
 and popup.SubText.textColor[3]==1 and itemFrame.Text.textColor[1]==.7,
 "static popup styling must retain native money warning detail and item-quality colors")
for _,f in ipairs(fields) do
 assert(skin.GetBackdrop(f) and skin.GetBackdrop(f)._quiRoundedSurface and f.Background:GetAlpha()==0,
 "all native denomination fields must receive rounded edit chrome")
end
popup:SetupMoneyFrame({hasMoneyFrame=false,hasMoneyInputFrame=true,EditBoxOnEnterPressed=true})
assert(not popup.MoneyFrame:IsShown() and popup.MoneyInputFrame:IsShown() and popup.MoneyInputFrame.nativeScaleCalls==1,
 "native money-input visibility and scaling must remain")
for i,f in ipairs(fields) do
 assert(f:GetScript("OnEnterPressed")==enter and f:GetText()==tostring(i*10),
 "native denomination contents and Enter handler must remain")
end
popup:SetupMoneyFrame({hasMoneyFrame=true,hasMoneyInputFrame=false})
assert(popup.MoneyFrame:IsShown() and not popup.MoneyInputFrame:IsShown(),"native display/input exclusion must remain")
popup:SetupMoneyFrame({hasMoneyFrame=false,hasMoneyInputFrame=true,EditBoxOnEnterPressed=false})
for _,f in ipairs(fields) do assert(f:GetScript("OnEnterPressed")==nil,"native no-Enter dialog must clear denomination acceptance handlers") end
_G.StaticPopupItemFrameMixin.DisplayInfo(itemFrame,"item:23","Reused item",{.2,.8,.3,1},"second-art",1,"new tooltip")
_G.QUI_RefreshSystemPopupSkins()
assert(itemFrame.Text.textColor[2]==.8 and itemFrame.Item.nativeTexture=="second-art" and not itemFrame.Item.Count:IsShown()
 and itemFrame.link=="item:23" and itemFrame.tooltip=="new tooltip","reused native item color artwork count and tooltip data must remain")
assert(popup.AlertIcon.texture=="native-warning-art" and popup.AlertIcon:GetAlpha()==1 and not dark:IsShown(),
 "warning art and native dark-overlay visibility must remain")
local forbidden=fields[1]
function forbidden:IsForbidden() return true end
function forbidden:SetFont() error("forbidden money field font mutation") end
function forbidden.Background:SetAlpha() error("forbidden money field art mutation") end
_G.QUI_RefreshSystemPopupSkins()
popup:SetupMoneyFrame({hasMoneyFrame=false,hasMoneyInputFrame=true,EditBoxOnEnterPressed=false})
env.profile.general.skinStaticPopups=false
local untouched=frame()
_G.StaticPopup2=untouched; _G.STATICPOPUP_NUMDIALOGS=2
untouched.MoneyInputFrame=frame(nil,untouched)
untouched.MoneyInputFrame.gold=frame("EditBox",untouched.MoneyInputFrame)
_G.QUI_RefreshSystemPopupSkins()
assert(not skin.GetBackdrop(untouched) and not skin.GetBackdrop(untouched.MoneyInputFrame.gold),
 "disabled static popup skin must leave a newly visible dialog alone")
assert(writes==0,"styling must not invoke denomination confirmation")
print("static popup money and semantic colors passed")
