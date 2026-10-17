local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local owner = env.NewFrame("Frame")
owner.selectedTab = 1
local tabs = {}
for i = 1, 3 do
    tabs[i] = env.NewFrame("Button", nil, owner)
    tabs[i]:SetID(i)
end
tabs[3].isSelected = true
env.SkinBase.SetFrameData(tabs[3], "tabChecked", true)
env.SkinBase.SkinTabGroup(tabs, owner, {})
assert(env.SkinBase.GetFrameData(tabs[1], "tabUnderline"):IsShown(), "Character must show its active underline")
assert(not env.SkinBase.GetFrameData(tabs[3], "tabUnderline"):IsShown(), "stale Currency flags must not override the window selection")
owner.Tabs = { tabs[3], tabs[2], tabs[1] }
owner.selectedTab = 3
for _, tab in ipairs(tabs) do env.SkinBase.RefreshTabSelected(tab, owner) end
assert(not env.SkinBase.GetFrameData(tabs[1], "tabUnderline"):IsShown(), "Character underline must clear when Currency is selected")
assert(env.SkinBase.GetFrameData(tabs[3], "tabUnderline"):IsShown(), "Currency must show its active underline")
print("OK character_tab_selection_owner_test")
