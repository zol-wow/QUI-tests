local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
_G.InCombatLockdown=function() return true end
assert(loadfile("core/uikit.lua"))("QUI",env.ns)
local skin,ns=env.ns.SkinBase,env.ns
env.profile.general.skinMail=true
local function frame(name) local f=env.NewFrame(name:find("PageButton") and "Button" or "Frame",name);_G[name]=f;f.DisabledTexture=false;f.RegisterForWidgetSet=false;return f end
local function label(f) local t=f:CreateFontString();t:SetFont("Native",12,"");t:SetTextColor(1,.82,0,1);return t end
local mail=frame("MailFrame");mail.TitleContainer={TitleText=label(mail)}
local open=frame("OpenMailFrame");open.TitleContainer={TitleText=label(open)}
local prev=frame("InboxPrevPageButton");local prevText=label(prev)
local next=frame("InboxNextPageButton");local nextText=label(next)
local click=function() error("mail action invoked") end
prev:SetScript("OnClick",click);next:SetScript("OnClick",click)
local labels={}
for _,name in ipairs({"SendMailNameEditBox","SendMailSubjectEditBox","SendMailCostMoneyFrame"}) do labels[#labels+1]=label(frame(name)) end
_G.SendMailMoneyText=label(frame("MoneyLabelOwner"))
local bars={}
for _,name in ipairs({"SendMailScrollFrame","OpenMailScrollFrame"}) do
 local f=frame(name);local b=env.NewFrame("Slider",nil,f);f.ScrollBar=b;bars[#bars+1]=b
 b.ThumbTexture=b:CreateTexture();b.ScrollUpButton=env.NewFrame("Button",nil,b);b.ScrollDownButton=env.NewFrame("Button",nil,b)
end
_G.SendMailBodyEditBox=env.NewFrame("EditBox",nil,_G.SendMailScrollFrame)
_G.SendMailBodyEditBox.RegisterForWidgetSet=false
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/mail.lua"))("QUI",ns)
for _,t in ipairs({mail.TitleContainer.TitleText,open.TitleContainer.TitleText,prevText,nextText,unpack(labels)}) do
 local r,g,b=t:GetTextColor();assert(r==g and g==b,"mail chrome must use neutral text")
end
for _,b in ipairs(bars) do assert(b.ScrollUpButton:GetAlpha()==0 and b.ScrollDownButton:GetAlpha()==0,"mail native arrows must be trimmed") end
assert(skin.GetBackdrop(_G.SendMailScrollFrame) and not skin.GetBackdrop(_G.SendMailBodyEditBox),"body chrome must surround fixed viewport instead of growing text")
assert(prev:GetScript("OnClick")==click and next:GetScript("OnClick")==click,"native paging handlers must stay unchanged")
env.profile.general.skinMail=false;prevText:SetTextColor(1,.82,0,1);_G.QUI_RefreshMailColors()
assert(select(2,prevText:GetTextColor())==.82,"disabled skin must leave mail labels unchanged")
print("mail chrome controls passed")
