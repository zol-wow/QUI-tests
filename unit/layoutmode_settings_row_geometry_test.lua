local originalLoadfile = loadfile
local baselineAnchor = os.getenv("QUI_LAYOUT_ANCHOR_SOURCE")
local baselineUtils = os.getenv("QUI_LAYOUT_UTILS_SOURCE")
_G.loadfile = function(path, ...)
    if path == "core/settings/content/anchoring_shared_content.lua" and baselineAnchor then path = baselineAnchor end
    if path == "modules/layout/layoutmode_utils.lua" and baselineUtils then path = baselineUtils end
    return originalLoadfile(path, ...)
end

local fh = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = fh:read("*a")
fh:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert((loadstring or load)(source:sub(1, cut - 1) .. "\nreturn ns", "@gen-preamble"))()
local GUI = assert(_G.QUI.GUI)
local Utils = assert(ns.QUI_LayoutMode_Utils)

local frames = {}
local timers = {}
local notifying = false
local pending = false
local fractions = {
    TOPLEFT = {0, 0}, TOP = {0.5, 0}, TOPRIGHT = {1, 0},
    LEFT = {0, 0.5}, CENTER = {0.5, 0.5}, RIGHT = {1, 0.5},
    BOTTOMLEFT = {0, 1}, BOTTOM = {0.5, 1}, BOTTOMRIGHT = {1, 1},
}

local function Axis(frame, horizontal)
    local axis = horizontal and 1 or 2
    local length = horizontal and frame._width or frame._height
    local first, firstFraction
    for _, point in ipairs(frame._points) do
        local ownFraction = fractions[point[1]][axis]
        local relative = point[2]
        local relativeStart, relativeLength = 0, 0
        if relative then relativeStart, relativeLength = Axis(relative, horizontal) end
        local relativeFraction = fractions[point[3]][axis]
        local offset = horizontal and point[4] or -point[5]
        local coordinate = relativeStart + relativeLength * relativeFraction + offset
        if first and math.abs(ownFraction - firstFraction) == 1 then
            length = (coordinate - first) / (ownFraction - firstFraction)
            return first - firstFraction * length, length
        end
        if not first then first, firstFraction = coordinate, ownFraction end
    end
    return first and first - firstFraction * length or 0, length
end

local function NotifySizes()
    pending = true
    if notifying then return end
    notifying = true
    local passes = 0
    while pending do
        pending = false
        passes = passes + 1
        assert(passes < 40, "frame size callbacks must settle")
        for _, frame in ipairs(frames) do
            local _, width = Axis(frame, true)
            local _, height = Axis(frame, false)
            if width ~= frame._lastWidth or height ~= frame._lastHeight then
                frame._lastWidth, frame._lastHeight = width, height
                local callback = frame._scripts.OnSizeChanged
                if callback then callback(frame, width, height) end
            end
        end
    end
    notifying = false
end

local function Decorate(frame)
    frame._scripts = {}
    frame._points = {}
    frames[#frames + 1] = frame
    frame.GetWidth = function(self) local _, width = Axis(self, true); return width end
    frame.GetHeight = function(self) local _, height = Axis(self, false); return height end
    frame.GetSize = function(self) return self:GetWidth(), self:GetHeight() end
    frame.GetLeft = function(self) return (Axis(self, true)) end
    frame.GetRight = function(self) local start, length = Axis(self, true); return start + length end
    frame.GetTop = function(self) return -(Axis(self, false)) end
    frame.GetBottom = function(self) local start, length = Axis(self, false); return -start - length end
    frame.SetWidth = function(self, width) self._width = width; pending = true end
    frame.SetHeight = function(self, height) self._height = height; pending = true end
    frame.SetSize = function(self, width, height) self._width, self._height = width, height; pending = true end
    frame.ClearAllPoints = function(self) self._points = {} end
    frame.SetPoint = function(self, point, relative, relativePoint, x, y)
        if type(relative) ~= "table" then
            y, x, relativePoint, relative = relativePoint or 0, relative or 0, point, self:GetParent()
        end
        if type(relativePoint) ~= "string" then
            y, x, relativePoint = x or 0, relativePoint or 0, point
        end
        local anchor = {point, relative, relativePoint, x or 0, y or 0}
        for i, existing in ipairs(self._points) do
            if existing[1] == point then self._points[i] = anchor; pending = true; return end
        end
        self._points[#self._points + 1] = anchor
        pending = true
    end
    frame.SetAllPoints = function(self, relative)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relative or self:GetParent(), "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relative or self:GetParent(), "BOTTOMRIGHT", 0, 0)
    end
    frame.SetScript = function(self, event, callback) self._scripts[event] = callback end
    frame.GetScript = function(self, event) return self._scripts[event] end
    frame.HookScript = function(self, event, callback)
        local previous = self._scripts[event]
        self._scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    for _, method in ipairs({"CreateTexture", "CreateFontString", "CreateMaskTexture"}) do
        local original = frame[method]
        frame[method] = function(self, ...) return Decorate(original(self, ...)) end
    end
    if frame._captureKind == "Slider" then
        frame.GetThumbTexture = function(self)
            if not self._nativeThumb then self._nativeThumb = self:CreateTexture() end
            return self._nativeThumb
        end
    end
    return frame
end

local createFrame = _G.CreateFrame
_G.CreateFrame = function(...) return Decorate(createFrame(...)) end
_G.C_Timer.After = function(_, callback) timers[#timers + 1] = callback end
local function Flush()
    while #timers > 0 do
        local current = timers
        timers = {}
        for _, callback in ipairs(current) do callback() end
    end
    NotifySizes()
end

local db = {frameAnchoring = {}}
ns.Helpers.GetCore = function() return {db = {profile = db}} end
ns.QUI_Anchoring = {GetAnchorTargetList = function() return {{value = "screen", text = "Screen"}} end}
assert(loadfile("core/settings/content/anchoring_shared_content.lua"))("QUI", ns)
_G.geterrorhandler = function() return function(err) error(err) end end

local function Rows(body)
    local rows = {}
    for _, child in ipairs({body:GetChildren()}) do
        if child._widgetLabel then rows[#rows + 1] = child end
    end
    table.sort(rows, function(a, b) return a:GetTop() > b:GetTop() end)
    return rows
end

local function CheckPanel(content, sections)
    for _, section in ipairs(sections) do
        local body = section._body
        local rows = Rows(body)
        for i, row in ipairs(rows) do
            if row._quiLayoutFormSlider then
                local labelOffset = section._sectionTitle == "Position" and 132 or 180
                local requiredWidth = labelOffset + 120 + row.editBox:GetWidth() + 60
                local stacked = row:GetWidth() < requiredWidth
                assert(row:GetHeight() == (stacked and 52 or 28), "responsive slider must use actual available width")
                assert(row.editBox:GetBottom() >= row:GetBottom(), "numeric edit box must remain inside its row")
                assert(row.slider:GetWidth() >= 100, "responsive slider must preserve a usable track")
                for _, control in ipairs({row:GetChildren()}) do
                    assert(control:GetTop() <= row:GetTop() and control:GetBottom() >= row:GetBottom(),
                        "slider track, numeric field and nudge buttons must fit inside their row")
                    if stacked then
                        assert(row.label:GetBottom() > control:GetTop(), "stacked slider label must remain above its track and numeric controls")
                    else
                        local labelCenter = (row.label:GetTop() + row.label:GetBottom()) / 2
                        local controlCenter = (control:GetTop() + control:GetBottom()) / 2
                        assert(math.abs(labelCenter - controlCenter) < 0.01,
                            "inline slider text and controls must share the same vertical center")
                    end
                end
            end
            if rows[i + 1] then
                assert(row:GetBottom() - rows[i + 1]:GetTop() >= (section._sectionTitle == "Position" and 1.99 or 3.99),
                    row._widgetLabel .. " overlaps the next row")
            end
        end
        local last = rows[#rows]
        assert(last and body:GetBottom() <= last:GetBottom() - 3.99, "body must reserve the final responsive row height")
        assert(section:GetBottom() <= body:GetBottom() - 7.99, "section must include its body and padding")
    end
    for i = 1, #sections - 1 do
        assert(sections[i]:GetBottom() - sections[i + 1]:GetTop() >= 3.99,
            "following section must move below expanded rows")
    end
    assert(content:GetBottom() <= sections[#sections]:GetBottom(), "scroll content must include every section")
end

local function BuildPanel(width, key, content)
    content = content or CreateFrame("Frame")
    content:SetWidth(width)
    local sections = {}
    local function Relayout() Utils.StandardRelayout(content, sections) end
    Utils.BuildPositionCollapsible(content, key, {autoWidth = true, autoHeight = true}, sections, Relayout)
    Utils.BuildSizeCollapsible(content, {
        getSize = function() return 400, 200 end,
        setSize = function() end,
    }, sections, Relayout)
    Utils.CreateCollapsible(content, "Following section", 40, function(body)
        local toggle = GUI:CreateFormToggle(body, "Following toggle", "enabled", {enabled = true})
        toggle:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -4)
        toggle:SetPoint("RIGHT", body, "RIGHT", 0, 0)
    end, sections, Relayout)
    Relayout()
    Flush()
    return content, sections
end

assert(loadfile("modules/layout/layoutmode_settings.lua"))("QUI", ns)
local settings = ns.QUI_LayoutMode_Settings
settings._currentKey = "inlineRowGeometry"
settings:Show("inlineRowGeometry")
local panelContent = settings._panel._content
local inlineContent, inlineSections = BuildPanel(panelContent:GetWidth(), "inlineRowGeometry", panelContent)
CheckPanel(inlineContent, inlineSections, false)

local content, sections = BuildPanel(374, "rowGeometry")
CheckPanel(content, sections, true)
local narrowHeight = content:GetHeight()
content:SetWidth(560)
Flush()
CheckPanel(content, sections, false)
assert(content:GetHeight() < narrowHeight, "widening the panel must reclaim stacked row space")
content:SetWidth(374)
Flush()
CheckPanel(content, sections, true)
assert(content:GetHeight() == narrowHeight, "resizing back must restore stacked section heights")

local lateContent, lateSections = BuildPanel(0, "lateRowGeometry")
lateContent:SetWidth(374)
Flush()
CheckPanel(lateContent, lateSections, true)
lateContent:SetWidth(560)
Flush()
CheckPanel(lateContent, lateSections, false)

local ownedRows = {}
for i = 1, 2 do
    local section = sections[i]
    local body = section._body
    body._dualRowFrames = {}
    local row = Rows(body)[1]
    ownedRows[i] = row
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", body, "TOPLEFT", 5, -123)
    row:SetPoint("RIGHT", body, "RIGHT", -20, 0)
    section._contentHeight = 1000 + i
    section:RefreshContentHeight()
end
content:SetWidth(350)
Flush()
for i = 1, 2 do
    local body = sections[i]._body
    local row = ownedRows[i]
    local _, _, _, x, y = row:GetPoint(1)
    assert(x == 5 and y == -123, "single-column callbacks must yield anchor ownership to dual-column rows")
    assert(body:GetHeight() == 1000 + i, "single-column callbacks must yield body height ownership to dual-column rows")
end

print("OK: layoutmode_settings_row_geometry")

-- A section queued by the previous mover must not resize the next provider.
local retiredHost = CreateFrame("Frame")
retiredHost._quiLayoutGeneration = 1
local retiredCalls = 0
local retired = Utils.CreateCollapsible(retiredHost, "Retired", 40, function() end, {},
    function() retiredCalls = retiredCalls + 1 end)
retiredHost._quiLayoutGeneration = 2
retired:SetParent(nil)
Flush()
assert(retiredCalls == 0, "a retired mover's queued layout must not resize the current panel")
print("OK: retired layout callbacks ignored")
