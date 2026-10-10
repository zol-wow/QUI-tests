local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinTrainer=true
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
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_TrainerUI" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinTrainer" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
_G.ClassTrainerFrame_InitServiceButton(first,{skillIndex=1,playerMoney=50,isTradeSkill=true})
assert(first.money.digits:GetFont()~="native-money-font","trainer row cost must receive QUI typography")
assert(not action.enabled and first.money.nativeColor=="red" and first.money.digits.textColor[2]==.1
 and first.money.nativeAmount==100,"unaffordable service must retain native cost and disabled train action")
assert(first.subText:GetText():find("|cffff0000",1,true) and first.icon.texture=="native-icon-1",
 "native unmet requirement colors and identifying art must remain")
assert(skin.GetBackdrop(first)._quiBorderR==skin.GetSkinColors() and first.selectedTex:IsShown(),
 "selected service must retain native selected state and QUI accent")
_G.ClassTrainerFrame_InitServiceButton(first,{skillIndex=1,playerMoney=500,isTradeSkill=true})
assert(action.enabled and first.money.digits.textColor[2]==1,"affordable reuse must retain native enable and white amount")
trainer.selectedService=2
_G.ClassTrainerFrame_InitServiceButton(first,{skillIndex=1,playerMoney=500,isTradeSkill=false})
_G.ClassTrainerFrame_InitServiceButton(second,{skillIndex=2,playerMoney=500,isTradeSkill=false})
assert(not first.selectedTex:IsShown() and second.selectedTex:IsShown()
 and skin.GetBackdrop(first)._quiBorderA==select(4,skin.GetWindowColors())*.5,"reused row must clear stale selected accent")
serviceType="unavailable"
_G.ClassTrainerFrame_InitServiceButton(second,{skillIndex=2,playerMoney=500,isTradeSkill=false})
assert(second.icon.nativeDesaturated and second.disabledBG:IsShown() and not action.enabled,
 "unavailable service feedback must remain native")
serviceType="used"
_G.ClassTrainerFrame_InitServiceButton(second,{skillIndex=2,playerMoney=500,isTradeSkill=false})
assert(not second.money:IsShown() and second.money:GetWidth()==1 and second.subText:GetText()=="Native known",
 "known service must retain native hidden cost and known caption")
serviceType="available"; isProfession=true; fullSlots=true
trainer.selectedService=3
_G.ClassTrainerFrame_InitServiceButton(step,{skillIndex=3,playerMoney=500,isTradeSkill=true})
assert(not action.enabled and trainer.showDialog and step.selectedTex:IsShown(),
 "profession-slot limit must retain native train eligibility and confirmation flag")
skin.SetBackdropColors(skin.GetBackdrop(step),{.91,.32,.43,1},nil)
skin.SetBackdropColors(skin.GetBackdrop(second),{.91,.32,.43,1},nil)
refresh()
assert(skin.GetBackdrop(step)._quiBorderR==skin.GetSkinColors()
 and skin.GetBackdrop(second)._quiBorderR~=.91,"theme refresh must reach list and profession-step rows")
assert(masks==3 and action:GetScript("OnClick")==buy and writes==0,
 "theme/native reuse must preserve single masks and train handler without buying a service")
env.profile.general.skinTrainer=false
local untouched=row()
_G.ClassTrainerFrame_InitServiceButton(untouched,{skillIndex=4,playerMoney=500,isTradeSkill=false})
assert(masks==3 and untouched.money.digits:GetFont()=="native-money-font","disabled Trainer skin must leave new rows native")
print("trainer surfaces passed")
