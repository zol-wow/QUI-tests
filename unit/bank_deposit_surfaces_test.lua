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
panel.Prompts={}
local bankType=Enum.BankType.Account
local deposit=frame(nil,panel)
panel.AutoDepositFrame=deposit
for k,v in pairs(_G.BankPanelAutoDepositFrameMixin) do deposit[k]=v end
function deposit:GetActiveBankType() return bankType end
local button=frame("Button",deposit)
deposit.DepositButton=button
for k,v in pairs(_G.BankPanelItemDepositButtonMixin) do button[k]=v end
function button:GetActiveBankType() return bankType end
function button:SetEnabled(value) self.enabled=value and true or false end
function button:IsEnabled() return self.enabled end
button.Text=button:CreateFontString()
function button:SetText(text) self.Text:SetText(text) end
button:SetScript("OnClick",button.OnClick)
local click=button:GetScript("OnClick")
local checkbox=frame("CheckButton",deposit)
deposit.IncludeReagentsCheckbox=checkbox
for k,v in pairs(_G.BankPanelIncludeReagentsCheckboxMixin) do checkbox[k]=v end
function checkbox:SetEnabled(value) self.enabled=value and true or false end
function checkbox:IsEnabled() return self.enabled end
function checkbox:SetChecked(value) self.checked=value end
function checkbox:GetChecked() return self.checked end
checkbox.Text=checkbox:CreateFontString()
checkbox.Text:SetTextColor(1,.82,0,1)
function checkbox.Text:SetFontObject(font) self:SetFont(font,12,"") end
checkbox.fontObject="native-reagent-font"
checkbox.text="Native reagent label"; checkbox.textWidth=180; checkbox.maxTextLines=2
checkbox:SetScript("OnShow",checkbox.OnShow)
checkbox:SetScript("OnClick",checkbox.OnClick)
local preferenceClick=checkbox:GetScript("OnClick")
checkbox:Hide()
local preference=true
local writes,iterations=0,0
_G.GetCVarBool=function(key) assert(key=="bankAutoDepositReagents"); return preference end
_G.SetCVar=function() writes=writes+1 end
_G.StaticPopup_Show=function() error("audit must not open deposit confirmation") end
_G.C_Bank={AutoDepositItemsIntoBank=function() writes=writes+1 end}
_G.ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL="Native account deposit"
_G.CHARACTER_BANK_DEPOSIT_BUTTON_LABEL="Native character deposit"
local inventory={{allowed=true,refundable=true}}
_G.ItemUtil={IteratePlayerInventory=function(predicate)
 iterations=iterations+1
 for _,item in ipairs(inventory) do if predicate(item) then return true end end
 return false
end}
_G.C_Bank.IsItemAllowedInBankType=function(kind,item) assert(kind==Enum.BankType.Account); return item.allowed end
_G.C_Item={CanBeRefunded=function(item) return item.refundable end}
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_UIPanels_Game" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinBank" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
assert(checkbox.Text.textColor[2]==1 and checkbox.Text.textColor[3]==1,
 "reagent label must receive neutral QUI chrome rather than native yellow")
deposit:SetEnabled(true)
assert(button:IsEnabled() and button.Text:GetText()=="Native account deposit" and checkbox:IsShown() and checkbox:GetChecked(),
 "native account deposit eligibility caption and reagent preference must survive")
assert(checkbox.Text:GetFont()~="native-reagent-font" and checkbox.Text:GetText()=="Native reagent label"
 and checkbox.Text:GetWidth()==180,"native checkbox initialization must retain QUI font and native label layout")
deposit:SetEnabled(false)
assert(not button:IsEnabled() and not checkbox:IsShown(),"disabled account deposits must retain hidden reagent control")
preference=false
deposit:SetEnabled(true)
assert(checkbox:IsShown() and not checkbox:GetChecked(),"native reagent preference must refresh on reopening")
bankType=Enum.BankType.Character
deposit:SetEnabled(true)
refresh()
assert(button:IsEnabled() and button.Text:GetText()=="Native character deposit" and not checkbox:IsShown(),
 "character banks must retain deposit action and suppress reagent-only option")
local previousIterations=iterations
assert(button:GetItemDepositConfirmationPopup()==nil and iterations==previousIterations,
 "native character routing must avoid account refund scan")
bankType=Enum.BankType.Account
deposit:SetEnabled(true)
assert(button:GetItemDepositConfirmationPopup()=="ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM",
 "allowed refundable items must retain native refund-loss confirmation routing")
inventory={{allowed=false,refundable=true}}
assert(button:GetItemDepositConfirmationPopup()==nil,"bank-ineligible refundable items must not trigger refund-loss confirmation")
inventory={{allowed=true,refundable=false}}
assert(button:GetItemDepositConfirmationPopup()==nil,"nonrefundable eligible items must not trigger refund-loss confirmation")
refresh()
assert(button:GetScript("OnClick")==click and checkbox:GetScript("OnClick")==preferenceClick and writes==0,
 "styling must preserve deposit and preference handlers without invoking them")
print("bank auto-deposit surfaces passed")
