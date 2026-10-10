local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local bar = env.NewFrame("Frame")
bar.Track = env.NewFrame("Frame", nil, bar)
bar.Track.Thumb = env.NewFrame("Button", nil, bar.Track)
local thumb = bar.Track.Thumb
for _, owner in ipairs({ bar.Track, thumb }) do
    for _, key in ipairs({ "Begin", "Middle", "End" }) do owner[key] = owner:CreateTexture() end
end
local drag = function() end
thumb:SetScript("OnMouseDown", drag)
env.SkinBase.SkinTrimScrollBar(bar)
assert(bar.Track:GetAlpha() == 1, "native thumb parent must stay visible")
assert(env.SkinBase.GetBackdrop(thumb), "nested native thumb must have visible skin")
assert(thumb:GetScript("OnMouseDown") == drag, "native drag handler must be retained")
thumb.Begin:SetAlpha(1)
assert(thumb.Begin:GetAlpha() == 0, "native hover artwork must remain suppressed")
print("OK: minimal_scrollbar_thumb_test")

local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBar.lua"))
local native=f:read("*a");f:close()
_G.ScrollBarMixin={Event={OnScroll="OnScroll"}}
for _,name in ipairs({"Update","SetThumbExtent","GetTrack","GetThumb","GetBackStepper","GetForwardStepper","GetThumbAnchor","HasScrollableExtent","SetScrollPercentageInternal"}) do
    assert(loadstring(assert(native:match("(function ScrollBarMixin:"..name.."%b().-\nend)"))))()
end
for name,fn in pairs(_G.ScrollBarMixin) do if type(fn)=="function" then bar[name]=fn end end
_G.MathUtil={Epsilon=.00001}
_G.WithinRangeExclusive=function(value,a,b) return value>a and value<b end
_G.ScrollUtil.GetScrollableDirections=function(self)
    return self.scroll>0 and self.allowed,self.scroll<1 and self.allowed
end
_G.ScrollControllerMixin={SetScrollPercentage=function(self,value) self.scroll=math.max(0,math.min(1,value)) end}
bar.Back=env.NewFrame("Button",nil,bar);bar.Forward=env.NewFrame("Button",nil,bar)
for _,control in ipairs({thumb,bar.Back,bar.Forward}) do
    function control:SetEnabled(value) self.enabled=value end
end
bar.Track:SetSize(8,400);bar.thumbAnchor="TOP";bar.minThumbExtent=23;bar.useProportionalThumb=true
bar.visible=.25;bar.scroll=0;bar.allowed=true;bar.hideIfUnscrollable=true
function bar:GetTrackExtent() return self.Track:GetHeight() end
function bar:GetFrameExtent(frame) return frame:GetHeight() end
function bar:SetFrameExtent(frame,value) frame:SetHeight(value) end
function bar:GetVisibleExtentPercentage() return self.visible end
function bar:GetScrollPercentage() return self.scroll end
function bar:IsScrollAllowed() return self.allowed end
local scrollEvents=0
function bar:TriggerEvent(event,value) assert(event=="OnScroll" and value==self.scroll);scrollEvents=scrollEvents+1 end
local function ApplyRecipeOwner()
    local file=assert(io.open("modules/skinning/frames/professions.lua"))
    local source=file:read("*a");file:close()
    local first=assert(source:find("local function SkinRecipeList(",1,true))
    local last=assert(source:find("local function SkinCraftingPage(",first,true))
    local chunk=assert(loadstring(source:sub(first,last-1).."\nreturn SkinRecipeList"))
    setfenv(chunk,setmetatable({SkinBase=env.SkinBase,HookRecipeRowHover=function() end,StyleScrollBoxRow=function() end},{__index=_G}))
    local owner=env.NewFrame("Frame");owner.RegisterForWidgetSet=false;owner.ScrollBar=bar
    chunk()(owner)
end
bar:Update();ApplyRecipeOwner()
assert(bar:IsShown() and thumb:IsShown() and thumb.enabled and thumb:GetHeight()==100
    and bar.Track:GetAlpha()==1 and env.SkinBase.GetBackdrop(thumb)._quiRoundedSurface,
    "recipe owner styling must retain native visible proportional thumb")
bar:SetScrollPercentageInternal(.5)
local point=thumb.points[#thumb.points]
assert(point[2]==bar.Track and point[4]==0 and point[5]==-150 and scrollEvents==1
    and bar.Back.enabled and bar.Forward.enabled,"native scrollbar percentage update must retain thumb geometry and scroll event")
bar.visible=1;bar:Update()
assert(not bar:IsShown() and not thumb:IsShown() and not thumb.enabled,
    "native unscrollable recipe list must hide scrollbar and thumb")
ApplyRecipeOwner();assert(not bar:IsShown() and not thumb:IsShown(),"theme styling must respect native unscrollable visibility")
bar.visible=.1;bar:Update()
assert(bar:IsShown() and thumb:IsShown() and thumb:GetHeight()==40,"native provider transition must restore proportional thumb")
bar.Track:SetHeight(15);bar:Update()
assert(not thumb:IsShown(),"native clamped thumb must hide when the track is smaller than minimum extent")
bar.Track:SetHeight(400);bar.allowed=false;bar:Update()
assert(thumb:IsShown() and not thumb.enabled,"native disabled scrolling must retain its visible but disabled thumb")
bar.allowed=true;bar:Update();assert(thumb.enabled)
local mf=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.lua"))
local minimal=mf:read("*a");mf:close()
_G.MinimalScrollBarThumbScriptsMixin={}
for _,name in ipairs({"GetAtlas","OnButtonStateChanged","OnSizeChanged"}) do
    assert(loadstring(assert(minimal:match("(function MinimalScrollBarThumbScriptsMixin:"..name.."%b().-\nend)"))))()
    thumb[name]=_G.MinimalScrollBarThumbScriptsMixin[name]
end
function thumb:IsEnabled() return self.enabled end
_G.TextureKitConstants={UseAtlasSize=true}
_G.C_Texture={GetAtlasInfo=function(atlas) assert(atlas=="down-middle");return {width=8,height=100} end}
function thumb.Middle:GetAtlas() return self.atlas end
for _,state in ipairs({"up","over","down"}) do
    thumb[state.."MiddleTexture"]=state.."-middle";thumb[state.."BeginTexture"]=state.."-begin";thumb[state.."EndTexture"]=state.."-end"
end
thumb.down=true;thumb:OnButtonStateChanged();thumb:OnSizeChanged(8,40)
assert(thumb.Middle:GetAtlas()=="down-middle" and thumb.Middle:GetHeight()==40 and thumb.Middle:GetAlpha()==0
    and env.SkinBase.GetBackdrop(thumb) and thumb:GetScript("OnMouseDown")==drag,
    "native pressed thumb atlas/sizing updates must retain QUI chrome and original drag script")
print("Native recipe scrollbar extent, state and thumb updates passed")
