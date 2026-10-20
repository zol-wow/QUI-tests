local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
_G.InCombatLockdown = function() return true end
assert(loadfile("core/uikit.lua"))("QUI", env.ns)
env.SkinBase = env.ns.SkinBase
env.profile.general.skinPVPMatch = true
_G.PVPMatchResults = env.NewFrame("Frame")
local frame = _G.PVPMatchResults
frame:Hide()
_G.PVPMatchScoreboard = env.NewFrame("Frame")
local scoreboard = _G.PVPMatchScoreboard
scoreboard.Content, scoreboard.content, scoreboard.buttonContainer = false, false, false
scoreboard:Hide()
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
local loaded
env.SkinBase.OnAddOnLoaded = function(_, callback) loaded = callback end
assert(loadfile(os.getenv("QUI_PVPMATCH_SOURCE") or "modules/skinning/frames/pvpmatch.lua"))("QUI", env.ns)
loaded()
loaded()
assert(not env.SkinBase.IsSkinned(frame) and not env.SkinBase.IsSkinned(scoreboard),
    "hidden PvP windows must not skin during addon loading")
assert(frame.content.Background:GetAlpha() == 1 and not acquired,
    "hidden results must defer content styling and pooled row hooks")
assert(#frame.hooks.OnShow == 1 and #scoreboard.hooks.OnShow == 1,
    "duplicate loading must share one first-show hook per window")
frame:Show()
assert(env.SkinBase.IsSkinned(frame) and not env.SkinBase.IsSkinned(scoreboard),
    "opening results in combat must skin results while the hidden scoreboard stays deferred")
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
env.profile.general.skinPVPMatch = false
scoreboard:Show()
assert(not env.SkinBase.IsSkinned(scoreboard), "first-show callback must respect the current setting")
env.profile.general.skinPVPMatch = true
loaded()
assert(env.SkinBase.IsSkinned(scoreboard), "already-visible scoreboard must initialize during combat")
local showHooks = #scoreboard.hooks.OnShow
scoreboard:Hide()
scoreboard:Show()
loaded()
assert(#scoreboard.hooks.OnShow == showHooks, "reopening must reuse initialization hooks")
print("OK: pvpmatch_inner_controls_test")
