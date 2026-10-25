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
    function node:Click() if self.enabled ~= false then return self:Fire("OnClick") end end
    function node:ClearAllPoints() self.points = {} end
    function node:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function node:SetWidth(value) self.width = value end
    function node:SetHeight(value) self.height = value end
    function node:GetWidth() return self.width or 240 end
    function node:GetHeight()
        if self.kind == "ScrollFrame" then
            local top, bottom
            for _, point in ipairs(self.points) do
                if point[1] == "TOPLEFT" then top = point[3] end
                if point[1] == "BOTTOMRIGHT" then bottom = point[3] end
            end
            if type(top) == "number" and type(bottom) == "number" then
                return self.parent:GetHeight() + top - bottom
            end
        end
        return self.height or 120
    end
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
local function FindRow(panel, pageIndex, key, sectionId, isGroup)
    for _, button in ipairs(panel._buttons) do
        local page = button._page
        if button:IsShown() and page and page.pageIndex == pageIndex and page.key == key
            and page.sectionId == sectionId and (not not page._group) == (not not isGroup) then
            return button
        end
    end
end
local function Row(panel, pageIndex, key, sectionId, isGroup)
    return assert(FindRow(panel, pageIndex, key, sectionId, isGroup),
        "missing visible navigation row " .. tostring(pageIndex) .. "/" .. tostring(key)
            .. "/" .. tostring(sectionId) .. "/" .. tostring(isGroup))
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
assert(flyout:IsShown() and selections == 0 and builds == 0, "hover reveals pages without navigating")
assert(flyout._title.textColor[1] == 1 and flyout._title.textColor[2] == 1 and flyout._title.textColor[3] == 1,
    "flyout titles explicitly override the native yellow font template with neutral text")
assert(flyout._hint.textColor[1] == gui.Colors.textDim[1], "flyout hints retain their intentional dim color")
assert(#flyout._pages == 4 and flyout._pages[3].key == "text" and flyout._pages[4].disabled,
    "surface pages retain exact keys and disabled state")
Row(flyout, 2, "disabled"):Fire("OnClick")
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
assert(gui:HandleNavigationKey(frame, "UP") and flyout._buttons[flyout._keyboardIndex]._page.key == "general", "Up selects the preceding surface page")
assert(gui:HandleNavigationKey(frame, "DOWN") and flyout._buttons[flyout._keyboardIndex]._page.key == "text", "Down returns to the exact text page")
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
tile._pageFrame:SetAlpha(0.35)
gui:AnimateOptionsPage(tile._pageFrame)
assert(tile._pageFrame.alpha == 1, "settings content must appear fully opaque immediately when navigating with motion enabled")
gui:AnimateOptionsPage(tile._pageFrame)
assert(tile._pageFrame.alpha == 1, "reselecting a cached settings page must not restart a content fade")
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
assert(tile._pageFrame.alpha == 1, "settings content must remain opaque while flyout motion advances")
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
sectionTile._subPageBodies = { { _contentBody = { _sections = {
    { id = "details", label = "Details", frame = heading },
    { id = "second", label = "Second", frame = Node("Frame") },
    { id = "third", label = "Third", frame = Node("Frame") },
} } } }
local sectionPages = gui:GetTileNavigationPages(sectionTile)
assert(#sectionPages == 4 and sectionPages[1].label == "Details" and sectionPages[1].section == heading and sectionPages[4].label == "Other",
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
Row(dock, 2, "general"):Fire("OnClick")
assert(selections == before + 1 and tile._activeSubPageIndex == 2 and selectedKey == "general", "one dock click must select the existing route")
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
sectionTile._subPageBodies[1]._contentBody._sections[3].frame.top = 300
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
-- Geometry settling is covered by options_initial_section_navigation_test;
-- these fixture owners intentionally contain only navigation data.
function gui:RunWhenSettingsLayoutReady(_, _, callback, isCurrent)
    C_Timer.After(0, function() if not isCurrent or isCurrent() then callback() end end)
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
    Row(frame._pageFlyout, 1, nil, sections[destination].id):Fire("OnClick")
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
Row(frame._pageFlyout, 1, nil, "second"):Fire("OnClick")
Advance(0)
assert(math.abs(viewport:GetVerticalScroll() - 300) < 1, "clicking a section taller than the viewport must show its beginning rather than its middle")
assert(gui:GetTileNavigationPages(sectionTile)[2].active, "the long section must remain highlighted at its beginning")
At = originalAt
viewport.scrollRange = 600
fourthHeading:Hide()
grouped = At(600)
assert(grouped[3].active and grouped[4].label == "Other", "scroll progress must ignore hidden sections and other subpages")
sections[4] = nil
thirdHeading.top = 300
viewport.scrollRange = 0
viewport.scroll = 0
heading.top, secondHeading.top = 790, 500
grouped = gui:GetTileNavigationPages(sectionTile)
assert(grouped[1].active and not grouped[2].active, "a page without scrolling must retain its first section")
secondHeading.top = 810
sectionTile.config.name = "Example"
gui:OpenNavigationFlyout(frame, sectionTile, true)
local groupHeader = Row(frame._pageFlyout, 1, nil, nil, true)
assert(groupHeader._label:GetText() == "General" and groupHeader._chevron,
    "the originating page must be a selectable row with a separate expansion control")
assert(groupHeader:GetHeight() == 26 and Row(frame._pageFlyout, 1, nil, "second"):GetHeight() == 26,
    "parents and section links must use compact 26-unit rows")
assert(Row(frame._pageFlyout, 2)._navTop - Row(frame._pageFlyout, 1, nil, "third")._navTop == 32,
    "expanded groups must leave a six-unit gap after their final section")
print("options_navigation_group_context: ok")

-- Unbuilt sections and nested tabs must be available without renderer work.
ns.QUI_OptionsNavigationCatalog = {
    cold = { sections = { { id = "Objective Tracker", label = "Objective Tracker" }, { id = "Frames", label = "Frames" }, { id = "Menus", label = "Menus" } } },
    surface = { tabs = { { key = "general", label = "General" }, { key = "text", label = "Text" } } },
}
local cold = frame._tiles[11]
cold._subPageBodies, cold._surfacePagesByPage = nil, nil
cold._navigationCatalog = nil
cold.config.subPages = { { name = "Skinning", featureId = "cold", sectionNav = true } }
local pages = gui:GetTileNavigationPages(cold)
assert(#pages == 3 and pages[1].sectionId == "Objective Tracker" and builds == 0)
cold._navigationCatalog = nil
cold.config.subPages = { { name = "Frame", featureId = "surface" } }
pages = gui:GetTileNavigationPages(cold)
assert(#pages == 2 and pages[2].key == "text" and builds == 0)
-- The descriptor registered by the first selection, not a stale cold row, wins.
local selectedCold
local oldSelect = gui.SelectFeatureTile
gui.SelectFeatureTile = function(self, f, index, opts)
    oldSelect(self, f, index, opts)
    cold._surfacePagesByPage = { [1] = { selectTab = function(key) selectedCold = key end } }
end
gui:OpenNavigationFlyout(frame, cold, true)
Row(frame._pageFlyout, 1, "text"):Fire("OnClick")
assert(selectedCold == "text", "cold nested page must resolve the newly registered native descriptor")
local standard = { config = { subPages = {
    { name = "General", featureId = "standardGeneral" },
    { name = "Frames", featureId = "standardFrames" },
} } }
ns.QUI_OptionsNavigationCatalog.standardGeneral = {
    sections = { { id = "Size", label = "Size" }, { id = "Colors", label = "Colors" }, { id = "Text", label = "Text" } }, tabs = {},
}
ns.QUI_OptionsNavigationCatalog.standardFrames = {
    sections = {}, tabs = {
        { key = "health", label = "Health", sections = { { id = "Absorbs", label = "Absorbs" } } },
        { key = "text", label = "Text", sections = { { id = "Names", label = "Names" }, { id = "Health", label = "Health" }, { id = "Power", label = "Power" } } },
    },
}
local standardPages = gui:GetTileNavigationPages(standard)
assert(standardPages[1].sectionId == "Size" and standardPages[1].group == "General",
    "ordinary settings pages must expose section shortcuts without per-page opt-in")
local names
for _, page in ipairs(standardPages) do
    if page.sectionId == "Names" then names = page end
end
assert(names and names.key == "text" and names.pageIndex == 2 and names.group == "Text" and names.parentGroup == "Frames",
    "unbuilt surface pages must expose correctly grouped section shortcuts without building editors")
standard.config.subPages[1].sectionNav = false
assert(gui:GetTileNavigationPages(standard)[1].sectionId == nil,
    "an explicit section navigation opt-out must remain available")

local sliced = { config = { featureId = "standardGeneral", searchSections = { "Colors" } } }
local slicedPages = gui:GetTileNavigationPages(sliced)
assert(#slicedPages == 0,
    "a one-section provider slice must not advertise a submenu or another page's sections")
local context = { providerKey = "partyFrames" }
local contextualFeature = { getNavigationContext = function() return context end }
ns.Settings = ns.Settings or {}
ns.Settings.Registry = ns.Settings.Registry or { GetFeature = function() end }
local getFeature = ns.Settings.Registry.GetFeature
ns.Settings.Registry.GetFeature = function(self, id)
    if id == "contextualFrames" then return contextualFeature end
    return getFeature(self, id)
end
ns.QUI_OptionsNavigationCatalog.contextualFrames = { tabs = {
    { key = "layout", label = "Layout", sections = {
        { id = "Dimensions", label = "Dimensions", contexts = { {} } },
        { id = "Spacing", label = "Spacing", contexts = { {} } },
        { id = "Growth", label = "Growth", contexts = { {} } },
        { id = "Spotlight", label = "Spotlight", contexts = { { providerKey = "raidFrames" } } },
    } },
} }
local contextual = { config = { featureId = "contextualFrames" } }
local contextPages = gui:GetTileNavigationPages(contextual)
assert(#contextPages == 3 and contextPages[1].sectionId == "Dimensions",
    "unopened Party settings must not advertise a raid-only Spotlight destination")
context.providerKey = "raidFrames"
contextPages = gui:GetTileNavigationPages(contextual)
assert(#contextPages == 4 and contextPages[4].sectionId == "Spotlight" and not contextual._built,
    "cold shortcuts must follow the selected context without constructing settings pages")
contextualFeature.getNavigationTabs = function() return {} end
assert(#gui:GetTileNavigationPages(contextual) == 0,
    "a provider with no available tabs must not expose unavailable cold destinations")
contextualFeature.getNavigationTabs = function()
    return { { key = "layout", label = "Layout", isSectionAvailable = function(id) return id ~= "Spotlight" end } }
end
assert(#gui:GetTileNavigationPages(contextual) == 3,
    "provider-specific section availability must filter the cold catalog")

print("OK: options_compact_navigation_test")

-- The parent may report zero while the resize path clears/rebuilds anchors.
-- Once resolved, the viewport must follow the panel without another refresh.
frame:SetWidth(1200)
frame.contentArea:SetHeight(0)
gui:RefreshNavigationDock(frame)
local resizeDock=frame._pageDock
frame.contentArea:SetHeight(680)
resizeDock:SetHeight(680)
assert(resizeDock._scroll:GetHeight()==617, "navigation viewport must recover from transient zero height")
resizeDock:SetHeight(450)
assert(resizeDock._scroll:GetHeight()==387, "viewport must follow shrinking dock height without rebuilding rows")
resizeDock:SetHeight(760)
assert(resizeDock._scroll:GetHeight()==697, "viewport must follow growing dock height without rebuilding rows")
print("options navigation resize viewport: ok")

for count = 0, 3 do
    local small = { config = { subPages = {
        { name = "Small Page", featureId = "smallPage" }, { name = "Other" },
    } }, _isActive = true, _activeSubPageIndex = 1 }
    local catalog, live = {}, {}
    for index = 1, count do
        catalog[index] = { id = "section" .. index, label = "Section " .. index }
        live[index] = { id = catalog[index].id, label = catalog[index].label, frame = Node("Frame") }
    end
    ns.QUI_OptionsNavigationCatalog.smallPage = { sections = catalog }
    local baseConfig = small.config
    for _, built in ipairs({ false, true }) do
        small.config, small._surfacePagesByPage = baseConfig, nil
        small._subPageBodies = built and { { _contentBody = { _sections = live } } } or nil
        local pages = gui:GetTileNavigationPages(small)
        if count <= 2 then
            assert(#pages == 2 and pages[1].label == "Small Page" and pages[1].active
                and not pages[1].group and not pages[1].sectionId,
                "pages with at most two sections must stay single clickable destinations, cold and built")
        else
            assert(#pages == 4 and pages[1].sectionId == "section1" and pages[1].group == "Small Page",
                "pages with three sections must retain grouped shortcuts, cold and built")
        end
        small.config = { featureId = "smallPage" }
        pages = gui:GetTileNavigationPages(small)
        assert(#pages == (count < 3 and 0 or 3),
            "a single page with at most two sections must not create a section submenu")
        small.config = { subPages = { baseConfig.subPages[1] } }
        pages = gui:GetTileNavigationPages(small)
        assert(#pages == (count < 3 and 1 or 3),
            "a single configured subpage must obey the same section threshold")
        local tab = { key = "settings", label = "Settings", disabled = true, sections = catalog }
        ns.QUI_OptionsNavigationCatalog.smallSurface = { tabs = { tab } }
        small.config = { featureId = "smallSurface" }
        small._navigationCatalog = nil
        small._surfacePagesByPage = built and { {
            getTabs = function() return { tab } end,
            getActiveTab = function() return "settings" end,
            getPage = function() return small._subPageBodies[1] end,
        } } or nil
        pages = gui:GetTileNavigationPages(small)
        assert(#pages == (count < 3 and 1 or 3) and pages[1].key == "settings" and pages[1].disabled,
            "compact surface destinations must retain their exact key and disabled state")
        assert((pages[1].sectionId ~= nil) == (count >= 3),
            "surface section links require three visible destinations")
        if count == 3 then
            if built then live[3].frame:Hide()
            else catalog[3].contexts = { { providerKey = "raidFrames" } } end
            pages = gui:GetTileNavigationPages(small)
            assert(#pages == 1 and not pages[1].sectionId,
                "hidden or unavailable sections must not force an unnecessary submenu")
            live[3].frame:Show()
            catalog[3].contexts = nil
        end
        small._navigationCatalog = nil
    end
end

local configuredSections = {
    { id = "Panel", label = "Panel" }, { id = "Slot", label = "Slot" },
    { id = "Time Options", label = "Time Options" },
}
local configuredFeature = { getNavigationSections = function() return configuredSections end }
local priorGetFeature = ns.Settings.Registry.GetFeature
ns.Settings.Registry.GetFeature = function(self, id)
    if id == "configured" then return configuredFeature end
    return priorGetFeature(self, id)
end
ns.QUI_OptionsNavigationCatalog.configured = { sections = {
    { id = "Outdated", label = "Outdated" },
} }
local configured = { config = { featureId = "configured" } }
local configuredPages = gui:GetTileNavigationPages(configured)
assert(#configuredPages == 3 and configuredPages[3].sectionId == "Time Options" and builds == 0,
    "cold section links must use current provider metadata without constructing its editor")
configuredSections[3] = { id = "Spec Display", label = "Spec Display" }
configuredPages = gui:GetTileNavigationPages(configured)
assert(#configuredPages == 3 and configuredPages[3].sectionId == "Spec Display",
    "changing a selected panel or slot must refresh cold section links without clearing the static catalog")
configured.config.searchSections = { "Panel", "Spec Display" }
assert(#gui:GetTileNavigationPages(configured) == 0,
    "provider section slices and the three-section minimum must apply to dynamic cold metadata")
configured.config.searchSections = nil
configuredSections = {}
assert(#gui:GetTileNavigationPages(configured) == 0,
    "an explicitly empty current section list must not fall back to stale generated entries")
configuredSections = nil
assert(#gui:GetTileNavigationPages(configured) == 0,
    "an unavailable metadata provider must fall back to the existing one-section catalog")
configuredSections = { { id = "Panel", label = "Panel" }, { id = "Slot", label = "Slot" }, { id = "Time Options", label = "Time Options" } }
configured._subPageBodies = {{ _contentBody = { _sections = {
    { id = "Live Panel", label = "Live Panel", frame = Node("Frame") },
    { id = "Live Slot", label = "Live Slot", frame = Node("Frame") },
    { id = "Live Options", label = "Live Options", frame = Node("Frame") },
} } }}
assert(gui:GetTileNavigationPages(configured)[3].sectionId == "Live Options",
    "mounted section frames must remain authoritative for actual jump destinations")
print("options dynamic cold navigation: ok")

local revealTile = Node("Button", frame)
revealTile.index = #frame._tiles + 1
revealTile.id, revealTile.config = "reveal_navigation", { name = "Reveal Navigation", subPages = {} }
revealTile._isActive, revealTile._activeSubPageIndex = true, 4
revealTile._subPageBodies = {}
revealTile._title = Node("FontString")
revealTile._pageFrame = Node("Frame", frame)
for pageIndex = 1, 4 do
    revealTile.config.subPages[pageIndex] = { name = "Page " .. pageIndex }
    local pageScroll = Node("ScrollFrame")
    pageScroll.scrollRange = 900
    local sections = {}
    for sectionIndex = 1, 3 do
        local section = Node("Frame")
        section.top = 800 - (sectionIndex - 1) * 300
        sections[sectionIndex] = { id = "Section " .. sectionIndex, frame = section }
    end
    revealTile._subPageBodies[pageIndex] = {
        _scrollFrame = pageScroll, _contentBody = { _sections = sections },
    }
end
frame._tiles[revealTile.index] = revealTile
frame._lastTileIndex = revealTile.index
frame:SetWidth(1200)
QUI.db.profile.general.optionsNavigationDocked = true
dock:SetHeight(180)
dock._keyboard = false
dock._scroll:SetVerticalScroll(0)
local revealWrites, scrollbarNotifications = 0, 0
local revealController = { target = 9 }
function revealController:ScrollTo(offset, instant)
    assert(instant, "explicit navigation must settle the page-list scroll immediately")
    self.target = nil
    revealWrites = revealWrites + 1
    dock._scroll:SetVerticalScroll(offset)
    scrollbarNotifications = scrollbarNotifications + 1
end
ns.UIKit.GetSmoothScroll = function(scrollFrame)
    if scrollFrame == dock._scroll then return revealController end
end
local function AssertRowVisible(row, message)
    local offset, viewport = dock._scroll:GetVerticalScroll(), dock._scroll:GetHeight()
    assert(row._navTop >= offset and row._navTop + row:GetHeight() <= offset + viewport, message)
end
gui:RefreshNavigationDock(frame, true)
assert(Row(dock, 4, nil, "Section 1")._page.active and not dock._keyboard,
    "explicit navigation must retain mouse mode and select the destination row")
AssertRowVisible(Row(dock, 4, nil, "Section 1"), "the dock must reveal an offscreen destination after a programmatic page jump")
assert(revealWrites > 0 and not revealController.target and scrollbarNotifications == revealWrites,
    "page-list jumps must use the existing scroll controller and notify its listeners")
dock._scroll:SetVerticalScroll(0)
local writesBefore = revealWrites
gui:RefreshNavigationDock(frame)
Row(dock, 4, nil, "Section 3"):Fire("OnEnter")
Row(dock, 4, nil, "Section 3"):Fire("OnLeave")
gui:RefreshNavigationSectionHighlight(revealTile)
assert(dock._scroll:GetVerticalScroll() == 0 and revealWrites == writesBefore,
    "ordinary refresh and hover must preserve manual page-list scrolling")
gui:RefreshNavigationDock(frame, true)
AssertRowVisible(Row(dock, 4, nil, "Section 1"), "reopening the same destination must reveal it after the list was manually scrolled away")
revealTile._activeSubPageIndex = 1
gui:RefreshNavigationDock(frame, true)
AssertRowVisible(Row(dock, 1, nil, "Section 1"), "an explicit jump must also reveal a destination above the current viewport")
revealTile._activeSubPageIndex = 4
gui:RefreshNavigationDock(frame, true)
local delayedPage = revealTile._subPageBodies[4]
delayedPage._scrollFrame:SetVerticalScroll(900)
for index, section in ipairs(delayedPage._contentBody._sections) do
    section.frame.top = 800 - (index - 1) * 20
end
dock._scroll:SetVerticalScroll(0)
gui:RefreshNavigationSectionHighlight(revealTile, true)
assert(Row(dock, 4, nil, "Section 3")._page.active, "settled content scrolling must identify the final section destination")
AssertRowVisible(Row(dock, 4, nil, "Section 3"), "the page list must reveal the destination section after its delayed content jump")
print("options explicit navigation destination reveal: ok")

assert(#dock._pages == 12 and #dock._rows == 7,
    "the complete catalog must remain available while only the selected page exposes section rows")
assert(not FindRow(dock, 1, nil, "Section 1") and not FindRow(dock, 2, nil, "Section 1"),
    "unselected page sections must start collapsed")
local selectionCount = selections
local editorScroll = revealTile._subPageBodies[4]._scrollFrame:GetVerticalScroll()
Row(dock, 2, nil, nil, true)._chevron:Click()
assert(#dock._rows == 10 and FindRow(dock, 2, nil, "Section 1") and FindRow(dock, 4, nil, "Section 1"),
    "a chevron must expose another group's sections without collapsing the selected group")
assert(selections == selectionCount and revealTile._activeSubPageIndex == 4
    and revealTile._subPageBodies[4]._scrollFrame:GetVerticalScroll() == editorScroll,
    "peeking at another page must preserve the editor and content scroll")
Row(dock, 4, nil, nil, true)._chevron:Click()
assert(not FindRow(dock, 4, nil, "Section 1"), "the selected page may be collapsed explicitly")
dock._scroll:SetVerticalScroll(25)
local positionsBefore = {}
for i, row in ipairs(dock._rows) do positionsBefore[i] = dock._buttons[i]._navTop .. ":" .. row.label end
gui:RefreshNavigationSectionHighlight(revealTile)
gui:RefreshNavigationDock(frame)
assert(not FindRow(dock, 4, nil, "Section 1") and dock._scroll:GetVerticalScroll() == 25,
    "ordinary section and layout refreshes must preserve manual collapse and navigation scroll")
for i, row in ipairs(dock._rows) do
    assert(positionsBefore[i] == dock._buttons[i]._navTop .. ":" .. row.label,
        "settings scrolling must never rearrange navigation targets")
end
gui:RefreshNavigationDock(frame, true)
assert(FindRow(dock, 4, nil, "Section 1") and not FindRow(dock, 2, nil, "Section 1"),
    "explicit destination reveal must reopen its group and compact unrelated groups")
Row(dock, 2, nil, nil, true):Click()
assert(revealTile._activeSubPageIndex == 2 and selections == selectionCount + 1,
    "clicking the parent page must navigate independently of its chevron")
assert(FindRow(dock, 2, nil, "Section 1") and not FindRow(dock, 4, nil, "Section 1"),
    "selecting a parent page must open its section links and collapse the previous page")

dock._keyboard = true
dock._keyboardIndex = Row(dock, 3, nil, nil, true)._index
assert(gui:HandleNavigationKey(frame, "RIGHT") and FindRow(dock, 3, nil, "Section 1"),
    "Right must expand the focused group without navigating")
assert(selections == selectionCount + 1, "keyboard expansion must preserve the editor")
assert(gui:HandleNavigationKey(frame, "DOWN") and dock._rows[dock._keyboardIndex].sectionId == "Section 1",
    "Down must reach the first displayed child")
assert(gui:HandleNavigationKey(frame, "LEFT") and dock._rows[dock._keyboardIndex]._group,
    "Left from a section must focus its parent")
assert(gui:HandleNavigationKey(frame, "LEFT") and not FindRow(dock, 3, nil, "Section 1"),
    "Left from an open parent must collapse its children")
assert(gui:HandleNavigationKey(frame, "END") and dock._keyboardIndex == #dock._rows
    and dock._rows[dock._keyboardIndex].pageIndex == 4,
    "End must select the last displayed row rather than a hidden catalog item")
assert(gui:HandleNavigationKey(frame, "HOME") and dock._keyboardIndex == 1,
    "Home must select the first displayed row")
dock._keyboard = false

dock._scroll:SetVerticalScroll(40)
local savedModule = frame._lastTileIndex
frame._lastTileIndex = sectionTile.index
sectionTile._isActive, revealTile._isActive = true, false
gui:RefreshNavigationDock(frame, true, true)
dock._scroll:SetVerticalScroll(7)
frame._lastTileIndex = savedModule
sectionTile._isActive, revealTile._isActive = false, true
gui:RefreshNavigationDock(frame, true, true)
assert(dock._scroll:GetVerticalScroll() == 40, "returning to a module must restore its saved page-list offset")
frame._lastTileIndex = sectionTile.index
sectionTile._isActive, revealTile._isActive = true, false
gui:RefreshNavigationDock(frame, true, true)
assert(dock._scroll:GetVerticalScroll() == 7, "each module must retain its own page-list offset")
print("options accordion navigation and scroll memory: ok")

local surfaceTile = Node("Button", frame)
surfaceTile.index = #frame._tiles + 1
surfaceTile.config = { name = "Surface Accordion", featureId = "accordionSurface" }
surfaceTile._title, surfaceTile._pageFrame = Node("FontString"), Node("Frame", frame)
surfaceTile._activeSubPageIndex = 1
frame._tiles[surfaceTile.index] = surfaceTile
local surfaceKey = "general"
local surfaceTabs, surfaceOwners = {}, {}
for _, key in ipairs({ "general", "advanced", "disabled" }) do
    local catalogSections, liveSections = {}, {}
    for i = 1, 3 do
        local id = key .. i
        catalogSections[i] = { id = id, label = id }
        liveSections[i] = { id = id, label = id, frame = Node("Frame") }
    end
    surfaceTabs[#surfaceTabs + 1] = { key = key, label = key, disabled = key == "disabled", sections = catalogSections }
    surfaceOwners[key] = { _contentBody = { _sections = liveSections } }
end
ns.QUI_OptionsNavigationCatalog.accordionSurface = { tabs = surfaceTabs }
local surfaceDescriptor = {
    getTabs = function() return surfaceTabs end,
    getActiveTab = function() return surfaceKey end,
    getPage = function(key) return surfaceOwners[key] end,
    selectTab = function(key)
        surfaceKey = key
        gui:UpdateTileNavigationTitle(surfaceTile)
    end,
}
surfaceTile._surfacePagesByPage = { surfaceDescriptor }
gui:SelectFeatureTile(frame, surfaceTile.index, { noHistory = true })
gui:RefreshNavigationDock(frame, true)
assert(FindRow(dock, 1, "general", "general1") and not FindRow(dock, 1, "advanced", "advanced1"),
    "surface accordions must expand the selected surface key")
local disabledRow = Row(dock, 1, "disabled", nil, true)
assert(disabledRow.enabled == false and disabledRow._chevron.enabled == false,
    "disabled surface groups must disable selection and expansion")
local beforeDisabled = selections
disabledRow:Fire("OnClick")
assert(selections == beforeDisabled and surfaceKey == "general", "disabled parent routes cannot navigate")
surfaceDescriptor.selectTab("advanced")
assert(FindRow(dock, 1, "advanced", "advanced1") and not FindRow(dock, 1, "general", "general1"),
    "a surface key change must expand its destination even without an explicit dock reveal")
frame._navigationHistory = {}
gui:PushNavigationHistory(frame)
surfaceDescriptor.selectTab("general")
gui:SelectFeatureTile(frame, revealTile.index, { noHistory = true })
gui:RefreshNavigationDock(frame, true)
gui:NavigateOptionsBack(frame)
assert(frame._lastTileIndex == surfaceTile.index and surfaceKey == "advanced"
    and FindRow(dock, 1, "advanced", "advanced1") and not FindRow(dock, 1, "general", "general1"),
    "Back must expand the final restored surface key, after restoring the outer page")
print("options surface accordion and Back restoration: ok")

gui:SetNavigationDocked(frame, false)
frame:SetHeight(760)
gui:OpenNavigationFlyout(frame, revealTile, true)
local resizeFlyout = frame._pageFlyout
local compactHeight = resizeFlyout:GetHeight()
Row(resizeFlyout, 3, nil, nil, true)._chevron:Click()
assert(resizeFlyout:GetHeight() == compactHeight + 84,
    "a flyout must grow to accommodate three expanded rows and their group gap when space allows")
Row(resizeFlyout, 3, nil, nil, true)._chevron:Click()
assert(resizeFlyout:GetHeight() == compactHeight,
    "collapsing a group must reclaim unused flyout height")
frame:SetHeight(220)
gui:OpenNavigationFlyout(frame, revealTile, true)
resizeFlyout._scroll:SetVerticalScroll(35)
gui:CloseNavigationFlyout(frame)
gui:OpenNavigationFlyout(frame, sectionTile, true)
resizeFlyout._scroll:SetVerticalScroll(9)
gui:CloseNavigationFlyout(frame)
gui:OpenNavigationFlyout(frame, revealTile, true)
assert(resizeFlyout._scroll:GetVerticalScroll() == 35,
    "reopening a module flyout must restore its own saved scroll position")
gui:CloseNavigationFlyout(frame)
gui:OpenNavigationFlyout(frame, sectionTile, true)
assert(resizeFlyout._scroll:GetVerticalScroll() == 9,
    "switching flyout modules must not reuse another module's scroll position")
frame:SetHeight(760)
gui:OpenNavigationFlyout(frame, sectionTile, true)
assert(resizeFlyout._scroll:GetVerticalScroll() == 0,
    "saved flyout scroll must clamp when the full list fits after resizing")
print("options accordion flyout height and scroll memory: ok")

gui:SetNavigationDocked(frame, true)
revealTile._activeSubPageIndex = 2
frame._lastTileIndex = revealTile.index
for _, entry in ipairs(frame._tiles) do entry._isActive = entry == revealTile end
gui:RefreshNavigationDock(frame, true)
Row(dock, 2, nil, nil, true)._chevron:Click()
assert(not FindRow(dock, 2, nil, "Section 1"), "fixture must leave the remembered destination manually collapsed")
frame._lastTileIndex = sectionTile.index
sectionTile._isActive, revealTile._isActive = true, false
gui:RefreshNavigationDock(frame, true, true)
frame._lastTileIndex = revealTile.index
sectionTile._isActive, revealTile._isActive = false, true
gui:RefreshNavigationDock(frame, true)
assert(FindRow(dock, 2, nil, "Section 1"),
    "a cross-module explicit destination must reopen a previously collapsed remembered group")
AssertRowVisible(Row(dock, 2, nil, "Section 1"),
    "cross-module search navigation must reveal its destination instead of restoring an unrelated offset")
print("options cross-module explicit destination expansion: ok")

gui:SetNavigationDocked(frame, false)
gui:OpenNavigationFlyout(frame, revealTile, true)
Row(frame._pageFlyout, 2, nil, nil, true)._chevron:Click()
assert(not FindRow(frame._pageFlyout, 2, nil, "Section 1"),
    "fixture must collapse the selected group in compact navigation")
gui:CloseNavigationFlyout(frame)
gui:RefreshNavigationDock(frame, true)
gui:OpenNavigationFlyout(frame, revealTile, true)
assert(FindRow(frame._pageFlyout, 2, nil, "Section 1"),
    "explicit navigation while the dock is disabled must expand its destination when the flyout reopens")
Row(frame._pageFlyout, 2, nil, nil, true)._chevron:Click()
Row(frame._pageFlyout, 2, nil, nil, true):Click()
gui:OpenNavigationFlyout(frame, revealTile, true)
assert(FindRow(frame._pageFlyout, 2, nil, "Section 1"),
    "selecting a collapsed parent must expand its sections when compact navigation reopens")
print("options compact explicit destination expansion: ok")

local hierarchyTile = Node("Button", frame)
hierarchyTile.index = #frame._tiles + 1
hierarchyTile.id = "nested_reminders"
hierarchyTile.config = { name = "Reminders", subPages = {
    { name = "Defensive Reminders" }, { name = "Spell Reminders", featureId = "nestedReminderSurface" },
} }
hierarchyTile._title, hierarchyTile._pageFrame = Node("FontString"), Node("Frame", frame)
hierarchyTile._activeSubPageIndex = 2
frame._tiles[hierarchyTile.index] = hierarchyTile
local hierarchyKey = "appearance"
local hierarchyTabs = {
    { key = "timing", label = "Timing", sections = { { id = "Timing", label = "Timing" } } },
    { key = "appearance", label = "Appearance", sections = {
        { id = "Icon", label = "Icon" }, { id = "Glow", label = "Glow" }, { id = "Position", label = "Position" },
    } },
    { key = "literal", label = "Audio / Voice", sections = {
        { id = "Voice", label = "Voice" }, { id = "Volume", label = "Volume" }, { id = "Channel", label = "Channel" },
    } },
    { key = "sounds", label = "Sounds", sections = { { id = "Sound", label = "Sound" } } },
}
ns.QUI_OptionsNavigationCatalog.nestedReminderSurface = { tabs = hierarchyTabs }
hierarchyTile._surfacePagesByPage = { [2] = {
    getTabs = function() return hierarchyTabs end,
    getActiveTab = function() return hierarchyKey end,
    selectTab = function(key) hierarchyKey = key; gui:UpdateTileNavigationTitle(hierarchyTile) end,
} }
gui:SelectFeatureTile(frame, hierarchyTile.index, { subPageIndex = 2 })
gui:SetNavigationDocked(frame, true)
gui:RefreshNavigationDock(frame, true)
local hierarchyParent = Row(dock, 2, nil, nil, true)
local appearanceParent = Row(dock, 2, "appearance", nil, true)
local iconRow = Row(dock, 2, "appearance", "Icon")
assert(hierarchyParent._page.label == "Spell Reminders" and hierarchyParent._page._depth == 0,
    "nested surfaces must retain one outer page parent")
assert(appearanceParent._page.label == "Appearance" and appearanceParent._page._depth == 1
    and iconRow._page._depth == 2,
    "surface tabs and their sections must form separate nested levels without slash-joined labels")
assert(Row(dock, 2, "timing")._page._depth == 1 and Row(dock, 2, "sounds")._page._depth == 1,
    "short surface tabs must share their parent with tabs that expose sections")
assert(Row(dock, 2, "literal", nil, true)._page.label == "Audio / Voice",
    "literal slashes in a label must not invent hierarchy levels")
local parentCount = 0
for _, row in ipairs(dock._rows) do
    if row.pageIndex == 2 and row._depth == 0 then parentCount = parentCount + 1 end
end
assert(parentCount == 1, "mixed short and section tabs must never duplicate the outer parent")
local nestedSelectionCount = selections
hierarchyParent._chevron:Click()
assert(not FindRow(dock, 2, "appearance", nil, true) and not FindRow(dock, 2, "timing")
    and not FindRow(dock, 2, "appearance", "Icon"),
    "collapsing the outer page must hide all descendant tabs and sections")
assert(selections == nestedSelectionCount, "collapsing an ancestor must not navigate")
gui:RefreshNavigationSectionHighlight(hierarchyTile)
gui:RefreshNavigationDock(frame)
assert(not FindRow(dock, 2, "appearance", nil, true),
    "ordinary updates must preserve an explicitly collapsed ancestor")
gui:RefreshNavigationDock(frame, true)
assert(FindRow(dock, 2, "appearance", "Icon"),
    "an explicit destination must expand every ancestor of its selected section")
dock._keyboard = true
dock._keyboardIndex = Row(dock, 2, "appearance", "Icon")._index
gui:HandleNavigationKey(frame, "LEFT")
assert(dock._rows[dock._keyboardIndex].key == "appearance" and dock._rows[dock._keyboardIndex]._group,
    "Left from a nested section must focus its surface-tab parent")
gui:HandleNavigationKey(frame, "LEFT")
assert(not FindRow(dock, 2, "appearance", "Icon"), "Left must collapse an expanded surface-tab parent")
gui:HandleNavigationKey(frame, "LEFT")
assert(dock._rows[dock._keyboardIndex].key == nil and dock._rows[dock._keyboardIndex]._group
    and dock._rows[dock._keyboardIndex].pageIndex == 2,
    "Left from a collapsed surface tab must move to its outer page parent")
dock._keyboard = false
Row(dock, 2, "literal", nil, true):Click()
assert(hierarchyKey == "literal" and FindRow(dock, 2, "literal", "Voice")
    and not FindRow(dock, 2, "appearance", "Icon"),
    "selecting a sibling surface tab must keep the outer ancestor open and reveal the exact tab")
print("options nested surface hierarchy: ok")

local hierarchyDescriptor = hierarchyTile._surfacePagesByPage[2]
local rootSelections = 0
hierarchyDescriptor.rootKey = "general"
hierarchyDescriptor.selectRoot = function()
    rootSelections = rootSelections + 1
    hierarchyDescriptor.selectTab("general")
end
Row(dock, 2, nil, nil, true):Click()
assert(rootSelections == 1 and hierarchyKey == "general",
    "an outer surface parent must open its own root controls")
assert(Row(dock, 2, nil, nil, true)._page.active and FindRow(dock, 2, "timing"),
    "a root destination must highlight and expand its parent without adding a General tab")
assert(not FindRow(dock, 2, "general"), "the root must not duplicate itself among child tabs")
gui:RefreshNavigationSectionHighlight(hierarchyTile)
assert(Row(dock, 2, nil, nil, true)._page.active,
    "scroll highlights must retain the active root destination")
gui:PushNavigationHistory(frame)
Row(dock, 2, "appearance", nil, true):Click()
assert(hierarchyKey == "appearance" and rootSelections == 1
    and FindRow(dock, 2, "appearance", "Glow"),
    "child destinations must keep selecting their exact surface tab")
gui:NavigateOptionsBack(frame)
assert(hierarchyKey == "general" and Row(dock, 2, nil, nil, true)._page.active
    and FindRow(dock, 2, "timing"), "Back must restore and reveal the root destination")
hierarchyTile._surfacePagesByPage[2] = nil
hierarchyKey = "appearance"
gui:RefreshNavigationDock(frame, true)
local selectBeforeRootBuild = gui.SelectFeatureTile
gui.SelectFeatureTile = function(self, target, index, options)
    selectBeforeRootBuild(self, target, index, options)
    hierarchyTile._surfacePagesByPage[2] = hierarchyDescriptor
end
Row(dock, 2, nil, nil, true):Click()
gui.SelectFeatureTile = selectBeforeRootBuild
assert(rootSelections == 2 and hierarchyKey == "general"
    and Row(dock, 2, nil, nil, true)._page.active,
    "a cold parent route must use the root callback registered while its page builds")
print("options surface root destination: ok")
