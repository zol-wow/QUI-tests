local nativeLoadfile = loadfile
loadfile = function(path)
    local baseline = os.getenv("QUI_PREVIEW_BASELINE")
    if baseline and (path == "core/settings/full_surface.lua"
        or path == "QUI_UnitFrames/unitframes/settings/unit_frames_surface.lua") then
        return nativeLoadfile(baseline .. "/" .. path:match("[^/]+$"))
    end
    return nativeLoadfile(path)
end
local handle = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = handle:read("*a")
handle:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(source:sub(1, marker - 1) .. "\nreturn ns"))()
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
QUI.db.profile = Copy(ns.defaults.profile)
QUI.QUICore.db.profile = QUI.db.profile
for _, path in ipairs({
    "QUI_ActionBars/actionbars/actionbars_env.lua", "QUI_ActionBars/actionbars/actionbars.lua",
    "QUI_ActionBars/actionbars/actionbars_helpers.lua", "QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local resource = assert(io.open("QUI_ResourceBars/resourcebars/resourcebars.lua", "rb"))
local runtime = resource:read("*a")
resource:close()
local start = assert(runtime:find("_G.QUI_BuildResourceBarPreview = function", 1, true))
local finish = assert(runtime:find("local function RecolorPowerBarBorder", start, true))
assert(loadstring("local _, ns = ...\n" .. runtime:sub(start, finish - 1)))("QUI", ns)
local create = CreateFrame
local panels = {}
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    if frame:GetParent() == UIParent then panels[#panels + 1] = frame end
    local originalIndex = getmetatable(frame).__index
    setmetatable(frame, { __index = function(self, key)
        if key == "RegisterSection" then return nil end
        return originalIndex(self, key)
    end })
    frame._scripts = {}
    frame.SetPoint = function(self, ...)
        local point = { ... }
        for index, previous in ipairs(self._points) do
            if previous[1] == point[1] then self._points[index] = point; return end
        end
        self._points[#self._points + 1] = point
    end
    local createFontString = frame.CreateFontString
    frame.CreateFontString = function(self, ...)
        local region = createFontString(self, ...)
        region.GetObjectType = function() return "FontString" end
        local stringHeight = region.GetStringHeight
        region.GetStringHeight = function(self)
            if (self:GetText() or ""):find("Named nameplate profiles", 1, true) then
                return rawget(self, "_width") and 42 or 14
            end
            return stringHeight(self)
        end
        return region
    end
    frame.SetWidth = function(self, width)
        if self._width == width then return end
        self._width = width
        if self._scripts.OnSizeChanged then self._scripts.OnSizeChanged(self, width, self:GetHeight()) end
    end
    frame.SetScript = function(self, key, callback) self._scripts[key] = callback end
    frame.GetScript = function(self, key) return self._scripts[key] end
    frame.HookScript = function(self, key, callback)
        local previous = self._scripts[key]
        self._scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    frame.SetHeight = function(self, height)
        if self._height == height then return end
        self._height = height
        if self._scripts.OnSizeChanged then self._scripts.OnSizeChanged(self, self:GetWidth(), height) end
    end
    frame.SetAllPoints = function(self, target)
        self._height = nil
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", target or self:GetParent(), "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", target or self:GetParent(), "BOTTOMRIGHT", 0, 0)
    end
    frame.GetHeight = function(self)
        if self._height then return self._height end
        local top, bottom
        for _, point in ipairs(self._points or {}) do
            if point[1]:find("TOP", 1, true) then top = point end
            if point[1]:find("BOTTOM", 1, true) then bottom = point end
        end
        if top and bottom and type(top[2]) == "table" and top[2] == bottom[2] then
            return top[2]:GetHeight() + (top[5] or 0) - (bottom[5] or 0)
        end
        return 24
    end
    frame.GetVerticalScroll = function(self) return self._verticalScroll or 0 end
    frame.SetVerticalScroll = function(self, offset) self._verticalScroll = offset end
    frame.SetIgnoreParentScale = function(self, ignore) self._ignoreParentScale = ignore end
    frame.GetEffectiveScale = function(self)
        local scale = rawget(self, "_scale") or 1
        if rawget(self, "_ignoreParentScale") then return scale end
        local parent = self:GetParent()
        return scale * (parent and parent:GetEffectiveScale() or 1)
    end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
_G.hooksecurefunc = function(target, key, callback)
    if type(target) ~= "table" then return end
    local original = target[key]
    target[key] = function(...)
        original(...)
        callback(...)
    end
end
ns.QUI_Options.CreateScrollableContent = function(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetAllPoints(parent)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    return scroll, body
end
local pending = {}
_G.C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
local function Flush()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1
        assert(passes < 100, "native preview autoheight updates must settle")
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
end
local GUI = QUI.GUI
local frame = CreateFrame("Frame")
frame:SetSize(1000, 700)
frame.contentArea = CreateFrame("Frame", nil, frame)
frame.contentArea:SetHeight(610)
frame.sidebar = CreateFrame("Frame", nil, frame)
frame._tiles = {}
for _, key in ipairs({ "UnitFrames", "ActionBars", "CooldownManager", "ResourceBars" }) do
    ns["QUI_" .. key .. "Tile"].Register(frame)
    local tile = frame._tiles[#frame._tiles]
    if key == "CooldownManager" then tile.config.buildFunc = nil end
    GUI:BuildTilePage(frame, tile)
    GUI:SelectFeatureTile(frame, tile.index)
    Flush()
    local pv = assert(tile._preview, key .. " mounts its actual registered preview callback")
    if key == "CooldownManager" then pv:SetWidth(728); Flush() end
    local toggle = assert(tile._previewToggle, key .. " mounts its native header disclosure")
    assert(toggle:GetParent() == pv and (toggle._points[1][2] == pv or toggle._points[1][2] == pv._quiPreviewHeader),
        key .. " disclosure is anchored inside its preview card")
    assert(pv:GetParent() == tile._pageFrame and pv._quiPreviewSurface,
        key .. " preview is boxed inside its native editor page")
    local header, host = pv._quiPreviewHeader, pv._quiPreviewHost
    assert(toggle.text:GetText() == "Hide preview" and toggle.chevron,
        key .. " expanded preview has a named control and native chevron")
    assert(toggle:GetWidth() >= toggle.text:GetStringWidth() + 30,
        key .. " control reserves space for its text and chevron")
    if header then
        local _, relative, _, x = header:GetPoint(header:GetNumPoints())
        assert(relative == pv and x == -toggle:GetWidth() - 12,
            key .. " selector reserves the actual collapse-control width")
    end
    if key == "UnitFrames" then
        assert(header:GetHeight() == 26 and toggle:GetHeight() == 26,
            "Unit Frames selector and disclosure must share a centered action row")
        local selector
        for _, child in ipairs({header:GetChildren()}) do
            if rawget(child, "dropdown") then selector = child; break end
        end
        assert(selector and select(1, selector:GetPoint(1)) == "RIGHT",
            "Unit selector must center vertically against its preview header")
    end
    if key == "CooldownManager" then
        assert(type(rawget(header, "_quiPreviewLayoutHeader")) == "function",
            "CDM native FontString label installs its responsive header layout")
        local selector
        for _, child in ipairs({ header:GetChildren() }) do
            if rawget(child, "dropdown") then selector = child; break end
        end
        local function ButtonWidth()
            local _, leftOwner, _, leftX = header:GetPoint(1)
            local _, rightOwner, _, rightX = header:GetPoint(2)
            assert(rightOwner == pv)
            local left = leftX + (leftOwner == pv and 0 or leftOwner:GetWidth())
            local _, _, _, selectorRight = selector:GetPoint(2)
            local _, _, _, buttonLeft = selector.dropdown:GetPoint(1)
            return pv:GetWidth() + rightX - left + selectorRight - buttonLeft
        end
        assert(ButtonWidth() >= 80 and pv._quiPreviewChromeHeight == 40,
            "default-width CDM selector remains usable beside the named collapse control")
        local nativeSpec, nativeSpecInfo, nativeTalents = GetSpecialization, GetSpecializationInfo, C_ClassTalents
        GetSpecialization = function() return 1 end
        GetSpecializationInfo = function() return 268, "Test spec" end
        C_ClassTalents = nil
        local _, leftCol = header:GetPoint(1)
        local loadoutToggle
        for _, child in ipairs({ leftCol:GetChildren() }) do
            if rawget(child, "_syncDBKey") == "perLoadoutSpec" then loadoutToggle = child end
        end
        assert(loadoutToggle, "CDM retains its native per-loadout toggle")
        loadoutToggle.SetValue(true)
        Flush()
        assert(pv._quiPreviewChromeHeight == 62, "shown loadout label reserves its actual second line")
        pv:SetWidth(478)
        Flush()
        assert(pv._quiPreviewChromeHeight == 94 and ButtonWidth() >= 80,
            "loadout context and selector remain usable together at minimum width")
        loadoutToggle.SetValue(false)
        Flush()
        assert(pv._quiPreviewChromeHeight == 72, "hiding the loadout label releases its unused line")
        pv:SetWidth(728)
        Flush()
        GetSpecialization, GetSpecializationInfo, C_ClassTalents = nativeSpec, nativeSpecInfo, nativeTalents
        local natural, content = pv._quiPreviewNaturalHeight, host:GetHeight()
        for _ = 1, 3 do
            pv:SetWidth(478)
            Flush()
            assert(ButtonWidth() >= 80 and pv._quiPreviewChromeHeight == 72,
                "minimum-width CDM header wraps without clipping its selector")
            assert(host:GetHeight() == content, "wrapping preserves preview content height")
            pv:SetWidth(728)
            Flush()
            assert(pv._quiPreviewNaturalHeight == natural and host:GetHeight() == content,
                "returning wide restores original preview height without cumulative drift")
        end
        toggle:GetScript("OnClick")(toggle)
        pv:SetWidth(478)
        Flush()
        assert(pv._quiPreviewCollapsed and pv:GetHeight() == 72 and not host:IsShown(),
            "a collapsed CDM preview keeps wrapped selectors without showing content")
        pv:SetWidth(728)
        Flush()
        assert(pv._quiPreviewCollapsed and pv:GetHeight() == 40,
            "collapsed CDM header shrinks again without losing collapsed state")
        toggle:GetScript("OnClick")(toggle)
        assert(host:IsShown() and host:GetHeight() == content)
    end
    if key == "UnitFrames" then
        local selector
        for _, child in ipairs({ header:GetChildren() }) do
            if rawget(child, "dropdown") then selector = child; break end
        end
        assert(selector and selector:GetWidth() < 180 and selector:GetHeight() == 22,
            "Unit selector fits its selected text instead of stretching across the preview")
        local width = selector:GetWidth()
        local textWidth = selector.dropdown.selected:GetStringWidth()
        selector.SetValue("targettarget", true)
        assert(selector:GetWidth() - width == selector.dropdown.selected:GetStringWidth() - textWidth,
            "compact Unit selector grows by the selected label's actual text width")
        selector.SetValue("player", true)
        assert(selector:GetWidth() == width, "compact Unit selector shrinks when returning to a shorter label")
        selector.dropdown.GetWidth = function(self)
            return self:GetParent():GetWidth() - select(4, self:GetPoint(1))
        end
        selector.dropdown:GetScript("OnClick")()
        local menu
        for _, panel in ipairs(panels) do
            if rawget(panel, "_owner") == selector then menu = panel end
        end
        assert(menu and menu.scrollContent:GetWidth() > selector.dropdown:GetWidth(),
            "compact selector's popup fits longer choices independently of the selected label")
        assert(menu._points[2][4] > 0, "popup's native right anchor reserves its measured choice width")
        menu:Hide()
        Flush()
    end
    local contentOwner
    if tile._subPageBodies then
        contentOwner = tile._subPageBodies[1]:GetParent()
    else
        for _, child in ipairs({ tile._pageFrame:GetChildren() }) do
            if child ~= pv then
                for _, point in ipairs(child._points or {}) do
                    if point[1] == "TOPLEFT" and point[2] == pv then contentOwner = child end
                end
            end
        end
    end
    if tile.config.buildFunc or tile.config.subPages then
        assert(contentOwner, key .. " mounts settings after its preview")
        local point = contentOwner._points[1]
        assert(point[2] == pv and point[3] == "BOTTOMLEFT" and point[5] == -4,
            key .. " uses one compact gap after its preview card")
    end
    local expanded = pv:GetHeight()
    assert(expanded > 1 and expanded <= tile.config.preview.height, "preview respects its editor height reservation")
    toggle:GetScript("OnClick")(toggle)
    assert(pv._quiPreviewCollapsed and pv:GetHeight() < expanded, "header disclosure releases preview space")
    assert(toggle.text:GetText() == "Show preview", "collapsed preview names its show action")
    assert(not header or header:IsShown(), "unit/viewer selector remains visible while collapsed")
    assert(not host or not host:IsShown(), "collapse hides preview content")
    toggle:GetScript("OnClick")(toggle)
    assert(not pv._quiPreviewCollapsed and pv:GetHeight() == expanded, "disclosure restores expanded preview")
    assert(toggle.text:GetText() == "Hide preview", "expanded preview names its hide action")
    assert(not host or host:IsShown(), "expansion restores actual preview content")
    if host then
        local normalHeight = tile._pageFrame:GetHeight()
        tile._pageFrame._height = 0
        pv._quiPreviewLayout()
        assert(not pv._quiPreviewViewport:IsShown(), "unresolved hidden geometry cannot draw outside the available card")
        tile._pageFrame._height = normalHeight
        pv:GetScript("OnShow")(pv)
        Flush()
        assert(pv._quiPreviewViewport:IsShown() and host:GetWidth() == pv._quiPreviewViewport:GetWidth(),
            "showing a warmed card restores its native viewport and explicit scroll-child width without a resize event")
        assert(host:GetParent() == pv._quiPreviewViewport, "content scrolls inside the reserved card")
        pv:SetHeight(620)
        assert(pv:GetHeight() <= tile.config.preview.height and host:GetHeight() > 500,
            "tall native geometry remains accessible without consuming the settings viewport")
        local bounded = pv:GetHeight()
        pv:SetHeight(bounded)
        assert(pv._quiPreviewNaturalHeight == bounded and host:GetHeight() < 200,
            "selecting a layout equal to current reservation resets stale tall content without a size event")
        pv:SetHeight(620)
        local natural = pv._quiPreviewNaturalHeight
        pv:GetScript("OnSizeChanged")(pv, 480, pv:GetHeight())
        assert(pv._quiPreviewNaturalHeight == natural, "width-only resize preserves natural preview geometry")
        toggle:GetScript("OnClick")(toggle)
        pv:SetHeight(710)
        assert(pv:GetHeight() == pv._quiPreviewCollapsedHeight, "driver autoheight cannot reopen collapsed card")
        toggle:GetScript("OnClick")(toggle)
        assert(pv._quiPreviewNaturalHeight == 710 and host:GetHeight() > 600,
            "expansion uses layout selected while collapsed without an extra refresh")
    end
    tile._pageFrame:SetHeight(275)
    assert(pv:GetHeight() <= tile.config.preview.height, "small editor budgets preview height while retaining selectors")
    local footerReserve = tile.config.relatedSettings and 32 or 0
    assert(275 - 14 - tile._header:GetHeight() - 20 - pv:GetHeight() - footerReserve >= 80,
        "minimum native window keeps at least 80 pixels for native settings")
    if key == "ActionBars" then
        tile._subPageSelect(2)
        local perBar = assert(tile._subPageBodies[2]._contentBody)
        assert(perBar:GetHeight() > 300 and #perBar._sections >= 5,
            "Per-Bar mounts its native settings with tall preview geometry")
        local layout = QUI.db.profile.actionBars.bars.bar1.ownedLayout
        layout.iconCount, layout.columns, layout.buttonSize = 12, 1, 44
        layout.orientation = "horizontal"
        for _, button in ipairs({ host:GetChildren() }) do
            button.GetTop = function(self)
                local point = self._points and self._points[1]
                return (point and point[5] or 0) + self:GetHeight() * 0.5
            end
            button.GetBottom = function(self)
                local point = self._points and self._points[1]
                return (point and point[5] or 0) - self:GetHeight() * 0.5
            end
        end
        pv._quiPreviewNaturalHeight = 110
        ns.QUI_ActionBarsPreviewDriver.Refresh()
        Flush()
        assert(pv._quiPreviewNaturalHeight > 500 and pv:GetHeight() <= 110,
            "actual twelve-row bar geometry cannot consume the Per-Bar settings reservation")
        assert(275 - 14 - tile._header:GetHeight() - 20 - pv:GetHeight() - footerReserve >= 80,
            "native Per-Bar body retains positive viewport height after the real tall-bar refresh")
    end
end
local nativeCreate = CreateFrame
local function NotifyVisibility(node, event)
    local script = node:GetScript(event)
    if script then script(node) end
    for _, child in ipairs({ node:GetChildren() }) do
        if child:IsShown() then NotifyVisibility(child, event) end
    end
end
_G.CreateFrame = function(...)
    local node = nativeCreate(...)
    node.IsVisible = function(self)
        local parent = self:GetParent()
        return self:IsShown() and (not parent or parent:IsVisible())
    end
    node.Show = function(self)
        local visible = self:IsVisible()
        self._shown = true
        if not visible and self:IsVisible() then NotifyVisibility(self, "OnShow") end
    end
    node.Hide = function(self)
        local visible = self:IsVisible()
        self._shown = false
        if visible then NotifyVisibility(self, "OnHide") end
    end
    node.SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end
    return node
end
ns.Helpers.IsSecretValue = function() return false end
for _, path in ipairs({
    "QUI_Nameplates/nameplates/shared.lua", "QUI_Nameplates/nameplates/plate_type.lua",
    "QUI_Nameplates/nameplates/plate_auras.lua", "core/appearance.lua", "core/cast_engine.lua", "QUI_Nameplates/nameplates/plate_colors.lua",
    "QUI_Nameplates/nameplates/plate_health.lua", "QUI_Nameplates/nameplates/plate_castbar.lua",
    "QUI_Nameplates/nameplates/plate_extras.lua", "QUI_Nameplates/nameplates/plate_power.lua",
    "QUI_Nameplates/nameplates/driver.lua", "QUI_Nameplates/nameplates/presets.lua", "QUI_Nameplates/nameplates/settings/nameplates_preview_driver.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local builds, activeHost = 0
local buildNameplate = ns.QUI_BuildNameplatePreview
ns.QUI_BuildNameplatePreview = function(host)
    builds, activeHost = builds + 1, host
    buildNameplate(host)
end
local window = CreateFrame("Frame")
window:SetSize(1000, 700)
window.contentArea = CreateFrame("Frame", nil, window)
window.contentArea:SetHeight(610)
window.sidebar = CreateFrame("Frame", nil, window)
window._tiles = {}
ns.QUI_NameplatesTile.Register(window)
ns.QUI_AurasTile.Register(window)
local nameplates, auras = window._tiles[1], window._tiles[2]
GUI:BuildTilePage(window, nameplates)
Flush()
assert(builds == 0, "warming hidden Nameplates settings cannot activate its preview driver")
GUI:SelectFeatureTile(window, nameplates.index)
Flush()
local card = assert(nameplates._preview, "Nameplates main registration mounts its inline preview")
local toggle = assert(nameplates._previewToggle)
local host = card._quiPreviewHost
assert(card._quiPreviewSurface and card:GetParent() == nameplates._pageFrame,
    "Nameplates preview belongs to its rounded settings card")
assert(activeHost and activeHost:GetParent() == host and builds > 0,
    "visible Nameplates preview uses the real driver within its scrollable card")
local mainHost = activeHost
local plate = mainHost:GetChildren()
assert(math.abs(plate:GetEffectiveScale() / UIParent:GetEffectiveScale() - 3) < 1e-6,
    "settings preview starts magnified so name, health and aura details are readable")
local zoom = assert(card._quiPreviewZoom, "preview exposes its magnification separately from plate settings")
local header = card._quiPreviewHeader
local _, _, _, _, headerTop = header:GetPoint(1)
local _, _, _, _, toggleTop = toggle:GetPoint(1)
assert(headerTop == toggleTop, "plate selector and disclosure share the same header baseline")
zoom:SetValue(1)
Flush()
assert(math.abs(plate:GetEffectiveScale() / UIParent:GetEffectiveScale() - 1) < 1e-6,
    "actual-size preview remains available without changing live plate settings")
host:Hide()
host:Show()
Flush()
assert(math.abs(plate:GetEffectiveScale() / UIParent:GetEffectiveScale() - 3) < 1e-6,
    "reopening the preview resets magnification to 3x")
assert(zoom:GetValue() == 3, "reopening synchronizes the zoom selector to 3x")
zoom:SetValue(1)
Flush()
local measuredWidth, measuredHeight = 240, 80
plate.healthBg.GetLeft = function() return 0 end
plate.healthBg.GetRight = function() return measuredWidth end
plate.healthBg.GetTop = function() return 0 end
plate.healthBg.GetBottom = function() return -measuredHeight end
ns.QUI_RefreshNameplatePreview()
Flush()
assert(mainHost:GetHeight() == measuredHeight,
    "the real driver's painted-bound observer sizes the specimen host")
local function CheckCentered(specimen, expectedWidth)
    local point, relative, relativePoint, x, y = specimen:GetPoint(1)
    assert(specimen:GetNumPoints() == 1 and point == "TOP" and relative == specimen:GetParent()
        and relativePoint == "TOP" and x == 0 and y == 0,
        "the measured specimen centers on its viewport instead of stretching from its left edge")
    assert(specimen:GetWidth() == expectedWidth,
        "the center anchor uses painted width including decorations")
end
CheckCentered(mainHost, measuredWidth)
for _, values in ipairs({ { 728, 340 }, { 478, 120 }, { 728, 240 } }) do
    host:SetWidth(values[1])
    measuredWidth = values[2]
    ns.QUI_RefreshNameplatePreview()
    Flush()
    CheckCentered(mainHost, measuredWidth)
end
local controlsToggle = assert(card._quiPreviewControlsToggle, "Nameplates offers a separate controls disclosure")
local strip
for _, child in ipairs({ host:GetChildren() }) do
    if child ~= mainHost and child ~= controlsToggle then strip = child end
end
assert(strip and not strip:IsShown() and controlsToggle.text:GetText() == "Preview controls",
    "preview scenarios start folded so the specimen and settings keep their space")
local compactHeight = card._quiPreviewChromeHeight + measuredHeight + 8 + controlsToggle:GetHeight()
assert(card:GetHeight() == compactHeight and card._quiPreviewNaturalHeight == compactHeight,
    "folding controls reserves only the actual specimen, disclosure and one bottom pad")
measuredHeight = 280
ns.QUI_RefreshNameplatePreview()
Flush()
assert(card:GetHeight() == card._quiPreviewNaturalHeight,
    "a normal magnified specimen and folded disclosure fit without internal scrolling in a roomy panel")
measuredHeight = 80
ns.QUI_RefreshNameplatePreview()
Flush()
local function FindWidget(node, key)
    if rawget(node, "_syncDBKey") == key then return node end
    for _, child in ipairs({ node:GetChildren() }) do
        local result = FindWidget(child, key)
        if result then return result end
    end
end
controlsToggle:GetScript("OnClick")(controlsToggle)
Flush()
assert(strip:IsVisible() and card._quiPreviewNaturalHeight == compactHeight + 4 + strip:GetHeight(),
    "expanding scenarios adds exactly their current content extent")
local casting = assert(FindWidget(strip, "casting"))
casting.SetValue(false)
Flush()
assert(not plate.castBar:IsShown(), "scenario toggles still drive the actual preview renderer")
card._quiPreviewViewport:SetVerticalScroll(90)
controlsToggle:GetScript("OnClick")(controlsToggle)
Flush()
assert(not strip:IsShown() and casting.GetValue() == false and not plate.castBar:IsShown()
    and card:GetHeight() == compactHeight and card._quiPreviewViewport:GetVerticalScroll() == 0,
    "folding preserves scenario values, removes their space and clears stale scroll offsets")
controlsToggle:GetScript("OnClick")(controlsToggle)
Flush()
assert(strip:IsVisible() and casting.GetValue() == false,
    "reopening controls preserves the chosen preview state")
casting.SetValue(true)
controlsToggle:GetScript("OnClick")(controlsToggle)
Flush()
local function FindRuntime(node)
    local runtime = rawget(node, "_quiSettingsRuntime")
    if runtime and runtime.feature.id == "nameplatesGeneralTab" then return runtime end
    for _, child in ipairs({ node:GetChildren() }) do
        local found = FindRuntime(child)
        if found then return found end
    end
end
local general = assert(FindRuntime(nameplates._pageFrame))
local enable, nextSection = general.sectionHosts.enable, general.sectionHosts.starterStyles
local checkbox = assert(FindWidget(enable, "enabled"))
assert((rawget(checkbox, "_width") or 0) > 0 and checkbox:GetWidth() == enable:GetWidth(),
    "Enable row must have a measured initial width so its label and toggle have live bounds")
assert(general.sectionHeights.enable == checkbox:GetHeight() + 10,
    "the first Nameplates setting reserves its widget extent instead of an empty 64-unit block")
local point, relative, relativePoint, x, nextY = nextSection:GetPoint(1)
assert(point == "TOPLEFT" and relative == enable and relativePoint == "BOTTOMLEFT" and x == 0 and nextY == -10,
    "the next settings section follows the measured first row with the standard gap")
local profiles = general.sectionHosts.nameplateProfiles
local profileDescription
for _, region in ipairs({ profiles:GetRegions() }) do
    if (region:GetText() or ""):find("Named nameplate profiles", 1, true) then profileDescription = region end
end
assert(profileDescription and profileDescription:GetWidth() == profiles:GetWidth(),
    "profile description gets an explicit settled width before measuring hidden text")
local profileCard
for _, child in ipairs({ profiles:GetChildren() }) do
    if rawget(child, "_height") and child:GetHeight() > 40 then profileCard = child; break end
end
local _, _, _, _, profileCardY = assert(profileCard):GetPoint(1)
assert(-profileCardY >= 22 + 42 + 8,
    "wrapped profile explanation reserves all lines plus a gap before its settings card")
local function CardRows(group)
    local result = {}
    for _, child in ipairs({ group:GetChildren() }) do
        if rawget(child, "_leftCell") then result[#result + 1] = child end
    end
    return result
end
local profileRows = CardRows(profileCard)
assert(#profileRows == 3 and profileRows[1]._rightCell and profileRows[2]._rightCell and profileRows[3]._rightCell,
    "profile status, selection actions and save actions use three paired rows instead of separate strips")
profileCard:SetWidth(900)
profileCard._quiRefreshSettingsRows()
Flush()
assert(not profileRows[2]._stacked and #profileRows[2]._rightCell._buttons == 4,
    "wide profile editor keeps all existing selection actions beside the dropdown")
local profileActions = profileRows[2]._rightCell
profileCard:SetWidth(640)
profileCard._quiRefreshSettingsRows()
Flush()
assert(select(5, profileActions._buttons[4]:GetPoint(1)) < 0,
    "profile actions wrap rather than overflow at the paired-card boundary")
profileCard:SetWidth(480)
profileCard._quiRefreshSettingsRows()
Flush()
assert(profileRows[2]._stacked and profileRows[3]._stacked,
    "narrow profile editor stacks selection and save actions without hiding controls")
profileCard:SetWidth(900)
profileCard._quiRefreshSettingsRows()
Flush()
local starterCard
for _, child in ipairs({ nextSection:GetChildren() }) do
    if rawget(child, "_quiCardGroup") then starterCard = child end
end
local starterRows = CardRows(assert(starterCard, "starter styles use the existing settings card"))
assert(#starterRows == 1 and #starterRows[1]._leftCell._buttons == 3,
    "starter styles expose three named actions in one responsive row")
local starterActions = starterRows[1]._leftCell
starterActions:Layout(900)
assert(select(5, starterActions._buttons[3]:GetPoint(1)) == 0,
    "wide starter styles do not reserve three separate rows")
starterActions:Layout(400)
assert(select(5, starterActions._buttons[3]:GetPoint(1)) == 0,
    "starter actions keep three columns in a narrow settings viewport")
assert(math.abs(starterActions._buttons[1]:GetWidth() - 128) < .01
    and starterActions._buttons[3]:GetWidth() == starterActions._buttons[1]:GetWidth(),
    "starter actions share the complete row equally without overflow")
local descriptor = assert(nameplates._surfacePagesByPage[1])
for _, key in ipairs({ "frame", "text", "indicators", "auras", "castbars", "colors" }) do
    descriptor.selectTab(key)
    Flush()
    local function FindCopy(node)
        local runtime = rawget(node, "_quiSettingsRuntime")
        if runtime and runtime.sectionHosts.copyFrom then return runtime.sectionHosts.copyFrom end
        for _, child in ipairs({ node:GetChildren() }) do
            local found = FindCopy(child)
            if found then return found end
        end
    end
    local copy = assert(FindCopy(nameplates._pageFrame), key .. " keeps its copy controls")
    local copyCard
    for _, child in ipairs({ copy:GetChildren() }) do
        if rawget(child, "_quiCardGroup") then copyCard = child end
    end
    local rows = CardRows(assert(copyCard))
    assert(#rows == 1 and rows[1]._rightCell and #rows[1]._rightCell._buttons == 1,
        key .. " keeps copy selection and Apply together in one responsive card row")
end
descriptor.selectTab("general")
Flush()
local measuredNatural = card._quiPreviewNaturalHeight
measuredHeight = 520
ns.QUI_RefreshNameplatePreview()
Flush()
assert(mainHost:GetHeight() == 520 and card._quiPreviewNaturalHeight == measuredNatural + 440
    and card:GetHeight() <= 360,
    "tall measured nameplate decorations scroll without consuming settings space")
assert(#({ mainHost:GetChildren() }) > 0, "the actual Nameplates builders paint a specimen inside the card")
assert(toggle.text:GetText() == "Hide preview" and card._quiPreviewViewport,
    "Nameplates retains a named disclosure and bounded viewport")
assert(strip and strip:GetHeight() >= 200, "all existing state/reaction controls remain in the preview content")
local stripLeft, stripLeftOwner, stripLeftRelative, stripX, stripY = strip:GetPoint(1)
local stripRight, stripRightOwner, stripRightRelative, stripRightX = strip:GetPoint(2)
assert(stripLeft == "TOPLEFT" and stripRight == "TOPRIGHT" and stripLeftOwner == controlsToggle
    and stripRightOwner == controlsToggle and stripLeftRelative == "BOTTOMLEFT" and stripRightRelative == "BOTTOMRIGHT"
    and stripX == 0 and stripRightX == 0 and stripY == -4,
    "scenario controls retain full disclosure width beneath the centered specimen")
local _, controlsOwner, _, _, controlsY = controlsToggle:GetPoint(1)
assert(controlsOwner == host and controlsY == -(mainHost:GetHeight() + 8),
    "the disclosure follows current specimen height without reserving hidden controls")
local natural = card._quiPreviewNaturalHeight
assert(natural > card:GetHeight() and card:GetHeight() <= 360,
    "preview controls scroll without consuming the settings viewport")
toggle:GetScript("OnClick")(toggle)
assert(card._quiPreviewCollapsed and not host:IsShown() and toggle.text:GetText() == "Show preview")
measuredHeight = 620
ns.QUI_RefreshNameplatePreview()
Flush()
assert(mainHost:GetHeight() == 520, "hidden preview measurements cannot resize the collapsed card")
ns.QUI_NameplatesSettingsSurface.SetSelectedType("bossElite")
Flush()
assert(card._quiPreviewCollapsed and card:GetHeight() == card._quiPreviewCollapsedHeight,
    "type changes preserve collapsed state")
toggle:GetScript("OnClick")(toggle)
Flush()
assert(host:IsVisible() and activeHost == mainHost and mainHost:GetHeight() == 620,
    "expanding reactivates the same native specimen host with its latest measured extent")
GUI:BuildTilePage(window, auras)
Flush()
local before = builds
assert(activeHost == mainHost, "warming Auras Nameplates cannot steal the visible preview driver")
GUI:SelectFeatureTile(window, auras.index, { subPageIndex = 5 })
Flush()
local auraPage = assert(auras._subPageBodies[5])
auraPage:SetHeight(500)
Flush()
local auraCard = assert(auraPage._preview, "Auras Nameplates mounts its inline subpage preview")
assert(auraCard._quiPreviewSurface and auraPage._previewToggle and auraCard._quiPreviewViewport,
    "subpage previews reuse the rounded, collapsible, bounded card")
assert(activeHost ~= mainHost and builds > before and activeHost:IsVisible(),
    "switching to Auras transfers ownership to its visible specimen host")
local auraHost = activeHost
local auraPlate = auraHost:GetChildren()
auraPlate.healthBg.GetLeft = function() return 0 end
auraPlate.healthBg.GetRight = function() return 300 end
auraPlate.healthBg.GetTop = function() return 0 end
auraPlate.healthBg.GetBottom = function() return -80 end
ns.QUI_RefreshNameplatePreview()
Flush()
CheckCentered(auraHost, 300)
local auraControls = assert(auraCard._quiPreviewControlsToggle)
local auraStrip
for _, child in ipairs({ auraCard._quiPreviewHost:GetChildren() }) do
    if child ~= auraHost and child ~= auraControls then auraStrip = child end
end
assert(auraStrip and not auraStrip:IsShown(), "Auras inherits the collapsed scenario preference")
auraControls:GetScript("OnClick")(auraControls)
Flush()
assert(auraStrip:IsVisible(), "Auras offers the same functional controls disclosure")
local expandedAura = auraCard:GetHeight()
local auraDisclosure = auraPage._previewToggle
assert(auraCard._quiPreviewHeader and auraCard._quiPreviewCollapsedHeight >= auraDisclosure:GetHeight(),
    "previews without selectors reserve a visible header for their show/hide control")
auraDisclosure:GetScript("OnClick")(auraDisclosure)
assert(auraCard:GetHeight() >= auraDisclosure:GetHeight() and not auraCard._quiPreviewHost:IsShown(),
    "collapsing the subpage keeps its disclosure inside the preview header")
auraDisclosure:GetScript("OnClick")(auraDisclosure)
Flush()
assert(auraCard:GetHeight() == expandedAura and activeHost == auraHost,
    "expanding the subpage restores the active Nameplates specimen")
GUI:SelectFeatureTile(window, auras.index, { subPageIndex = 3 })
Flush()
local unitPage = assert(auras._subPageBodies[3])
unitPage:SetHeight(500)
Flush()
local unitCard, unitToggle = assert(unitPage._preview), assert(unitPage._previewToggle)
assert(unitCard._quiPreviewHeader and unitCard._quiPreviewCollapsedHeight >= unitToggle:GetHeight(),
    "Auras Unit Frames also retains a real header when its selector is omitted")
unitToggle:GetScript("OnClick")(unitToggle)
assert(unitCard:GetHeight() >= unitToggle:GetHeight() and not unitCard._quiPreviewHost:IsShown(),
    "Unit Frames subpage disclosure stays inside its collapsed preview card")
unitToggle:GetScript("OnClick")(unitToggle)
GUI:SelectFeatureTile(window, auras.index, { subPageIndex = 5 })
Flush()
assert(activeHost == auraHost, "returning from Unit Frames restores Auras Nameplates ownership")
local _, gapOwner, _, _, gap = auraPage._contentRoot:GetPoint(1)
assert(gapOwner == auraCard and gap == -4, "Auras uses the same compact preview-to-settings gap")
GUI:SelectFeatureTile(window, nameplates.index)
Flush()
assert(activeHost == mainHost and mainHost:GetChildren() == plate and not auraHost:IsVisible(),
    "returning from Auras restores the cached main specimen and hides the old host")
assert(strip:IsVisible(), "returning to Nameplates restores the shared expanded controls preference")
assert(ns.QUI_NameplatesSettingsSurface.GetSelectedType() == "bossElite",
    "the selected nameplate type survives navigation between preview owners")
window:Hide()
Flush()
local hiddenBuilds = builds
GUI:BuildTilePage(window, nameplates)
assert(builds == hiddenBuilds and not mainHost:IsVisible(), "closing settings hides the inline specimen")
window:Show()
Flush()
assert(builds > hiddenBuilds and activeHost == mainHost and mainHost:IsVisible(),
    "reopening settings restores native Nameplates preview ownership")
assert(zoom:GetValue() == 3, "reopening settings defaults the cached preview to 3x")
zoom:SetValue(1)
Flush()
measuredWidth, measuredHeight = 240, 80
plate.healthBg.GetEffectiveScale = function() return plate:GetEffectiveScale() end
for _, panelScale in ipairs({ 0.8, 1.5, 1.0 }) do
    window:SetScale(panelScale)
    ns.UIKit.RefreshScaleBoundWidgets()
    Flush()
    assert(math.abs(plate:GetEffectiveScale() - UIParent:GetEffectiveScale()) < 1e-6,
        "the inline specimen retains its world scale while the settings window zooms")
    assert(math.abs(mainHost:GetWidth() * mainHost:GetEffectiveScale() - measuredWidth) < 1e-6
        and math.abs(mainHost:GetHeight() * mainHost:GetEffectiveScale() - measuredHeight) < 1e-6,
        "actual card observer reserves the specimen's physical extent after panel zoom")
    CheckCentered(mainHost, measuredWidth / panelScale)
    assert(math.abs(card._quiPreviewNaturalHeight - (card._quiPreviewChromeHeight
        + measuredHeight / panelScale + 8 + controlsToggle:GetHeight() + 4 + strip:GetHeight())) < 1e-6,
        "card height follows remeasured specimen space and keeps expanded controls below it")
end
print("options_inline_preview_mounting_test: ok")
