local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, Skin = env.ns, env.SkinBase
env.profile.general.skinWorldMap = true
local callbacks, acquiredRows = {}, {}
_G.ScrollUtil.AddAcquiredFrameCallback = function(box, callback) acquiredRows[box] = callback end
Skin.OnAddOnLoaded = function(name, fn) callbacks[name] = fn end
local function Frame(kind, parent)
    local frame = env.NewFrame(kind or "Frame", nil, parent)
    setmetatable(frame, {__index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end})
    return frame
end
local function Texture(parent) return parent:CreateTexture() end
local function Font(parent) return parent:CreateFontString(nil, "OVERLAY", "GameFontNormal") end
local map = Frame()
map.BorderFrame = Frame(nil, map)
map.ScrollContainer = Frame(nil, map)
map.NavBar = Frame(nil, map)
local home = Frame("Button", map.NavBar)
home.text = Font(home)
local crumb = Frame("Button", map.NavBar)
crumb.text = Font(crumb)
crumb.text:SetText("Silvermoon")
crumb.MenuArrowButton = Frame("DropdownButton", crumb)
crumb.MenuArrowButton.Art = Texture(crumb.MenuArrowButton)
crumb.arrowUp, crumb.arrowDown = Texture(crumb), Texture(crumb)
map.NavBar.navList = {home, crumb}
map.NavBar.homeButton = home
map.NavBar.overflowButton = Frame("DropdownButton", map.NavBar)
map.QuestLog = Frame(nil, map)
local quest = map.QuestLog
quest.QuestsTab = Frame(nil, quest)
quest.QuestsTab.SelectedTexture = Texture(quest.QuestsTab)
quest.QuestsTab.SetChecked = function(self, checked) self.SelectedTexture:SetShown(checked) end
quest.EventsFrame = Frame(nil, quest)
local eventsBackground = Texture(quest.EventsFrame)
quest.QuestsFrame = Frame(nil, quest)
local scroll = Frame("ScrollFrame", quest.QuestsFrame)
quest.QuestsFrame.ScrollFrame = scroll
scroll.Background = Texture(scroll)
scroll.SearchBox = Frame("EditBox", scroll)
local row = Frame("Button", scroll)
row.Background = Texture(row)
row.Progress = Font(row)
row.NextObjective = Frame(nil, row)
row.NextObjective.Text = Font(row.NextObjective)
row.NextObjective.Text:SetText("Continue the campaign by accepting the next quest.")
row.UpdateNextObjective = function(self, expanded)
    self.NextObjective:SetShown(expanded)
end
row.bottomPadding = 10
local objectiveLayouts, headerLayouts = 0, 0
row.NextObjective.Layout = function() objectiveLayouts = objectiveLayouts + 1 end
row.Layout = function() headerLayouts = headerLayouts + 1 end
row.Text = Font(row)
local title = Frame("Button", scroll)
title.Text = Font(title)
title.Text:SetTextColor(1, .4, .1, 1)
scroll.headerFramePool = {EnumerateActive = function() return pairs({[row] = true}) end}
scroll.titleFramePool = {EnumerateActive = function() return pairs({[title] = true}) end}
local details = Frame(nil, quest)
quest.DetailsFrame = details
details.ScrollFrame = Frame("ScrollFrame", details)
details.ScrollFrame.Contents = Frame(nil, details.ScrollFrame)
local description = Font(details.ScrollFrame.Contents)
description:SetTextColor(.2, .15, .1, 1)
description.GetTextColor = function(self) return unpack(self.textColor) end
_G.QuestInfoDescriptionText = description
local objectives = Frame(nil, details.ScrollFrame.Contents)
local objective = Font(objectives)
objective:SetTextColor(.25, .15, 0, 1)
local completed = Font(objectives)
completed:SetTextColor(.2, .2, .2, 1)
objectives.Objectives = {objective, completed}
_G.QuestInfoObjectivesFrame = objectives
_G.QUEST_OBJECTIVE_COMPLETED_FONT_COLOR = {GetRGB = function() return .2, .2, .2 end}
_G.QUEST_OBJECTIVE_COMPLETED_FONT_COLOR_DARK_BACKGROUND = {GetRGB = function() return .65, .65, .65 end}
details.RewardsFrameContainer = Frame(nil, details)
details.RewardsFrameContainer.RewardsFrame = Frame(nil, details.RewardsFrameContainer)
_G.WorldMapFrame, _G.QuestScrollFrame = map, scroll
_G.NavBar_AddButton = function(nav, button) table.insert(nav.navList, button) end
_G.QuestLogQuests_Update = function() end
home.xoffset, crumb.xoffset, map.NavBar.overflowButton.xoffset = -18, -15, -18
home:Hide()
quest.EventsTab, quest.MapLegendTab = Frame(nil, quest), Frame(nil, quest)
local eventScroll = Frame(nil, quest.EventsFrame)
quest.EventsFrame.ScrollBox = eventScroll
local date = Frame(nil, eventScroll)
date.Background, date.Label = Texture(date), Font(date)
date.GetElementData = function() return {GetData = function() return {date = {}} end} end
local scheduled = Frame(nil, eventScroll)
scheduled.Timeline = Texture(scheduled)
eventScroll.HasView = function() return true end
eventScroll.ForEachFrame = function(_, fn) fn(date); fn(scheduled) end
local tracking = Frame("DropdownButton", map)
tracking.Icon, tracking.Border = Texture(tracking), Texture(tracking)
local nativeTrackingBackground = Texture(tracking)
tracking.FilterCounter = Frame(nil, tracking)
local activity = Frame("Button", map)
activity.Icon, activity.IconBorder, activity.Background = Texture(activity), Texture(activity), Texture(activity)
activity.BountyDropdown = Frame("DropdownButton", activity)
activity.SetSelectedBounty = function(self, bounty) self.selectedBounty = bounty end
activity.Refresh = function() end
_G.C_Reputation = {GetFactionDataByID = function() return {name = "Silvermoon Court"} end}
local createActivityFont = activity.CreateFontString
activity.CreateFontString = function(self, ...)
    local font = createActivityFont(self, ...)
    local setFont, setText = font.SetFont, font.SetText
    local ready = false
    font.SetFont = function(owner, ...) ready = true; return setFont(owner, ...) end
    font.SetText = function(owner, ...) assert(ready, "new reputation labels require a font before SetText"); return setText(owner, ...) end
    return font
end
local floor = Frame("DropdownButton", map)
floor.RefreshMenu = function() return true end
floor.ShouldShowTrackingIconOnFloor = function() return false end
local floorClick = function() end
floor:SetScript("OnClick", floorClick)
local board = Frame(nil, map)
board.TrackerBackground = Texture(board)
board.DesaturatedTrackerBackground = Texture(board)
board.BountyName = Font(board)
board.GetSelectedBountyIndex = function(self) return self.selectedIndex end
board.SetSelectedBountyIndex = function(self, value) self.selectedIndex = value end
board.selectedIndex = 1
local factionTab = Frame("Button", board)
factionTab.Icon = Texture(factionTab)
factionTab.bountyIndex = 1
factionTab.isEmpty = false
board.RefreshBountyTabs = function() factionTab.bountyIndex = 2 end
local bountyClick = function() end
factionTab:SetScript("OnClick", bountyClick)
board.bountyTabPool = {EnumerateActive = function()
    local returned = false
    return function() if not returned then returned = true; return factionTab end end
end}
local threat = Frame(nil, map)
threat.Background = Texture(threat)
threat.Eye = Frame(nil, threat)
threat.Eye.Eye = Texture(threat.Eye)
threat.ModelSceneBottom = Frame(nil, threat)
threat.ModelSceneTop = Frame(nil, threat)
map.overlayFrames = {tracking, activity, floor, board, threat}
_G.NavBar_CheckLength = function(nav)
    crumb:ClearAllPoints()
    crumb:SetPoint("LEFT", nav.overflowButton, "RIGHT", -18, 0)
end
local clicked = 0
crumb:SetScript("OnClick", function() clicked = clicked + 1 end)
assert(loadfile(os.getenv("QUI_MAP_SOURCE") or "modules/skinning/frames/worldmap.lua"))("QUI", ns)
callbacks.Blizzard_WorldMap()
assert(crumb.xoffset == 0 and map.NavBar.overflowButton.xoffset == 0, "rectangular breadcrumbs must remove native arrow overlap offsets")
_G.NavBar_CheckLength(map.NavBar)
local _, relative, _, x = crumb:GetPoint()
assert(relative == map.NavBar.overflowButton and x == 0, "native navigation refresh must retain non-overlapping overflow spacing")
local _, tabRelative, _, tabX, tabY = quest.EventsTab:GetPoint()
assert(tabRelative == quest.QuestsTab and tabX == 0 and tabY == 0, "map tabs must snap together without native gaps")
assert(Skin.GetBackdrop(date):GetFrameLevel() > scheduled:GetFrameLevel(), "date surfaces must render above neighboring event timelines")
assert(Skin.GetBackdrop(date)._quiRoundedSurface.background.color[4] == 1, "date masks must be opaque")
assert(tracking.Border:GetAlpha() == 0 and nativeTrackingBackground:GetAlpha() == 0, "tracking chrome without a Background field must be removed")
assert(tracking.Icon:GetAlpha() == 0 and Skin.GetFrameData(tracking, "mapFilterIcon"), "filter button must replace its embedded circular art with a shared drawn funnel")
assert(not Skin.GetBackdrop(crumb.MenuArrowButton):IsShown(), "breadcrumb arrow must not add a second nested outline")
assert(Skin.GetBackdrop(row).ignoreInLayout, "owned campaign chrome must not feed back into native resize layout")
assert(row.heightPadding >= 12 and row.bottomPadding == 10 and objectiveLayouts > 0 and headerLayouts > 0, "campaign font styling must recalculate content height with bottom padding")
row:UpdateNextObjective(false)
assert(row.heightPadding == 0, "collapsed campaign must remove objective height padding before native list layout")
row:UpdateNextObjective(true)
assert(row.heightPadding >= 12, "expanded campaign must restore height padding before native list layout")
local selectedFill = Skin.GetBackdrop(quest.QuestsTab)._quiRoundedSurface.background.color
local inactiveFill = Skin.GetBackdrop(quest.EventsTab)._quiRoundedSurface.background.color
assert(selectedFill[1] == inactiveFill[1] and selectedFill[2] == inactiveFill[2] and selectedFill[3] == inactiveFill[3], "all map tabs must blend into the same window fill")
assert(Skin.GetFrameData(activity, "mapActivityLabel"):GetText() == "Faction", "empty activity control must be labeled Faction")
assert(Skin.GetFrameData(quest.QuestsTab, "mapTabJoin"), "side tabs must have an open inner edge joining the window")
assert(activity:GetWidth() == 176 and activity:GetHeight() == 36, "empty reputation control must use a compact labeled layout")
local _, selectorParent, selectorAnchor, selectorX = activity.BountyDropdown:GetPoint()
assert(selectorParent == activity and selectorAnchor == "RIGHT" and selectorX == -4, "reputation selector must sit inside its own right-hand slot")
assert(Skin.GetFrameData(activity, "mapActivityLabel"):GetText() ~= "", "unselected reputation must have an explicit label")
activity:SetSelectedBounty({factionID = 1})
assert(Skin.GetFrameData(activity, "mapActivityLabel"):GetText() == "Silvermoon Court", "reputation selection must update the compact label")
activity:SetSelectedBounty(nil)
assert(Skin.GetFrameData(activity, "mapActivityLabel"):GetText() ~= "Silvermoon Court", "clearing reputation must restore the empty label")
activity:Refresh()
assert(activity:GetHeight() == 36, "native refresh must preserve the compact layout")
assert(activity.IconBorder:GetAlpha() == 0 and Skin.GetBackdrop(activity.BountyDropdown), "activity ring and dropdown must use shared chrome")
assert(Skin.GetBackdrop(crumb) and Skin.GetBackdrop(crumb)._quiRoundedSurface, "map breadcrumbs must use rounded shared controls")
assert(Skin.GetBackdrop(scroll)._quiRoundedSurface, "quest list must have a rounded dark surface")
assert(Skin.GetBackdrop(row)._quiRoundedSurface, "pooled quest headings must use shared rounded chrome")
for _, owner in ipairs({crumb, scroll, row, details, quest.QuestsTab}) do
    local surface = Skin.GetBackdrop(owner)._quiRoundedSurface
    assert(surface.background.color[4] > 0, "map controls and panes must retain their rounded background fill")
end
assert(row.Background:IsShown(), "campaign background must retain native layout participation when collapsed")
assert(row.Background:GetAlpha() == 0, "layout-bearing campaign art must remain transparent")
assert(eventsBackground.alpha == 0, "Events pane background must not leak around its rounded surface")
assert(scroll.Background.alpha == 0, "native parchment must not show through the quest list")
assert(title.Text.textColor[2] == .4, "quest difficulty colors must survive font styling")
assert(description.textColor[1] == .9, "quest detail text must be readable on the dark surface")
assert(objective.textColor[1] == .9, "dynamic quest objectives must be readable on a dark map pane")
assert(completed.textColor[1] == .65, "completed objectives must retain their subdued dark-background state")
assert(Skin.GetBackdrop(details.RewardsFrameContainer.RewardsFrame), "fixed rewards must have a background separating them from scrolling text")
_G.QUI_RefreshWorldMapColors()
assert(completed.textColor[1] == .65, "theme refresh must preserve completed objective contrast")
details:Hide()
assert(objective.textColor[1] == .25 and completed.textColor[1] == .2, "shared objective colors must be restored for other quest owners")
assert(description.textColor[1] == .2, "shared quest text colors must be restored when details close")
crumb:Fire("OnClick")
assert(clicked == 1, "map click handlers must remain intact")
local recycled = Frame("Button", map.NavBar)
recycled.text = Font(recycled)
_G.NavBar_AddButton(map.NavBar, recycled)
assert(Skin.GetBackdrop(recycled)._quiRoundedSurface, "new navigation buttons must be styled after native creation")
local pooled = Frame("Button", scroll)
pooled.Text = Font(pooled)
scroll.headerFramePool = {EnumerateActive = function() return pairs({[pooled] = true}) end}
_G.QuestLogQuests_Update()
assert(Skin.GetBackdrop(pooled)._quiRoundedSurface, "newly acquired quest headings must be styled after native update")
local combat = Frame("Button", map.NavBar)
_G.InCombatLockdown = function() return true end
_G.NavBar_AddButton(map.NavBar, combat)
assert(Skin.GetBackdrop(combat), "visual styling must remain active in combat")
_G.InCombatLockdown = function() return false end
map:Fire("OnShow")
assert(Skin.GetBackdrop(combat), "combat styling must remain intact on later refresh")
print("OK: worldmap_modern_controls_test")

assert(Skin.GetBackdrop(floor) and floor:GetScript("OnClick") == floorClick,
    "dungeon floor overlay requires QUI dropdown chrome with native menu navigation")

assert(board.TrackerBackground:GetAlpha() == 0 and board.DesaturatedTrackerBackground:GetAlpha() == 0
    and Skin.GetBackdrop(board), "legacy bounty panel must replace native decorative tracker art")
assert(Skin.GetBackdrop(factionTab) and factionTab.Icon:GetAlpha() == 1 and factionTab:GetScript("OnClick") == bountyClick,
    "pooled bounty tabs require QUI chrome with native faction icons and actions")
board:SetSelectedBountyIndex(2)
local wr, wg, wb = Skin.GetWindowColors()
local color = Skin.GetFrameData(factionTab, "windowColor")
assert(color[1] == wr and color[2] == wg and color[3] == wb,
    "pooled faction selection must clear old selection and hover-leave border")
assert(threat.Background:GetAlpha() == 0 and threat.Eye.Eye:GetAlpha() == 1,
    "threat overlay must preserve semantic eye art while suppressing separate decoration")

board:RefreshBountyTabs()
local selectedColor = Skin.GetFrameData(factionTab, "windowColor")
local accentR, accentG, accentB = Skin.GetSkinColors()
assert(selectedColor[1] == accentR and selectedColor[2] == accentG and selectedColor[3] == accentB,
    "recycled bounty tab follows its reassigned faction index")

local selectionLine=Skin.GetFrameData(quest.QuestsTab,"mapTabJoin").Edge
quest.QuestsTab:SetChecked(true);assert(selectionLine:IsShown())
env.profile.general.skinWorldMap=false
quest.QuestsTab:SetChecked(false)
assert(not quest.QuestsTab.SelectedTexture:IsShown() and selectionLine:IsShown(),
    "disabled map skin must preserve native checked changes without restyling its selection line")
env.profile.general.skinWorldMap=true
quest.QuestsTab:SetChecked(false);assert(not selectionLine:IsShown())
quest.QuestsTab:SetChecked(true)
for _,owner in ipairs({map,quest,quest.QuestsTab}) do
    owner.IsForbidden=function() return true end
    quest.QuestsTab:SetChecked(false)
    assert(selectionLine:IsShown(),"forbidden tab ancestry must prevent owned map styling callbacks")
    owner.IsForbidden=function() return false end
    quest.QuestsTab:SetChecked(true)
end
quest.QuestsTab:SetParent(env.NewFrame("Frame"))
quest.QuestsTab:SetChecked(false)
assert(selectionLine:IsShown(),"map tab borrowed outside current root must not be restyled")
quest.QuestsTab:SetParent(quest)
quest.QuestsTab:SetChecked(false)
assert(not selectionLine:IsShown(),"native selected line must resume after restoring map ownership")
print("World Map tab callback ownership guards passed")

local eventAcquire=assert(acquiredRows[eventScroll])
local lateEvent=Frame(nil,eventScroll);lateEvent.Label=Font(lateEvent);lateEvent.Label:SetFont("Native",14,"")
env.profile.general.skinWorldMap=false
eventAcquire(eventScroll,lateEvent);env.RunTimers()
assert(lateEvent.Label.font=="Native","disabled map skin must leave newly acquired event row typography native")
env.profile.general.skinWorldMap=true
eventAcquire(eventScroll,lateEvent);env.RunTimers()
assert(lateEvent.Label.font=="QUIFont.ttf","owned acquired event row must receive QUI typography")
lateEvent:SetParent(env.NewFrame("Frame"));lateEvent.Label:SetFont("Borrowed",14,"")
eventAcquire(eventScroll,lateEvent);env.RunTimers()
assert(lateEvent.Label.font=="Borrowed","borrowed event row must not receive map styling")
lateEvent:SetParent(eventScroll);lateEvent.IsForbidden=function() return true end
eventAcquire(eventScroll,lateEvent);env.RunTimers()
assert(lateEvent.Label.font=="Borrowed","forbidden acquired event row must remain untouched")
print("World Map acquired event-row ownership guards passed")
