local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true; env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false; f.DisabledTexture=false
 return f
end
local popup=frame()
_G.StaticPopup1=popup; _G.STATICPOPUP_NUMDIALOGS=1
popup.Text=popup:CreateFontString()
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a"); file:close()
local native=assert(source:match("(StaticPopupItemFrameMixin = {};.-)StaticPopup_AddShowCondition"))
assert(loadstring(native,"@native-static-popup-item-methods"))()
local itemFrame=frame(nil,popup)
popup.ItemFrame=itemFrame
for k,v in pairs(_G.StaticPopupItemFrameMixin) do itemFrame[k]=v end
itemFrame.Text=itemFrame:CreateFontString()
itemFrame.NameFrame=itemFrame:CreateTexture()
itemFrame.Item=frame("Button",itemFrame)
local button=itemFrame.Item
button.icon,button.IconBorder=button:CreateTexture(),button:CreateTexture()
button.Count=button:CreateFontString()
button.IconBorder:Hide()
function button.IconBorder:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
function button:SetItemLocation(location) self.nativeLocation=location; self.icon:SetTexture("location-art") end
local masks=0
function button:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
function button.icon:AddMaskTexture() masks=masks+1 end
local click=function() error("audit must not accept item confirmation") end
button:SetScript("OnClick",click)
local loaded,quality=false,4
local colors={[0]={1,1,1,1},[2]={.2,.8,.3,1},[4]={.7,.2,1,1}}
_G.C_Item={
 GetItemInfo=function() if loaded then return "Loaded item",nil,quality,nil,nil,nil,nil,nil,nil,"late-art" end end,
 GetItemInfoInstant=function() return 22,nil,nil,nil,"pending-art" end,
 GetItemQualityColor=function(q) return unpack(colors[q]) end,
 GetItemName=function() return "Location item" end,
 GetItemQuality=function() return 2 end,
}
_G.ColorManager={GetColorDataForItemQuality=function(q) return {color={GetRGB=function() return unpack(colors[q]) end}} end}
_G.SetItemButtonTexture=function(f,value) f.icon:SetTexture(value) end
_G.SetItemButtonQuality=function(f,q)
 f.nativeQuality=q
 if q and q>0 then f.IconBorder:SetVertexColor(unpack(colors[q])); f.IconBorder:Show()
 else f.IconBorder:Hide() end
end
_G.RETRIEVING_ITEM_INFO="Native retrieving"
_G.RED_FONT_COLOR={r=1,g=.1,b=.1}
local tooltip={SetOwner=function(self,f) self.owner=f end,SetHyperlink=function(self,link) self.link=link end,Hide=function(self) self.hidden=true end}
_G.GameTooltip=tooltip
itemFrame:SetScript("OnEnter",itemFrame.OnEnter); itemFrame:SetScript("OnLeave",itemFrame.OnLeave)
popup.data={link="item:22",count=3}
itemFrame:RetrieveInfo(popup.data)
itemFrame:DisplayInfo(popup.data.link,popup.data.name,popup.data.color,popup.data.texture,popup.data.count)

_G.GameDialogMixin={}
local helpers=assert(source:match("(local function ShouldHideButton.-)GameDialogBaseMixin = {}"))
local methods={}
for _,key in ipairs({"SetupButtons","SetupAlertIcon","SetupStartDelay","SetupExtraButton","SetupItemFrame"}) do
 methods[#methods+1]=assert(source:match("(function GameDialogMixin:"..key..".-)\nfunction "))
end
assert(loadstring(helpers..table.concat(methods,"\n"),"@native-static-dialog-action-setup"))()
for k,v in pairs(_G.GameDialogMixin) do popup[k]=v end
local actions,barMasks,writes={},0,0
local function action()
 local f=frame("Button",popup)
 f.Text=f:CreateFontString()
 function f:GetFontString() return self.Text end
 function f:SetText(value) self.Text:SetText(value); self.Text:SetFont("native-action-reset",11,"") end
 function f:IsEnabled() return self.enabled~=false end
 function f:Enable() self.enabled=true; self:Fire("OnEnable") end
 function f:Disable() self.enabled=false; self:Fire("OnDisable") end
 function f:SetEnabled(value) if value then self:Enable() else self:Disable() end end
 function f:GetTextWidth() return 180 end
 function f:SetDesiredWidth(value) self.nativeWidth=value end
 f.Flash=f:CreateTexture(nil,"OVERLAY"); f.Flash:SetAlpha(.37)
 function f:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
 function f.Flash:AddMaskTexture() barMasks=barMasks+1 end
 f.PulseAnim={Play=function(self) self.playing=true end,Stop=function(self) self.playing=false end}
 f:SetScript("OnClick",function() writes=writes+1 end)
 return f
end
for i=1,4 do actions[i]=action() end
popup.ExtraButton=action()
function popup:GetButton(index) return actions[index] end
function popup:GetButtons() return actions end
function popup:GetItemFrame() return itemFrame end
popup.ButtonContainer,popup.Separator=frame(nil,popup),popup:CreateTexture()
popup.AlertIcon=popup:CreateTexture()
popup.which="Native test"
local padding=10
function popup:GetHeightPadding() return padding end
function popup:SetHeightPadding(value) padding=value end
_G.GameDialogAlertTextureName="native-alert"
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
assert(actions[1].Flash.texture==[[Interface\Buttons\WHITE8x8]] and actions[1].Flash:GetAlpha()==.37 and barMasks==5,
 "native action flash must use rounded QUI tint without resetting animation alpha")
popup:SetupButtons({button1="Accept",button2="Cancel",button3="Hidden",DisplayButton3=function() return false end,button1Pulse=true},{})
assert(popup.numButtons==2 and popup.ButtonContainer:IsShown() and actions[1]:IsShown() and not actions[3]:IsShown()
 and actions[1].PulseAnim.playing and not actions[2].PulseAnim.playing,"native button visibility and pulse selection must remain")
assert(actions[1].Text:GetText()=="Accept" and actions[1].Text:GetFont()~="native-action-reset",
 "native action caption reset must retain QUI typography")
popup:SetupStartDelay({acceptDelay=3})
assert(not actions[1]:IsEnabled() and actions[1].Text.textColor[4]==.30,"native acceptance delay must retain disabled action presentation")
popup:SetupStartDelay({StartDelay=function() return 2 end})
assert(popup.startDelay==2 and not actions[1]:IsEnabled(),"native dynamic start delay must remain")
popup:SetupStartDelay({})
assert(actions[1]:IsEnabled() and popup.startDelay==nil and popup.acceptDelay==nil,"native delay clearing must restore eligibility")
popup:SetupExtraButton({extraButton="Native long extra action"})
assert(popup.ExtraButton:IsShown() and popup.Separator:IsShown() and popup.ExtraButton.nativeWidth==220 and padding==15
 and popup.ExtraButton.Text:GetFont()~="native-action-reset","native extra-action width/padding/caption must retain QUI font")
popup:SetupExtraButton({})
assert(not popup.ExtraButton:IsShown() and not popup.Separator:IsShown(),"native extra-action reuse must hide separator")
popup:SetupAlertIcon({showAlertGear=true},{})
assert(popup.AlertIcon:IsShown() and popup.AlertIcon.texture==[[Interface\DialogFrame\UI-Dialog-Icon-AlertOther]],
 "native gear warning art must remain")
popup:SetupAlertIcon({customAlertIcon="native-custom-atlas",alertIconIsAtlas=true},{})
assert(popup.AlertIcon.atlas=="native-custom-atlas","native custom alert atlas must remain")
popup:SetupAlertIcon({}, {})
assert(not popup.AlertIcon:IsShown(),"native no-alert reuse must hide warning art")
local callbacks=0
popup:SetupItemFrame({hasItemFrame=true},{itemFrameOnEnter=function() callbacks=callbacks+1 end,
 itemFrameCallback=function(f) f:DisplayInfoFromStandardCallback({slot=4},"Callback item",2,2) end})
assert(itemFrame:IsShown() and itemFrame.Text:GetText()=="Callback item" and button.Count:GetText()=="2",
 "native caller item callback must retain content")
itemFrame:Fire("OnEnter")
assert(callbacks==1,"native setup must retain caller tooltip callback")
popup:SetupItemFrame({hasItemFrame=false},{})
assert(not itemFrame:IsShown() and itemFrame.itemID==nil,"native item reuse must hide frame and clear pending identity")
actions[1].Flash:SetAlpha(.61)
_G.QUI_RefreshSystemPopupSkins()
assert(actions[1].Flash:GetAlpha()==.61 and barMasks==5 and writes==0,
 "theme refresh must preserve pulse phase reuse masks and invoke no action")
print("static popup action lifecycle passed")
