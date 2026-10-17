local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinInspectFrame=true;env.profile.character={enabled=true,inspectEnabled=false}
local root=env.NewFrame("Frame");_G.InspectFrame=root;root.CloseButton=false;root.unit="target"
local items=env.NewFrame("Frame",nil,root);_G.InspectPaperDollItemsFrame=items
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local xml=read("tests/framexml/Interface/AddOns/Blizzard_InspectUI/Mainline/InspectPaperDollFrame.xml")
local slots={};local masks=0
for name in xml:gmatch('<ItemButton name="(Inspect[^"]+Slot)"') do
 local b=env.NewFrame("Button",name,items);_G[name]=b;b:SetID(#slots+1);b:SetSize(37,37)
 b.Icon=b:CreateTexture();b.IconBorder=b:CreateTexture();b.Count=b:CreateFontString()
 b.Normal=b:CreateTexture();b.Normal:SetTexture("native-quickslot")
 b.IconOverlay=b:CreateTexture();b.ItemContextOverlay=b:CreateTexture()
 b.backgroundTextureName="native-empty"
 function b.IconBorder:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
 function b:GetNormalTexture() return self.Normal end
 function b:GetHighlightTexture() return nil end
 function b:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
 function b.Icon:AddMaskTexture() masks=masks+1 end
 b.SocketDisplay={SetItem=function(self,link) self.link=link end}
 b:SetScript("OnClick",function() error("inspect gear action invoked") end)
 slots[#slots+1]=b
end
assert(#slots>=18,"saved native template must expose the complete equipment roster")
local populated=true;local reads=0
_G.GetInventoryItemTexture=function(_,id) reads=reads+1;if id~=2 or populated then return "native-gear-"..id end end
_G.GetInventoryItemCount=function() return 1 end
_G.GetInventoryItemQuality=function() return 4 end
_G.GetInventoryItemID=function(_,id) return 100+id end
_G.GetInventoryItemLink=function(_,id) return "native-link-"..id end
_G.UnitHasRelicSlot=function() return false end
_G.SetItemButtonTexture=function(b,texture) b.Icon:SetTexture(texture) end
_G.SetItemButtonCount=function(b,count) b.Count:SetText(tostring(count)) end
_G.SetItemButtonQuality=function(b) b.IconBorder:SetVertexColor(.6,.2,.8,1);b.IconBorder:Show() end
_G.GameTooltip={IsOwned=function() return false end}
local native=read("tests/framexml/Interface/AddOns/Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua")
assert(loadstring(assert(native:match("(function InspectPaperDollItemSlotButton_Update%b().-\nend)"))))()
for _,b in ipairs(slots) do _G.InspectPaperDollItemSlotButton_Update(b) end
local before=reads
local setup;skin.OnAddOnLoaded=function(_,fn) setup=fn end
assert(loadfile(arg[1] or "modules/skinning/frames/inspect.lua"))("QUI",ns);setup()
for _,b in ipairs(slots) do
 local border=skin.GetFrameData(b,"qInspectFallbackBorder")
 assert(border and border._quiRoundedSurface and border:IsShown(),"every native fallback equipment slot must receive rounded border")
 assert(border._quiBorderB==.8 and b.Icon:GetAlpha()==1 and b.Normal:GetAlpha()==0 and b.IconBorder:GetAlpha()==0,
 "fallback quality color and art must remain while decorative slot frames clear")
 assert(b.IconOverlay:GetAlpha()==1 and b.ItemContextOverlay:GetAlpha()==1 and b.SocketDisplay.link=="native-link-"..b:GetID(),
 "context/quality overlays and native socket data must remain")
end
assert(reads==before and masks==#slots,"initial fallback styling must not query inventory or duplicate masks")
populated=false;_G.InspectPaperDollItemSlotButton_Update(slots[2])
local fallback=skin.GetFrameData(slots[2],"qInspectFallbackBorder")
local r,g,blue=skin.GetWindowColors()
assert(slots[2].Icon.texture=="native-empty" and slots[2].hasItem==nil and not slots[2].IconBorder:IsShown()
 and fallback._quiBorderR==r and fallback._quiBorderG==g and fallback._quiBorderB==blue,
 "native empty slot update must reset fallback quality and retain empty art")
local source=read(arg[2] or "modules/skinning/character_pane/inspect.lua")
local a=assert(source:find("local function SkinInspectEquipmentSlot(slot)",1,true))
local b=assert(source:find("local inspectSlotUpdateHooked",a,true))
local state={}
local sandbox=setmetatable({
 frameState=state,EMPTY={},GetState=function(value) state[value]=state[value] or {};return state[value] end,
 GetSkinBase=function() return skin end,
 BlockInspectIconBorder=function(border) border:SetAlpha(0) end,
 ApplyOnePixelBorder=function(border) skin.ApplyChromeBackdrop(border,{radius=4,withBackground=false}) end,
 SetOnePixelBorderColors=function(border,color) skin.SetBackdropColors(border,color,nil) end,
 GetReadableInventoryItemLink=function() return "native-link" end,
 IsFullInspectEnabled=function() return env.profile.character.inspectEnabled end,
 Helpers={IsSecretValue=function() return false end},
}, {__index=_G})
_G.C_Item={GetItemQualityByID=function() return 4 end,GetItemQualityColor=function() return .6,.2,.8 end}
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn SkinInspectEquipmentSlot,UpdateInspectSlotBorder"))
setfenv(chunk,sandbox);local customSkin,customUpdate=chunk()
local first=slots[1];local nativeBorder=skin.GetFrameData(first,"qInspectFallbackBorder")
env.profile.character.inspectEnabled=true;customSkin(first);customUpdate(first,"target")
local custom=skin.GetFrameData(first,"qInspectCustomBorder")
assert(custom and custom:IsShown() and not nativeBorder:IsShown(),"custom pane takeover must leave only custom quality border visible")
env.profile.character.inspectEnabled=false;_G.QUI_RefreshInspectColors();customUpdate(first,"target")
assert(nativeBorder:IsShown() and not custom:IsShown(),"fallback return must suppress custom border even during later custom quality update")
env.profile.character.inspectEnabled=true;customSkin(first)
assert(not nativeBorder:IsShown(),"already-skinned custom takeover must still hide fallback border")
print("inspect equipment fallback passed")
