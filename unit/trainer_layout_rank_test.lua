local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinTrainer=true
ns.Helpers.GetSkinBarColor=function() return .2,.8,.6,1 end
_G.UIPanelWindows,_G.StaticPopupDialogs={},{}
_G.EnumUtil={MakeEnum=function(...) local t={}; for i,v in ipairs({...}) do t[v]=i end; return t end}
_G.format=string.format
_G.PROFESSION_CONFIRMATION1="%s"
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua"))()
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false; f.DisabledTexture=false
 return f
end
local trainer=frame()
_G.ClassTrainerFrame=trainer
trainer.selectedService=1
trainer.FilterDropdown=frame("DropdownButton",trainer)
trainer.ScrollBox=frame(nil,trainer)
trainer.ScrollBar=frame("Slider",trainer)
trainer.ScrollBar.ThumbTexture=trainer.ScrollBar:CreateTexture()
trainer.bottomInset=frame(nil,trainer)
trainer.BG=trainer:CreateTexture()
local action=frame("Button",trainer)
_G.ClassTrainerTrainButton=action
action.Text=action:CreateFontString()
function action:SetEnabled(value) self.enabled=value end
local writes=0
local buy=function() writes=writes+1 end
action:SetScript("OnClick",buy)
local masks=0
local function row()
 local r=frame("Button",trainer)
 r.icon,r.lock,r.disabledBG,r.selectedTex,r.art=r:CreateTexture(),r:CreateTexture(),r:CreateTexture(),r:CreateTexture(),r:CreateTexture()
 r.name,r.subText=r:CreateFontString(),r:CreateFontString()
 r.money=frame(nil,r); r.money.digits=r.money:CreateFontString()
 r.money.digits:SetFont("native-money-font",10,"")
 r.lock:Hide(); r.disabledBG:Hide(); r.selectedTex:Hide()
 function r.icon:SetDesaturated(value) self.nativeDesaturated=value end
 function r:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
 function r.icon:AddMaskTexture() masks=masks+1 end
 r:SetScript("OnClick",function() error("audit must not select trainer service") end)
 return r
end
local first,second,step=row(),row(),row()
trainer.skillStepButton=step
function trainer.ScrollBox:ForEachFrame(fn) fn(first); fn(second) end
_G.ClassTrainerFrameMoneyFrame=frame(nil,trainer)
_G.ClassTrainerFrameMoneyFrame.digits=_G.ClassTrainerFrameMoneyFrame:CreateFontString()
local serviceType,cost,isProfession,fullSlots="available",100,false,false
_G.GetTrainerServiceInfo=function(index) return "Native service "..index,serviceType,"native-icon-"..index,20 end
_G.UnitLevel=function() return 10 end
_G.GetTrainerServiceSkillReq=function() return "Native craft",5,false end
_G.GetTrainerServiceNumAbilityReq=function() return 1 end
_G.GetTrainerServiceAbilityReq=function() return "Native ability",false end
_G.GetTrainerServiceCost=function() return cost,isProfession end
_G.GetProfessions=function() return 1,fullSlots and 2 or nil end
_G.TRAINER_REQ_LEVEL="%d"; _G.TRAINER_REQ_LEVEL_RED="|cffff0000Level %d|r"
_G.TRAINER_REQ_SKILL_RANK="%s %d"; _G.TRAINER_REQ_SKILL_RANK_RED="|cffff0000%s %d|r"
_G.TRAINER_REQ_ABILITY="%s"; _G.TRAINER_REQ_ABILITY_RED="|cffff0000%s|r"
_G.PLAYER_LIST_DELIMITER=", "; _G.REQUIRES_LABEL="Requires"; _G.ITEM_SPELL_KNOWN="Native known"
_G.GRAY_FONT_COLOR_CODE="|cff808080"; _G.FONT_COLOR_CODE_CLOSE="|r"
_G.MoneyFrame_Update=function(f,value) f.nativeAmount=value; f.digits:SetText(tostring(value)) end
_G.SetMoneyFrameColorByFrame=function(f,value) f.nativeColor=value; f.digits:SetTextColor(1,value=="red" and .1 or 1,value=="red" and .1 or 1,1) end

trainer.Inset=frame(nil,trainer)
local bar=frame("StatusBar",trainer)
_G.ClassTrainerStatusBar=bar
bar.fill=bar:CreateTexture()
bar.nativeColor={0,0,1,.5}
function bar:GetStatusBarColor() return unpack(self.nativeColor) end
function bar:SetStatusBarColor(r,g,b,a) self.nativeColor={r,g,b,a} end
function bar:SetStatusBarTexture(value) self.fill:SetTexture(value) end
function bar:GetStatusBarTexture() return self.fill end
function bar:SetMinMaxValues(lo,hi) self.minimum,self.maximum=lo,hi end
function bar:SetValue(value) self.value=value end
bar.rankText=bar:CreateFontString()
function bar.rankText:SetFormattedText(pattern,...) self:SetText(string.format(pattern,...)) end
local barMasks=0
function bar:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
function bar.fill:AddMaskTexture() barMasks=barMasks+1 end
for _,suffix in ipairs({"Left","Right","Middle","Background"}) do
 _G["ClassTrainerStatusBar"..suffix]=bar:CreateTexture()
end
_G.TRADESKILL_RANK_WITH_MODIFIER="%d (+%d) / %d"
_G.TRADESKILL_RANK="%d / %d"
_G.PANEL_INSET_RIGHT_OFFSET,_G.PANEL_INSET_ATTIC_OFFSET,_G.PANEL_INSET_BOTTOM_BUTTON_OFFSET=-4,-24,26
local stepIndex,rank,maxRank,modifier=3,40,75,5
local providers=0
_G.GetNumTrainerServices=function() return 3 end
_G.GetMoney=function() return 500 end
_G.IsTradeskillTrainer=function() return true end
_G.GetTrainerServiceStepIndex=function() return stepIndex end
_G.GetTrainerTradeskillRankValues=function() return rank,maxRank,modifier end
_G.CreateDataProvider=function()
 providers=providers+1
 return {data={},Insert=function(self,item) self.data[#self.data+1]=item end}
end
function trainer.ScrollBox:SetDataProvider(provider,retain)
 self.provider,self.retain=provider,retain
 _G.ClassTrainerFrame_InitServiceButton(first,provider.data[1])
 _G.ClassTrainerFrame_InitServiceButton(second,provider.data[2])
end
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_TrainerUI" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinTrainer" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
assert(bar.nativeColor[1]==0 and bar.nativeColor[3]==1 and bar.nativeColor[4]==.5,
 "Trainer rank bar must preserve native fill color and alpha")
assert(bar.fill:IsShown() and bar.fill:GetAlpha()==1 and barMasks==1 and skin.GetBackdrop(bar)._quiRoundedSurface
 and skin.GetBackdrop(bar):GetFrameLevel()<bar:GetFrameLevel(),"rank bar must receive one rounded fill mask and shell behind text")
for _,suffix in ipairs({"Left","Right","Middle","Background"}) do
 assert(_G["ClassTrainerStatusBar"..suffix]:GetAlpha()==0,"rank bar decoration must be suppressed")
end
_G.ClassTrainerFrame_Update(true)
assert(trainer.ScrollBox:GetHeight()==278 and trainer.bottomInset:IsShown() and step:IsShown()
 and trainer.ScrollBox.retain and #trainer.ScrollBox.provider.data==3,
 "native profession-step layout and retained provider scroll state must survive")
assert(bar:IsShown() and bar.minimum==1 and bar.maximum==75 and bar.value==40 and bar.rankText:GetText()=="40 (+5) / 75",
 "native rank values modifier caption and visibility must survive")
stepIndex=nil; modifier=0; rank=55
_G.ClassTrainerFrame_Update(false)
assert(trainer.ScrollBox:GetHeight()==330 and not trainer.bottomInset:IsShown() and not step:IsShown()
 and not trainer.ScrollBox.retain and providers==2,"native ordinary-list layout must replace provider and hide step row")
assert(bar.rankText:GetText()=="55 / 75" and bar.value==55,"native rank reuse must clear modifier caption")
rank=0
_G.ClassTrainerFrame_Update(true)
assert(not bar:IsShown() and barMasks==1,"native zero-rank state must hide bar without adding masks")
rank=nil
_G.ClassTrainerFrame_Update(true)
assert(not bar:IsShown(),"native missing rank must retain hidden bar")
rank,maxRank,modifier,stepIndex=70,100,2,3
_G.ClassTrainerFrame_Update(true)
assert(bar:IsShown() and bar.value==70 and bar.maximum==100 and bar.rankText:GetText()=="70 (+2) / 100"
 and step:IsShown() and trainer.ScrollBox:GetHeight()==278,"returning profession rank must restore native layout and text")
local count=providers
refresh()
assert(providers==count and barMasks==1 and masks==3 and action:GetScript("OnClick")==buy and writes==0,
 "theme refresh must not rebuild provider reset rank attach duplicate masks or train a service")
print("trainer layout and rank passed")
