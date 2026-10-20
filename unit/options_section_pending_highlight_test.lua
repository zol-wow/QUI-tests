local file = assert(io.open(os.getenv("QUI_NAV_SOURCE") or "QUI_Options/navigation.lua", "rb"))
local source = file:read("*a")
file:close()
local GUI, drivers = {}, {}
local ns = { UIKit = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
local sandbox = setmetatable({ QUI = { GUI = GUI } }, { __index = _G })
sandbox.CreateFrame = function()
    local driver = { scripts = {}, shown = false }
    function driver:SetScript(event, callback) self.scripts[event] = callback end
    function driver:Show() self.shown = true end
    function driver:Hide()
        local shown = self.shown
        self.shown = false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    drivers[#drivers + 1] = driver
    return driver
end
local chunk = assert(loadstring(source .. "\nreturn SelectPage"))
setfenv(chunk, sandbox)
local selectPage = chunk("QUI", ns)
local settled = false
local function Page(names)
    local scroll = { offset = 0 }
    function scroll:GetVerticalScroll() return self.offset end
    function scroll:GetVerticalScrollRange() return 2000 end
    function scroll:GetHeight() return 600 end
    function scroll:GetTop() return 1000 end
    function scroll:HookScript() end
    function scroll:SetVerticalScroll(offset) self.offset = offset end
    local body = { _sections = {} }
    function body:GetTop() return settled and 1000 + scroll.offset or nil end
    function body:GetHeight() return 2600 end
    function scroll:GetScrollChild() return body end
    for index, name in ipairs(names) do
        local heading = { shown = true }
        function heading:IsShown() return self.shown end
        function heading:GetTop() return 1000 + scroll.offset - (index - 1) * 800 end
        body._sections[index] = { id = name, label = name, frame = heading }
    end
    return { _scrollFrame = scroll, _contentBody = body,
        GetWidth = function() return 800 end, GetHeight = function() return 600 end }
end
local general = Page({ "Auras", "General", "Skins" })
local perBar = Page({ "Layout", "Visual", "Keybind Text" })
local tile = { index = 1, _isActive = true, _activeSubPageIndex = 1,
    config = { subPages = { { name = "General" }, { name = "Per Bar" } } },
    _subPageBodies = { general, perBar } }
local expected
local function CheckHighlight()
    if not expected then return end
    local active = {}
    for _, page in ipairs(GUI:GetTileNavigationPages(tile)) do
        if page.active then active[#active + 1] = page.sectionId end
    end
    assert(#active == 1 and active[1] == expected,
        "section navigation must highlight " .. expected .. " throughout the delayed page transition")
end
GUI.CloseNavigationFlyout = function() end
GUI.AnimateOptionsPage = function() end
GUI.RefreshNavigationSectionHighlight = CheckHighlight
GUI.UpdateTileNavigationTitle = CheckHighlight
GUI.SelectFeatureTile = function(_, _, _, options)
    CheckHighlight()
    tile._activeSubPageIndex = options.subPageIndex
    CheckHighlight()
end
local function Tick(count)
    for _ = 1, count or 1 do
        for _, driver in ipairs(drivers) do
            if driver.shown and driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, 0.1) end
        end
    end
end
local function Click(section)
    expected = section
    selectPage({}, tile, { pageIndex = 2, sectionId = section })
    CheckHighlight()
end
Click("Visual")
Tick(3)
CheckHighlight()
assert(perBar._scrollFrame.offset == 0, "unsettled layout must not scroll early")
settled = true
Tick(3)
assert(perBar._scrollFrame.offset == 800, "settled layout must scroll to the clicked section")
CheckHighlight()
expected = "Layout"
perBar._scrollFrame.offset = 0
CheckHighlight()

settled = false
Click("Visual")
Click("Keybind Text")
settled = true
Tick(3)
assert(perBar._scrollFrame.offset == 1600, "a newer section click must replace the pending jump")

for _, cancel in ipairs({ "page", "leave", "timeout", "hidden", "variant", "owner_hide" }) do
    settled = false
    tile._isActive, tile._activeSubPageIndex = true, 2
    tile._subPageBodies[2] = perBar
    perBar._scrollFrame.offset = 0
    perBar._contentBody._sections[2].frame.shown = true
    Click("Visual")
    expected = nil
    if cancel == "page" then tile._activeSubPageIndex = 1
    elseif cancel == "leave" then tile._isActive = false
    elseif cancel == "hidden" then perBar._contentBody._sections[2].frame.shown = false
    elseif cancel == "variant" then tile._subPageBodies[2] = Page({ "Layout", "Visual", "Keybind Text" })
    elseif cancel == "owner_hide" then perBar._quiLayoutReadyDriver:Hide() end
    Tick(cancel == "timeout" and 25 or 1)
    assert(not tile._pendingNavigationSection, cancel .. " must clear the pending highlight")
    assert(perBar._scrollFrame.offset == 0, cancel .. " must not perform a stale jump")
end

tile._isActive, tile._activeSubPageIndex = true, 2
tile._subPageBodies[2] = perBar
perBar._contentBody._sections[2].frame.shown = true
local activeTab = "bars"
local innerOwner = perBar
tile._surfacePagesByPage = { [2] = {
    getTabs = function() return { { key = "bars", label = "Bars" } } end,
    getActiveTab = function() return activeTab end,
    selectTab = function(key) activeTab = key end,
    getPage = function() return innerOwner end,
} }
for _, cancel in ipairs({ "tab", "variant" }) do
    settled, activeTab, innerOwner = false, "bars", perBar
    expected = "Visual"
    selectPage({}, tile, { pageIndex = 2, key = "bars", sectionId = "Visual" })
    CheckHighlight()
    expected = nil
    if cancel == "tab" then activeTab = "other"
    else innerOwner = Page({ "Layout", "Visual", "Keybind Text" }) end
    Tick()
    assert(not tile._pendingNavigationSection, cancel .. " must clear a surface's pending highlight")
end
tile._surfacePagesByPage = nil
Click("Visual")
expected = nil
selectPage({}, tile, { pageIndex = 1 })
Tick()
assert(not tile._pendingNavigationSection and perBar._scrollFrame.offset == 0,
    "a newer plain page selection must cancel the pending section highlight and scroll")
print("OK: options_section_pending_highlight_test")
