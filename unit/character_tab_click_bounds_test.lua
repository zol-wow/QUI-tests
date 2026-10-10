local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local frame = env.BuildCharacterFrame()
local function Read(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end
local native = Read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/CharacterFrame.lua")
local bounds = assert(native:match("(function CharacterFrameMixin:UpdateTabBounds%(%)%s.-)\nfunction CharacterFrameMixin:OnShow"))
_G.CharacterFrameMixin = {}
_G.min = math.min
assert(loadstring("local function CompareFrameSize(a,b) return a:GetWidth() > b:GetWidth() end\n" .. bounds))()
frame.UpdateTabBounds = _G.CharacterFrameMixin.UpdateTabBounds
frame.GetRight = function() return 540 end
frame.Tabs = {}
frame.numTabs, frame.selectedTab = 3, 1
for i = 1, 3 do
    local tab = env.NewFrame("Button", "CharacterFrameTab" .. i, frame)
    tab.id = i
    tab.Text = tab:CreateFontString()
    tab.Text:SetText(({"Character", "Reputation", "Currency"})[i])
    tab.GetRight = function() return 595 end
    tab.Enable = function(self) self.enabled = true end
    tab.Disable = function(self) self.enabled = false end
    tab.IsEnabled = function(self) return self.enabled end
    frame.Tabs[i] = tab
    _G["CharacterFrameTab" .. i] = tab
end
local panel = Read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua")
local update = assert(panel:match("(local function GetTabByIndex%(.-)\nfunction PanelTemplates_GetTabWidth"))
_G.PanelTemplates_SelectTab = function(tab) tab:Disable() end
_G.PanelTemplates_DeselectTab = function(tab) tab:Enable() end
_G.PanelTemplates_SetDisabledTabState = function(tab) tab:Disable() end
_G.PanelTemplates_TabResize = function(tab, padding) tab:SetWidth(tab:GetWidth() + padding) end
assert(loadstring(update))()
assert(env.Chrome.Initialize())
for _, selected in ipairs({1, 2, 3, 1}) do
    frame.selectedTab = selected
    CharacterFrameTab1:SetWidth(192)
    CharacterFrameTab2:SetWidth(194)
    CharacterFrameTab3:SetWidth(193)
    frame:UpdateTabBounds()
    _G.PanelTemplates_UpdateTabs(frame)
    for i, tab in ipairs(frame.Tabs) do
        assert(tab:GetID() == i, "native width sorting must not corrupt Character tab ID order")
        assert(tab:IsEnabled() == (i ~= selected), "only the selected Character tab may be disabled")
    end
    assert(CharacterFrameTab1:GetWidth() == CharacterFrameTab3:GetWidth(), "native width adjustment must retain integrated tab widths")
end
print("OK: character_tab_click_bounds_test")
