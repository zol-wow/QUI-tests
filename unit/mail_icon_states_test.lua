local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinMail=true
local function button(kind)
 local b=env.NewFrame(kind or "Button");b.RegisterForWidgetSet=false;b.DisabledTexture=false
 b:SetSize(37,37);b.IconBorder=b:CreateTexture();b.IconOverlay=b:CreateTexture();b.IconOverlay2=b:CreateTexture()
 b.Count=b:CreateFontString();b.Count:SetTextColor(1,.1,.1,1)
 b.Highlight=b:CreateTexture();b.Highlight:Hide()
 function b:GetHighlightTexture() return self.Highlight end
 function b:GetCheckedTexture() return self.Checked end
 function b:GetNormalTexture() return self.Normal end
 b.Checked=false;b.Normal=false;b.Icon=false;b.icon=false
 function b:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
 return b
end
local inbox=button("CheckButton");inbox.Icon=inbox:CreateTexture();inbox.Checked=inbox:CreateTexture()
inbox.Checked:Hide();inbox.checked=false
function inbox:SetChecked(value) self.checked=value;self.Checked:SetShown(value) end
_G.MailItem1Button=inbox;_G.MailItem1=env.NewFrame("Frame");inbox:SetParent(_G.MailItem1)
local send=button();send.Normal=send:CreateTexture();_G.SendMailAttachment1=send
function send:SetNormalTexture(art) self.Normal:SetTexture(art) end
function send:ClearNormalTexture() self.Normal:SetTexture(nil) end
_G.SendMailFrame=env.NewFrame("Frame");_G.SendMailFrame.SendMailAttachments={send}
local open=button();open.Icon=open:CreateTexture();_G.OpenMailAttachmentButton1=open
local masks=0
for _,b in ipairs({inbox,send,open}) do
 local art=b.Icon or b.Normal
 art:SetTexture("native-art");art:SetVertexColor(1,.1,.1,1);art:SetDesaturated(true)
 for _,tex in ipairs({art,b.Highlight,b.Checked}) do
  if tex then function tex:AddMaskTexture() masks=masks+1 end end
 end
end
local click=function() error("mail action invoked") end
for _,b in ipairs({inbox,send,open}) do b:SetScript("OnClick",click);b:SetScript("OnDragStart",click) end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua"));local native=f:read("*a");f:close()
local start=assert(native:find("if ( InboxFrame.openMailID == index ) then",1,true))
local stop=assert(native:find("\n\t\telse\n\t\t\t-- Clear everything",start,true))
local selected=assert(loadstring("return function(button,index,stationeryIcon)\n"..native:sub(start,stop-1).."\nend"))()
_G.InboxFrame={openMailID=1};_G.OpenMailFrame=env.NewFrame("Frame")
function _G.OpenMailFrame:SetPortraitToAsset(art) self.portrait=art end
skin.MarkSkinned(_G.OpenMailFrame)
selected(inbox,1,"native-letter")
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/mail.lua"))("QUI",ns)
assert(inbox.Checked:GetAlpha()==1 and inbox.Checked:IsShown(),"mail selection must survive decorative texture suppression")
assert(masks==7,"inbox and attachments need one mask per item/hover/selection texture")
for _,b in ipairs({inbox,send,open}) do
 local art=b.Icon or b.Normal
 assert(art:GetAlpha()==1 and art.texture=="native-art" and art.vertex[2]==.1,
  "native item art and unusable color must remain")
 assert(b.Count.textColor[2]==.1 and b.IconBorder:GetAlpha()==0 and b.IconOverlay:GetAlpha()==1
  and b:GetScript("OnClick")==click and b:GetScript("OnDragStart")==click,"quality, overlays, count colors and action scripts must remain")
 assert(not b.Highlight:IsShown() and b:GetWidth()==37,"native hover state and hitbox size must remain")
end
selected(inbox,2,"native-letter")
assert(not inbox.Checked:IsShown() and not inbox.checked,"native letter switching must deselect icon")
local populated=true
_G.ATTACHMENTS_MAX_SEND=1
_G.HasSendMailItem=function(i) assert(i==1);return populated end
_G.GetSendMailItem=function() return "native item",123,"new-art",8,4 end
_G.SetItemButtonCount=function(b,count) b.Count:SetText(tostring(count)) end
_G.SetItemButtonQuality=function(b,quality) b.nativeQuality=quality;b.IconBorder:SetShown(quality~=nil) end
start=assert(native:find("local last = 0;",native:find("function SendMailFrame_Update",1,true),true))
stop=assert(native:find("\n\tif ( itemCount > 0 ) then",start,true))
local update=assert(loadstring("return function()\nlocal itemCount=0;local itemTitle;local gap;\n"..native:sub(start,stop-1).."\nend"))()
update();_G.QUI_RefreshMailColors()
assert(send.Normal.texture=="new-art" and send.nativeQuality==4 and send.Count:GetText()=="8"
 and masks==7 and not inbox.Checked:IsShown(),"native attachment update and theme must preserve state without duplicate masks")
populated=false;update();_G.QUI_RefreshMailColors()
assert(send.Normal.texture==nil and send.nativeQuality==nil and not send.IconBorder:IsShown(),
 "native cleared attachment must retain empty art and hidden quality")
inbox.IsForbidden=function() return true end
inbox.Checked:SetColorTexture(.3,.4,.5,1);_G.QUI_RefreshMailColors()
assert(inbox.Checked.color[1]==.3,"forbidden button must stop state styling")
print("mail icon states passed")
