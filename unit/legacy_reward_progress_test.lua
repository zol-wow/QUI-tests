local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinLegacySystem = true
ns.Helpers.GetSkinBarColor = function() return .9,.1,.1,1 end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyRewardTrack.lua"))()
local root = env.NewFrame("Frame"); root.CloseButton=false; root.Tabs={}; root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root); page.RegisterForWidgetSet=false; root.RewardTrackPage=page
for key, method in pairs(_G.LegacyRewardTrackPageMixin) do page[key]=method end
local bar=env.NewFrame("StatusBar",nil,page); bar.RegisterForWidgetSet=false; page.LegacyRewardProgressBar=bar
bar:SetSize(840,13)
local fill=bar:CreateTexture(); fill:SetAtlas("Legacy-Progressbar-Fill")
function bar:GetStatusBarTexture() return fill end
function bar:SetStatusBarColor(...) self.color={...} end
function bar:SetMinMaxValues(lo,hi) self.range={lo,hi} end
function bar:SetValue(value) self.value=value end
function bar:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
page.ProgressBarBackground=page:CreateTexture(); bar.ProgressBarFrame=bar:CreateTexture()
local function maskStorage(texture)
    texture.masks={}
    function texture:AddMaskTexture(mask) self.masks[mask]=true end
    function texture:RemoveMaskTexture(mask) self.masks[mask]=nil end
end
maskStorage(fill); maskStorage(page.ProgressBarBackground); maskStorage(bar.ProgressBarFrame)
local factory=_G.CreateFrame
_G.CreateFrame=function(kind,name,parent,...)
    local frame=factory(kind,name,parent,...)
    if parent==bar then
        local createTexture=frame.CreateTexture
        frame.CreateTexture=function(self,...)
            local texture=createTexture(self,...);maskStorage(texture);return texture
        end
    end
    return frame
end
local fade=page:CreateTexture()
page.LegacyRewardProgressFrame={ClipFrame={Mask=fade}}
_G.LegacySystem={RegisterCurrencyInfoCallback=function() end}
page:OnLoad()
page.renownLevelsInfo={{level=1},{level=2},{level=3},{level=4}}
page.majorFactionData={renownLevel=2,renownLevelThreshold=100,renownReputationEarned=25}
page:SetupProgressDetails(); local nativeValue=bar.value
page:UpdateProgressBarMask(true)
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
assert(fill.texture=="Interface\\Buttons\\WHITE8x8" and bar.color[1]==.9,
    "legacy reward progress must use shared QUI fill style/color")
assert(page.progressBarMaskTextures[2]==fill and fill.masks[fade] and bar.value==nativeValue and bar:IsShown()
    and bar:GetWidth()==840 and bar:GetHeight()==13,
    "native fade texture identity, value, visibility and geometry must remain")
local chrome=skin.GetBackdrop(bar)
assert(chrome and chrome._quiRoundedSurface and page.ProgressBarBackground:GetAlpha()==0
    and bar.ProgressBarFrame:GetAlpha()==0, "native progress background/frame must receive rounded replacement chrome")
local chromeTextures={}
for _,texture in ipairs({chrome:GetRegions()}) do
    if texture:IsObjectType("Texture") then
        chromeTextures[#chromeTextures+1]=texture
        assert(texture.masks[fade], "new progress chrome must inherit already-active native fade")
    end
end
assert(#chromeTextures>0 and #page.progressBarMaskTextures==3+#chromeTextures,
    "owned chrome textures must extend native mask registry without replacing original references")
local registrySize=#page.progressBarMaskTextures
local round=skin.GetFrameData(bar,"qBarMask")
local count=0; for mask in pairs(fill.masks) do if mask~=fade then round=mask;count=count+1 end end
assert(round and count==1, "rounded fill mask must coexist with native track fade")
page:UpdateProgressBarMask(false)
assert(not fill.masks[fade] and fill.masks[round], "native fade removal must retain QUI rounded mask")
for _,texture in ipairs(chromeTextures) do assert(not texture.masks[fade], "native static mask removal must include owned chrome") end
page.renownLevelsInfo={{level=1},{level=2},{level=3},{level=4},{level=5},{level=6}}
page.centerIndex=3; page.majorFactionData.renownLevel=2
page:SetupProgressDetails()
assert(bar.range[1]==0 and bar.range[2]==100 and bar.value==27,
    "native scrolling-track card-position mapping must remain")
page.majorFactionData.renownLevel=20; page:SetupProgressDetails()
assert(bar.value==100, "native completed visible range must remain full")
page:UpdateProgressBarMask(true); registry.skinLegacySystem.refresh()
assert(fill.masks[round] and fill.masks[fade] and page.progressBarMaskTextures[2]==fill,
    "theme must retain both masks and native stored texture identity")
assert(#page.progressBarMaskTextures==registrySize and skin.GetBackdrop(bar)==chrome,
    "theme must cache chrome and avoid duplicate native mask registration")
for _,texture in ipairs(chromeTextures) do assert(texture.masks[fade], "native scrolling mask addition must include owned chrome") end
env.profile.general.skinLegacySystem=false; fill:SetTexture("Native-disabled")
page:SetupProgressDetails(); assert(fill.texture=="Native-disabled", "disabled fill must stop overrides")
env.profile.general.skinLegacySystem=true; bar.IsForbidden=function() return true end
registry.skinLegacySystem.refresh(); assert(fill.texture=="Native-disabled", "forbidden progress bar must remain native")
bar.IsForbidden=function() return false end; root.IsForbidden=function() return true end
page:SetupProgressDetails(); assert(fill.texture=="Native-disabled", "forbidden root must stop fill overrides")
print("Legacy native reward progress mapping and masks passed")
