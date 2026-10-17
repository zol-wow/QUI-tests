local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local f = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua"))
local native = f:read("*a"); f:close()
assert(loadstring(assert(native:match("(function QuestInfoItem_OnClick%b().-\nend)"))))()
_G.QuestInfoRewardItemMixin = {}
assert(loadstring(assert(native:match("(function QuestInfoRewardItemMixin:OnClick%b().-\nend)"))))()
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = {rewardsFrame = rewards, chooseItems = true, itemChoice = 0}
local highlight = env.NewFrame("Frame", "QuestInfoItemHighlight", rewards)
_G.QuestInfoItemHighlight = highlight; rewards.ItemHighlight = highlight
highlight:SetSize(256, 64); highlight:Hide()
function highlight:SetPoint(point, ...)
    for index, entry in ipairs(self.points) do
        if entry[1] == point then self.points[index] = {point, ...}; return end
    end
    self.points[#self.points + 1] = {point, ...}
end
local material = highlight:CreateTexture(); material:SetTexture("Interface/QuestFrame/UI-QuestItemHighlight")
local function row(id, kind, parent)
    local b = env.NewFrame("Button", nil, parent or rewards)
    b.type = kind or "choice"; b.objectType = "item"; b:SetID(id); b:SetSize(200, 40)
    return b
end
local a, b = row(1), row(2)
local modified, links = false, {}
_G.IsModifiedClick = function() return modified end
_G.GetQuestItemLink = function(kind, id) return kind .. ":" .. id end
_G.GetQuestLogItemLink = function(kind, id) return "log:" .. kind .. ":" .. id end
_G.HandleModifiedItemClick = function(link) links[#links + 1] = link end
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
_G.QuestInfoRewardItemMixin.OnClick(a, "LeftButton")
local backdrop = skin.GetBackdrop(highlight)
assert(backdrop and backdrop._quiRoundedSurface and backdrop.points[1][2] == a and backdrop.points[2][2] == a,
    "quest selection must use rounded chrome contained within the chosen reward")
assert(_G.QuestInfoFrame.itemChoice == 1 and highlight:IsShown() and material:GetAlpha() == 0,
    "native choice identity/show lifecycle must remain while legacy highlight art is suppressed")
assert(highlight:GetWidth() == 256 and highlight:GetHeight() == 64 and highlight.points[#highlight.points][4] == -8
    and a:GetWidth() == 200 and a:GetHeight() == 40 and material.texture == "Interface/QuestFrame/UI-QuestItemHighlight",
    "reward geometry and native texture identity must remain")
_G.QuestInfoRewardItemMixin.OnClick(b, "LeftButton")
assert(_G.QuestInfoFrame.itemChoice == 2 and backdrop.points[1][2] == b and backdrop.points[2][2] == b and skin.GetBackdrop(highlight) == backdrop,
    "selection changes must follow the new row and reuse the surface")
registry.skinQuest.refresh()
assert(backdrop.points[1][2] == b and backdrop.points[2][2] == b and highlight:IsShown(),
    "theme refresh must track the current native selected anchor")
material:SetAlpha(1)
assert(material:GetAlpha() == 0, "native highlight material reuse must remain suppressed")
modified = true
_G.QuestInfoRewardItemMixin.OnClick(a, "LeftButton")
_G.QuestInfoFrame.questLog = true
_G.QuestInfoRewardItemMixin.OnClick(a, "LeftButton")
assert(#links == 2 and links[1] == "choice:1" and links[2] == "log:choice:1"
    and _G.QuestInfoFrame.itemChoice == 2 and backdrop.points[1][2] == b and backdrop.points[2][2] == b,
    "native modified click must retain both link paths without changing selection")
modified = false
_G.QuestInfoRewardItemMixin.OnClick(row(3, "reward"), "LeftButton")
_G.QuestInfoFrame.chooseItems = false
_G.QuestInfoRewardItemMixin.OnClick(a, "LeftButton")
assert(_G.QuestInfoFrame.itemChoice == 2 and backdrop.points[1][2] == b and backdrop.points[2][2] == b, "nonchoice/unavailable selection must remain native")
_G.QuestInfoFrame.chooseItems = true
local hideBody = assert(native:match("(QuestInfoFrame.itemChoice = 0;\n\tif %( rewardsFrame.ItemHighlight %) then.-\n\tend)"))
assert(loadstring("return function(rewardsFrame) " .. hideBody .. " end"))()(rewards)
registry.skinQuest.refresh()
assert(not highlight:IsShown() and _G.QuestInfoFrame.itemChoice == 0 and #links == 2,
    "native reward reset and theme refresh must not select, show, or invoke links")
env.profile.general.skinQuest = false
_G.QuestInfoItem_OnClick(a)
assert(_G.QuestInfoFrame.itemChoice == 1 and highlight.points[#highlight.points][2] == a
    and highlight.points[#highlight.points][4] == -8, "disabled skin must retain native click anchoring")
env.profile.general.skinQuest = true
root.IsForbidden = function() return true end
_G.QuestInfoItem_OnClick(b)
assert(highlight.points[#highlight.points][4] == -8, "forbidden root must stop selection overrides")
root.IsForbidden = function() return false end
local outside = row(4, "choice", _G.UIParent)
_G.QuestInfoItem_OnClick(outside)
assert(highlight.points[#highlight.points][2] == outside and highlight.points[#highlight.points][4] == -8,
    "shared reward frames outside NPC quest ownership must retain native anchoring")
print("Quest reward native selection passed")
