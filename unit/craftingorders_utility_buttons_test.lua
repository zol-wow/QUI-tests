local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(parent)
 local f=env.NewFrame("Button",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(root);root.Form=form;form.BackButton=false
form.PaymentContainer=frame(form);form.PaymentContainer.ListOrderButton=false;form.PaymentContainer.CancelOrderButton=false;form.PaymentContainer.DurationDropdown=false
local listings=frame(form.PaymentContainer);form.PaymentContainer.ViewListingsButton=listings;listings:SetSize(27,26)
for _,key in ipairs({"Normal","Pushed","Highlight"}) do
 listings[key.."Texture"]=listings:CreateTexture()
 listings[key.."Texture"]:SetAtlas(key=="Pushed" and "UI-CraftingOrderIcon-Down" or "UI-CraftingOrderIcon-Up")
 listings["Get"..key.."Texture"]=function(self) return self[key.."Texture"] end
end
listings.HighlightTexture:SetAlpha(.3)
function listings:SetHighlightAtlas(atlas) self.HighlightTexture:SetAtlas(atlas) end
form.OrderRecipientDisplay=frame(form)
local social=frame(form.OrderRecipientDisplay);form.OrderRecipientDisplay.SocialDropdown=social
social:SetSize(22,22);social.icon=social:CreateTexture();social.icon:SetPoint("CENTER",social,"CENTER",0,0)
social.Background=social:CreateTexture();social.NineSlice=frame(social)
function social:SetupMenu(generator) self.generator=generator end
_G.SquareButton_SetIcon=function(button,direction) assert(direction=="DOWN");button.icon:SetTexCoord(.453125,.640625,.203125,.015625) end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=f:read("*a");f:close()
local start=assert(native:find('self.PaymentContainer.ViewListingsButton:SetScript',1,true))
local stop=assert(native:find('self.TrackRecipeCheckbox.Text',start,true))
local block=native:sub(start,stop-1)
local shows=0
function form:ShowCurrentListings() shows=shows+1 end
_G.GameTooltip={}
function GameTooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function GameTooltip:Show() self.shown=true end
_G.GameTooltip_AddHighlightLine=function(tooltip,text) tooltip.text=text end
_G.CRAFTING_ORDER_VIEW_ORDERS="Native view orders"
assert(loadstring("return function(self)\n"..block.."\nend"))()(form)
start=assert(native:find('SquareButton_SetIcon(self.OrderRecipientDisplay.SocialDropdown',1,true))
stop=assert(native:find('\nend',start,true))
assert(loadstring("return function(self)\n"..native:sub(start,stop-1).."\nend"))()(form)
_G.Enum={ChatWhisperTargetStatus={Offline=1,WrongFaction=2,CanWhisper=3,CanWhisperGuild=4}}
local status=3;local friend=false
function form:GetWhisperCrafterStatus() return status end
form.order={crafterName="Native crafter",crafterGuid="native-guid"}
_G.C_FriendList={IsLegacyFriendSystemEnabled=function() return true end,IsFriend=function() return friend end,IsIgnoredByGuid=function() return false end}
_G.nop=function() end
_G.WHISPER_MESSAGE="Native whisper";_G.ADD_CHARACTER_FRIEND="Native add friend";_G.IGNORE="Native ignore"
_G.GameTooltip_AddNormalLine=function() end
local function menu()
 local description={entries={}}
 function description:SetTag(tag) self.tag=tag end
 function description:CreateButton(text,callback)
  local entry={text=text,callback=callback,enabled=true}
  function entry:SetEnabled(value) self.enabled=value end
  function entry:SetTooltip(fn) self.tooltip=fn end
  self.entries[#self.entries+1]=entry;return entry
 end
 social.generator(social,description);return description
end
local click=listings:GetScript("OnClick");local enter=listings:GetScript("OnEnter");local generator=social.generator
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
assert(skin.GetBackdrop(listings) and skin.GetBackdrop(social),"utility controls must receive QUI chrome")
assert(skin.GetBackdrop(listings):GetFrameLevel()<listings:GetFrameLevel()
 and listings.NormalTexture:GetAlpha()==1 and listings.PushedTexture:GetAlpha()==1 and listings.HighlightTexture:GetAlpha()==.3,
 "listings chrome must sit behind native up/down/highlight art")
assert(social.icon:GetAlpha()==1 and social.Background:GetAlpha()==0 and social:GetWidth()==22
 and listings:GetWidth()==27 and listings:GetHeight()==26,"native social arrow and control dimensions must remain")
click(listings,"LeftButton",true)
assert(shows==0 and listings.HighlightTexture.atlas=="UI-CraftingOrderIcon-Down","native press must change icon without opening")
_G.QUI_RefreshCraftingOrdersColors()
assert(listings.HighlightTexture.atlas=="UI-CraftingOrderIcon-Down" and listings.HighlightTexture:GetAlpha()==.3,
 "theme must retain pressed icon and native highlight alpha")
click(listings,"LeftButton",false)
assert(shows==1 and listings.HighlightTexture.atlas=="UI-CraftingOrderIcon-Up","native release must open bounded listings once")
enter(listings)
assert(GameTooltip.owner==listings and GameTooltip.anchor=="ANCHOR_RIGHT" and GameTooltip.text=="Native view orders",
 "native listings tooltip must remain")
local description=menu()
assert(description.tag=="MENU_PROFESSIONS_CUSTOMER_ORDER_FORM" and #description.entries==3
 and description.entries[1].enabled and description.entries[2].enabled,"native eligible social descriptions must remain")
status=1;friend=true;description=menu()
assert(not description.entries[1].enabled and not description.entries[2].enabled
 and description.entries[1].tooltip and description.entries[2].tooltip,"native offline/friend eligibility must remain")
social:Hide();listings:Hide();_G.QUI_RefreshCraftingOrdersColors()
assert(not social:IsShown() and not listings:IsShown() and shows==1 and social.generator==generator
 and listings:GetScript("OnClick")==click and listings:GetScript("OnEnter")==enter,
 "theme must preserve native visibility, generators and handlers without actions")
print("craftingorders utility buttons passed")
