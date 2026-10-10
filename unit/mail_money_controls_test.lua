local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinMail=true
local money=env.NewFrame("Frame");_G.SendMailMoney=money
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local native=read("tests/framexml/Interface/AddOns/Blizzard_MoneyFrame/Mainline/MoneyInputFrame.lua")
_G.MoneyFrameEditBoxMixin={}
assert(loadstring(assert(native:match("(function MoneyFrameEditBoxMixin:OnLoad%b().-\nend)"))))()
for _,key in ipairs({"MoneyInputFrame_SetCopper","MoneyInputFrame_GetCopper","MoneyInputFrame_SetTextColor",
 "MoneyInputFrame_OnShow","MoneyInputFrame_OnTextChanged"}) do
 assert(loadstring(assert(native:match("(function "..key.."%b().-\nend)"))))()
end
_G.COPPER_PER_GOLD=10000;_G.COPPER_PER_SILVER=100
_G.floor=math.floor;_G.mod=math.fmod;_G.strlen=string.len
local colorblind=false;local callbacks=0
_G.CVarCallbackRegistry={GetCVarValueBool=function(_,key) assert(key=="colorblindMode");return colorblind end}
money.onValueChangedFunc=function() callbacks=callbacks+1 end
for _,key in ipairs({"gold","silver","copper"}) do
 local field=env.NewFrame("EditBox",nil,money);money[key]=field
 field.RegisterForWidgetSet=false;field.DisabledTexture=false
 field.texture=field:CreateTexture();field.label=field:CreateFontString()
 field.coinAtlas="coin-"..key;field.coinSymbol=key:sub(1,1)
 field.label:SetFont("Native symbol",12,"");field.label:SetTextColor(.4,.5,.6,1)
 field.value="";field.font={"Native input",12,""}
 function field:SetFont(...) self.font={...} end
 function field:GetFont() return unpack(self.font) end
 function field:SetText(text) self.value=tostring(text) end
 function field:GetText() return self.value end
 function field:SetNumber(value) self:SetText(value) end
 function field:GetNumber() return tonumber(self.value) or 0 end
 function field:SetTextColor(...) self.displayColor={...} end
 function field:GetTextColor() return unpack(self.displayColor or {1,1,1,1}) end
 field:SetSize(key=="gold" and 70 or 48,20)
 _G.MoneyFrameEditBoxMixin.OnLoad(field)
 field:SetScript("OnTextChanged",_G.MoneyInputFrame_OnTextChanged)
end
_G.MoneyInputFrame_SetCopper(money,12345)
money.expectChanges=nil
_G.MoneyInputFrame_SetTextColor(money,1,.1,.1)
_G.MoneyInputFrame_OnShow(money)
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/mail.lua"))("QUI",ns)
for _,key in ipairs({"gold","silver","copper"}) do
 local field=money[key]
 assert(field.texture:GetAlpha()==1,"mail denomination coin art must survive input skin")
 assert(skin.GetBackdrop(field) and field:GetFont()==ns.Helpers.GetGeneralFont(),"money input must receive QUI chrome and font")
 assert(field.texture.atlas=="coin-"..key and field.displayColor[2]==.1
  and field.label:GetText()==key:sub(1,1),"native atlas, semantic input color and symbol must remain")
end
assert(_G.MoneyInputFrame_GetCopper(money)==12345 and callbacks==0,"styling must preserve native amount without eligibility callbacks")
local changed=money.gold:GetScript("OnTextChanged")
money.gold.darkenOnDigits=9
money.gold:SetText("123456789");changed(money.gold)
assert(callbacks==1 and money.gold.texture:GetAlpha()==.2,"native digit darkening and callback must remain")
_G.QUI_RefreshMailColors()
assert(money.gold.texture:GetAlpha()==.2 and callbacks==1 and money.gold:GetScript("OnTextChanged")==changed,
 "theme must preserve native coin opacity and callback ownership without input updates")
colorblind=true;_G.MoneyInputFrame_OnShow(money);_G.QUI_RefreshMailColors()
assert(not money.gold.texture:IsShown() and money.gold.label:IsShown()
 and money.gold.label:GetFont()==ns.Helpers.GetGeneralFont(),"colorblind native symbol visibility must remain")
money.goldOnly=true;_G.MoneyInputFrame_SetCopper(money,30000)
assert(not money.silver:IsShown() and not money.copper:IsShown(),"gold-only native hiding must remain")
_G.QUI_RefreshMailColors()
assert(not money.silver:IsShown() and not money.copper:IsShown() and callbacks==1,
 "theme must leave native hidden denominations unchanged")
money.IsForbidden=function() return true end
money.gold.texture:SetAlpha(.7);_G.QUI_RefreshMailColors()
assert(money.gold.texture:GetAlpha()==.7,"forbidden money owner must stop input styling")
print("mail money controls passed")
