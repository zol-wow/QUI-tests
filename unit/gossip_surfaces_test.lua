local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinGossip = true
_G.CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do result[key] = value end end
    return result
end
_G.FlagsUtil = {IsAnySet = function() return false end}
_G.bit = {bor = function() return 3 end}
_G.Enum = {GossipOptionRecFlags = {QuestLabelPrepend = 1, PlayMovieLabelPrepend = 2}}
_G.IGNORED_QUEST_DISPLAY, _G.TRIVIAL_QUEST_DISPLAY, _G.NORMAL_QUEST_DISPLAY =
    "|cff414141%s|r", "|cff414141%s|r", "|cff000000%s|r"
local actions = 0
local rank, available, maximum = 1, true, false
_G.C_GossipInfo = {
    SelectAvailableQuest = function() actions = actions + 1 end,
    SelectActiveQuest = function() actions = actions + 1 end,
    SelectOptionByIndex = function() actions = actions + 1 end,
    GetFriendshipReputation = function()
        if not available then return {} end
        return {friendshipFactionID = 99, texture = "native-friend", reactionThreshold = 100,
            nextThreshold = not maximum and 200 or nil, standing = 150}
    end,
    GetFriendshipReputationRanks = function() return {currentLevel = rank, maxLevel = 4} end,
}
for index, name in ipairs({"PURE_RED_COLOR", "FACTION_ORANGE_COLOR", "FACTION_YELLOW_COLOR", "FACTION_GREEN_COLOR"}) do
    _G[name] = {GetRGBA = function() return index / 4, 0.25, 0.5, 1 end}
end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/FriendshipStatusBar.lua"))()
local frame = env.NewFrame("Frame", "GossipFrame")
_G.GossipFrame = frame
frame.Background = frame:CreateTexture()
local greeting = env.NewFrame("Frame", nil, frame)
frame.GreetingPanel = greeting
local materials = {}
for index = 1, 4 do materials[index] = greeting:CreateTexture() end
local goodbye = env.NewFrame("Button", nil, greeting)
goodbye.DisabledTexture = false
goodbye:SetScript("OnClick", function() actions = actions + 1 end)
local click = goodbye:GetScript("OnClick")
greeting.GoodbyeButton = goodbye
greeting.ScrollBar = false
local rows = {}
local function row(mixin)
    local widget = env.NewFrame("Button", nil, greeting)
    widget.DisabledTexture = false
    widget.Text = widget:CreateFontString()
    function widget:GetFontString() return self.Text end
    widget.Icon = widget:CreateTexture()
    widget.Icon:SetHeight(16)
    function widget:SetText(text) self.text = text; self.Text:SetText(text) end
    function widget:GetText() return self.text end
    function widget:SetFormattedText(format, text) self:SetText(string.format(format, text)) end
    function widget:GetTextHeight() return 12 end
    for key, value in pairs(_G.GossipSharedTitleButtonMixin) do widget[key] = value end
    for key, value in pairs(mixin) do widget[key] = value end
    widget:SetScript("OnClick", mixin.OnClick)
    rows[#rows + 1] = widget
    return widget
end
local option = row(_G.GossipOptionButtonMixin)
local quest = row(_G.GossipSharedAvailableQuestButtonMixin)
option:Setup({orderIndex = 3, flags = 0, name = "|cffff9900Native option|r", icon = "native-option", spellID = 42})
quest:Setup({questID = 123, title = "Native quest", isTrivial = true})
local optionClick, questClick = option:GetScript("OnClick"), quest:GetScript("OnClick")
greeting.ScrollBox = {ForEachFrame = function(_, fn) for _, widget in ipairs(rows) do fn(widget) end end}
skin.HookScrollBoxRowFonts = function() end
local acquired
skin.HookScrollBoxAcquired = function(_, fn) acquired = fn end
local bar = env.NewFrame("StatusBar", nil, frame)
frame.FriendshipStatusBar = bar
bar:SetFrameLevel(5)
bar.Bar = bar:CreateTexture()
bar.icon = bar:CreateTexture()
for _, key in ipairs({"BarBorder", "BarRingBackground", "BarCircle"}) do bar[key] = bar:CreateTexture() end
local notches = {}
for index = 1, 4 do notches[index] = bar:CreateTexture(); bar["Notch" .. index] = notches[index] end
local background = bar:CreateTexture()
function background:GetDrawLayer() return "BACKGROUND" end
function bar:GetStatusBarTexture() return self.Bar end
function bar:SetStatusBarTexture(path) self.Bar:SetTexture(path) end
function bar:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function bar:SetValue(value) self.value = value end
function bar:SetStatusBarColor(...) self.nativeColor = {...} end
function bar:CreateMaskTexture()
    local mask = self:CreateTexture()
    mask.kind = "MaskTexture"
    return mask
end
local masks = 0
function bar.Bar:AddMaskTexture() masks = masks + 1 end
for key, value in pairs(_G.NPCFriendshipStatusBarMixin) do bar[key] = value end
bar:SetScript("OnEnter", _G.NPCFriendshipStatusBarMixin.OnEnter)
local tooltip = bar:GetScript("OnEnter")
function frame:HandleShow()
    self.Background:SetAlpha(1)
    for _, material in ipairs(materials) do material:SetAlpha(1) end
    bar:Update()
end
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_UIPanels_Game" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinGossip" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
assert(skin.IsStyled(goodbye), "native Goodbye action must be styled")
assert(skin.GetBackdrop(option)._quiRoundedSurface and skin.GetBackdrop(quest)._quiRoundedSurface,
    "native option and quest rows must have rounded interactive surfaces")
assert(option:GetText() == "|cFFff9900Native option|r" and option.Icon.texture == "native-option"
    and option:GetID() == 3 and option.spellID == 42, "native option identity, art and semantic colors must survive")
assert(quest:GetText() == "|cFF7b8489Native quest|r" and quest.Icon.vertex[1] == 0.5
    and quest:GetID() == 123, "trivial quest text must remain distinguishable with native icon tint")
assert(goodbye:GetScript("OnClick") == click and option:GetScript("OnClick") == optionClick
    and quest:GetScript("OnClick") == questClick, "native actions must retain ownership")
local shell = skin.GetBackdrop(bar)
assert(shell._quiRoundedSurface.radius == 3 and shell:GetFrameLevel() < bar:GetFrameLevel(),
    "friendship shell must sit behind the native status bar")
for index = 1, 4 do
    rank = index
    frame:HandleShow()
    assert(bar.nativeColor[1] == index / 4 and bar.value == 150 and bar.minimum == 100 and bar.maximum == 200,
        "native friendship rank color and progress must remain authoritative")
    assert(bar.icon.texture == "native-friend" and bar:IsShown(), "native friendship identity/visibility must survive")
    assert(frame.Background:GetAlpha() == 0 and background:GetAlpha() == 0, "theme scenery must remain suppressed")
    for _, material in ipairs(materials) do assert(material:GetAlpha() == 0, "greeting materials must remain suppressed") end
    for _, notch in ipairs(notches) do assert(notch:GetAlpha() == 1, "semantic rank dividers must remain visible") end
end
maximum = true
bar:Update()
assert(bar.value == 1 and bar.minimum == 0 and bar.maximum == 1, "maximum friendship rank must remain full")
available = false
bar:Update()
assert(not bar:IsShown(), "absent friendship must remain hidden")
refresh()
assert(not bar:IsShown() and bar:GetScript("OnEnter") == tooltip and masks == 1 and skin.GetBackdrop(bar) == shell,
    "theme refresh must preserve native visibility/tooltips and reuse shell/mask")
option:Setup({orderIndex = 8, flags = 0, name = "|cff000000Recycled option|r", icon = "replacement", spellID = 9})
acquired(option)
assert(option:GetID() == 8 and option.Icon.texture == "replacement" and option:GetText() == "|cFFffffffRecycled option|r",
    "pooled option setup must retain current data and normalize native black text")
assert(actions == 0, "styling must not invoke gameplay selections or dismissal")
print("OK: gossip_surfaces_test")
