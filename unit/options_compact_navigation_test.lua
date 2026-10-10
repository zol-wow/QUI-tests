local nodes = {}
local function Node(kind, parent)
    local node = { kind = kind, parent = parent, children = {}, scripts = {}, points = {}, shown = true }
    nodes[#nodes + 1] = node
    if parent and kind ~= "FontString" and kind ~= "Texture" then parent.children[#parent.children + 1] = node end
    setmetatable(node, { __index = function(_, key)
        if key:match("^Set") or key:match("^Enable") or key:match("^Register") then return function() end end
    end })
    function node:GetParent() return self.parent end
    function node:SetParent(value) self.parent = value end
    function node:GetChildren() return unpack(self.children) end
    function node:SetScript(key, callback) self.scripts[key] = callback end
    function node:HookScript(key, callback)
        local previous = self.scripts[key]
        self.scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function node:Fire(key, ...) if self.scripts[key] then return self.scripts[key](self, ...) end end
    function node:ClearAllPoints() self.points = {} end
    function node:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function node:SetWidth(value) self.width = value end
    function node:SetHeight(value) self.height = value end
    function node:GetWidth() return self.width or 240 end
    function node:GetHeight() return self.height or 120 end
    function node:GetTop() return self.top or 800 end
    function node:GetFrameLevel() return 1 end
    function node:SetAlpha(value) self.alpha = value end
    function node:SetText(value) self.text = value end
    function node:SetTextColor(...) self.textColor = { ... } end
    function node:GetText() return self.text or "" end
    function node:GetStringWidth() return #(self.text or "") * 6 end
    function node:SetEnabled(value) self.enabled = value end
    function node:Enable() self.enabled = true end
    function node:Disable() self.enabled = false end
    function node:Show() self.shown = true end
    function node:Hide() self.shown = false end
    function node:IsShown() return self.shown end
    function node:SetShown(value) self.shown = value end
    function node:IsMouseOver() return self.over == true end
    function node:SetVerticalScroll(value) self.scroll = value end
    function node:GetVerticalScroll() return self.scroll or 0 end
    function node:GetVerticalScrollRange() return self.scrollRange or 0 end
    function node:CreateFontString()
        local label = Node("FontString", self)
        label:SetTextColor(1, 0.82, 0)
        return label
    end
    function node:CreateTexture() return Node("Texture", self) end
    return node
end
_G.CreateFrame = function(kind, _, parent) return Node(kind, parent) end
local now, timers = 0, {}
_G.C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
local function Advance(elapsed)
    now = now + elapsed
    for index = #timers, 1, -1 do
        if timers[index].at <= now + 0.0000001 then
            local timer = table.remove(timers, index)
            timer.callback()
        end
    end
end
local animations, cancellations, selections, builds = 0, 0, 0, 0
local gui = { Colors = {} }
for _, key in ipairs({ "accentText", "text", "bgLight", "borderStrong", "textDim", "accent", "sectionLabel" }) do
    gui.Colors[key] = { 0.5, 0.5, 0.5, 1 }
end
gui.Colors.text = { 1, 1, 1, 1 }
function gui:GetFontPath() return "font" end
function gui:BuildTilePage() builds = builds + 1 end
function gui:CreateButton(parent, _, _, _, callback)
    local button = Node("Button", parent)
    button:SetScript("OnClick", callback)
    return button
end
function gui:SelectFeatureTile(frame, index, options)
    options = options or {}
    if not options.noHistory then self:PushNavigationHistory(frame) end
    frame._searchBox.editBox:SetText("")
    selections = selections + 1
    frame._lastTileIndex = index
    for _, tile in ipairs(frame._tiles) do tile._isActive = tile.index == index end
    frame._tiles[index]._activeSubPageIndex = options.subPageIndex or 1
end
_G.QUI = { GUI = gui, db = { profile = { general = {} } } }
local ns = { Helpers = { AssetPath = [[Interface\AddOns\QUI\assets\]], ApplyFontWithFallback = function(label, path) label.fontPath = path end }, UIKit = {
    CreateBackground = function() end, CreateBorderLines = function() end, UpdateBorderLines = function() end,
    CreateCloseButton = function() end, CreateScrollBar = function()
        return { IsDragging = function(self) return self.dragging == true end }
    end, AttachSmoothScroll = function() end,
    CancelValueAnimation = function() cancellations = cancellations + 1 end,
    AnimateValue = function(owner, _, options) animations = animations + 1; options.onUpdate(owner, options.toValue, 1) end,
} }
(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile(os.getenv("QUI_NAV_SOURCE") or "QUI_Options/navigation.lua"))("QUI", ns)
local frame = Node("Frame")
frame:SetWidth(1100)
frame:SetHeight(760)
frame.sidebar = Node("Frame", frame)
frame.sidebar:SetWidth(180)
frame._sidebarScrollChild = Node("Frame", frame.sidebar)
frame._sidebarScroll = Node("ScrollFrame", frame.sidebar)
frame._searchBox = { editBox = Node("EditBox", frame), onSearch = function(query) frame.restoredQuery = query end }
frame._tiles = {}
for index, id in ipairs({
    "welcome", "global", "help", "unit_frames", "group_frames", "nameplates", "action_bars",
    "cooldown_manager", "resource_bars", "auras", "appearance", "minimap", "infobar", "chat_tooltips",
    "bags", "alts", "gameplay", "reminders", "qol",
}) do
    local tile = Node("Button", frame)
    tile.id, tile.index, tile.config = id, index, { name = id }
    tile:SetHeight(28)
    tile.text = tile:CreateFontString()
    if id == "action_bars" then
        tile.moduleToggle = Node("Button", tile)
        tile.moduleToggle:SetWidth(26)
    end
    tile._title, tile._crumb = tile:CreateFontString(), tile:CreateFontString()
    tile._pageFrame = Node("Frame", frame)
    frame._tiles[index] = tile
    gui:AttachTileNavigation(frame, tile)
end
local toggleTile = frame._tiles[7]
local arrowPoint, togglePoint = toggleTile._navArrow.points[1], toggleTile.moduleToggle.points[1]
assert(arrowPoint[1] == "RIGHT" and arrowPoint[2] == toggleTile and arrowPoint[4] == -9,
    "the chevron occupies the right edge of the module row")
assert(togglePoint[1] == "RIGHT" and togglePoint[2] == toggleTile._navArrow and togglePoint[3] == "LEFT" and togglePoint[4] == -8,
    "the module toggle sits left of the chevron with a gap")
gui.MainFrame = frame
gui:LayoutSidebarGroups(frame)
assert(#frame._sidebarGroups == 5 and #frame._tiles == 19, "five categories contain all 19 module buttons")
local positions = {}
for _, tile in ipairs(frame._tiles) do
    assert(tile.parent == frame._sidebarScrollChild and tile._sidebarTop, "each module uses the shared sidebar")
    positions[tile.id] = tile._sidebarTop
end
assert(positions.gameplay < positions.reminders and positions.reminders < positions.qol,
    "the visible sidebar must place Reminders between Gameplay and Quality of Life")
assert(frame._tiles[18]:IsShown(), "the Reminders module must remain visible in the sidebar")
for _, label in ipairs(frame._sidebarGroups) do
    assert(label.kind == "FontString" and not next(label.scripts), "category labels have no collapse handlers")
end
local tile = frame._tiles[4]
tile.config.subPages = { { name = "General" }, { name = "Frame" } }
tile._activeSubPageIndex, tile._isActive, frame._lastTileIndex = 2, true, 4
local owner = Node("Frame", tile._pageFrame)
owner._quiOptionsTile = tile
local subpage = Node("Frame", owner)
subpage._quiOptionsSubPageIndex = 2
local nested = Node("Frame", subpage)
local activeKey, selectedKey, callbacks = "text", nil, 0
local descriptor = {
    getTabs = function() return { { key = "general", label = "General" }, { key = "text", label = "Text" }, { key = "disabled", label = "Disabled", enabled = false } } end,
    getActiveTab = function() return activeKey end,
    selectTab = function(key) selectedKey, activeKey, callbacks = key, key, callbacks + 1 end,
}
assert(gui:RegisterTileSurfacePages(nested, descriptor), "nested bodies register their owning surface")
assert(tile._surfacePagesByPage[2] == descriptor and descriptor.owner == nested, "nested subpage index survives ancestor lookup")
assert(tile._title:GetText() == "Text", "surface active getter supplies the exact current title")
tile.over = true
tile:Fire("OnEnter")
Advance(0.249)
assert(not frame._pageFlyout and selections == 0, "hover waits 250 ms and does not select")
Advance(0.001)
local flyout = assert(frame._pageFlyout)
assert(flyout:IsShown() and selections == 0 and builds > 0, "hover reveals pages without navigating")
assert(flyout._title.textColor[1] == 1 and flyout._title.textColor[2] == 1 and flyout._title.textColor[3] == 1,
    "flyout titles explicitly override the native yellow font template with neutral text")
assert(flyout._hint.textColor[1] == gui.Colors.textDim[1], "flyout hints retain their intentional dim color")
assert(#flyout._pages == 5 and flyout._pages[4].key == "text" and flyout._pages[5].disabled,
    "surface pages retain exact keys and disabled state")
flyout._buttons[5]:Fire("OnClick")
assert(selections == 0 and callbacks == 0 and flyout:IsShown(), "disabled pages cannot invoke navigation callbacks")
tile.over = false
tile:Fire("OnLeave")
flyout:Fire("OnUpdate", 0.299)
assert(flyout:IsShown(), "leaving preserves a 300 ms crossing grace period")
flyout:Fire("OnUpdate", 0.001)
assert(not flyout:IsShown(), "unhovered flyout closes after the grace period")
gui:OpenNavigationFlyout(frame, tile)
flyout._scrollbar.dragging = true
flyout:Fire("OnUpdate", 1)
assert(flyout:IsShown(), "dragging a scrollbar outside the flyout preserves the menu")
flyout._scrollbar.dragging = false
flyout:Fire("OnUpdate", 0.3)
assert(not flyout:IsShown(), "releasing the scrollbar resumes the normal leave grace")
tile:Fire("OnClick")
assert(flyout:IsShown() and flyout._pinned, "click pins the module pages")
flyout:Fire("OnUpdate", 1)
assert(flyout:IsShown(), "pinned pages stay open outside the hover region")
flyout:Fire("OnEvent", "GLOBAL_MOUSE_DOWN")
assert(not flyout:IsShown(), "clicking outside closes pinned pages")
tile.over = true
tile:Fire("OnEnter")
tile.over = false
tile:Fire("OnLeave")
Advance(0.25)
assert(not flyout:IsShown(), "leaving before the delay cancels hover opening")
assert(gui:HandleNavigationKey(frame, "RIGHT") and flyout._keyboard, "Right opens keyboard navigation")
assert(gui:HandleNavigationKey(frame, "UP") and flyout._keyboardIndex == 3, "Up selects the preceding surface page")
assert(gui:HandleNavigationKey(frame, "DOWN") and flyout._keyboardIndex == 4, "Down returns to the exact text page")
assert(gui:HandleNavigationKey(frame, "ENTER") and selectedKey == "text" and selections == 1,
    "Enter selects the exact surface key on the owning subpage")
assert(tile._activeSubPageIndex == 2 and not flyout:IsShown(), "selection keeps the outer page and closes the list")
gui:HandleNavigationKey(frame, "RIGHT")
assert(gui:HandleNavigationKey(frame, "ESCAPE") and not flyout:IsShown(), "Escape closes keyboard navigation")
gui:LayoutSidebarGroups(frame)
for _, module in ipairs(frame._tiles) do assert(module._sidebarTop == positions[module.id], "opening and selecting never displaces module rows") end
gui:CreateNavigationBackButton(frame, Node("Frame", frame))
frame._navigationHistory = {}
frame._searchBox.editBox:SetText("player health font")
activeKey = "text"
gui:PushNavigationHistory(frame)
activeKey = "general"
gui:SelectFeatureTile(frame, 2, { noHistory = true })
gui:NavigateOptionsBack(frame)
assert(frame._lastTileIndex == 4 and tile._activeSubPageIndex == 2 and selectedKey == "text", "Back restores the module, outer page and surface key")
assert(frame._searchBox.editBox:GetText() == "player health font" and frame.restoredQuery == "player health font", "Back restores and reruns the previous search query")
assert(frame._navigationBack.enabled == false, "Back disables when history is exhausted")
local before = animations
QUI.db.profile.general.optionsMotion = false
tile._pageFrame:SetAlpha(0.35)
gui:AnimateOptionsPage(tile._pageFrame)
gui:RefreshOptionsMotion()
assert(animations == before and tile._pageFrame.alpha == 1 and cancellations > 0, "disabled motion cancels fades and keeps pages opaque")
local previousSelections = selections
local other = frame._tiles[2]
other.config.subPages = { { name = "General" }, { name = "Options Window" } }
tile:Fire("OnClick")
assert(flyout:IsShown() and flyout._pinned, "click opens a persistent flyout")
tile.over, other.over = false, true
other:Fire("OnEnter")
Advance(0.249)
assert(flyout._tile == tile, "switching a click-open flyout observes the normal hover delay")
Advance(0.001)
assert(flyout._tile == other and flyout._pinned and selections == previousSelections,
    "hover switches a persistent flyout without changing the selected editor")
other:Fire("OnClick")
assert(not flyout:IsShown(), "clicking the hovered module closes the switched flyout")
other.over, tile.over = false, true
tile:Fire("OnClick")
tile:Fire("OnEnter")
tile:Fire("OnClick")
Advance(0.25)
assert(not flyout:IsShown(), "clicking an already-open module closes it and cancels pending hover reopening")
tile:Fire("OnEnter")
Advance(0.25)
assert(flyout:IsShown() and not flyout._pinned, "hover alone opens a temporary flyout")
tile:Fire("OnClick")
assert(not flyout:IsShown(), "click closes a hover-open flyout too")
gui:OpenNavigationFlyout(frame, tile)
tile.over = false
flyout:Fire("OnUpdate", 0.2)
other.over = true
other:Fire("OnEnter")
flyout:Fire("OnUpdate", 0.1)
Advance(0.25)
assert(flyout:IsShown() and flyout._tile == other and not flyout._pinned,
    "the old flyout leave grace cannot cancel the newest sidebar hover")
gui:CloseNavigationFlyout(frame)
other.over = false
tile.over = true
tile:Fire("OnEnter")
tile.over, other.over = false, true
other:Fire("OnEnter")
tile:Fire("OnLeave")
Advance(0.25)
assert(flyout:IsShown() and flyout._tile == other,
    "a previous module leave callback cannot cancel the newer module hover")
other:Fire("OnClick")
Advance(0.25)
assert(not flyout:IsShown(), "closing the newest module cannot leave a pending reopen")
tile.over, other.over = true, false
tile:Fire("OnEnter")
tile.over, other.over = false, true
other:Fire("OnEnter")
other:Fire("OnClick")
Advance(0.25)
assert(flyout:IsShown() and flyout._tile == other and flyout._pinned,
    "clicking the newest module invalidates all earlier delayed opens")
gui:CloseNavigationFlyout(frame)
other.over, tile.over = false, true
local single = frame._tiles[10]
single.config.subPages = { { name = "Auras" } }
single._surfacePagesByPage = { [1] = descriptor }
local flatPages = gui:GetTileNavigationPages(single)
assert(#flatPages == 3 and flatPages[1].key == "general" and not flatPages[1].indent and not flatPages[2].indent,
    "a single wrapper exposes its real surface pages without an extra module row")
local nativeNS = { Helpers = {
    CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = {} },
    AssetPath = "Interface\\AddOns\\QUI\\assets\\",
    GetCore = function() return { GetPixelSize = function() return 1 end } end,
    CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
    SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
} }
assert(loadfile("core/safecall.lua"))("QUI", nativeNS)
assert(loadfile("core/uikit.lua"))("QUI", nativeNS)
for _, key in ipairs({ "CreateScrollBar", "AttachSmoothScroll", "AnimateValue", "CancelValueAnimation" }) do
    ns.UIKit[key] = nativeNS.UIKit[key]
end
gui.Colors.scrollThumb, gui.Colors.scrollTrack = { 1, 1, 1, 0.6 }, { 1, 1, 1, 0.02 }
QUI.db.profile.general.optionsMotion = true
frame._pageFlyout = nil
gui:OpenNavigationFlyout(frame, tile, true)
flyout = frame._pageFlyout
assert(not flyout._scrollbar.track:IsShown() and not flyout._scrollbar.hit:IsShown(), "real UIKit hides the scrollbar when pages fit exactly")
local anchor = flyout._optionsEntranceAnchor
assert(flyout.alpha == 0.25 and flyout.points[#flyout.points][5] == anchor.y - 3, "flyout entrance starts faded and three units below its final anchor")
local driver
for _, node in ipairs(nodes) do
    if not node.parent and node.scripts.OnUpdate then driver = node end
end
assert(driver, "native UIKit supplies the animation driver")
driver:Fire("OnUpdate", 0.065)
assert(math.abs(flyout.alpha - 0.90625) < 0.0001, "the entrance eases out rather than fading linearly")
QUI.db.profile.general.optionsMotion = false
gui:RefreshOptionsMotion()
assert(flyout.alpha == 1 and flyout.points[#flyout.points][5] == anchor.y, "disabling motion restores opacity and final position immediately")
gui:CloseNavigationFlyout(frame)
frame:SetHeight(150)
gui:OpenNavigationFlyout(frame, tile, true)
assert(flyout._scrollbar.track:IsShown() and flyout._scrollbar.hit:IsShown(), "real UIKit shows a usable scrollbar only when the short viewport overflows")
frame:SetHeight(760)
gui:OpenNavigationFlyout(frame, tile, true)
assert(not flyout._scrollbar.track:IsShown() and not flyout._scrollbar.hit:IsShown(), "reopening at full height hides the overflow scrollbar again")
print("options_compact_navigation_test: ok")

local sectionTile = Node("Button", frame)
sectionTile.config = { subPages = { { name = "General", sectionNav = true }, { name = "Other" } } }
sectionTile._activeSubPageIndex = 1
local heading = Node("Frame")
sectionTile._subPageBodies = { { _contentBody = { _sections = { { id = "details", label = "Details", frame = heading } } } } }
local sectionPages = gui:GetTileNavigationPages(sectionTile)
assert(#sectionPages == 2 and sectionPages[1].label == "Details" and sectionPages[1].section == heading and sectionPages[2].label == "Other",
    "section links must replace the parent and omit its prefix")
sectionTile._activeSubPageIndex = 2
local otherPages = gui:GetTileNavigationPages(sectionTile)
assert(#otherPages == #sectionPages, "changing pages must preserve every navigation destination")
for index, page in ipairs(sectionPages) do
    assert(otherPages[index].label == page.label and otherPages[index].pageIndex == page.pageIndex,
        "changing pages must preserve navigation order and routes")
end

assert(type(gui.RefreshNavigationDock) == "function", "navigation must provide a responsive persistent page dock")
frame.contentArea = Node("Frame", frame)
frame.footerBar = Node("Frame", frame)
local headerSearch = Node("Frame", frame)
frame._searchBox = Node("Frame", headerSearch)
frame._searchBox.editBox = Node("EditBox", frame._searchBox)
frame:SetWidth(1200)
frame._lastTileIndex = tile.index
QUI.db.profile.general.optionsNavigationDocked = true
gui:RefreshNavigationDock(frame)
assert(frame._navigationModeButton:GetParent() == frame, "dock toggle must live in the navigation header")
assert(frame._navigationModeButton.points[1][2] == headerSearch, "dock toggle must sit beside Search")
local dock = frame._pageDock
assert(dock and dock:IsShown() and frame._navigationDocked, "wide windows must show persistent pages")
assert(dock._pages[1].label == gui:GetTileNavigationPages(tile)[1].label, "dock and flyout must use the same page model")
assert(not dock.scripts.OnUpdate and not dock.scripts.OnEvent, "docked navigation must not auto-close or poll mouse position")
assert(frame.contentArea.points[#frame.contentArea.points][4] == 201, "dock must consume width instead of overlaying controls")
local before = selections
dock._buttons[2]:Fire("OnClick")
assert(selections == before + 1 and tile._activeSubPageIndex == dock._pages[2].pageIndex, "one dock click must select the existing route")
gui:SetNavigationDocked(frame, false)
assert(not dock:IsShown() and QUI.db.profile.general.optionsNavigationDocked == false, "compact preference must be remembered")
gui:SetNavigationDocked(frame, true)
frame:SetWidth(900)
gui:RefreshNavigationDock(frame)
assert(not dock:IsShown() and not frame._navigationDocked, "narrow windows must fall back without shrinking controls")
assert(QUI.db.profile.general.optionsNavigationDocked == true, "responsive fallback must preserve the user's docking preference")
frame:SetWidth(1200)
gui:RefreshNavigationDock(frame)
assert(dock:IsShown(), "widening the window must restore the dock")
assert(gui:HandleNavigationKey(frame, "RIGHT") and dock._keyboard, "Right must focus the visible page list")
assert(gui:HandleNavigationKey(frame, "ESCAPE") and not dock._keyboard and dock:IsShown(), "Escape must leave keyboard navigation without hiding the dock")
print("options_docked_navigation: ok")

gui.MainFrame = frame
function gui:_CreateV2SearchResultsArea(owner)
    local wrapper = Node("Frame", owner.contentArea)
    wrapper.inner = Node("Frame", wrapper)
    return wrapper
end
tile._title = Node("FontString")
tile._title:SetText("General")
frame._recentDestinations = nil
gui:RememberNavigationDestination(frame, tile)
gui:RememberNavigationDestination(frame, tile)
assert(#frame._recentDestinations == 1, "revisiting a page must not duplicate recent destinations")
local pinnedPath
ns.Settings = { Pins = {
    List = function() return { { label = "Example favorite", path = "example.enabled" } } end,
    NavigateToPinned = function(_, path) pinnedPath = path end,
} }
function gui:CreateButton(parent, label, _, _, callback)
    local button = Node("Button", parent)
    button.text = Node("FontString", button)
    function button:SetText(value) self.text:SetText(value) end
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end
frame._tileContent = Node("Frame", frame.contentArea)
gui:ShowNavigationSuggestions(frame)
local suggestions = frame._navigationSuggestions
assert(suggestions:IsShown() and not frame._tileContent:IsShown(), "empty focused search must expose destinations instead of overlapping the current page")
suggestions._rows[2]:Fire("OnClick")
assert(pinnedPath == "example.enabled" and not suggestions:IsShown(), "favorite suggestion must use existing precise-control navigation")
gui:ShowNavigationSuggestions(frame)
before = selections
suggestions._rows[4]:Fire("OnClick")
assert(selections == before + 1 and not suggestions:IsShown(), "recent suggestion must restore its shared page route")
print("options_navigation_discovery: ok")

local flatNavigation = gui:GetTileNavigationPages(tile)
for _, destination in ipairs(flatNavigation) do
    assert(not destination.indent, "page navigation must never add nested branches")
end
print("options_flat_navigation: ok")

function frame:GetScale() return self.testScale or 1 end
frame.testScale = 0.9
gui:RefreshNavigationDock(frame)
assert(not frame._pageDock:IsShown() and QUI.db.profile.general.optionsNavigationDocked == true,
    "reduced Panel Scale must fall back before a fixed-size specimen loses its space")
frame.testScale = 1
gui:RefreshNavigationDock(frame)
assert(frame._pageDock:IsShown(), "restoring Panel Scale must restore the saved dock preference")
print("options_navigation_scale_fallback: ok")

sectionTile._isActive = true
sectionTile._activeSubPageIndex = 1
local viewport = Node("ScrollFrame")
viewport.top = 800
local secondHeading = Node("Frame")
heading.top, secondHeading.top = 790, 600
sectionTile._subPageBodies[1]._scrollFrame = viewport
sectionTile._subPageBodies[1]._contentBody._sections[2] = { id = "second", label = "Second", frame = secondHeading }
local grouped = gui:GetTileNavigationPages(sectionTile)
assert(grouped[1].group == "General" and grouped[2].group == "General", "section destinations must retain their originating page group")
assert(grouped[1].active and not grouped[2].active, "only the section at the viewport top must be active")
heading.top, secondHeading.top = 990, 795
grouped = gui:GetTileNavigationPages(sectionTile)
assert(not grouped[1].active and grouped[2].active, "manual scrolling must move the active section")
viewport:SetHeight(400)
viewport.scrollRange = 600
local thirdHeading = Node("Frame")
local fourthHeading = Node("Frame")
local sections = sectionTile._subPageBodies[1]._contentBody._sections
sections[3] = { id = "third", label = "Third", frame = thirdHeading }
sections[4] = { id = "fourth", label = "Fourth", frame = fourthHeading }
local function At(offset)
    viewport.scroll = offset
    heading.top = 800 + offset
    secondHeading.top = 800 + offset - 300
    thirdHeading.top = 800 + offset - 700
    fourthHeading.top = 800 + offset - 900
    return gui:GetTileNavigationPages(sectionTile)
end
for _, sample in ipairs({ {0, 1}, {200, 2}, {430, 3}, {550, 4}, {600, 4}, {430, 3}, {200, 2} }) do
    grouped = At(sample[1])
    for i = 1, 4 do
        assert((not not grouped[i].active) == (i == sample[2]), "scroll progress must traverse every section in both directions without a bottom jump")
    end
end
sectionTile.index = 20
sectionTile.config.name = "Sections"
sectionTile._pageFrame = Node("Frame", frame)
frame._tiles[20] = sectionTile
local content = Node("Frame")
function viewport:GetScrollChild() return content end
function gui:_findAncestorScroll() return viewport end
local originalSetScroll = viewport.SetVerticalScroll
function viewport:SetVerticalScroll(value)
    originalSetScroll(self, value)
    content.top = 800 + value
    At(value)
    self:Fire("OnVerticalScroll", value)
end
viewport:SetVerticalScroll(0)
gui:OpenNavigationFlyout(frame, sectionTile, true)
for destination = 1, 4 do
    gui:OpenNavigationFlyout(frame, sectionTile, true)
    frame._pageFlyout._buttons[destination]:Fire("OnClick")
    Advance(0)
    grouped = gui:GetTileNavigationPages(sectionTile)
    assert(grouped[destination].active, "clicking each section must scroll into its own progress interval")
    if destination > 1 then assert(viewport:GetVerticalScroll() > 0, "section clicks must move the scrollbar") end
end
local originalAt = At
At = function(offset)
    local pages = originalAt(offset)
    thirdHeading.top = 800 + offset - 1200
    fourthHeading.top = 800 + offset - 1400
    return pages
end
viewport.scrollRange = 1100
viewport:SetVerticalScroll(0)
gui:OpenNavigationFlyout(frame, sectionTile, true)
frame._pageFlyout._buttons[2]:Fire("OnClick")
Advance(0)
assert(math.abs(viewport:GetVerticalScroll() - 300) < 1, "clicking a section taller than the viewport must show its beginning rather than its middle")
assert(gui:GetTileNavigationPages(sectionTile)[2].active, "the long section must remain highlighted at its beginning")
At = originalAt
viewport.scrollRange = 600
fourthHeading:Hide()
grouped = At(600)
assert(grouped[3].active and grouped[4].label == "Other", "scroll progress must ignore hidden sections and other subpages")
sections[3], sections[4] = nil, nil
viewport.scrollRange = 0
viewport.scroll = 0
heading.top, secondHeading.top = 790, 500
grouped = gui:GetTileNavigationPages(sectionTile)
assert(grouped[1].active and not grouped[2].active, "a page without scrolling must retain its first section")
secondHeading.top = 810
sectionTile.config.name = "Example"
gui:OpenNavigationFlyout(frame, sectionTile, true)
assert(frame._pageFlyout._headings[1]:GetText() == "General", "flyouts must show the originating page heading")
assert(frame._pageFlyout._buttons[2]._navTop == 60, "group headings must reserve their own space above direct section links")
print("options_navigation_group_context: ok")

assert(frame._pageFlyout._headings[1]._divider:GetWidth() == frame._pageFlyout._headings[1]:GetStringWidth(), "navigation divider must span its heading text")

assert(frame._pageFlyout._headings[1].fontPath:find("Poppins-Bold.ttf", 1, true), "navigation group headings must use the bundled bold font")
