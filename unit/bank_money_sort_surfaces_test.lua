local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinBank = true
_G.CreateFromMixins = function(...) local t = {}; for _, m in ipairs({...}) do for k,v in pairs(m) do t[k]=v end end; return t end
_G.CallbackRegistryMixin = {GenerateCallbackEvents = function() end}
_G.Enum = {BankType={Account=2,Character=1}}
_G.Enum.PlayerInteractionType = {Banker=1,CharacterBanker=2,AccountBanker=3}
_G.Enum.BankLockedReason={BankConversionFailed=1,BankDisabled=2,NoAccountInventoryLock=3}
_G.Enum.BagSlotFlags={ExpansionCurrent=1,ExpansionLegacy=2}
_G.StaticPopupDialogs = {}
_G.RegisterPlayerInteraction = function() end
_G.TextureKitConstants = {IgnoreAtlasSize=false}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua"))()
local function frame(kind, parent)
    local f=env.NewFrame(kind or "Frame",nil,parent)
    f.RegisterForWidgetSet=false; f.DisabledTexture=false
    return f
end

local bank=frame()
_G.BankFrame=bank
bank.BankPanel=frame(nil,bank)
local panel=bank.BankPanel
local bankType,locked,supported,withdrawAllowed,depositAllowed=Enum.BankType.Account,false,true,false,true
local transactions=0
local function native(f,mixin)
 for k,v in pairs(mixin) do f[k]=v end
 function f:GetActiveBankType() return bankType end
 function f:IsActiveBankTypeLocked() return locked end
 function f:GetBankPanel() return panel end
 return f
end
local function button(parent,mixin)
 local b=native(frame("Button",parent),mixin)
 b.Text=b:CreateFontString(); b.Text:SetText("Native action")
 function b:SetEnabled(value) self.enabled=value and true or false end
 function b:IsEnabled() return self.enabled~=false end
 b:SetScript("OnClick",b.OnClick)
 b.nativeClick=b.OnClick
 return b
end
local money=native(frame(nil,panel),_G.BankPanelMoneyFrameMixin)
panel.MoneyFrame=money
money.Border=frame(nil,money); money.Border.decor=money.Border:CreateTexture()
money.WithdrawButton=button(money,_G.BankPanelWithdrawMoneyButtonMixin)
money.DepositButton=button(money,_G.BankPanelDepositMoneyButtonMixin)
money.MoneyDisplay=native(frame(nil,money),_G.BankPanelMoneyFrameMoneyDisplayMixin)
money.MoneyDisplay.digits=money.MoneyDisplay:CreateFontString()
_G.MoneyFrame_SetType=function(f,value) f.moneyType=value end
_G.MoneyFrame_UpdateMoney=function(f) f.nativeAmount=f.moneyType=="ACCOUNT" and 500 or 75; f.digits:SetText(tostring(f.nativeAmount)) end
_G.ACCOUNT_BANK_ERROR_NO_LOCK="Native bank lock warning"
_G.C_Bank={
 DoesBankTypeSupportMoneyTransfer=function() return supported end,
 CanWithdrawMoney=function() return withdrawAllowed end,
 CanDepositMoney=function() return depositAllowed end,
}
local nextTab={tabCost=1000,canAfford=false,purchasePromptTitle="Native purchase title",purchasePromptBody="Native body"}
_G.C_Bank.FetchNextPurchasableBankTabData=function() return nextTab end
_G.MoneyFrame_Update=function(f,value) f.nativeAmount=value; f.digits:SetText(tostring(value)) end
_G.SetMoneyFrameColorByFrame=function(f,value) f.nativeColor=value; f.digits:SetTextColor(1,value=="red" and .1 or 1,value=="red" and .1 or 1,1) end
local prompt=native(frame(nil,panel),_G.BankPanelPurchasePromptMixin)
prompt.Title,prompt.PromptText=prompt:CreateFontString(),prompt:CreateFontString()
prompt.TabCostFrame=frame(nil,prompt)
local cost=prompt.TabCostFrame
cost.TabCost=cost:CreateFontString(); cost.TabCost:SetText("Native cost caption")
cost.MoneyDisplay=frame(nil,cost); cost.MoneyDisplay.digits=cost.MoneyDisplay:CreateFontString()
cost.PurchaseButton=button(cost,_G.BankPanelPurchaseTabButtonMixin)
panel.Prompts={prompt}
prompt:Refresh()
local confirm=native(frame(),_G.BankCleanUpConfirmationPopupMixin)
_G.BankCleanUpConfirmationPopup=confirm
confirm:Hide()
confirm.Border=frame(nil,confirm)
confirm.Text=confirm:CreateFontString()
confirm.HidePopupCheckbox=frame(nil,confirm)
confirm.HidePopupCheckbox.Label=confirm.HidePopupCheckbox:CreateFontString()
confirm.HidePopupCheckbox.Label:SetText("Do not show again")
local check=frame("CheckButton",confirm.HidePopupCheckbox)
confirm.HidePopupCheckbox.Checkbox=check
check.Init=_G.BankPanelCheckboxMixin.Init
function check:SetChecked(value) self.checked=value end
function check:GetChecked() return self.checked end
confirm.AcceptButton,confirm.CancelButton=frame("Button",confirm),frame("Button",confirm)
local layouts=0
function confirm:Layout() layouts=layouts+1 end
_G.GetCVarBool=function() return true end
_G.SetCVar=function() transactions=transactions+1 end
_G.C_Container={SortBank=function() transactions=transactions+1 end}
_G.StaticPopupSpecial_Hide=function() error("audit must not accept or cancel sort") end
_G.BANK_CONFIRM_CLEANUP_PROMPT="Generic native cleanup"
function panel:GetSelectedTabData() return {tabCleanupConfirmation="Native selected tab cleanup"} end
confirm:OnLoad()
confirm:SetScript("OnShow",confirm.OnShow)
local acceptHandler,cancelHandler=confirm.AcceptButton:GetScript("OnClick"),confirm.CancelButton:GetScript("OnClick")
local sort=button(panel,_G.BankAutoSortButtonMixin)
panel.AutoSortButton=sort
sort.normalTexture,sort.pushedTexture,sort.highlightTexture=sort:CreateTexture(),sort:CreateTexture(),sort:CreateTexture()
function sort:GetNormalTexture() return self.normalTexture end
function sort:GetPushedTexture() return self.pushedTexture end
function sort:GetHighlightTexture() return self.highlightTexture end
sort.normalTexture:SetAtlas("bags-button-autosort-up"); sort.pushedTexture:SetAtlas("bags-button-autosort-down")
local masks=0
function sort:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
for _,t in ipairs({sort.normalTexture,sort.pushedTexture,sort.highlightTexture}) do function t:AddMaskTexture() masks=masks+1 end end
sort:SetScript("OnEnter",sort.OnEnter); sort:SetScript("OnLeave",sort.OnLeave)
_G.BAG_CLEANUP_ACCOUNT_BANK,_G.BAG_CLEANUP_BANK="Native account sort tooltip","Native character sort tooltip"
_G.GameTooltip={SetOwner=function() end,SetText=function(self,text) self.text=text end,Show=function() end}
_G.GameTooltip_Hide=function() end
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_UIPanels_Game" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinBank" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
assert(cost.MoneyDisplay.digits.textColor[2]==.1,"purchase amount must retain native red affordability through skinning")
assert(not confirm:IsShown() and skin.IsSkinned(confirm),"separate cleanup popup must receive QUI skin without opening")
assert(money.Border:IsShown() and money.Border.decor:GetAlpha()==0 and skin.GetBackdrop(money.Border)._quiRoundedSurface,
 "money border must remain visible with rounded QUI shell")
assert(skin.GetBackdrop(money.Border):GetFrameLevel()<money.Border:GetFrameLevel()
 and cost.TabCost:GetText()=="Native cost caption","money shell must sit below digits and retain cost caption")
money:Refresh()
assert(money:GetWidth()==394 and money.MoneyDisplay.moneyType=="ACCOUNT" and money.MoneyDisplay.nativeAmount==500
 and not money.WithdrawButton.enabled and money.DepositButton.enabled,"native account money and permission states must remain")
locked=true
money:Refresh()
assert(money.WithdrawButton.disabledTooltip=="Native bank lock warning" and money.DepositButton.disabledTooltip=="Native bank lock warning",
 "locked-bank tooltip feedback must survive")
bankType=Enum.BankType.Character; supported=false
money:Refresh()
assert(money:GetWidth()==180 and not money.WithdrawButton:IsShown() and not money.DepositButton:IsShown()
 and money.MoneyDisplay.moneyType=="PLAYER" and money.MoneyDisplay.nativeAmount==75,"native character money layout and hidden transfer actions must remain")
nextTab.canAfford=true
prompt:Refresh()
refresh()
assert(cost.MoneyDisplay.digits.textColor[2]==1 and cost.MoneyDisplay.nativeAmount==1000,"native affordable cost must remain white through theme refresh")
nextTab.canAfford=false
prompt:Refresh()
refresh()
assert(cost.MoneyDisplay.digits.textColor[2]==.1,"theme refresh must preserve renewed red cost")
confirm:Show()
assert(confirm.Text:GetText()=="Native selected tab cleanup" and layouts==1,"native cleanup caption and layout must remain")
check:Fire("OnShow")
assert(not check:GetChecked(),"native cleanup checkbox preference must remain")
sort:Fire("OnEnter")
assert(_G.GameTooltip.text=="Native character sort tooltip" and skin.GetBackdrop(sort)._quiBorderR==skin.GetSkinColors(),
 "native sort tooltip and QUI hover must coexist")
sort:Fire("OnLeave")
assert(skin.GetBackdrop(sort)._quiBorderR==skin.GetWindowColors(),"sort hover must clear")
refresh()
assert(masks==3 and sort.normalTexture.atlas=="bags-button-autosort-up" and sort.pushedTexture.atlas=="bags-button-autosort-down",
 "sort normal and pushed artwork must remain with three reused masks")
assert(confirm.AcceptButton:GetScript("OnClick")==acceptHandler and confirm.CancelButton:GetScript("OnClick")==cancelHandler
 and sort:GetScript("OnClick")==sort.nativeClick and money.WithdrawButton:GetScript("OnClick")==money.WithdrawButton.nativeClick
 and cost.PurchaseButton:GetScript("OnClick")==cost.PurchaseButton.nativeClick and transactions==0,
 "styling must preserve all action handlers without sorting changing preferences or transferring money")
print("bank money and sort surfaces passed")
