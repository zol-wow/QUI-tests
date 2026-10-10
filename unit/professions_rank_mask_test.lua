local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin=env.SkinBase
local enabled=true
local pixel=1
skin.GetPixelSize=function() return pixel end
local function Read(path)
    local f=assert(io.open(path));local text=f:read("*a");f:close();return text
end
local native=Read("tests/clients/forever/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRankBar.lua")
_G.ProfessionsRankBarMixin={}
local generate=assert(native:match("(local function GenerateRankText%b().-\nend)"))
assert(loadstring(generate.."\n"..assert(native:match("(function ProfessionsRankBarMixin:Update%b().-\nend)"))))()
for _,name in ipairs({"OnLoad","GetMaskWidth","OnHide"}) do
    assert(loadstring(assert(native:match("(function ProfessionsRankBarMixin:"..name.."%b().-\nend)"))))()
end
_G.TRADESKILL_NAME_RANK="%s %d/%d";_G.TRADESKILL_NAME_RANK_WITH_MODIFIER="%s %d +%d/%d"
_G.GameLimitedMode_IsActive=function() return false end
_G.TextureKitConstants={IgnoreAtlasSize=false,UseAtlasSize=true}
_G.Professions={GetAtlasKitSpecifier=function() return "Native" end}
_G.C_Texture={GetAtlasInfo=function() return {height=68} end}
local interpolator
_G.InterpolatorUtil={InterpolateEaseOut=function() end,InterpolateLinear=function(a,b,t) return a+(b-a)*t end}
_G.CreateInterpolator=function()
    local job={}
    function job:Cancel() self.cancelled=true end
    function job:Interpolate(a,b,duration,update,complete)
        assert(a==0 and b==1 and duration==.5);self.update=update;self.complete=complete
    end
    interpolator=job;return job
end
local bar=env.NewFrame("Frame");bar.RegisterForWidgetSet=false;bar:SetSize(453,18);bar.ownerManagesEvents=true
for name,fn in pairs(_G.ProfessionsRankBarMixin) do bar[name]=fn end
for _,key in ipairs({"Background","Border","Fill","Mask","Flare"}) do bar[key]=bar:CreateTexture() end
bar.Fill:SetSize(441,18);bar.Mask:SetSize(453,18)
bar.Rank=env.NewFrame("Frame",nil,bar);bar.Rank.Text=bar.Rank:CreateFontString()
local restarts=0
bar.BarAnimation={Restart=function() restarts=restarts+1 end,
    Flipbook={SetFlipBookRows=function(self,value) self.rows=value end,
        SetFlipBookFrames=function(self,value) self.frames=value end,GetFlipBookColumns=function() return 2 end}}
bar.FlareFadeOut={Restart=function(self) self.playing=true end,Stop=function(self) self.playing=false end}
bar:OnLoad()
local info={professionName="Alchemy",profession=1,skillLevel=50,maxSkillLevel=100,skillModifier=0}
bar:Update(info)
local source=Read(arg[1] or "modules/skinning/frames/professions.lua")
local first=assert(source:find("local function StyleProfessionRankBar(",1,true))
local last=assert(source:find("local function StyleProfessionOrderView(",first,true))
local chunk=assert(loadstring(source:sub(first,last-1).."\nreturn StyleProfessionRankBar"))
setfenv(chunk,setmetatable({SkinBase=skin,IsEnabled=function() return enabled end},{__index=_G}))
local apply=chunk()
apply(bar)
assert(bar.Mask:GetWidth()==bar.Fill:GetWidth()*.5,
    "rank progress mask must use inset fill width rather than the outer bar width")
assert(bar.Mask:GetHeight()==bar.Fill:GetHeight() and bar.Mask.points[1][2]==bar.Fill
    and bar.Mask.points[1][4]==0 and bar.Mask.points[1][5]==0,
    "rank mask must align with the resized fill without the native decorative left offset")
assert(bar.Rank.Text:GetText()=="Alchemy 50/100" and bar.ratio==.5 and restarts==1
    and bar.BarAnimation.Flipbook.rows==2 and bar.BarAnimation.Flipbook.frames==4,
    "styling must preserve native rank text, ratio and flipbook setup")
local getter=bar.GetMaskWidth
apply(bar);assert(bar.GetMaskWidth==getter and bar:GetWidth()==425,"theme refresh must reuse wrapper and avoid repeated shrink")
info.skillLevel=75;bar:Update(info)
assert(bar.ratio==.75 and restarts==2 and interpolator,"native rank changes must retain interpolation")
interpolator.update(.5)
assert(bar.Mask:GetWidth()==bar.Fill:GetWidth()*.625,"native interpolation must measure the resized fill")
info.skillLevel=100;bar:Update(info)
assert(interpolator and bar.FlareFadeOut.playing,"native full-rank transition must retain flare fade")
interpolator.update(1)
assert(bar.Mask:GetWidth()==bar.Fill:GetWidth(),"full-rank mask must terminate at fill edge")
info.skillLevel=0;bar:Update(info);interpolator.update(1)
assert(bar.Mask:GetWidth()==0,"empty rank must retain zero-width mask")
bar.overrideMaskRightOffset=3
assert(bar:GetMaskWidth(.5)==bar.Fill:GetWidth()*.5+3,"native mask offset override must be preserved")
bar.overrideMaskRightOffset=nil
pixel=2;apply(bar)
assert(bar.Fill:GetWidth()==421 and bar.Mask:GetHeight()==18,"pixel-scale refresh must update fill and mask together")
enabled=false
assert(bar:GetMaskWidth(.5)==bar:GetWidth()*.5,"disabled skin must delegate to native mask measurement")
enabled=true
bar:OnHide()
assert(bar.ratio==nil and bar.lastProfession==nil,"native OnHide state reset must remain")
print("Native profession rank-mask alignment and interpolation passed")
