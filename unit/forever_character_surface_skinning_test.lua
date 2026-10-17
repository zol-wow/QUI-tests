local Harness = assert(loadfile("tests/helpers/character_chrome_harness.lua"))()
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local function slice(source, first, after)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(after, start + #first, true), after)
    return source:sub(start, finish - 1)
end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
local nativeSource = read(corpus .. "Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua")
local shared = read(corpus .. "Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua")
assert(loadstring(slice(shared, "SidePanelTabButtonMixin =", "function PanelTemplates_Tab_OnClick(")))()
_G.PlaySound = function() end
_G.SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 }
_G.STAT_FORMAT = "%s:"
_G.format = string.format
_G.PAPERDOLL_STATINFO = {}
_G.CharacterStatFrameMixin = {}
_G.CreateFromMixins = function(source) return source or {} end
assert(loadstring(slice(nativeSource, "CharacterStatFrameCategoryScrollBoxElementMixin =", "CharacterStatFrameScrollBoxIconElementMixin =")))()
local harness = Harness.Build()
harness.ns.Client = { isForever = true }
local function newFrame(...)
    local frame = harness.NewFrame(...)
    frame.RegisterForWidgetSet = false
    return frame
end
if arg[1] then assert(loadfile(arg[1]))("QUI", harness.ns) end
local chrome = harness.ns.CharacterChrome
local skin = harness.SkinBase
harness.SetGates(true, false)
local character = harness.BuildCharacterFrame()
character.LeftPaneHost = newFrame("Frame", nil, character)
character.RightPaneHost = newFrame("Frame", nil, character)
local leftArt = character.LeftPaneHost:CreateTexture(nil, "BACKGROUND")
local rightArt = character.RightPaneHost:CreateTexture(nil, "BACKGROUND")
character.ModeTabs = { Tabs = {} }
local characterXML = read(corpus .. "Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml")
for name, id in characterXML:gmatch('<Frame name="(CharacterFrameModeTab%d+)" parentArray="Tabs".- id="(%d+)"') do
    local tab = newFrame("Frame", name, character)
    tab:SetID(tonumber(id))
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Mask = tab:CreateTexture(nil, "ARTWORK")
    tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
    tab.SelectedTexture:SetShown(id == "1")
    tab.Background = tab:CreateTexture(nil, "BACKGROUND")
    for method, fn in pairs(_G.SidePanelTabButtonMixin) do tab[method] = fn end
    function tab:HasScript(script) return script ~= "OnClick" end
    tab:SetScript("OnMouseUp", tab.OnMouseUp)
    character.ModeTabs.Tabs[#character.ModeTabs.Tabs + 1] = tab
end
assert(#character.ModeTabs.Tabs == 6, "the corpus exposes six Character mode tabs")
local rowsByScrollBox, callbacks = {}, {}
_G.ScrollUtil.AddAcquiredFrameCallback = function(box, callback) callbacks[box] = callback end
local function scrollBox(parent)
    local box = newFrame("Frame", nil, parent)
    rowsByScrollBox[box] = {}
    function box:HasView() return true end
    function box:ForEachFrame(callback)
        for _, row in ipairs(rowsByScrollBox[self]) do callback(row) end
    end
    return box
end
local nativePane = newFrame("Frame", nil, character)
nativePane.ScrollBox = scrollBox(nativePane)
nativePane.Border = nativePane:CreateTexture(nil, "BORDER")
local petPane = newFrame("Frame", nil, character)
petPane.ScrollBox = scrollBox(petPane)
_G.CharacterStatsPanePetScrollBox = petPane
local slotArt = {}
local paperXML = read(corpus .. "Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml")
for _, name in ipairs({ "CharacterRangedSlot", "CharacterAmmoSlot", "CharacterHeadSlot" }) do
    assert(paperXML:find('name="' .. name .. '"', 1, true), "equipment slot must exist in the corpus")
    local slot = newFrame("Button", name, character)
    slot.BorderFrame = newFrame("Frame", nil, slot)
    slotArt[slot] = slot.BorderFrame:CreateTexture(nil, "BACKGROUND")
    slot.Icon = slot:CreateTexture(nil, "ARTWORK")
    _G[name] = slot
end
function character:GetStatsPane() return nativePane end
assert(loadstring("CharacterFrameMixin = {}\n" .. slice(nativeSource,
    "function CharacterFrameMixin:ShowSubFrame(", "local CharacterFrameEvents =")))()
character.ShowSubFrame = _G.CharacterFrameMixin.ShowSubFrame
_G.CHARACTERFRAME_SUBFRAMES = { "PaperDollFrame", "ReputationFrame", "TokenFrame", "PVPRankFrame", "SkillsFrame", "StatisticsFrame" }
for _, name in ipairs(_G.CHARACTERFRAME_SUBFRAMES) do
    _G[name] = _G[name] or newFrame("Frame", name, character)
end
chrome.Initialize()
harness.RunTimers()
for slot, art in pairs(slotArt) do
    assert(chrome.GetSlotBorder(slot) and art:GetAlpha() == 0,
        "native ranged/ammo slots and child gear rings must receive chrome-only skin")
    assert(slot.Icon:GetAlpha() == 1, "gear-ring skin must preserve the inventory icon")
end
for _, tab in ipairs(character.ModeTabs.Tabs) do
    assert(skin.IsStyled(tab), "every native Character mode tab must be styled")
    assert(tab.Icon:GetAlpha() == 1 and tab.Mask:GetAlpha() == 1, "native tab icons and masks must survive")
    assert(tab:GetScript("OnMouseUp") == tab.OnMouseUp, "native mouse-release handler must survive")
end
local tab = character.ModeTabs.Tabs[6]
tab:SetCustomOnMouseUpHandler(function(self) self:SetChecked(true) end)
tab:Fire("OnMouseUp", "LeftButton", true)
assert(skin.GetFrameData(tab, "tabChecked") == true, "native SetChecked must update skinned selection")
assert(leftArt:GetAlpha() == 0 and rightArt:GetAlpha() == 0, "shared Camelot pane artwork must yield to the skin")
chrome.SetExtended(true)
character:ShowSubFrame("SkillsFrame")
assert(#chrome.GetShell().points == 0 and chrome.GetShell().allPoints == character,
    "all native non-character modes must shrink the shell")
local header = newFrame("Frame", nil, nativePane.ScrollBox)
header.Title = header:CreateFontString(nil, "ARTWORK")
header.Background = header:CreateTexture(nil, "BACKGROUND")
_G.CharacterStatFrameCategoryScrollBoxElementMixin.Init(header, { name = "Resistance" })
callbacks[nativePane.ScrollBox](nativePane.ScrollBox, header)
local row = newFrame("Frame", nil, nativePane.ScrollBox)
row.Label = row:CreateFontString(nil, "ARTWORK")
row.Value = row:CreateFontString(nil, "ARTWORK")
row.Background = row:CreateTexture(nil, "BACKGROUND")
_G.CharacterStatFrameScrollBoxBaseElementMixin.Init(row, { statIndex = 1, labelText = "Fire", valueText = "42" })
callbacks[nativePane.ScrollBox](nativePane.ScrollBox, row)
harness.RunTimers()
assert(header.Title.font == "QUIFont.ttf", "native ScrollBox category headers must be skinned")
assert(row.Label.font == "QUIFont.ttf" and row.Value.font == "QUIFont.ttf", "native resistance rows must be skinned without the legacy stat writer")
assert(row.Value.text == "42" and row.Label.text == "Fire:", "skinning must preserve native stat values")
local petRow = newFrame("Frame", nil, petPane.ScrollBox)
petRow.Label = petRow:CreateFontString(nil, "ARTWORK")
petRow.Value = petRow:CreateFontString(nil, "ARTWORK")
petRow.Background = petRow:CreateTexture(nil, "BACKGROUND")
_G.CharacterStatFrameScrollBoxBaseElementMixin.Init(petRow, { statIndex = 1, labelText = "Pet Fire", valueText = "27" })
callbacks[petPane.ScrollBox](petPane.ScrollBox, petRow)
harness.RunTimers()
assert(petRow.Value.font == "QUIFont.ttf" and petRow.Value.text == "27", "native pet resistance rows must be skinned")
local scratch = _G.CharacterStatsPane.statsFramePool:Acquire()
_G.PaperDollFrame_SetLabelAndText(scratch, "scratch", "0")
assert(scratch.Value.font == nil, "hidden legacy scratch rows must retain native ownership on Camelot")
local addonCallbacks = {}
skin.OnAddOnLoaded = function(name, callback) addonCallbacks[name] = callback end
local function sidePane(parent)
    local pane = newFrame("Frame", nil, parent)
    pane.Title = pane:CreateFontString(nil, "ARTWORK")
    pane.Content = newFrame("Frame", nil, pane)
    function pane:Refresh()
        local reward = newFrame("Frame", nil, self.Content)
        reward.Label = reward:CreateFontString(nil, "ARTWORK")
        reward.Label:SetTextColor(0.1, 0.8, 0.2, 1)
        self.lastReward = reward
    end
    return pane
end
_G.SkillsFrame.ScrollBox = scrollBox(_G.SkillsFrame)
_G.SkillsFrame.SkillDetailFrame = sidePane(_G.SkillsFrame)
_G.PVPRankFrame.DetailFrame = sidePane(_G.PVPRankFrame)
_G.TokenFrame.DetailFrame = sidePane(_G.TokenFrame)
local transfer = newFrame("Button", nil, _G.TokenFrame.DetailFrame)
transfer.Text = transfer:CreateFontString(nil, "ARTWORK")
_G.TokenFrame.DetailFrame.CurrencyTransferToggleButton = transfer
assert(loadfile(arg[2] or "modules/skinning/frames/character.lua"))("QUI", harness.ns)
addonCallbacks.Blizzard_UIPanels_Game()
for _, pane in ipairs({ _G.SkillsFrame.SkillDetailFrame, _G.PVPRankFrame.DetailFrame, _G.TokenFrame.DetailFrame }) do
    assert(pane.Title.font == "QUIFont.ttf", "native side panes must use the skin font")
    pane:Refresh()
    assert(pane.lastReward.Label.font == "QUIFont.ttf", "new dynamic native side-pane rows must be styled")
    assert(pane.lastReward.Label.textColor[2] == 0.8, "native reward semantic colors must survive")
end
assert(transfer.Text.font == nil and not skin.IsStyled(transfer), "currency transfer controls must retain native ownership")
_G.StatisticsFrame.ScrollBox = scrollBox(_G.StatisticsFrame)
addonCallbacks.Blizzard_Statistics()
assert(callbacks[_G.StatisticsFrame.ScrollBox], "late Statistics load must install its pooled-row hook")
local statistic = newFrame("Button", nil, _G.StatisticsFrame.ScrollBox)
statistic.Content = newFrame("Frame", nil, statistic)
statistic.Content.Name = statistic.Content:CreateFontString(nil, "ARTWORK")
statistic.Content.Value = statistic.Content:CreateFontString(nil, "ARTWORK")
statistic.Content.Value:SetTextColor(0.2, 0.3, 0.4, 1)
callbacks[_G.StatisticsFrame.ScrollBox](_G.StatisticsFrame.ScrollBox, statistic)
harness.RunTimers()
assert(statistic.Content.Value.font == "QUIFont.ttf", "late Statistics rows must use the skin font")
assert(statistic.Content.Value.textColor[2] == 0.3, "Statistics value colors must survive")
print("OK: forever_character_surface_skinning_test")
