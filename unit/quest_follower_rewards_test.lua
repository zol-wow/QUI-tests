local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local quest = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
local body = assert(quest:match("(local followerFrame = rewardsFrame.followerRewardPool:Acquire%b().-followerFrame:Show%b())"))
local populate = assert(loadstring("return function(rewardsFrame, spellInfo) " .. body .. " return followerFrame end"))()
local portraitSource = read("tests/framexml/Interface/AddOns/Blizzard_GarrisonBase/GarrisonBaseUtils.lua")
_G.GarrisonFollowerPortraitMixin = {}
for _, method in ipairs({"SetPortraitIcon", "SetQuality", "SetQualityColor", "SetNoLevel", "SetLevel", "SetILevel", "SetupPortrait"}) do
    assert(loadstring(assert(portraitSource:match("(function GarrisonFollowerPortraitMixin:" .. method .. "%b().-\nend)"))))()
end
_G.AdventuresLevelPortraitMixin = {}
local adventure = read("tests/framexml/Interface/AddOns/Blizzard_GarrisonBase/AdventuresFollowerTooltip.lua")
assert(loadstring(assert(adventure:match("(function AdventuresLevelPortraitMixin:SetupPortrait%b().-\nend)"))))()
_G.Enum = { GarrFollowerQuality = {Title = 6}, GarrisonFollowerType = {FollowerType_9_0_GarrisonFollower = 9} }
_G.GarrisonFollowerOptions = {[1] = {showILevelOnFollower = false, minQualityLevelToShowLevel = 2}}
_G.ColorManager = { GetColorDataForFollowerQuality = function() return {r = .8, g = .3, b = 1} end }
_G.GARRISON_FOLLOWER_ITEM_LEVEL = "Item level %d"
local info = {
    [1] = {name = "Follower", portraitIconID = 111, quality = 4, followerTypeID = 1, level = 100, classAtlas = "class-mage"},
    [2] = {name = "Companion", portraitIconID = 222, quality = 4, followerTypeID = 9, level = 60},
}
_G.C_Garrison = { GetFollowerInfo = function(id) return info[id] end,
    GetFollowerLinkByID = function() error("ordinary hover/click must not request links") end }
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = {rewardsFrame = rewards}
local rows, reuse = {}, nil
local pool = {}; rewards.followerRewardPool = pool
function pool:EnumerateActive() return pairs(rows) end
function pool:Acquire()
    local b = reuse; local isNew = b == nil; reuse = nil
    if not b then
        b = env.NewFrame("Button", nil, rewards); b.DisabledTexture = false; b:SetSize(144, 55)
        b.BG = b:CreateTexture(); b.BG:SetAtlas("GarrMission_FollowerListButton")
        b.Class = b:CreateTexture(); b.Class:SetAlpha(.2); b.Name = b:CreateFontString()
        local p = env.NewFrame("Frame", nil, b); b.PortraitFrame = p; p.RegisterForWidgetSet = false
        p:SetSize(52, 60); p:SetScale(.8)
        for _, key in ipairs({"Portrait", "PortraitRing", "PortraitRingQuality", "LevelBorder", "PortraitRingCover"}) do p[key] = p:CreateTexture() end
        p.Level = p:CreateFontString()
        function p.Level:SetFormattedText(pattern, value) self:SetText(string.format(pattern, value)) end
        for key, method in pairs(_G.GarrisonFollowerPortraitMixin) do p[key] = method end
        local a = env.NewFrame("Frame", nil, b); b.AdventuresFollowerPortraitFrame = a; a.RegisterForWidgetSet = false
        a:SetSize(54, 54); a:SetScale(.8); a.Portrait = a:CreateTexture(); a.PuckBorder = a:CreateTexture()
        a.LevelDisplayFrame = env.NewFrame("Frame", nil, a); a.LevelDisplayFrame.RegisterForWidgetSet = false
        a.LevelDisplayFrame.LevelText = a.LevelDisplayFrame:CreateFontString()
        a.SetupPortrait = _G.AdventuresLevelPortraitMixin.SetupPortrait
    end
    rows[b] = b; return b, isNew
end
function pool:ReleaseAll() for b in pairs(rows) do b:Hide(); rows[b] = nil; reuse = b end end
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == pool and method == "Acquire" then
        local acquire = target[method]
        target[method] = function(...) local b, isNew = acquire(...); callback(...); return b, isNew end
    else originalHook(target, method, callback) end
end
local xml = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.xml")
local template = assert(xml:match('<Button name="QuestInfoRewardFollowerCodeTemplate".-</Button>'))
local scripts = {}
for _, script in ipairs({"OnEnter", "OnClick", "OnLeave"}) do
    local nativeBody = assert(template:match("<" .. script .. ">(.-)</" .. script .. ">"))
    scripts[script] = assert(loadstring("return function(self) " .. nativeBody .. " end"))()
end
_G.GarrisonFollowerTooltip = env.NewFrame("Frame")
_G.GarrisonFollowerTooltipTemplate_BuildDefaultDataForID = function(id) return {id = id} end
local tooltipID
_G.GarrisonFollowerTooltip_ShowWithData = function(data) tooltipID = data.id; _G.GarrisonFollowerTooltip:Show() end
_G.IsModifiedClick = function() return false end
_G.ChatFrameUtil = {InsertLink = function() error("styling must not send chat links") end}
local first = populate(rewards, {garrFollowerID = 1})
for key, script in pairs(scripts) do first:SetScript(key, script) end
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
assert(skin.GetBackdrop(first) and skin.GetBackdrop(first)._quiRoundedSurface and first.BG:GetAlpha() == 0,
    "pooled follower rows must receive rounded chrome and suppress native row decoration")
assert(first.Class.atlas == "class-mage" and first.Class:GetAlpha() == .2 and first.Name:GetText() == "Follower",
    "native class art/name must remain")
local p = first.PortraitFrame
assert(p:IsShown() and not first.AdventuresFollowerPortraitFrame:IsShown() and p.Portrait.texture == 111
    and p.Level:GetText() == 100 and p.PortraitRingQuality.vertex[1] == .8 and p.LevelBorder:IsShown(),
    "native follower portrait, quality and level visibility must remain")
first:Fire("OnEnter"); first:Fire("OnClick")
assert(tooltipID == 1 and _G.GarrisonFollowerTooltip:IsShown(), "native follower tooltip identity must remain")
first:Fire("OnLeave"); assert(not _G.GarrisonFollowerTooltip:IsShown())
local backdrop, click = skin.GetBackdrop(first), first:GetScript("OnClick")
pool:ReleaseAll()
local companion = populate(rewards, {garrFollowerID = 2}); registry.skinQuest.refresh()
assert(companion == first and not p:IsShown() and companion.AdventuresFollowerPortraitFrame:IsShown()
    and companion.AdventuresFollowerPortraitFrame.Portrait.texture == 222
    and companion.AdventuresFollowerPortraitFrame.LevelDisplayFrame.LevelText:GetText() == 60,
    "native pooled companion switch must retain portrait/level/visibility")
assert(skin.GetBackdrop(first) == backdrop and first:GetScript("OnClick") == click and first:GetWidth() == 144
    and p:GetWidth() == 52 and p.scale == .8, "theme must retain surfaces, geometry, scale and handlers")
info[1].isTroop = true
p:SetupPortrait(info[1])
assert(not p.Level:IsShown() and not p.LevelBorder:IsShown(), "native troop must suppress level display")
info[1].isTroop = false; info[1].iLevel = 700
p:SetupPortrait(info[1], true)
assert(p.Level:GetText() == "Item level 700" and p.LevelBorder:GetWidth() == 70, "native item-level format/geometry must remain")
info[1].quality = 6
p:SetupPortrait(info[1])
assert(not p.PortraitRingQuality:IsShown() and p.LevelBorder.atlas == "legionmission-portraitring_levelborder_epicplus",
    "native title-quality portrait decoration must remain")
env.profile.general.skinQuest = false
local fresh = populate(rewards, {garrFollowerID = 1})
assert(not skin.GetBackdrop(fresh) and fresh.BG:GetAlpha() == 1, "disabled fresh follower must remain native")
env.profile.general.skinQuest = true; root.IsForbidden = function() return true end
local forbidden = populate(rewards, {garrFollowerID = 2})
assert(not skin.GetBackdrop(forbidden), "forbidden root must exclude follower acquisition")
print("Quest follower reward native portraits passed")
