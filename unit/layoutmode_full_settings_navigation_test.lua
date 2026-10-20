local function Read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local bootstrap = Read("tools/generate_search_cache.lua")
local marker = assert(bootstrap:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(bootstrap:sub(1, marker - 1)))()
local GUI, ns = QUI.GUI
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
assert(loadfile(os.getenv("QUI_LAYOUT_UTILS_SOURCE") or "modules/layout/layoutmode_utils.lua"))("QUI", ns)

local create = CreateFrame
CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    frame.scripts = {}
    local createFontString = frame.CreateFontString
    frame.CreateFontString = function(self, ...)
        local label = createFontString(self, ...)
        label._captureKind = "FontString"
        return label
    end
    frame.SetScript = function(self, key, callback) self.scripts[key] = callback end
    frame.SetVerticalScroll = function(self, value) self.scroll = value end
    frame.GetVerticalScroll = function(self) return self.scroll or 0 end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
local frame = CreateFrame("Frame")
local owner = CreateFrame("Frame", nil, frame)
local scroll = CreateFrame("ScrollFrame", nil, owner)
local body = CreateFrame("Frame", nil, scroll)
owner._contentBody, owner._scrollFrame = body, scroll
owner:SetWidth(800)
owner:SetHeight(500)
body:SetWidth(800)
scroll:SetScrollChild(body)
scroll.GetVerticalScrollRange = function() return 2000 end
local ready = false
body.GetTop = function() return ready and 1000 + scroll:GetVerticalScroll() or nil end
local profile = QUI.QUICore.db.profile
profile.swingTimers = {}
for _, entry in ipairs(ns.SwingTimers.entries) do
    profile.swingTimers[entry.key] = { width = 250, height = 20, fontSize = 11 }
end
ns.Settings.Registry:GetFeature("swingTimersPage").sectionsById.settings.build(body)
body:SetHeight(2500)
local tile = { id = "gameplay", config = { name = "Gameplay" }, _pageFrame = owner,
    _subPageBodies = { [9] = owner }, indicator = frame:CreateTexture(), hoverBg = frame:CreateTexture(),
    text = frame:CreateFontString() }
frame._tiles = { tile }
GUI.MainFrame = frame
GUI.BuildTilePage = function(_, _, target, page) target._activeSubPageIndex = page end
GUI.CloseNavigationFlyout = nil
GUI.PushNavigationHistory = nil
GUI.AnimateOptionsPage = nil
GUI.UpdateTileNavigationTitle = nil
QUI.SlashCommandOpen = function() end
local navigationReveals = 0
GUI.RefreshNavigationSectionHighlight = function(_, target, revealActive)
    assert(target == tile and revealActive, "mover jumps must reveal the destination in the pages list")
    navigationReveals = navigationReveals + 1
end

local source = Read(os.getenv("QUI_FRAMEWORK_SOURCE") or "QUI_Options/framework.lua")
local start = assert(source:find("function GUI:SelectFeatureTile(frame, index, opts)", 1, true))
local finish = assert(source:find("local SelectFeatureTileWithContent", start, true))
local chunk = assert(loadstring(source:sub(start, finish - 1)))
local jumps = {}
local jumpStart = assert(source:find("local function JumpScrollTo(", 1, true))
local jumpEnd = assert(source:find("function GUI:ScrollToRegisteredSection", jumpStart, true))
local jumpChunk = assert(loadstring(source:sub(jumpStart, jumpEnd - 1) .. "\nreturn JumpScrollTo"))
setfenv(jumpChunk, setmetatable({ UIKit = ns.UIKit }, { __index = _G }))
local JumpScrollTo = jumpChunk()
setfenv(chunk, setmetatable({ GUI = GUI, C = GUI.Colors, EnsureSidebarTileVisible = function() end,
    JumpScrollTo = JumpScrollTo }, { __index = _G }))
chunk()
ns.UIKit.GetSmoothScroll = function(target)
    assert(target == scroll)
    return { ScrollTo = function(_, offset, immediate)
        assert(immediate, "mover links must immediately update the smooth-scroll controller")
        jumps[#jumps + 1] = offset
        target:SetVerticalScroll(offset)
    end }
end
local function Tick()
    local driver = owner._quiLayoutReadyDriver
    if driver and driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, 0.1) end
end
for index, entry in ipairs(ns.SwingTimers.entries) do
    local heading = assert(GUI:_findWidgetByLabel(body, ns.L[entry.label]), "main settings heading must exist")
    local position = index * 500
    heading.GetTop = function() local top = body:GetTop(); return top and top - position end
    local rows = {}
    ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, entry.key, rows)
    assert(#rows == 1)
    ready = false
    scroll:SetVerticalScroll(125)
    local previous = #jumps
    local previousReveals = navigationReveals
    rows[1].scripts.OnClick()
    Tick()
    assert(#jumps == previous, "cold layout must wait for section geometry")
    assert(navigationReveals == previousReveals, "the pages list must wait for the final section destination")
    ready = true
    Tick(); Tick(); Tick()
    assert(#jumps == previous + 1, entry.key .. " mover link must scroll to its own settings section")
    assert(navigationReveals == previousReveals + 1, "the settled mover jump must reveal its row in the pages list")
    assert(jumps[#jumps] == position - 50, "section navigation must use an absolute offset from the content body")
    scroll:SetVerticalScroll(1800)
    rows[1].scripts.OnClick()
    Tick(); Tick(); Tick()
    assert(#jumps == previous + 2 and jumps[#jumps] == position - 50,
        "reopening a mounted page must reset its previous scroll position to the selected section")
end

local rows, previous = {}, #jumps
ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, "swingTimersPage", rows)
rows[1].scripts.OnClick()
Tick(); Tick(); Tick()
assert(#jumps == previous + 1 and jumps[#jumps] == 0,
    "single-feature destinations must reset a cached scroll position to the top")

local gameplay
GUI.AddFeatureTile = function(_, _, config) gameplay = config end
ns.QUI_GameplayTile.Register(frame)
local renderFeature = ns.Settings.Renderer.RenderFeature
ns.Settings.Renderer.RenderFeature = function(_, _, host) host:SetHeight(300) end
gameplay.subPages[6].buildFunc(body)
ns.Settings.Renderer.RenderFeature = renderFeature
body:SetHeight(2500)
tile._subPageBodies[6] = owner
for index, key in ipairs({ "petWarning", "actionTracker" }) do
    local heading = assert(GUI:_findSectionByFeatureId(body, key), "actual stacked feature title must be present")
    local position = index * 500
    heading.GetTop = function() return body:GetTop() - position end
    rows = {}
    ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, key, rows)
    rows[1].scripts.OnClick()
    Tick(); Tick(); Tick()
    assert(tile._activeSubPageIndex == 6 and jumps[#jumps] == position,
        key .. " must target its registered feature on the shared Combat page")
end

local feature = ns.Settings.Registry:GetFeature("actionTracker")
local activeTab, selectedLookup
feature.onNavigate = function(key) selectedLookup = key end
feature.searchNavigate = function(entry)
    assert(selectedLookup == entry.providerKey, "lookup selection must run before inner-tab navigation")
    activeTab = entry.surfaceTabKey
end
ns.Settings.Registry:RegisterLookupKey("actionTracker", "actionTracker", {
    subPageIndex = 7, surfaceTabKey = "text", scrollToLabel = "Test inner heading",
})
local outer = CreateFrame("Frame")
tile._subPageBodies[7] = outer
tile._surfacePagesByPage = { [7] = {
    getActiveTab = function() return activeTab end,
    getPage = function() return owner end,
} }
local heading = CreateFrame("Frame", nil, body)
heading:CreateFontString():SetText("Test inner heading")
heading.GetTop = function() return body:GetTop() - 700 end
rows = {}
ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, "actionTracker", rows)
rows[1].scripts.OnClick()
Tick(); Tick(); Tick()
assert(tile._activeSubPageIndex == 7 and activeTab == "text" and jumps[#jumps] == 650,
    "lookup overrides must select their page, inner tab and explicit heading ahead of the base feature route")

rows[1].scripts.OnClick()
previous = #jumps
activeTab = "other"
Tick(); Tick(); Tick()
assert(#jumps == previous, "changing the inner tab must cancel a pending mover jump")
rows[1].scripts.OnClick()
previous = #jumps
tile._surfacePagesByPage[7].getPage = function() return outer end
Tick(); Tick(); Tick()
assert(#jumps == previous, "changing the active variant must cancel a pending mover jump")

tile._surfacePagesByPage[7].getPage = function() return owner end
ns.Settings.Registry:RegisterLookupKey("actionTracker", "testDynamicMover", {
    subPageIndex = 7, surfaceTabKey = "text", scrollToLabel = "No heading on this page",
})
rows = {}
ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, "testDynamicMover", rows)
scroll:SetVerticalScroll(1400)
rows[1].scripts.OnClick()
Tick(); Tick(); Tick()
assert(selectedLookup == "testDynamicMover" and scroll:GetVerticalScroll() == 0,
    "dynamic lookup aliases must reset the active inner viewport when no section destination exists")

heading._quiPinBinding = { path = "profile.actionTracker.testSetting" }
ns.Settings.Registry:RegisterLookupKey("actionTracker", "testPathMover", {
    scrollToPath = heading._quiPinBinding.path,
})
rows = {}
ns.QUI_LayoutMode_Utils.BuildOpenFullSettingsLink(frame, "testPathMover", rows)
rows[1].scripts.OnClick()
Tick(); Tick(); Tick()
assert(tile._activeSubPageIndex == 6 and jumps[#jumps] == 650,
    "an explicit setting path must take precedence over the generic feature header")

print("OK: layoutmode_full_settings_navigation_test")
