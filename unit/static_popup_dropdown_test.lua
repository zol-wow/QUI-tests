local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true;env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local popup=frame()
_G.StaticPopup1=popup;_G.STATICPOPUP_NUMDIALOGS=1
local dropdown=frame("Button",popup)
popup.Dropdown=dropdown
dropdown:SetFrameLevel(25)
dropdown.Arrow=dropdown:CreateTexture()
dropdown.Text=dropdown:CreateFontString()
dropdown.Text:SetText("Native option")
function dropdown:GetFontString() return self.Text end
local menu,callbacks=nil,0
function dropdown:SetupMenu(builder) menu=builder end
local click=function() end
dropdown:SetScript("OnClick",click)
local actions={frame("Button",popup),frame("Button",popup)}
function popup:GetButton(i) return actions[i] end
function popup:GetButton1() return actions[1] end
function popup:GetButton2() return actions[2] end
function popup:SetText(value) self.nativeText=value end
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a");file:close()
_G.GameDialogMixin={}
assert(loadstring(assert(source:match("(function GameDialogMixin:SetupDropdown.-)\nfunction ")),"@native-static-dropdown-setup"))()
popup.SetupDropdown=_G.GameDialogMixin.SetupDropdown
file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua"))
source=file:read("*a");file:close()
_G.StaticPopupDialogs={};_G.ACCEPT="Accept";_G.CANCEL="Cancel"
local definition=assert(source:match('(StaticPopupDialogs%["GENERIC_DROP_DOWN"%] = .-)\n\nStaticPopupDialogs'))
assert(loadstring(definition,"@native-generic-dropdown-definition"))()
popup:SetupDropdown({hasDropdown=true})
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
local backdrop=skin.GetBackdrop(dropdown)
assert(backdrop and backdrop._quiRoundedSurface and skin.GetFrameData(dropdown,"dropdownCaret"),
 "static dropdown must receive rounded chrome and QUI caret")
assert(dropdown.Arrow:GetAlpha()==0 and backdrop:GetFrameLevel()<dropdown:GetFrameLevel(),
 "native arrow art must be replaced with chrome below the control")
local options={{text="First",value=1},{text="Second",value=2}}
local data={text="Native prompt",requiresConfirmation=true,defaultOption=1,options=options,
 callback=function() callbacks=callbacks+1 end}
local def=_G.StaticPopupDialogs.GENERIC_DROP_DOWN
def.OnShow(popup,data)
local radios={}
local root={CreateRadio=function(_,text,selected,choose,value)
 radios[#radios+1]={text=text,selected=selected,choose=choose,value=value}
end}
menu(dropdown,root)
assert(popup.nativeText=="Native prompt" and #radios==2 and radios[1].selected(1) and not radios[2].selected(2),
 "native menu builder and default selection must remain")
radios[2].choose(2)
assert(popup.selection==2 and callbacks==0 and actions[1]:IsShown() and actions[2]:IsShown(),
 "confirmation selection must remain native without accepting")
skin.SetBackdropColors(backdrop,{.91,.32,.43,1},nil)
popup:SetupDropdown({hasDropdown=false})
assert(not dropdown:IsShown() and backdrop._quiBorderR~=.91,
 "native hidden reuse must retain visibility and refresh theme")
popup:SetupDropdown({hasDropdown=true})
assert(dropdown:IsShown() and skin.GetBackdrop(dropdown)==backdrop and dropdown:GetScript("OnClick")==click,
 "native visible reuse must retain shell and click ownership")
data.requiresConfirmation=false
def.OnShow(popup,data)
assert(not actions[1]:IsShown() and not actions[2]:IsShown() and callbacks==0,
 "immediate-selection native action visibility must remain without invoking callback")
_G.QUI_RefreshSystemPopupSkins()
assert(callbacks==0 and skin.GetBackdrop(dropdown)==backdrop and dropdown.Text:GetText()=="Native option",
 "theme refresh must retain caption and invoke no selection or acceptance")
env.profile.general.skinStaticPopups=false
local fresh=frame("Button",popup);popup.Dropdown=fresh
popup:SetupDropdown({hasDropdown=true})
assert(fresh:IsShown() and not skin.GetBackdrop(fresh),"disabled skin must leave fresh native dropdown untouched")
print("static popup dropdown passed")
