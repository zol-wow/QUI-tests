local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local payment=frame(nil,form);form.PaymentContainer=payment
payment.ListOrderButton=false;payment.CancelOrderButton=false;payment.DurationDropdown=false
local note=frame(nil,payment);payment.NoteEditBox=note
note.SetFont=false;note.GetFont=false;note.SetFontObject=false
note.Border=note:CreateTexture();note.Border:SetAtlas("CraftingOrders-NoteFrameNarrow")
note.TitleBox=frame(nil,note);note.TitleBox.Title=note.TitleBox:CreateFontString()
note.TitleBox.Title:SetText("Native note title")
local scrolling=frame(nil,note);note.ScrollingEditBox=scrolling
scrolling.ScrollBox=frame(nil,scrolling)
local edit=frame("EditBox",scrolling.ScrollBox);scrolling.ScrollBox.EditBox=edit
edit.fontName="NativeInput";edit.defaultFontName="NativePlaceholder";edit.defaultText="Native optional message"
edit.defaultTextEnabled=true;edit.focused=false
function edit:ExpectedHasFocus() return self.focused end
function edit:SetEnabled(enabled) self.enabled=enabled end
function edit:SetTextColor(...) self.displayColor={...} end
function edit:SetCursorPosition(value) self.cursor=value end
function edit:SetFont(path,size,flags) self.font=path;self.fontSize=size;self.fontFlags=flags end
function edit:GetFont() return self.font,self.fontSize,self.fontFlags end
function edit:SetFontObject(name) self:SetFont(name,14,"") end
_G.DISABLED_FONT_COLOR={GetRGB=function() return .4,.4,.4 end}
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
_G.EventEditBoxMixin={}
local native=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Frame/EventEditBox.lua")
for _,key in ipairs({"ApplyText","SetDefaultTextEnabled","IsDefaultTextEnabled","ShouldDefault","TryApplyDefaultText","GetInputText","IsDefaultTextDisplayed","ApplyTextColor","ApplyDefaultTextColor"}) do
 assert(loadstring(assert(native:match("(function EventEditBoxMixin:"..key.."%b().-\nend)")),"@native-note-input-"..key))()
 edit[key]=_G.EventEditBoxMixin[key]
end
_G.ScrollingEditBoxMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua")
for _,key in ipairs({"GetScrollBox","GetEditBox","SetText","GetText","GetInputText","SetDefaultTextEnabled","SetEnabled","OnShow"}) do
 assert(loadstring(assert(native:match("(function ScrollingEditBoxMixin:"..key.."%b().-\nend)")),"@native-order-note-"..key))()
 scrolling[key]=_G.ScrollingEditBoxMixin[key]
end
local updates=0
function scrolling:UpdateScrollBox() updates=updates+1 end
scrolling:SetText("")
local textChanged=function() error("note text callback invoked by styling") end
edit:SetScript("OnTextChanged",textChanged)
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local expected=ns.Helpers.GetGeneralFont()
assert(edit:GetFont()==expected,"actual nested note input must receive QUI font")
assert(not skin.GetFrameData(note,"skinFont") and skin.GetBackdrop(note)._quiRoundedSurface
 and not skin.GetBackdrop(edit) and note.Border:GetAlpha()==0,
 "note must have a single wrapper shell without styling wrapper fonts or adding nested border")
assert(edit:IsDefaultTextDisplayed() and edit:GetText()=="Native optional message" and scrolling:GetInputText()==""
 and edit.displayColor[1]==.4 and updates==1,"placeholder semantics and native gray color must remain")
scrolling:SetText("Native first line\nNative second line")
assert(scrolling:GetInputText()=="Native first line\nNative second line" and edit:GetFont()==expected
 and edit.displayColor[1]==1 and edit.cursor==0,"native multiline content/font reset/color/cursor must remain")
local inputText=scrolling:GetInputText()
local count=updates
_G.QUI_RefreshCraftingOrdersColors()
assert(scrolling:GetInputText()==inputText and updates==count and edit:GetScript("OnTextChanged")==textChanged,
 "theme must preserve input text, scrolling updates and native callback ownership")
scrolling:SetDefaultTextEnabled(false);scrolling:SetText("");scrolling:SetEnabled(false)
assert(not edit:IsDefaultTextDisplayed() and edit:GetText()=="" and not edit.enabled,
 "native committed empty note must disable placeholder and input")
note:Hide();_G.QUI_RefreshCraftingOrdersColors()
assert(not note:IsShown() and not edit.enabled and edit:GetFont()==expected,
 "theme must preserve native disabled/hidden note state")
note:Show();scrolling:SetDefaultTextEnabled(true);scrolling:SetEnabled(true);scrolling:SetText("")
assert(edit:IsDefaultTextDisplayed() and edit.displayColor[1]==.4 and edit:GetFont()==expected,
 "reused uncommitted empty note must restore native gray placeholder with QUI font")
local warning={GetRGB=function() return 1,.1,.1 end}
edit:ApplyDefaultTextColor(warning);_G.QUI_RefreshCraftingOrdersColors()
assert(edit.displayColor[2]==.1,"native non-default placeholder color must survive font-only styling")
assert(note.TitleBox.Title:GetText()=="Native note title" and note.TitleBox.Title.textColor[1]==.9,
 "native title text must retain neutral QUI typography")
print("craftingorders nested note input passed")
