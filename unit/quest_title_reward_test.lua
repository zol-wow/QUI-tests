local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local native = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
local branch = assert(native:match("if %( playerTitle %) then.-\n\tend"))
local populate = assert(loadstring("return function(rewardsFrame, playerTitle, AddHeaderElement, BeginRewardsSection, AddRewardElement) "
    .. branch .. " end"))()
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}; rewards.PlayerTitleText = rewards:CreateFontString()
_G.QuestInfoFrame = { rewardsFrame = rewards }
local title = env.NewFrame("Frame", nil, rewards); rewards.TitleFrame = title
title:SetSize(500, 39)
title.Icon = title:CreateTexture(); title.Icon:SetTexture("Interface/Icons/INV_Misc_Note_02")
title.Icon:SetSize(39, 39); title.Icon:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
title.Icon:SetTexCoord(0, 1, 0, 1)
for i, key in ipairs({"FrameLeft", "FrameCenter", "FrameRight"}) do
    local t = title:CreateTexture(); title[key] = t
    t:SetTexture("Interface/QuestFrame/UI-QuestItemNameFrame")
    t:SetSize(({4, 200, 11})[i], 40)
    t:SetPoint("LEFT", i == 1 and title.Icon or title[({"FrameLeft", "FrameCenter"})[i - 1]], "RIGHT", i == 1 and 2 or 0, 0)
end
title.Name = title:CreateFontString(); title.Name:SetPoint("LEFT", title.FrameLeft, "LEFT", 8, -2)
title.Name:SetTextColor(.8, .3, 1, 1)
local masks = 0
function title:CreateMaskTexture() masks = masks + 1; return env.NewTexture(self, "MaskTexture") end
function title.Icon:AddMaskTexture(mask) self.mask = mask end
local headerCalls, sectionCalls, layoutCalls = 0, 0, 0
local function setTitle(value)
    populate(rewards, value,
        function(header) headerCalls = headerCalls + 1; header:Show() end,
        function() sectionCalls = sectionCalls + 1 end,
        function(frame) layoutCalls = layoutCalls + 1; frame:Show() end)
end
setTitle("First title")
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
local backdrop = skin.GetBackdrop(title)
assert(backdrop and backdrop._quiRoundedSurface, "Quest title reward must receive rounded contained chrome")
assert(backdrop.points[1][2] == title.Icon and backdrop.points[2][2] == title.FrameRight,
    "title chrome must follow native icon/nameplate bounds rather than the 500px layout frame")
for _, key in ipairs({"FrameLeft", "FrameCenter", "FrameRight"}) do
    assert(title[key]:GetAlpha() == 0 and title[key].texture == "Interface/QuestFrame/UI-QuestItemNameFrame",
        "native title material must be suppressed while its layout anchors remain")
end
assert(title:GetWidth() == 500 and title:GetHeight() == 39 and title.FrameCenter:GetWidth() == 200
    and title.Name.points[1][2] == title.FrameLeft, "native title layout/text anchors must remain")
assert(title.Icon.texture == "Interface/Icons/INV_Misc_Note_02" and title.Icon.texCoord[1] == 0 and title.Icon.mask
    and title.Name.textColor[1] == .8, "native title artwork, UVs and semantic text color must remain")
setTitle(nil)
registry.skinQuest.refresh()
assert(not title:IsShown() and not rewards.PlayerTitleText:IsShown(), "native absent-title branch must remain hidden")
setTitle("Second title")
registry.skinQuest.refresh()
assert(title:IsShown() and title.Name:GetText() == "Second title" and skin.GetBackdrop(title) == backdrop and masks == 1,
    "native title reuse/theme must retain text, visibility and cached surfaces")
assert(headerCalls == 2 and sectionCalls == 2 and layoutCalls == 2, "styling must not invoke native layout callbacks")
title.FrameLeft:SetAlpha(1)
assert(title.FrameLeft:GetAlpha() == 0, "native material alpha reuse must stay suppressed")
env.profile.general.skinQuest = false
local fresh = env.NewFrame("Frame", nil, rewards); fresh.Icon = fresh:CreateTexture(); fresh.FrameRight = fresh:CreateTexture()
rewards.TitleFrame = fresh
registry.skinQuest.refresh()
assert(not skin.GetBackdrop(fresh), "disabled title rewards must remain native")
env.profile.general.skinQuest = true
fresh.IsForbidden = function() return true end
registry.skinQuest.refresh()
assert(not skin.GetBackdrop(fresh), "forbidden title rewards must remain native")
print("Quest title reward native branch passed")
