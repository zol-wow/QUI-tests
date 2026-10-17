local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local Skin = env.SkinBase
env.profile.general.skinAchievement = true
local callback
Skin.OnAddOnLoaded = function(_, fn) callback = fn end
local function Frame(kind, name, parent)
    local widget = env.NewFrame(kind or "Frame", name, parent)
    setmetatable(widget, {__index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end})
    return widget
end
local frame = Frame("Frame", "AchievementFrame")
_G.AchievementFrame = frame
frame.HeaderDetails = Frame(nil, nil, frame)
frame.HeaderDetails.Back = Frame("Button", nil, frame.HeaderDetails)
frame.HeaderDetails.Filters = Frame(nil, nil, frame.HeaderDetails)
local filters = frame.HeaderDetails.Filters
filters.SearchBox = Frame("EditBox", nil, filters)
filters.FilterDropdown = Frame("DropdownButton", nil, filters)
filters.FilterDropdown.Text = filters.FilterDropdown:CreateFontString()
filters.FilterDropdown.Text:SetTextColor(1, 0.82, 0, 1)
local preview = Frame("Frame", nil, filters.SearchBox)
filters.SearchBox.SearchPreviewContainer = preview
preview.Background = preview:CreateTexture()
preview.BorderAnchor = preview:CreateTexture()
preview.searchPreviews = {}
for i = 1, 5 do
    local result = Frame("Button", nil, preview)
    result.Icon = result:CreateTexture()
    result.Icon:SetTexture("native-result-icon-" .. i)
    result.IconFrame = result:CreateTexture()
    result.SelectedTexture = result:CreateTexture()
    result.Name = result:CreateFontString()
    result.achievementID = i
    result:SetScript("OnClick", function(owner) owner.clicked = owner.achievementID end)
    result.SelectedTexture:SetShown(i == 1)
    preview.searchPreviews[i] = result
end
preview.ShowAllSearchResults = Frame("Button", nil, preview)
preview.ShowAllSearchResults.Text = preview.ShowAllSearchResults:CreateFontString()
preview.ShowAllSearchResults.SelectedTexture = preview.ShowAllSearchResults:CreateTexture()
preview.ShowAllSearchResults.SelectedTexture:Hide()
_G.AchievementFrame_ShowSearchPreviewResults = function(count)
    for i, result in ipairs(preview.searchPreviews) do result:SetShown(i <= count) end
    preview.ShowAllSearchResults:SetShown(count > 5)
end
frame.SearchResults = Frame("Frame", nil, frame)
frame.SearchResults.Background = frame.SearchResults:CreateTexture()
frame.SearchResults.TitleText = frame.SearchResults:CreateFontString()
local summary = Frame("Frame", "AchievementFrameSummary", frame)
_G.AchievementFrameSummary = summary
summary.Background = summary:CreateTexture()
local row = Frame("Button", nil, summary)
row.GetElementData = false
row.IsSelected = function(owner)
    assert(type(owner.GetElementData) == "function", "released rows cannot query intrusive selection")
    return owner:GetElementData().selected
end
row.Background = row:CreateTexture()
row.Description = row:CreateFontString()
row.Label = row:CreateFontString()
row.PlusMinus = row:CreateTexture()
row.PlusMinus:SetTexture("native-achievement-plus-minus")
function row.PlusMinus:SetDesaturated(value) self.desaturated = value end
_G.AchievementTemplateMixin = {
    Saturate = function() end,
    UpdatePlusMinusTexture = function(owner, expanded, shown)
        owner.PlusMinus:SetTexCoord(0, 0.5, expanded and 0.25 or 0, expanded and 0.5 or 0.25)
        owner.PlusMinus:SetShown(shown)
        owner.PlusMinus:SetDesaturated(false)
        owner.PlusMinus:SetVertexColor(1, 0.82, 0, 1)
    end,
}
_G.AchievementFrameSummaryAchievements = {buttons = {row}}
local recentHeader = Frame("Frame", "AchievementFrameSummaryAchievementsHeader", summary)
_G.AchievementFrameSummaryAchievementsHeader = recentHeader
local recentTitle = recentHeader:CreateFontString()
_G.AchievementFrameSummaryAchievementsHeaderTitle = recentTitle
local emptyText = summary:CreateFontString()
_G.AchievementFrameSummaryAchievementsEmptyText = emptyText
emptyText:Hide()
_G.AchievementFrameSummary_UpdateAchievements = function(hasRecent)
    emptyText:SetShown(not hasRecent)
end
for i = 1, 3 do
    local tab = Frame("Button", "AchievementFrameTab" .. i, frame)
    tab.Text = tab:CreateFontString()
    tab.Text:SetText(({"Achievements", "Guild", "Statistics"})[i])
    tab.id = i
    _G["AchievementFrameTab" .. i] = tab
end
local stats = Frame("Frame", "AchievementFrameStats", frame)
_G.AchievementFrameStats = stats
local acquired
stats.ScrollBox = Frame("Frame", nil, stats)
function stats.ScrollBox:HasView() return true end
function stats.ScrollBox:ForEachFrame() end
_G.ScrollUtil.AddAcquiredFrameCallback = function(scrollBox, fn)
    if scrollBox == stats.ScrollBox then acquired = fn end
end
local statsBG = Frame("Frame", "AchievementFrameStatsBG", stats)
_G.AchievementFrameStatsBG = statsBG
local parchment = statsBG:CreateTexture()

local statRow = Frame("Button", nil, stats)
for _, key in ipairs({"Background", "Left", "Middle", "Right"}) do statRow[key] = statRow:CreateTexture() end
for _, key in ipairs({"Title", "Text", "Value"}) do statRow[key] = statRow:CreateFontString() end
_G.AchievementStatTemplateMixin = {Init = function(owner, header)
    owner.isHeader = header
    owner.Background:SetAlpha(1)
    owner.Left:Show()
    owner.Title:SetTextColor(1, 0.8, 0, 1)
    owner.Value:SetTextColor(1, 0.8, 0, 1)
end}
local comparison = Frame("Frame", "AchievementFrameComparison", frame)
_G.AchievementFrameComparison = comparison
comparison.Watermark = comparison:CreateTexture()
comparison.Dark = comparison:CreateTexture()
local compareRow = Frame("Frame", nil, comparison)
for _, key in ipairs({"Player", "Friend"}) do
    local side = Frame("Frame", nil, compareRow)
    compareRow[key] = side
    for _, texture in ipairs({"Background", "TitleBar", "Glow"}) do side[texture] = side:CreateTexture() end
    for _, text in ipairs({"Label", "Description", "DateCompleted", "Status"}) do side[text] = side:CreateFontString() end
    side.Icon = Frame("Frame", nil, side)
    side.Icon.texture = side.Icon:CreateTexture()
    side.Icon.texture:SetTexture("comparison-native-art")
    side.Shield = Frame("Frame", nil, side)
    side.Shield.Points = side.Shield:CreateFontString()
end
local compareStat = Frame("Frame", nil, comparison)
for _, key in ipairs({"Background", "Left", "Middle", "Right", "Left2", "Middle2", "Right2"}) do compareStat[key] = compareStat:CreateTexture() end
for _, key in ipairs({"Title", "Text", "Value", "FriendValue"}) do compareStat[key] = compareStat:CreateFontString() end
for _, key in ipairs({"AchievementContainer", "StatContainer"}) do
    local panel = Frame("Frame", nil, comparison)
    comparison[key] = panel
    panel.ScrollBox = Frame("Frame", nil, panel)
    function panel.ScrollBox:HasView() return true end
    function panel.ScrollBox:ForEachFrame(fn) fn(key == "AchievementContainer" and compareRow or compareStat) end
end
_G.AchievementComparisonTemplateMixin = {Init = function(owner, id)
    owner.id = id
    for _, side in ipairs({owner.Player, owner.Friend}) do
        side.Background:SetAlpha(1)
        side.Description:SetTextColor(0, 0, 0, 1)
    end
    owner.Player.Description:SetText("native-description-" .. id)
    owner.Friend.Status:SetText("native-date-" .. id)
end}
_G.AchivementComparisonStatMixin = {Init = function(owner, header)
    owner.isHeader = header
    owner.Left2:SetAlpha(1)
    owner.FriendValue:SetText("native-friend-stat")
end}
_G.AchievementFrameComparisonHeader = Frame("Frame", "AchievementFrameComparisonHeader", comparison)
_G.AchievementFrameComparisonHeaderBG = _G.AchievementFrameComparisonHeader:CreateTexture()
_G.AchievementFrameComparisonHeaderPortrait = _G.AchievementFrameComparisonHeader:CreateTexture()
_G.AchievementFrameComparisonHeaderPortrait:SetTexture("native-portrait")
_G.AchievementFrameComparisonHeaderName = _G.AchievementFrameComparisonHeader:CreateFontString()
assert(loadfile(os.getenv("QUI_ACHIEVEMENT_SOURCE") or "modules/skinning/frames/achievement.lua"))("QUI", env.ns)
callback()
assert(preview.Background:GetAlpha() == 0 and preview.BorderAnchor:GetAlpha() == 0, "search popup must suppress native background and corners")
local first = preview.searchPreviews[1]
assert(first.IconFrame:GetAlpha() == 0 and first.Icon.texture == "native-result-icon-1", "search must suppress ornamental icon frame and preserve native art")
assert(first.SelectedTexture:IsShown() and not preview.searchPreviews[2].SelectedTexture:IsShown(), "native keyboard selection visibility must remain intact")
first:Fire("OnClick")
assert(first.clicked == 1, "search click handler and achievement ID must remain native")
_G.AchievementFrame_ShowSearchPreviewResults(2)
local previewBD = Skin.GetBackdrop(preview)
assert(previewBD.points[2][2] == preview.searchPreviews[2], "popup backdrop must follow last visible result rather than fixed preview height")
_G.AchievementFrame_ShowSearchPreviewResults(10)
assert(previewBD.points[2][2] == preview.ShowAllSearchResults, "popup must include Show All when present")
assert(frame.SearchResults.Background:GetAlpha() == 0 and Skin.GetBackdrop(frame.SearchResults), "full results need QUI chrome")
_G.QUI_RefreshAchievementColors()
assert(first.Icon.texture == "native-result-icon-1" and first.SelectedTexture:IsShown(), "theme refresh must preserve result art and keyboard selection")
assert(summary.Background:GetAlpha() == 0, "summary parchment must be replaced by a QUI surface")
assert(Skin.GetBackdrop(summary), "summary must have a rounded inner surface")
assert(row.Background:GetAlpha() == 0, "recent achievements must not retain parchment")
assert(Skin.GetBackdrop(row), "recent achievement rows must have QUI surfaces")
assert(Skin.GetBackdrop(filters.SearchBox) and Skin.GetBackdrop(filters.FilterDropdown), "search and filter must share QUI control styling")
local fr, fg, fb = filters.FilterDropdown.Text:GetTextColor()
assert(fr == 0.95 and fg == 0.95 and fb == 0.95, "filter chrome label must be neutral")
for _, expanded in ipairs({false, true}) do
    _G.AchievementTemplateMixin.UpdatePlusMinusTexture(row, expanded, true)
    assert(row.PlusMinus.desaturated and row.PlusMinus.vertex[3] == 1, "native expansion art must remain neutral after state changes")
    assert(row.PlusMinus.texture == "native-achievement-plus-minus" and row.PlusMinus:IsShown(), "expansion texture and visibility must remain native")
    assert(row.PlusMinus.texCoord[3] == (expanded and 0.25 or 0), "native plus and minus coordinates must remain intact")
end
_G.AchievementTemplateMixin.UpdatePlusMinusTexture(row, false, false)
assert(not row.PlusMinus:IsShown(), "rows without expandable criteria must keep the native hidden state")
assert(_G.AchievementFrameTab1:GetWidth() >= 140, "bottom tabs must fit full labels")
_G.AchievementStatTemplateMixin.Init(statRow, true)
assert(parchment:GetAlpha() == 0, "named Statistics background must suppress its native parchment")
assert(statRow.Left:GetAlpha() == 0 and statRow.Background:GetAlpha() == 0, "statistic headers must suppress native parchment after Init")
assert(Skin.GetBackdrop(statRow), "statistic rows need QUI rounded surfaces")
local r, g, b = statRow.Title:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "statistic header text must be neutral")
_G.AchievementStatTemplateMixin.Init(statRow, false)
assert(statRow.Background:GetAlpha() == 0, "recycled value rows must suppress restored native stripes")
r, g, b = statRow.Value:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "statistic values must remain readable after native Init")
_G.AchievementFrameSummary_UpdateAchievements(false)
local point = emptyText.points[1]
assert(point[1] == "CENTER" and point[2] == recentHeader,
    "empty summary text must occupy the heading instead of overlaying the first suggested row")
assert(not recentTitle:IsShown(), "empty state must replace the recent-achievements heading")
assert(row:IsShown(), "suggested achievement rows must retain their native visibility")
_G.AchievementFrameSummary_UpdateAchievements(true)
assert(recentTitle:IsShown() and not emptyText:IsShown(),
    "recent achievement updates must restore the normal heading without stale empty text")
for _ = 1, 3 do stats:Fire("OnShow") end
env.RunTimers()
local backdropCalls = 0
local createBackdrop = Skin.CreateBackdrop
Skin.CreateBackdrop = function(owner, ...)
    if owner == statRow then backdropCalls = backdropCalls + 1 end
    return createBackdrop(owner, ...)
end
assert(acquired, "statistics must register acquired row styling")
acquired(stats.ScrollBox, statRow)
env.RunTimers()
Skin.CreateBackdrop = createBackdrop
assert(backdropCalls == 1, "reopening statistics must style each acquired row once")
_G.AchievementComparisonTemplateMixin.Init(compareRow, 123)
assert(compareRow.Player.Background:GetAlpha() == 0 and compareRow.Friend.Background:GetAlpha() == 0,
    "both comparison columns must suppress native parchment after Init")
assert(Skin.GetBackdrop(compareRow.Player) and Skin.GetBackdrop(compareRow.Friend), "both comparison columns need rounded QUI rows")
local cr, cg, cb = compareRow.Player.Description:GetTextColor()
assert(cr > 0.8 and cg > 0.8 and cb > 0.8, "completed comparison descriptions must remain readable")
_G.AchievementComparisonTemplateMixin.Init(compareRow, 456)
assert(compareRow.id == 456 and compareRow.Player.Description:GetText() == "native-description-456"
    and compareRow.Friend.Status:GetText() == "native-date-456", "pooled comparison data must remain native")
assert(compareRow.Player.Icon.texture.texture == "comparison-native-art", "comparison icon art must be preserved")
_G.AchivementComparisonStatMixin.Init(compareStat, true)
assert(compareStat.Left2:GetAlpha() == 0 and Skin.GetBackdrop(compareStat), "comparison statistic headers need QUI chrome in both columns")
assert(compareStat.FriendValue:GetText() == "native-friend-stat", "native friend statistic must remain intact")
comparison.Watermark:Show()
assert(comparison.Watermark:GetAlpha() == 0 and Skin.GetBackdrop(comparison), "comparison shell watermark must remain hidden after native Show")
assert(_G.AchievementFrameComparisonHeaderBG:GetAlpha() == 0
    and _G.AchievementFrameComparisonHeaderPortrait.texture == "native-portrait", "comparison header must remove decoration and preserve portrait")
print("OK: achievement_inner_surfaces_test")
