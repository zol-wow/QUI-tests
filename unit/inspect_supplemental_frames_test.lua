local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinInspectFrame=true
_G.NORMAL_FONT_COLOR={r=1,g=.82,b=0}
local function frame(parent) return env.NewFrame("Frame",nil,parent) end
local root=frame();_G.InspectFrame=root;root.unit="target";root.CloseButton=false
local guild=frame(root);_G.InspectGuildFrame=guild
_G.InspectGuildFrameBG=guild:CreateTexture();_G.InspectGuildFrameBG:SetTexture("native-parchment")
local function text(owner,color)
 local fs=owner:CreateFontString();fs:SetFont("Native text",14,"");fs:SetTextColor(unpack(color or {1,.82,0,1}))
 function fs:SetFormattedText(pattern,...) self:SetText(string.format(pattern,...)) end
 return fs
end
for _,key in ipairs({"guildName","guildRealmName","guildLevel","guildNumMembers"}) do guild[key]=text(guild) end
guild.Points=frame(guild)
for _,key in ipairs({"LeftCap","RightCap","Icon"}) do
 guild.Points[key]=guild.Points:CreateTexture();guild.Points[key]:SetWidth(key=="Icon" and 28 or 46)
end
guild.Points.SumText=text(guild.Points,{0,1,0,1})
for _,key in ipairs({"TabardLeftIcon","TabardRightIcon","Banner","BannerBorder"}) do
 _G["InspectGuildFrame"..key]=guild:CreateTexture()
end
local pvp=frame(root);_G.InspectPVPFrame=pvp;pvp.BG=pvp:CreateTexture();pvp.SmallWreath=pvp:CreateTexture()
pvp.HKs=text(pvp,{1,1,1,1});pvp.HonorLevel=text(pvp)
pvp.Slots={}
for _,key in ipairs({"RatedBG","Arena2v2","Arena3v3","RatedSoloShuffle","RatedBGBlitz"}) do
 local row=frame(pvp);pvp[key]=row
 for _,field in ipairs({"BGType","RatingLabel","Rating","RecordLabel","Record"}) do row[field]=text(row) end
end
pvp.RatedBG.Rating:SetTextColor(1,.1,.1,1)
local guildUpdates,tabards=0,0
_G.C_PaperDollInfo={GetInspectGuildInfo=function(unit) assert(unit=="target");guildUpdates=guildUpdates+1;return 55,12,"Native Guild","Realm" end,
 GetInspectRatedBGData=function() return {rating=1800,won=8,played=10} end,
 GetInspectRatedSoloShuffleData=function() return {rating=1700,roundsWon=10,roundsPlayed=12} end,
 GetInspectRatedBGBlitzData=function() return {rating=1600,gamesWon=6,gamesPlayed=9} end}
_G.UnitFactionGroup=function() return "Alliance","Alliance" end
_G.UnitLevel=function() return 90 end
_G.INSPECT_GUILD_REALM="Realm: %s";_G.INSPECT_GUILD_FACTION="Faction: %s";_G.INSPECT_GUILD_NUM_MEMBERS="Members: %d"
_G.SetDoubleGuildTabardTextures=function(_,left,right,banner,border)
 tabards=tabards+1;left:SetTexture("native-left");right:SetTexture("native-right");banner:SetTexture("native-banner");border:SetTexture("native-banner-border")
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local native=read("tests/framexml/Interface/AddOns/Blizzard_InspectUI/Mainline/InspectGuildFrame.lua")
assert(loadstring(assert(native:match("(function InspectGuildFrame_Update%b().-\nend)"))))()
native=read("tests/framexml/Interface/AddOns/Blizzard_InspectUI/Mainline/InspectPVPFrame.lua")
local onload=assert(native:match("(function InspectPVPFrame_OnLoad%b().-\nend)"))
local update=assert(native:match("(function InspectPVPFrame_Update%b().-\nend)"))
assert(loadstring("local arenaFrames;\n"..onload.."\n"..update))()
_G.INSPECTED_UNIT="target";_G.MAX_ARENA_TEAMS=2
_G.INSPECT_HONORABLE_KILLS="Kills: %d";_G.HONOR_LEVEL_LABEL="Honor: %d";_G.PVP_RECORD_DESCRIPTION="%d/%d"
_G.GetInspectHonorData=function() return nil,nil,nil,nil,300,nil,15 end
_G.GetInspectArenaData=function(index) return 1500+index,10,7,0,0 end
local allowed=true
_G.C_SpecializationInfo={CanPlayerUsePVPTalentUI=function() return allowed end,GetActiveSpecGroup=function() return 1 end}
_G.InspectPVPFrame_OnLoad(pvp);_G.InspectGuildFrame_Update();_G.InspectPVPFrame_Update()
local before=guildUpdates
local setup;skin.OnAddOnLoaded=function(_,fn) setup=fn end
assert(loadfile(arg[1] or "modules/skinning/frames/inspect.lua"))("QUI",ns);setup()
assert(_G.InspectGuildFrameBG:GetAlpha()==0 and pvp.BG:GetAlpha()==0,"inspect supplemental native backgrounds must be suppressed")
assert(guild.guildName:GetFont()==ns.Helpers.GetGeneralFont() and guild.guildName:GetText()=="Native Guild"
 and guild.guildName.textColor[1]==.92,"guild title must use QUI font and neutral caption color")
assert(guild.Points.LeftCap:GetAlpha()==0 and guild.Points.RightCap:GetAlpha()==0
 and guild.Points.Icon:GetAlpha()==1 and guild.Points.SumText.textColor[2]==1,"decorative points caps must clear while achievement icon and green sum remain")
assert(_G.InspectGuildFrameBannerBorder.texture=="native-banner-border" and _G.InspectGuildFrameBannerBorder:GetAlpha()==1
 and _G.InspectGuildFrameTabardLeftIcon.texture=="native-left","native tabard identity art must remain")
assert(pvp.RatedBG.Rating:GetText()==1800 and pvp.RatedBG.Rating.textColor[2]==.1
 and pvp.RatedSoloShuffle.Record:GetText()=="10/2","native rating/record values and semantic colors must remain")
local width=guild.Points:GetWidth()
_G.InspectGuildFrame_Update();_G.InspectPVPFrame_Update();_G.QUI_RefreshInspectColors()
assert(guild.Points:GetWidth()==width and guildUpdates==before+1 and tabards==2,
 "skin refresh must preserve native measured points layout without guild data/tabard updates")
allowed=false;_G.InspectPVPFrame_Update();_G.QUI_RefreshInspectColors()
assert(not pvp.RatedBG:IsShown() and not pvp.Arena2v2:IsShown() and not pvp.HonorLevel:IsShown(),
 "native PvP eligibility visibility must remain")
guild.IsForbidden=function() return true end;guild.guildName:SetFont("Forbidden guild",14,"")
_G.QUI_RefreshInspectColors()
assert(guild.guildName:GetFont()=="Forbidden guild","forbidden guild pane must stop styling")
print("inspect supplemental frames passed")
