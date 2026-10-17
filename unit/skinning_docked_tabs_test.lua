local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local owner = env.NewFrame("Frame")
owner.selectedTab = 1
local tabs = {}
local clicks = 0
for i = 1, 3 do
    local tab = env.NewFrame("Button", nil, owner)
    tab:SetID(i)
    tab.Text = tab:CreateFontString()
    tab.SetTabSelected = function(self, selected) self.isSelected = selected end
    tab:SetScript("OnClick", function() clicks = clicks + 1 end)
    tabs[i] = tab
end
env.SkinBase.SkinTabGroup(tabs, owner, { resizeToText = true, dockBottom = true })
local point, relative, relativePoint, x, y = tabs[1]:GetPoint()
assert(point == "TOPLEFT" and relative == owner and relativePoint == "BOTTOMLEFT" and x == 12 and y == 1,
    "first footer tab must join the window's bottom edge")
local _, previous, edge, gap = tabs[2]:GetPoint()
assert(previous == tabs[1] and edge == "TOPRIGHT" and gap == -1,
    "adjacent footer tabs must share one physical border")
assert(env.SkinBase.GetFrameData(tabs[1], "tabWindowJoin"), "footer tabs must cover their top seam with the window")
tabs[1]:SetTabSelected(true)
tabs[2]:SetTabSelected(false)
for _, tab in ipairs(tabs) do
    local join = env.SkinBase.GetFrameData(tab, "tabWindowJoin")
    assert(join:IsShown() and join:GetAlpha() == 1, "native tab selection must preserve the window join")
end
tabs[1]:Fire("OnClick")
assert(clicks == 1, "docked tabs must preserve native clicks")
tabs[2]:Hide()
owner:Fire("OnShow")
assert(select(2, tabs[3]:GetPoint()) == tabs[1], "hidden tabs must not leave a gap in the joined strip")
print("OK: skinning_docked_tabs_test")
