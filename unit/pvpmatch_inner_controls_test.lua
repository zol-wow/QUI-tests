local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinPVPMatch = true
_G.PVPMatchResults = env.NewFrame("Frame")
local frame = _G.PVPMatchResults
frame.Content = false
frame.content = env.NewFrame("Frame", nil, frame)
frame.content.Background = frame.content:CreateTexture()
frame.content.Background:SetAtlas("pvpscoreboard-background")
frame.content.ScrollBar, frame.content.ScrollBox = false, false
frame.content.scrollBar = false
frame.content.scrollBox = env.NewFrame("Frame", nil, frame.content)
function frame.content.scrollBox:HasView() return true end
function frame.content.scrollBox:ForEachFrame() end
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback = function(scrollBox, fn)
    if scrollBox == frame.content.scrollBox then acquired = fn end
end
frame.content.TabContainer = false
frame.content.tabContainer = env.NewFrame("Frame", nil, frame.content)
local container = frame.content.tabContainer
container.TabGroup = false
container.tabGroup = env.NewFrame("Frame", nil, container)
for i = 1, 3 do
    local tab = env.NewFrame("Button", nil, container.tabGroup)
    tab:SetID(i)
    container.tabGroup["Tab" .. i] = false
    container.tabGroup["tab" .. i] = tab
end
frame.buttonContainer = env.NewFrame("Frame", nil, frame)
for _, key in ipairs({ "leaveButton", "requeueButton" }) do
    frame.buttonContainer[key] = env.NewFrame("Button", nil, frame.buttonContainer)
    frame.buttonContainer[key].DisabledTexture = false
end
local leave = function() end
frame.buttonContainer.leaveButton:SetScript("OnClick", leave)
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_PVPMATCH_SOURCE") or "modules/skinning/frames/pvpmatch.lua"))("QUI", env.ns)
assert(frame.content.Background:GetAlpha() == 0 and env.SkinBase.GetBackdrop(frame.content)._quiRoundedSurface,
    "scoreboard content must replace native framed art with a rounded QUI panel")
assert(env.SkinBase.GetBackdrop(frame.buttonContainer.leaveButton)._quiRoundedSurface,
    "match actions must use rounded QUI controls")
assert(frame.buttonContainer.leaveButton:GetScript("OnClick") == leave, "match actions must preserve native ownership")
assert(env.SkinBase.GetFrameData(container.tabGroup.tab1, "skinTabOwner") == frame,
    "scoreboard tabs must follow the actual native selection owner")
for _ = 1, 3 do frame:Fire("OnShow") end
env.RunTimers()
local row = env.NewFrame("Button", nil, frame.content.scrollBox)
row.Label = row:CreateFontString()
local fontChecks = 0
local getFrameData = env.SkinBase.GetFrameData
env.SkinBase.GetFrameData = function(owner, key)
    if owner == row and key == "qListRowFonted" then fontChecks = fontChecks + 1 end
    return getFrameData(owner, key)
end
assert(acquired, "match results must register acquired row fonts")
acquired(frame.content.scrollBox, row)
env.SkinBase.GetFrameData = getFrameData
assert(fontChecks == 2, "reopening match results must dispatch each acquired font callback once")
print("OK: pvpmatch_inner_controls_test")
