local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinMail=true
local function button()
 local b=env.NewFrame("Button");b.RegisterForWidgetSet=false;b.DisabledTexture=false
 b.Icon=b:CreateTexture();b.IconBorder=b:CreateTexture();b.IconBorder:SetVertexColor(.2,.7,.3,1)
 b.IconOverlay=b:CreateTexture();b.IconOverlay2=b:CreateTexture()
 b.SetItemButtonQuality=false;b.SetItemButtonBorder=false;b.SetItemButtonBorderVertexColor=false
 function b.IconBorder:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
 function b:GetNormalTexture() return nil end
 function b:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
 return b
end
local b=button();_G.SendMailAttachment1=b
local updates={0,0,0}
_G.InboxFrame_Update=function() updates[1]=updates[1]+1 end
_G.SendMailFrame_Update=function() updates[2]=updates[2]+1 end
_G.OpenMail_Update=function() updates[3]=updates[3]+1 end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua"))
local native=f:read("*a");f:close()
local methods={}
for _,key in ipairs({"SetItemButtonBorderVertexColor_Base","SetItemButtonBorderVertexColor",
 "SetItemButtonBorder_Base","SetItemButtonBorder","SetItemButtonQuality_Base","SetItemButtonQuality"}) do
 local prefix=key:sub(-5)=="_Base" and "local " or ""
 methods[#methods+1]=prefix..assert(native:match("(function "..key.."%b().-\nend)"))
end
local clears=0
_G.ClearItemButtonOverlay=function() clears=clears+1 end
_G.ColorManager={GetColorDataForBagItemQuality=function(quality)
 if quality==4 then return {r=.6,g=.2,b=.8} end
 if quality==2 then return {r=.2,g=.7,b=.3} end
end}
assert(loadstring(table.concat(methods,"\n")))()
_G.SetItemButtonQuality(b,4,nil,true)
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/mail.lua"))("QUI",ns)
local bd=assert(skin.GetBackdrop(b))
assert(b.IconBorder:GetAlpha()==0 and bd._quiBorderR==.6 and bd._quiBorderB==.8,
 "mail rounded border must replace native square quality art and retain initial color")
local n=clears;_G.QUI_RefreshMailColors()
assert(bd._quiBorderR==.6 and bd._quiBorderB==.8 and clears==n,"theme must retain quality without native quality updates")
_G.SetItemButtonQuality(b,2,nil,true)
assert(bd._quiBorderG==.7 and b.IconBorder:IsShown(),"native quality reuse must update rounded border")
b.IconBorder:SetVertexColor(.5,.5,.5,1)
assert(bd._quiBorderR==.5,"native read-mail dimmed border must remain")
_G.SetItemButtonQuality(b,nil,nil,true)
local r,g,blue=skin.GetWindowColors()
assert(not b.IconBorder:IsShown() and bd._quiBorderR==r and bd._quiBorderG==g and bd._quiBorderB==blue,
 "native clear must reset rounded border to current neutral chrome")
b.IconBorder:SetVertexColor(.6,.2,.8,1);b.IconBorder:Show()
assert(bd._quiBorderB==.8,"native border show must restore cached color")
b.IconBorder:SetAlpha(.9)
assert(b.IconBorder:GetAlpha()==0,"native decoration opacity reset must remain suppressed")
env.profile.general.skinMail=false
local fresh=button();_G.SendMailAttachment2=fresh
_G.MailItem1=env.NewFrame("Frame");local inbox=button();_G.MailItem1Button=inbox
_G.OpenMailAttachmentButton1=button()
local before=clears
_G.InboxFrame_Update();_G.SendMailFrame_Update();_G.OpenMail_Update()
assert(not skin.GetBackdrop(fresh) and not skin.GetBackdrop(inbox)
 and not skin.GetBackdrop(_G.OpenMailAttachmentButton1),"disabled mail skin hooks must leave new controls untouched")
assert(updates[1]==1 and updates[2]==1 and updates[3]==1 and clears==before,
 "native refresh functions must still run once without quality actions")
print("mail quality refresh passed")
