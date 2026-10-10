local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local progress=frame();_G.AuctionHouseMultisellProgressFrame=progress
progress:SetSize(300,64);progress:SetAlpha(.4);progress:Hide()
for _,key in ipairs({"Fill","Left","Middle","Right"}) do progress[key]=progress:CreateTexture() end
local bar=frame("StatusBar",progress);progress.ProgressBar=bar
bar:SetSize(195,11);bar:SetPoint("CENTER",progress,"CENTER",3,5)
local fill=bar:CreateTexture();fill:SetAtlas("ui-castingbar-filling-standard")
function bar:GetStatusBarTexture() return fill end
function bar:SetStatusBarTexture(value) fill:SetTexture(value) end
local value,min,max,color=0,0,0,{.2,.7,.5,1}
function bar:SetMinMaxValues(a,b) min,max=a,b end
function bar:SetValue(v) value=v end
function bar:SetStatusBarColor(...) color={...} end
bar.Icon=bar:CreateTexture();bar.Icon:SetSize(24,24);bar.Icon:SetPoint("RIGHT",bar,"LEFT",-10,-6)
bar.Text=bar:CreateFontString();bar.Text:SetTextColor(.3,.8,.5,1)
function bar.Text:SetFormattedText(format,...) self:SetText(string.format(format,...)) end
for _,key in ipairs({"Border","TextBorder","Background","DropShadow","Spark","Flash"}) do bar[key]=bar:CreateTexture() end
bar.Spark:Hide();bar.Flash:Hide()
local masks=0
function bar:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
function fill:AddMaskTexture() masks=masks+1 end
function bar.Icon:AddMaskTexture() masks=masks+1 end
local cancel=frame("Button",progress);progress.CancelButton=cancel
cancel:SetSize(32,32);cancel:SetPoint("LEFT",bar,"RIGHT",2,-7)
local normal=cancel:CreateTexture()
function cancel:GetNormalTexture() return normal end
function cancel:GetPushedTexture() return nil end
function cancel:GetHighlightTexture() return nil end
function cancel:GetDisabledTexture() return nil end
local cancelClick=function() error("auction cancellation invoked") end
cancel:SetScript("OnClick",cancelClick)
local idleUpdate=function() error("idle update invoked") end
progress:SetScript("OnUpdate",idleUpdate)
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseMultisell.lua"))
assert(loadstring(f:read("*a"),"@native-ah-multisell"))();f:close()
progress.Start=_G.MultisellProgressFrameMixin.Start
progress.Refresh=_G.MultisellProgressFrameMixin.Refresh
_G.AUCTION_CREATING="Native creating %d/%d"
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(progress.Fill:GetAlpha()==0 and progress.Left:GetAlpha()==0 and skin.GetBackdrop(progress)._quiRoundedSurface,
 "multisell native decoration must receive rounded QUI shell")
assert(not progress:IsShown() and progress:GetAlpha()==.4 and progress:GetScript("OnUpdate")==idleUpdate,
 "initial styling must not open multisell display or change native opacity/update ownership")
progress:Start("native-item-one",5)
assert(min==0 and max==5 and value==.01 and bar.Text:GetText()=="Native creating 0/5"
 and bar.Icon.texture=="native-item-one" and progress:GetAlpha()==1 and progress:GetScript("OnUpdate")==nil,
 "native Start must retain icon, initial value/count and fade reset")
assert(fill.texture==[[Interface\Buttons\WHITE8x8]] and masks==2 and color[2]==.7
 and bar.Text.textColor[2]==.8 and not bar.Spark:IsShown() and not bar.Flash:IsShown(),
 "QUI progress styling must retain native colors, hidden effects and single masks")
progress:Refresh(2,5)
assert(value==2 and bar.Text:GetText()=="Native creating 2/5" and progress:GetScript("OnUpdate")==nil,
 "native progress update must retain partial count without starting fade")
progress:Refresh(5,5)
local fade=progress:GetScript("OnUpdate")
assert(type(fade)=="function" and value==5 and bar.Text:GetText()=="Native creating 5/5",
 "native completion must retain its fade update")
fade(progress)
local alpha=progress:GetAlpha()
_G.QUI_RefreshAuctionHouseColors()
assert(progress:GetAlpha()==alpha and progress:GetScript("OnUpdate")==fade and masks==2
 and cancel:GetScript("OnClick")==cancelClick and normal:GetAlpha()==0,
 "theme must preserve native fade and cancel ownership without duplicate masks")
for _=1,30 do local fn=progress:GetScript("OnUpdate");if fn then fn(progress) end end
assert(progress:GetScript("OnUpdate")==nil and progress:GetAlpha()>0 and progress:GetAlpha()<=.05,
 "native fade completion must retain its exact final alpha and update cleanup")
progress:Start("native-item-two",3)
assert(progress:GetAlpha()==1 and progress:GetScript("OnUpdate")==nil and value==.01 and max==3
 and bar.Icon.texture=="native-item-two" and masks==2,"restart must retain native reset and reuse masks")
assert(cancel:GetWidth()==32 and bar:GetWidth()==195 and progress:GetWidth()==300
 and skin.GetFrameData(cancel,"closeLabel"):GetText()=="X","native frame/control dimensions and QUI cancel glyph must remain")
print("auctionhouse multisell progress passed")
