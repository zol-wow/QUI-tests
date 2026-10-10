local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true;env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local popup=frame()
popup.which="AUDIT_EDIT"
popup.data={native=true}
_G.StaticPopup1=popup;_G.STATICPOPUP_NUMDIALOGS=1
local edit=frame("EditBox",popup)
popup.EditBox=edit;edit.baseWidth=130
edit.Instructions=edit:CreateFontString()
edit.Instructions:SetTextColor(.35,.35,.35,1)
edit.Background=edit:CreateTexture()
function popup:GetEditBox() return edit end
function edit:SetMaxLetters(value) self.nativeMax=value end
function edit:SetCountInvisibleLetters(value) self.nativeInvisible=value end
function edit:SetDesiredWidth(value) self.nativeWidth=value end
function edit:SetSecureText(value) self.nativeSecure=value end
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a");file:close()
_G.GameDialogMixin={}
assert(loadstring(assert(source:match("(function GameDialogMixin:SetupEditBox.-)\nfunction ")),"@native-static-editbox-setup"))()
popup.SetupEditBox=_G.GameDialogMixin.SetupEditBox
_G.CreateFromMixins=function(base)
 local result={};for k,v in pairs(base) do result[k]=v end;return result
end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_StaticPopup/SharedTemplates.lua"))()
local mixin=_G.StaticPopupEditBoxMixin
for k,v in pairs(mixin) do edit[k]=v end
edit:SetOwningDialog(popup)
local autocompleteSource,autocompleteArgs,consume=nil,nil,false
_G.AutoCompleteEditBox_SetAutoCompleteSource=function(_,value,...)
 autocompleteSource=value;autocompleteArgs={...}
end
_G.AutoCompleteEditBox_OnEnterPressed=function() return consume end
_G.AutoCompleteEditBox_OnTextChanged=function() return consume end
local enters,changes,escapes=0,0,0
_G.StaticPopupDialogs={AUDIT_EDIT={
 EditBoxOnEnterPressed=function(self,data) assert(self==edit and data==popup.data);enters=enters+1 end,
 EditBoxOnTextChanged=function(self,data) assert(self==edit and data==popup.data);changes=changes+1 end,
 EditBoxOnEscapePressed=function(self,data) assert(self==edit and data==popup.data);escapes=escapes+1 end}}
edit:SetScript("OnEnterPressed",mixin.OnEnterPressed)
edit:SetScript("OnEscapePressed",mixin.OnEscapePressed)
edit:SetScript("OnTextChanged",mixin.OnTextChanged)
local function setup()
 popup:SetupEditBox({hasEditBox=true,editBoxInstructions="Native instructions",maxLetters=32,
 countInvisibleLetters=true,editBoxWidth=350,editBoxSecureText=true,
 autoCompleteSource="native-source",autoCompleteArgs={"native-arg"}})
end
setup()
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile("modules/skinning/system/popups.lua"))("QUI",ns)
assert(skin.GetBackdrop(edit)._quiRoundedSurface and edit.Background:GetAlpha()==0,
 "editbox must retain existing rounded QUI chrome")
assert(edit.nativeMax==32 and edit.nativeInvisible and edit.nativeWidth==350 and edit.nativeSecure
 and autocompleteSource=="native-source" and autocompleteArgs[1]=="native-arg",
 "native setup must retain input limits width secure flag and autocomplete")
assert(edit.Instructions:GetText()=="Native instructions" and edit.Instructions.textColor[1]==.35,
 "placeholder caption and disabled semantic color must remain")
edit:SetText("")
edit:Fire("OnTextChanged",true)
assert(edit.Instructions:IsShown() and changes==1,"native empty placeholder and handler must remain")
edit:SetText("Audit text")
consume=true
edit:Fire("OnTextChanged",true);edit:Fire("OnEnterPressed")
assert(not edit.Instructions:IsShown() and enters==0 and changes==1,
 "autocomplete consuming input must suppress native confirmation and text callbacks")
consume=false
edit:Fire("OnEnterPressed");edit:Fire("OnEscapePressed")
assert(enters==1 and escapes==1,"native unconsumed Enter and Escape routing must remain")
_G.QUI_RefreshSystemPopupSkins()
assert(edit:GetText()=="Audit text" and edit.nativeSecure and edit.nativeWidth==350
 and enters==1 and escapes==1 and changes==1,"theme refresh must not mutate input or invoke dialog callbacks")
edit:OnAttributeChanged("unrelated")
assert(edit:GetText()=="Audit text" and edit.nativeSecure,"unrelated native attribute must preserve secure text")
edit:OnAttributeChanged("clear-editbox")
assert(edit:GetText()=="" and edit.nativeSecure==false,"native clear attribute must clear secure state")
popup:SetupEditBox({hasEditBox=true})
assert(edit:IsShown() and edit.nativeWidth==130 and not edit.hasAutoComplete and autocompleteSource==nil
 and edit.Instructions:GetText()=="","plain reuse must restore native width and remove autocomplete and instructions")
popup:SetupEditBox({hasEditBox=false})
_G.QUI_RefreshSystemPopupSkins()
assert(not edit:IsShown() and edit:GetScript("OnEnterPressed")==mixin.OnEnterPressed
 and edit:GetScript("OnEscapePressed")==mixin.OnEscapePressed
 and edit:GetScript("OnTextChanged")==mixin.OnTextChanged,"hidden reuse must retain native visibility and script ownership")
print("static popup editbox lifecycle passed")
