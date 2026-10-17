local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
env.profile.general.applyGlobalFontToBlizzard=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
_G.ProfessionsCrafterTableHeaderStringMixin={}
local native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.lua")
for _,key in ipairs({"Init","OnClick","UpdateArrow"}) do
 assert(loadstring(assert(native:match("(function ProfessionsCrafterTableHeaderStringMixin:"..key.."%b().-\nend)"))))()
end
local copied={}
for key,method in pairs(_G.ProfessionsCrafterTableHeaderStringMixin) do copied[key]=method end
_G.TableBuilderMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/TableBuilder.lua")
assert(loadstring(assert(native:match("(function TableBuilderMixin:EnumerateHeaders%b().-\nend)"))))()
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
root.Form=frame(nil,root);root.Form.BackButton=false
root.Form.CurrentListings=frame(nil,root.Form);root.Form.CurrentListings.CloseButton=false
root.BrowseOrders=frame(nil,root);root.MyOrdersPage=frame(nil,root);root.MyOrdersPage.RefreshButton=false
local owners={root.BrowseOrders,root.MyOrdersPage,root.Form.CurrentListings}
local clicks,arranges=0,0
local function header(owner)
 local h=frame("Button",owner);h.Text=h:CreateFontString();h.Text:SetFont("Native header font",14,"")
 for _,key in ipairs({"Left","Middle","Right","Arrow","Highlight"}) do h[key]=h:CreateTexture() end
 h.Arrow:SetAtlas("auctionhouse-ui-sortarrow");h.Arrow:SetPoint("LEFT",h.Text,"RIGHT",3,0)
 function h:GetHighlightTexture() return self.Highlight end
 function h:GetFontString() return self.Text end
 function h:SetText(value) self.Text:SetText(value) end
 for key,method in pairs(copied) do h[key]=method end
 h:SetScript("OnClick",h.OnClick)
 h:Init(owner,"Native header",1)
 return h
end
for _,owner in ipairs(owners) do
 owner.order=1;owner.ascending=true
 function owner:GetSortOrder() return self.order,self.ascending end
 function owner:SetSortOrder(order)
  if order==self.order then self.ascending=not self.ascending else self.order=order;self.ascending=true end
  clicks=clicks+1
 end
 local first=header(owner)
 local builder={headers={[first]=true}}
 owner.tableBuilder=builder;owner.first=first
 builder.EnumerateHeaders=_G.TableBuilderMixin.EnumerateHeaders
 builder.headerPoolCollection={EnumerateActive=function() return pairs(builder.headers) end}
 function builder:Arrange()
  arranges=arranges+1
  if self.nextHeader then self.headers={[self.nextHeader]=true};self.nextHeader:Init(owner,"Native new header",1) end
 end
end
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local expected=ns.Helpers.GetGeneralFont()
for _,owner in ipairs(owners) do
 local h=owner.first
 assert(h.Left:GetAlpha()==0 and h.Middle:GetAlpha()==0 and h.Right:GetAlpha()==0 and h.Highlight:GetAlpha()==0,
  "each already-initialized customer table header must suppress native decoration")
 assert(h.Text:GetFont()==expected and h.Arrow:IsShown() and h.Arrow.texCoord[3]==1 and h.Arrow.atlas=="auctionhouse-ui-sortarrow",
  "native sorted arrow and actual header font must remain")
 local click=h:GetScript("OnClick")
 h:OnClick()
 assert(not owner.ascending and h.Arrow.texCoord[3]==0,"native header click must preserve sort direction")
 h.Text:SetFont("Native reset",14,"");h:Init(owner,"Native rebound caption",nil)
 assert(h.Text:GetFont()==expected and h.Text:GetText()=="Native rebound caption" and not h.Arrow:IsShown(),
  "copied native Init must reassert font and retain unsortable arrow state")
 local n=clicks;h:OnClick();assert(clicks==n,"native unsortable header click must remain inert")
 local late=header(owner);owner.tableBuilder.nextHeader=late;owner.tableBuilder:Arrange()
 assert(late.Left:GetAlpha()==0 and late.Text:GetFont()==expected and late.Arrow:IsShown(),
  "new pre-copied header must be styled after builder arrangement")
 late.Text:SetFont("Native reused font",14,"");late:Init(owner,"Native reused label",1)
 assert(late.Text:GetFont()==expected,"late copied Init must receive its own durable hook")
 assert(h:GetScript("OnClick")==click,"native click script ownership must remain")
end
local sorted=clicks;local layouts=arranges
_G.QUI_RefreshCraftingOrdersColors()
assert(clicks==sorted and arranges==layouts,"theme must not sort or rebuild tables")
env.profile.general.applyGlobalFontToBlizzard=false
local nativeOwner=owners[2];local fontOff=header(nativeOwner)
nativeOwner.tableBuilder.nextHeader=fontOff;nativeOwner.tableBuilder:Arrange()
assert(fontOff.Left:GetAlpha()==0 and fontOff.Text:GetFont()=="Native header font",
 "header styling must respect disabled global font override")
env.profile.general.skinCraftingOrders=false
local owner=owners[1];local late=header(owner);owner.tableBuilder.nextHeader=late;owner.tableBuilder:Arrange()
assert(late.Left:GetAlpha()==1 and not skin.GetFrameData(late,"qOrderHeaderInitHooked"),
 "disabled skin must leave new headers untouched")
print("craftingorders header lifecycle passed")
