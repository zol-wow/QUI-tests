local handle = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = handle:read("*a")
handle:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI = QUI.GUI
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
assert(loadfile(os.getenv("QUI_NAVIGATION_CACHE") or "QUI_Options/search_cache.lua"))("QUI", ns)
local runWhenSettingsLayoutReady = GUI.RunWhenSettingsLayoutReady
function GUI:RunWhenSettingsLayoutReady(_, _, callback, isCurrent)
    C_Timer.After(0, function() if not isCurrent or isCurrent() then callback() end end)
end
for _, path in ipairs({
    "modules/qol/sound_mute_catalog.lua",
    "QUI_ActionBars/actionbars/actionbars_env.lua", "QUI_ActionBars/actionbars/actionbars.lua",
    "QUI_ActionBars/actionbars/actionbars_helpers.lua", "QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
local profile = QUI.QUICore.db.profile
for key, value in pairs(ns.defaults.profile) do
    profile[key] = Copy(value)
end
profile.general.optionsMotion = false
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    local originalIndex = getmetatable(frame).__index
    setmetatable(frame, { __index = function(self, key)
        if key == "RegisterSection" then return nil end
        return originalIndex(self, key)
    end })
    frame._scripts = {}
    frame.SetScript = function(self, key, callback) self._scripts[key] = callback end
    frame.HookScript = function(self, key, callback)
        local previous = self._scripts[key]
        self._scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    frame.GetVerticalScroll = function(self) return self._verticalScroll or 0 end
    frame.SetVerticalScroll = function(self, offset) self._verticalScroll = offset end
    if kind == "ScrollFrame" then
        frame.GetVerticalScrollRange = function(self)
            local body = self:GetScrollChild()
            return math.max(0, (body and body:GetHeight() or 0) - self:GetHeight())
        end
    end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
ns.QUI_Options.CreateScrollableContent = function(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    return scroll, body
end
local pending = {}
_G.C_Timer.After = function(delay, callback) if delay == 0 then pending[#pending + 1] = callback end end
local function Flush()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1
        assert(passes < 100, "deferred provider updates must settle")
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
end
_G.geterrorhandler = function() return function(err) error(err, 0) end end
local frame = CreateFrame("Frame")
frame:SetWidth(1000)
frame:SetHeight(850)
frame._tiles = {}
frame.sidebar = CreateFrame("Frame", nil, frame)
frame.sidebar:SetWidth(211)
frame.contentArea = CreateFrame("Frame", nil, frame)
GUI.AddFeatureTile = function(_, owner, config)
    local tile = CreateFrame("Button", nil, owner)
    tile.id, tile.index, tile.config = config.id, #owner._tiles + 1, config
    tile.text = tile:CreateFontString()
    tile.indicator, tile.hoverBg = tile:CreateTexture(), tile:CreateTexture()
    owner._tiles[#owner._tiles + 1] = tile
    GUI:AttachTileNavigation(owner, tile)
end
GUI.MainFrame = frame

tinsert = table.insert
UISpecialFrames = {}
for _, entry in ipairs(ns.SwingTimers.entries) do
    profile.swingTimers[entry.key] = Copy(profile.swingTimers["*"])
end
for _, unit in pairs(profile.quiUnitFrames) do
    if type(unit) == "table" and unit.castbar then
        unit.castbar.empoweredStageColors = unit.castbar.empoweredStageColors or {}
        unit.castbar.empoweredFillColors = unit.castbar.empoweredFillColors or {}
    end
end
local function Rows(tile, pageIndex, key)
    local result = {}
    for _, page in ipairs(GUI:GetTileNavigationPages(tile)) do
        if page.pageIndex == pageIndex and page.key == key then
            result[#result + 1] = (page.sectionId or "<page>") .. ":" .. page.label
        end
    end
    return table.concat(result, " | ")
end
local checked = 0
for _, key in ipairs({"Global", "UnitFrames", "GroupFrames", "Nameplates", "ActionBars", "Auras", "CooldownManager", "ResourceBars", "Minimap", "InfoBar", "Appearance", "ChatTooltips", "Gameplay", "Reminders", "QoL", "Bags", "Alts", "Help"}) do
    ns["QUI_" .. key .. "Tile"].Register(frame)
    local tile = frame._tiles[#frame._tiles]
    local cold = GUI:GetTileNavigationPages(tile)
    local function ColdRows(pageIndex, surfaceKey)
        local rows = {}
        for _, page in ipairs(cold) do
            if page.pageIndex == pageIndex and page.key == surfaceKey then
                rows[#rows + 1] = (page.sectionId or "<page>") .. ":" .. page.label
            end
        end
        return table.concat(rows, " | ")
    end
    for index = 1, #(tile.config.subPages or {tile.config}) do
        local ok, err = pcall(function()
            GUI:SelectFeatureTile(frame, tile.index, {subPageIndex=index})
            Flush()
            local descriptor = tile._surfacePagesByPage and tile._surfacePagesByPage[index]
            for _, tab in ipairs(descriptor and descriptor.getTabs() or {{}}) do
                if tab.key then descriptor.selectTab(tab.key); Flush() end
                local before, after = ColdRows(index, tab.key), Rows(tile, index, tab.key)
                assert(before == after, tile.id .. "/" .. index .. "/" .. (tab.key or "")
                    .. " must keep identical section links before and after opening: cold " .. before .. "; built " .. after)
                checked = checked + 1
            end
        end)
        assert(ok, tile.id .. "/" .. index .. ": " .. tostring(err))
    end
end

print("OK: cold navigation matches rendered pages across " .. checked .. " destinations")

frame:SetWidth(1400)
-- Mounted Bonus Roll headings share the sidebar jump and reveal lifecycle.
local bonusTile
for _, tile in ipairs(frame._tiles) do if tile.id == "qol" then bonusTile = tile end end
GUI:SelectFeatureTile(frame, bonusTile.index, { subPageIndex = 14 })
Flush()
local bonusBody = bonusTile._subPageBodies[14]._contentBody
local worldSection
for _, section in ipairs(bonusBody._sections) do
    if section.id == "World Bosses" then worldSection = section.frame end
end
assert(worldSection and not worldSection._expanded, "World Bosses starts collapsed")
GUI:ScrollToTileNavigationSection(bonusTile, { pageIndex = 14, sectionId = "World Bosses" })
Flush()
assert(worldSection._expanded and worldSection._body:IsShown(),
    "sidebar section navigation must reveal the actual collapsed provider body")

local actionTile
for _, tile in ipairs(frame._tiles) do
    if tile.id == "action_bars" then actionTile = tile; break end
end
GUI:SelectFeatureTile(frame, actionTile.index, { subPageIndex = 2 })
Flush()
local owner = actionTile._subPageBodies[2]
local body, scroll = owner._contentBody, owner._scrollFrame
scroll:SetHeight(600)
body:SetHeight(2000)
body.GetTop = function() return 1000 + scroll:GetVerticalScroll() end
scroll.GetTop = function() return 1000 end
local function DockSections()
    local labels = {}
    for _, page in ipairs(frame._pageDock._pages) do
        if page.pageIndex == 2 then labels[#labels + 1] = page.sectionId or page.label end
    end
    return table.concat(labels, "|")
end
local function SetHeadingPositions(labels)
    for index, label in ipairs(labels) do
        for _, section in ipairs(body._sections) do
            if section.id == label and section.frame:IsShown() then
                section.frame.GetTop = function() return body:GetTop() - (index - 1) * 400 end
            end
        end
    end
end
ns.QUI_ActionBarsOptions.SetSelectedBar("microMenu", "navigation-test")
SetHeadingPositions({ "Bar", "Layout", "Ticket Icon", "Context Visibility" })
Flush()
assert(DockSections() == "Bar|Layout|Ticket Icon|Context Visibility",
    "changing the selected bar must replace the mounted dock links in rendered heading order: " .. DockSections())
body:SetHeight(2000)
for _, button in ipairs(frame._pageDock._buttons) do
    if button._page and button._page.pageIndex == 2 and button._page.sectionId == "Layout" then
        button._scripts.OnClick(button)
        break
    end
end
Flush()
assert(scroll:GetVerticalScroll() == 400,
    "section jumps must use rendered order after a structural rebuild, preserving the first Bar heading")
ns.QUI_ActionBarsOptions.SetSelectedBar("bar2", "navigation-test")
local standard = { "Bar", "Layout", "Visual", "Keybind Text", "Macro Names", "Stack Count", "Cooldown Duration Text", "Context Visibility" }
SetHeadingPositions(standard)
Flush()
assert(DockSections() == table.concat(standard, "|"), "returning to a standard bar must restore its current dock links")

local synthetic = CreateFrame("Frame")
GUI:InitializeNavigationSections(synthetic)
local function Heading(id, top)
    local heading = CreateFrame("Frame", nil, synthetic)
    heading.GetTop = function() return top end
    synthetic:RegisterSection(id, id, heading)
    return heading
end
Heading("Top", 1000)
local old = Heading("Middle", 750)
Heading("Bottom", 500)
old:Hide()
Heading("Middle", 750)
Heading("New", 700)
local syntheticTile = { config = {}, _subPageBodies = { { _contentBody = synthetic } } }
local function SyntheticOrder()
    local labels = {}
    for _, page in ipairs(GUI:GetTileNavigationPages(syntheticTile)) do labels[#labels + 1] = page.sectionId end
    return table.concat(labels, "|")
end
assert(SyntheticOrder() == "Top|Middle|New|Bottom", "partial rebuilds must preserve sibling headings in layout order")
synthetic._sections[2].frame.GetTop = function() return nil end
assert(SyntheticOrder() == "Top|Middle|Bottom|New", "unsettled mixed bounds must preserve a consistent registry order")
ns.QUI_ActionBarsOptions.SetSelectedBar("microMenu", "navigation-test")
GUI:SelectFeatureTile(frame, frame._tiles[1].index)
Flush()
assert(frame._pageDock._tile == frame._tiles[1], "a pending section refresh must not restore an inactive page's dock")
print("OK: structural settings rebuilds refresh mounted navigation and preserve ordered jumps")
