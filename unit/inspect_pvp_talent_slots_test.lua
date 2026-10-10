local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinInspectFrame=true
local root=env.NewFrame("Frame");_G.InspectFrame=root;root.CloseButton=false
local pvp=env.NewFrame("Frame",nil,root);_G.InspectPVPFrame=pvp;pvp.Slots={}
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_InspectUI/Mainline/InspectPVPFrame.lua"))
local native=f:read("*a");f:close();_G.InspectPvpTalentSlotMixin={}
for _,key in ipairs({"OnLoad","Update","OnEnter","OnClick"}) do
 assert(loadstring(assert(native:match("(function InspectPvpTalentSlotMixin:"..key.."%b().-\nend)"))))()
end
local talentIDs={101,nil,103};local reads,masks,removed=0,0,0
_G.INSPECTED_UNIT="target"
_G.C_SpecializationInfo={GetInspectSelectedPvpTalent=function(unit,index) assert(unit=="target");reads=reads+1;return talentIDs[index] end}
_G.GetPvpTalentInfoByID=function(id) return nil,"Native talent","native-art-"..id end
_G.TALENT_NOT_SELECTED="Native talent not selected"
_G.HIGHLIGHT_FONT_COLOR={GetRGB=function() return 1,1,1 end}
local tooltip={}
_G.GameTooltip=tooltip
function tooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function tooltip:SetPvpTalent(id,inspect) self.id=id;self.inspect=inspect;self.text=nil end
function tooltip:SetText(text) self.text=text;self.id=nil end
function tooltip:Show() self.shown=true end
_G.IsModifiedClick=function() return false end
_G.ChatFrameUtil={InsertLink=function() error("chat-link action invoked") end}
local function slot(index)
 local s=env.NewFrame("Button",nil,pvp);s.RegisterForWidgetSet=false;s.DisabledTexture=false
 s.slotIndex=index;s:SetSize(46,46)
 local create=s.CreateTexture
 function s:CreateTexture(...)
  local texture=create(self,...)
  function texture:AddMaskTexture() masks=masks+1 end
  return texture
 end
 s.Texture=s:CreateTexture();s.Texture:SetVertexColor(1,.1,.1,1)
 s.Texture:SetTexCoord(.1,.9,.1,.9);s.Texture:SetPoint("CENTER",s,"CENTER")
 s.Border=s:CreateTexture();s.Border:SetAtlas("pvptalents-talentborder")
 s.CircleMask=s:CreateTexture()
 function s.Texture:RemoveMaskTexture(mask) assert(mask==s.CircleMask);removed=removed+1 end
 function s.Texture:AddMaskTexture() masks=masks+1 end
 function s:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
 for key,method in pairs(_G.InspectPvpTalentSlotMixin) do s[key]=method end
 s:SetScript("OnEnter",s.OnEnter);s:SetScript("OnClick",s.OnClick)
 s:OnLoad();s:Update();return s
end
for i=1,3 do pvp.Slots[i]=slot(i) end
local first=pvp.Slots[1];local click=first:GetScript("OnClick")
local before=reads
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/inspect.lua"))("QUI",ns)
local border=skin.GetFrameData(first.Texture,"iconBorder")
assert(border and border._quiRoundedSurface,"inspect talent icon needs rounded QUI border")
assert(removed==3 and masks==6 and reads==before,"initial styling must replace each circle mask once without talent queries")
assert(first.Texture.texture=="native-art-101" and first.Texture.vertex[2]==.1
 and first.Texture.texCoord[1]==.1 and first.Texture:GetWidth()==34 and first:GetWidth()==46,
 "native talent art, color, UVs and icon/hitbox geometry must remain")
assert(skin.GetFrameData(skin.GetFrameData(first,"qInspectTalentHover"),"roundedIconMask"),"hover fill must receive rounded mask")
assert(first.Border:GetAlpha()==0 and not pvp.Slots[2].Texture:IsShown(),"native empty icon visibility must remain")
first:Fire("OnEnter")
local hover=skin.GetFrameData(first,"qInspectTalentHover")
assert(tooltip.id==101 and tooltip.inspect==true and tooltip.owner==first and hover:IsShown(),
 "native inspected talent tooltip must coexist with hover fill")
first:Fire("OnLeave");assert(not hover:IsShown(),"leaving icon must clear hover")
first:Fire("OnEnter");first:Hide();assert(not hover:IsShown(),"native hide must clear sticky hover")
pvp.Slots[2]:OnEnter();assert(tooltip.text=="Native talent not selected","native initially empty tooltip must remain")
talentIDs[1]=105;first:Update()
assert(first.Texture.texture=="native-art-105" and removed==3 and masks==6,"native talent reuse must retain single icon and hover masks")
before=reads;_G.QUI_RefreshInspectColors()
assert(reads==before and first:GetScript("OnClick")==click and not hover:IsShown(),
 "theme must preserve handlers and hover state without native talent reads")
click(first)
_G.INSPECTED_UNIT=nil;first:Update()
assert(first.Texture.texture=="native-art-105","native no-inspected-unit update must retain previous icon")
_G.INSPECTED_UNIT="target";env.profile.general.skinInspectFrame=false
local fresh=slot(3);pvp.Slots[4]=fresh;_G.QUI_RefreshInspectColors()
assert(not skin.GetFrameData(fresh.Texture,"iconBorder"),"disabled inspect skin must leave new talent slots untouched")
print("inspect pvp talent slots passed")
