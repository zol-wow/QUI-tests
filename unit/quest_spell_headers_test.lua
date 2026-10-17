local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local source = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
local nativeBody = assert(source:match("(local header = rewardsFrame.spellHeaderPool:Acquire%b().-AddHeaderElement%b(header%))"))
local populate = assert(loadstring("return function(rewardsFrame, spellBucketType, AddHeaderElement) " .. nativeBody .. " return header end"))()
_G.QUEST_INFO_SPELL_REWARD_TO_HEADER = {[1] = "Learned spells", [2] = "Follower rewards"}
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = {rewardsFrame = rewards}
local active, released = {}, {}
local pool = {textR = 0, textG = 0, textB = 0}; rewards.spellHeaderPool = pool
function pool:EnumerateActive() return pairs(active) end
function pool:Acquire()
    local h = table.remove(released); local isNew = h == nil
    if not h then
        h = rewards:CreateFontString(); h:SetFont("NativeFont.ttf", 14, "OUTLINE"); h:SetSize(285, 20)
        h:SetPoint("TOPLEFT", rewards, "TOPLEFT", 0, -5)
        h.fontObjectCalls = 0
        function h:SetFontObject(font) self.nativeFontObject = font; self.fontObjectCalls = self.fontObjectCalls + 1 end
    end
    active[h] = h; return h, isNew
end
function pool:ReleaseAll()
    for h in pairs(active) do h:Hide(); active[h] = nil; released[#released + 1] = h end
end
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == pool and method == "Acquire" then
        local acquire = target[method]
        target[method] = function(...) local h, isNew = acquire(...); callback(...); return h, isNew end
    else originalHook(target, method, callback) end
end
local layoutCalls = 0
local function layout() layoutCalls = layoutCalls + 1 end
local first = populate(rewards, 1, layout)
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
assert(first.vertex[1] == .92 and first.font == "QUIFont.ttf", "pooled quest headers must use neutral QUI text/font")
assert(first:GetText() == "Learned spells" and first:GetWidth() == 285 and first.fontSize == 14,
    "native header text, size and layout geometry must remain")
local second = populate(rewards, 2, layout)
assert(second.vertex[1] == .92 and second:GetText() == "Follower rewards" and pool.textR == 0,
    "native post-acquire color reset must be neutralized without changing shared pool color data")
local font = {}; second:SetFontObject(font)
assert(second.fontObjectCalls == 1 and second.nativeFontObject == font and second.font == "QUIFont.ttf",
    "native borrowed-font setter must run once while presentation follows QUI")
pool:ReleaseAll()
local reused = populate(rewards, 1, layout)
local calls = layoutCalls; registry.skinQuest.refresh()
assert(reused:GetText() == "Learned spells" and reused:IsShown() and reused.vertex[1] == .92 and layoutCalls == calls,
    "pool/theme reuse must preserve visibility/text without layout callbacks")
reused.parent = _G.UIParent
reused:SetVertexColor(.2, .3, .4)
assert(reused.vertex[1] == .2, "header reparented outside quest must retain native color")
reused.parent = rewards
env.profile.general.skinQuest = false
reused:SetVertexColor(.1, .2, .3)
assert(reused.vertex[1] == .1, "disabled skin must stop header color overrides")
populate(rewards, 1, layout)
local fresh = populate(rewards, 2, layout)
assert(fresh.font == "NativeFont.ttf" and fresh.vertex[1] == 0, "disabled fresh header must remain native")
env.profile.general.skinQuest = true; root.IsForbidden = function() return true end
fresh:SetVertexColor(.3, .4, .5)
assert(fresh.vertex[1] == .3, "forbidden root must stop header overrides")
print("Quest pooled header native acquisition passed")
