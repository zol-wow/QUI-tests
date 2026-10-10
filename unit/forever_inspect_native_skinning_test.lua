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
local shared = read(corpus .. "Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua")
assert(loadstring(slice(shared, "SidePanelTabButtonMixin =", "function PanelTemplates_Tab_OnClick(")))()
local harness = Harness.Build()
harness.profile.general.skinInspectFrame = true
local frame = harness.NewFrame("Frame", "InspectFrame")
_G.InspectFrame = frame
frame.ModeTabs = { Tabs = {} }
frame.CloseButton = harness.NewFrame("Button", nil, frame)
local xml = read(corpus .. "Blizzard_InspectUI/Camelot/Blizzard_InspectUI.xml")
for name, id in xml:gmatch('<Frame name="(InspectFrameModeTab%d+)" parentArray="Tabs".- id="(%d+)"') do
    local tab = harness.NewFrame("Frame", name, frame)
    tab:SetID(tonumber(id))
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Mask = tab:CreateTexture(nil, "ARTWORK")
    tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
    tab.SelectedTexture:SetShown(id == "1")
    for method, fn in pairs(_G.SidePanelTabButtonMixin) do tab[method] = fn end
    function tab:HasScript(script) return script ~= "OnClick" end
    tab:SetScript("OnMouseUp", tab.OnMouseUp)
    frame.ModeTabs.Tabs[#frame.ModeTabs.Tabs + 1] = tab
end
assert(#frame.ModeTabs.Tabs == 3, "Forever exposes three native inspect side tabs")
local paperDoll = harness.NewFrame("Frame", "InspectPaperDollFrame", frame)
_G.InspectPaperDollFrame = paperDoll
_G.InspectPaperDollItemsFrame = harness.NewFrame("Frame", "InspectPaperDollItemsFrame", paperDoll)
paperDoll.InspectTalents = harness.NewFrame("Button", nil, paperDoll)
paperDoll.InspectTalents.DisabledTexture = false
local setup
harness.SkinBase.OnAddOnLoaded = function(_, callback) setup = callback end
assert(loadfile(arg[1] or "modules/skinning/frames/inspect.lua"))("QUI", harness.ns)
setup()
assert(harness.SkinBase.IsStyled(paperDoll.InspectTalents), "Camelot paper-doll talents button must be skinned")
for _, tab in ipairs(frame.ModeTabs.Tabs) do
    assert(harness.SkinBase.IsStyled(tab), "the visible inspect side tabs must be skinned")
    assert(tab.Icon:GetAlpha() == 1 and tab.Mask:GetAlpha() == 1, "inspect portrait and mask must survive")
    assert(tab:GetScript("OnMouseUp") == tab.OnMouseUp, "inspect native mouse-release routing must survive")
end
local tab = frame.ModeTabs.Tabs[3]
tab:SetChecked(true)
assert(harness.SkinBase.GetFrameData(tab, "tabChecked"), "inspect selected side tab must follow native SetChecked")
local source = read("modules/skinning/character_pane/inspect.lua")
local reposition = assert(loadstring(slice(source, "local function RepositionInspectTabs()", "local function ResetInspectTabsPosition()")
    .. "\nreturn RepositionInspectTabs"))()
_G.InspectTrinket1Slot = harness.NewFrame("Button", "InspectTrinket1Slot", paperDoll)
reposition()
assert(paperDoll.InspectTalents.points[1][2] == _G.InspectTrinket1Slot, "enhanced Inspect layout must place the actual Camelot talents button")
local slotXML = read(corpus .. "Blizzard_InspectUI/Camelot/InspectPaperDollFrame.xml")
assert(slotXML:find('name="InspectRangedSlot"', 1, true), "native inspect exposes a ranged slot")
local slot = harness.NewFrame("Button", "InspectRangedSlot", paperDoll)
slot.BorderFrame = harness.NewFrame("Frame", nil, slot)
local gearRing = slot.BorderFrame:CreateTexture(nil, "BACKGROUND")
slot.Icon = slot:CreateTexture(nil, "ARTWORK")
local state = {}
local env = setmetatable({ frameState = state, EMPTY = {},
    GetState = function(value) state[value] = state[value] or {}; return state[value] end,
    GetSkinBase = function() return harness.SkinBase end,
    ApplyOnePixelBorder = function() end,
}, { __index = _G })
local skinSlot = assert(loadstring(slice(source, "local function SkinInspectEquipmentSlot(slot)",
    "local function UpdateInspectSlotBorder(slot, unit)") .. "\nreturn SkinInspectEquipmentSlot"))
setfenv(skinSlot, env)
skinSlot()(slot)
assert(gearRing:GetAlpha() == 0 and slot.Icon:GetAlpha() == 1,
    "enhanced inspect must hide child gear art while preserving inventory icons")
print("OK: forever_inspect_native_skinning_test")
