local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin=env.SkinBase
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local tip=frame();tip:SetSize(226,72)
tip.BG=tip:CreateTexture();tip.BG:SetColorTexture(1,1,1,1);tip.GlowTop=tip:CreateTexture()
tip.Text=tip:CreateFontString();tip.Text:SetText("Existing tutorial")
tip.Arrow=frame(nil,tip);tip.Arrow.Arrow=tip.Arrow:CreateTexture();tip.Arrow.Glow=tip.Arrow:CreateTexture()
function tip.Arrow:CreateLine()
 local line=self:CreateTexture()
 function line:SetStartPoint(...)self.start={...}end
 function line:SetEndPoint(...)self.finish={...}end
 function line:SetThickness(v)self.thickness=v end
 return line
end
tip.CloseButton=frame("Button",tip);tip.CloseButton.Texture=tip.CloseButton:CreateTexture()
tip.OkayButton=frame("Button",tip)
local acknowledges=0
local acknowledge=function()acknowledges=acknowledges+1 end
tip.CloseButton:SetScript("OnClick",acknowledge);tip.OkayButton:SetScript("OnClick",acknowledge)
function tip:Init(info)
 self.info=info;self.Arrow.rotation=info.rotation or 1
 self.BG:SetAlpha(1);self.CloseButton.Texture:SetAlpha(1)
 self.Arrow.Arrow:SetAlpha(1);self.Arrow.Glow:SetAlpha(1)
 self.Arrow:SetShown(not info.hideArrow)
end
function tip:RotateArrow(rotation)self.Arrow.rotation=rotation end
local active={tip}
_G.HelpTip={framePool={EnumerateActive=function()
 local i=0;return function()i=i+1;return active[i]end end}}
local shows=0
function _G.HelpTip:Show()shows=shows+1 end
local file=assert(io.open(os.getenv("QUI_TOOLTIP_SOURCE") or "modules/skinning/system/tooltips.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("local HELP_TIP_POINTERS =",1,true))
local last=assert(source:find("local function RefreshAllColors()",first,true))
local enabled=true
local color={.2,.6,1,1,.04,.05,.06,.9}
local chunk=assert(loadstring(source:sub(first,last-1).."\nreturn HookHelpTips"))
setfenv(chunk,setmetatable({SkinBase=skin,IsEnabled=function()return enabled end,
 GetEffectiveColors=function()return unpack(color)end,GetEffectiveBorderThickness=function()return 1 end},{__index=_G}))
local hook=chunk()
local info={rotation=3,acknowledgeOnHide=true,cvarBitfield="untouched",bitfieldFlag=2}
tip:Init(info)
-- Styling must leave tutorial layout and lifecycle entirely native.
for _,key in ipairs({"SetPoint","ClearAllPoints","SetSize","SetWidth","SetHeight","SetParent","Hide","Show"}) do
 tip[key]=function()error("tutorial geometry/lifecycle touched: "..key)end
end
hook()
assert(skin.GetBackdrop(tip)._quiRoundedSurface.radius==8 and tip.BG:GetAlpha()==0 and tip.GlowTop:GetAlpha()==0,
 "HelpTip native GlowBox art must be replaced by QUI rounded chrome")
assert(tip.CloseButton.Texture:GetAlpha()==0 and skin.GetBackdrop(tip.OkayButton),
 "close and acknowledgement controls must receive QUI treatment")
assert(tip.info==info and tip.Text:GetText()=="Existing tutorial" and acknowledges==0,
 "styling must not acknowledge, replace text, hide, or close a tutorial")
local lines=skin.GetFrameData(tip.Arrow,"qHelpTipPointer")
assert(#lines==2 and lines[1].start[4]==-3 and lines[1].finish[4]==2,
 "Up pointer must use plain continuous chevron segments")
tip:RotateArrow(2)
assert(lines[1].finish[3]==-2 and lines[1].finish[4]==0,
 "native arrow rotation must update the QUI pointer direction")
local backdrop=skin.GetBackdrop(tip)
tip.BG:SetAlpha(1)
assert(tip.BG:GetAlpha()==0,"native callout background refresh must remain suppressed")
assert(not tip.BG:IsShown() and tip.BG.texture=="",
 "native gradient background must be cleared, not merely alpha-clamped")
local reused={rotation=4,hideArrow=true}
tip:Init(reused)
assert(not tip.Arrow:IsShown() and tip.Arrow.Arrow:GetAlpha()==0 and tip.CloseButton.Texture:GetAlpha()==0,
 "pooled reset must preserve native hidden-arrow state and suppress restored artwork")
assert(skin.GetFrameData(tip.Arrow,"qHelpTipPointer")==lines and skin.GetBackdrop(tip)==backdrop,
 "pooled tutorial reuse must not accumulate pointer or panel regions")
color[1]=.9;_G.HelpTip:Show()
assert(shows==1 and lines[1].color[1]==.9,"active HelpTips must follow native Show and theme refresh")
assert(tip.CloseButton:GetScript("OnClick")==acknowledge and tip.OkayButton:GetScript("OnClick")==acknowledge
 and tip.info==reused and acknowledges==0,"all native acknowledgement and progress state must remain intact")
enabled=false
local fresh=frame();active={fresh};_G.HelpTip:Show()
assert(not skin.GetBackdrop(fresh),"disabled tooltip skin must leave fresh HelpTips native")
print("HelpTip skin passed")
