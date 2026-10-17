local unpackValues = table.unpack or unpack
local compile = loadstring or load
local function Read(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end
local source = Read(os.getenv("QUI_CARD_SOURCE") or "QUI_Options/shared.lua")
local function Extract(first, last)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local deferred = {}
local timer = {After = function(_, fn) deferred[#deferred + 1] = fn end}
local function Flush()
    local count = 0
    while #deferred > 0 do
        count = count + 1
        assert(count < 100, "layout must settle")
        table.remove(deferred, 1)()
    end
end
local function Region(parent)
    local region = {parent = parent, points = {}, height = 0, shown = true}
    function region:SetPoint(point, relative, relativePoint, x, y)
        for i, anchor in ipairs(self.points) do
            if anchor[1] == point then self.points[i] = {point, relative, relativePoint, x, y}; return end
        end
        self.points[#self.points + 1] = {point, relative, relativePoint, x, y}
    end
    function region:GetPoint(i) return unpackValues(self.points[i or 1]) end
    function region:GetNumPoints() return #self.points end
    function region:ClearAllPoints() self.points = {} end
    function region:SetAllPoints() end
    function region:SetWidth(value) self.width = value end
    function region:SetSize(width, height) self:SetWidth(width); self:SetHeight(height) end
    function region:GetWidth() return self.width or self.parent:GetWidth() end
    function region:SetHeight(value) self.height = value end
    function region:GetHeight() return self.height end
    function region:SetColorTexture() end
    function region:SetShown(value) self.shown = value end
    function region:IsShown() return self.shown end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    return region
end
local function Frame(_, _, parent)
    local frame = Region(parent)
    frame.children, frame.scripts = {}, {}
    if parent then parent.children[#parent.children + 1] = frame end
    function frame:SetParent(value)
        self.reparentCount = (self.reparentCount or 0) + 1
        if self.parent then
            for i, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, i); break end
            end
        end
        self.parent = value
        if value then value.children[#value.children + 1] = self end
    end
    function frame:GetParent() return self.parent end
    function frame:GetChildren() return unpackValues(self.children) end
    function frame:GetNumRegions() return 0 end
    function frame:CreateTexture() return Region(self) end
    function frame:CreateFontString()
        local text = Region(self)
        function text:GetFont() return "font", 11 end
        function text:SetFont() end
        function text:SetTextColor() end
        function text:SetText(value) self.text = value end
        function text:SetJustifyH() end
        function text:SetWordWrap(value) self.wrap = value end
        function text:SetNonSpaceWrap(value) self.nonSpace = value end
        function text:GetStringHeight() return math.ceil(#self.text * 5 / self:GetWidth()) * 12 end
        return text
    end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    function frame:HookScript(event, fn)
        self.hooks = self.hooks or {}
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = fn
    end
    function frame:SetHeight(value)
        local previous = self.height
        self.height = value
        if value ~= previous then
            if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self:GetWidth(), value) end
            for _, fn in ipairs(self.hooks and self.hooks.OnSizeChanged or {}) do fn(self, self:GetWidth(), value) end
        end
    end
    function frame:EnableMouse() end
    return frame
end
local ns = {QUI_Options = {}}
assert(compile(Read("core/settings_layout_shared.lua")))("QUI", ns)
local GUI = {Colors = {}, GetFontPath = function() return "font" end}
local helpers = {ApplyFontWithFallback = function() end}
local code = Extract("local function CreateSettingsCardGroup(", "local function CreatePreviewArea(")
    .. Extract("-- BEGIN setting row state", "-- END setting row state")
local loader = assert(compile("return function(ns, QUI, Helpers, CreateFrame, C_Timer)\n" .. code .. "\nend"))
loader()(ns, {GUI = GUI}, helpers, Frame, timer)
local options = ns.QUI_Options
local content = Frame()
content:SetWidth(800)
content:SetHeight(500)
local card = options.CreateSettingsCardGroup(content, -10)
local function Cell(label)
    local widget = Frame(nil, nil, content)
    widget:SetWidth(150)
    widget:SetHeight(22)
    widget._quiSearchID = label
    return options.BuildSettingRow(content, label, widget, "Description wraps too")
end
local adaptiveSlider = Frame(nil, nil, content)
adaptiveSlider:SetSize(236, 28)
adaptiveSlider._quiPreferredControlWidth = 236
adaptiveSlider._quiMinimumControlWidth = 196
local adaptiveRow = options.BuildSettingRow(content, "Out-of-Range Alpha", adaptiveSlider)
adaptiveRow:Layout(330)
assert(adaptiveSlider:GetWidth() == 232 and adaptiveRow:GetHeight() == 28,
    "slider must use available inline width before stacking its label")
adaptiveSlider._quiPinButton = Frame()
adaptiveSlider._quiPinButton:SetWidth(16)
adaptiveRow:Layout(305)
assert(adaptiveRow:GetHeight() == 28, "minimap slider must stay inline with a pin at 305 pixels")
adaptiveSlider._quiPinButton = nil
adaptiveRow:Layout(280)
assert(adaptiveSlider:GetWidth() == 196 and adaptiveRow:GetHeight() > 28,
    "narrow slider rows must stack without shrinking the usable track")
adaptiveRow:Layout(400)
assert(adaptiveSlider:GetWidth() == 236 and adaptiveRow:GetHeight() == 28,
    "slider preferred width must restore when the row grows")
local adaptiveDropdown = Frame(nil, nil, content)
adaptiveDropdown:SetSize(180, 28)
adaptiveDropdown._quiPreferredControlWidth = 180
adaptiveDropdown._quiMinimumControlWidth = 140
local dropdownRow = options.BuildSettingRow(content, "Pet Anchor", adaptiveDropdown)
dropdownRow:Layout(260)
assert(adaptiveDropdown:GetWidth() == 162 and dropdownRow:GetHeight() == 28,
    "dropdown must fit beside its label before stacking")
dropdownRow:Layout(210)
assert(adaptiveDropdown:GetWidth() == 140 and dropdownRow:GetHeight() > 28,
    "dropdown must retain readable minimum width when stacked")
dropdownRow:Layout(330)
assert(adaptiveDropdown:GetWidth() == 180 and dropdownRow:GetHeight() == 28,
    "dropdown must restore preferred width when space returns")
local left, right = Cell("A moderately long translated setting label"), Cell("Right setting")
local row = card.AddRow(left, right)
card.Finalize()
Flush()
local wideHeight = card.frame:GetHeight()
assert(left.reparentCount == 1 and right.reparentCount == 1,
    "unchanged pairs must not reparent during initial layout and deferred refresh")
assert(row:GetHeight() == math.max(left:GetHeight(), right:GetHeight()) + 4,
    "paired settings reserve four units of padding around their measured controls")
assert(select(5, left:GetPoint(1)) == -2 and select(5, right:GetPoint(1)) == -2,
    "paired controls share a compact, equal top inset")
assert(not row._stacked and row._centerDivider:IsShown(), "wide cards must pair fields")
assert(left._label.wrap and left._label.nonSpace, "translated labels must wrap")
assert(left._label:GetWidth() > 0, "label width must reserve space for the control")
local nextHeader = Frame(nil, nil, content)
nextHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -10 - wideHeight - 14)
nextHeader:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -10 - wideHeight - 14)
local headerY = select(5, nextHeader:GetPoint(1))
local initialExtent = content:GetHeight()
content:SetWidth(480)
card.frame.scripts.OnSizeChanged()
Flush()
local narrowHeight = card.frame:GetHeight()
assert(row:GetHeight() == left:GetHeight() + right:GetHeight() + 8,
    "stacked settings keep a four-unit gap and four units of outer padding")
assert(select(5, right:GetPoint(1)) == -(left:GetHeight() + 6),
    "stacked controls follow the measured first cell without overlap")
assert(row._stacked and not row._centerDivider:IsShown(), "narrow cards must stack fields")
assert(narrowHeight > wideHeight, "stacking must grow the card")
assert(select(5, nextHeader:GetPoint(1)) == headerY - (narrowHeight - wideHeight), "following section must move by the card height delta")
assert(content:GetHeight() == initialExtent + narrowHeight - wideHeight, "scroll extent must grow")
assert(left._widget._quiSearchID == left._widgetLabel, "reflow must retain search identity")
content:SetWidth(800)
card.frame.scripts.OnSizeChanged()
Flush()
assert(card.frame:GetHeight() == wideHeight and content:GetHeight() == initialExtent, "wide layout must restore original extents")
assert(select(5, nextHeader:GetPoint(1)) == headerY, "following section must return without height drift")

local denseContent = Frame()
denseContent:SetWidth(900)
denseContent:SetHeight(400)
local dense = options.CreateSettingsCardGroup(denseContent, -10)
local denseCells, denseRows = {}, {}
for i = 1, 6 do
    local cell = Cell("Compact setting " .. i)
    cell._widget:SetWidth(30)
    denseCells[i] = cell
end
denseRows[1] = dense.AddRow(denseCells[1])
denseRows[2] = dense.AddRow(denseCells[2], denseCells[3])
denseRows[3] = dense.AddRow(denseCells[4], denseCells[5])
denseRows[4] = dense.AddRow(denseCells[6])
dense.Finalize()
Flush()
assert(dense.frame._quiColumnCount == 3, "wide compact cards must use three columns")
assert(denseCells[1]:GetParent() == denseCells[3]:GetParent(), "three consecutive settings share the first visual row")
assert(denseCells[4]:GetParent() == denseCells[6]:GetParent(), "remaining three settings share the second visual row")
assert(denseCells[1]:GetParent() ~= denseCells[4]:GetParent(), "settings retain their reading order across rows")
assert(not denseRows[3]:IsShown() and not denseRows[4]:IsShown(), "unused pair rows must not leave empty stripes")
local denseHeight = dense.frame:GetHeight()
for _, cell in ipairs(denseCells) do cell._widget:SetWidth(150) end
denseContent:SetWidth(700)
dense.frame.scripts.OnSizeChanged()
Flush()
assert(dense.frame._quiColumnCount == 2 and denseRows[3]:IsShown() and not denseRows[4]:IsShown(), "medium cards fill three two-column rows")
assert(denseCells[3]:GetParent() == denseRows[2], "two-column reflow retains reading order")
assert(dense.frame:GetHeight() > denseHeight, "three columns must reduce the compact card height")
for _, cell in ipairs(denseCells) do cell._widget:SetWidth(30) end
denseContent:SetWidth(900)
dense.frame.scripts.OnSizeChanged()
Flush()
assert(dense.frame:GetHeight() == denseHeight, "repeated responsive reflow must not accumulate height")
denseCells[6]._widget:SetWidth(220)
dense.frame.scripts.OnSizeChanged()
Flush()
assert(dense.frame._quiColumnCount == 3, "mixed cards retain compact columns around wider rows")
assert(denseCells[6]:GetParent() ~= denseCells[4]:GetParent() and denseCells[6]._label:GetWidth() >= 110,
    "wide controls retain a separate row with enough room for their labels")

local shortCard = options.CreateSettingsCardGroup(denseContent, -200)
local shortLeft, shortRight = Cell("One"), Cell("Two")
shortLeft._widget:SetWidth(30)
shortRight._widget:SetWidth(30)
shortCard.AddRow(shortLeft, shortRight)
shortCard.Finalize()
Flush()
assert(shortCard.frame._quiColumnCount == 2, "two settings must not leave an empty third column")
local pin = Region()
pin:SetWidth(20)
left._widget._quiPinButton = pin
left:Layout(240)
assert(left._label:GetWidth() == 240, "tight pinned controls must move below a full width label")
assert(left:GetHeight() >= left._label:GetStringHeight() + left._widget:GetHeight(), "vertical label layout must not overlap the control")
content:Hide()
content:SetWidth(480)
card.frame.scripts.OnSizeChanged()
Flush()
assert(card.frame:GetHeight() == wideHeight, "hidden cards must defer resize until shown")
content:Show()
card.frame.scripts.OnShow()
Flush()
assert(row._stacked, "show must apply the hidden width change")

_G.CreateFrame = Frame
_G.QUI = {GUI = GUI}
GUI.SetSearchContext = function() end
GUI.TeardownFrameTree = function(_, frame)
    for _, child in ipairs({frame:GetChildren()}) do child:Hide(); child:SetParent(nil) end
end
ns.Settings = {Util = {ShallowCopy = function(value)
    local copy = {}
    for key, item in pairs(value) do copy[key] = item end
    return copy
end}}
assert(loadfile(os.getenv("QUI_SCHEMA_SOURCE") or "core/settings/schema.lua"))("QUI", ns)
assert(loadfile("core/settings/renderer.lua"))("QUI", ns)
local cards = {}
local function RenderCard(host)
    local group = options.CreateSettingsCardGroup(host, -10)
    group.AddRow(Cell("First setting"), Cell("Second setting"))
    group.Finalize()
    host:SetHeight(group.frame:GetHeight() + 20)
    cards[#cards + 1] = group
    return host:GetHeight()
end
local features = {}
for _, id in ipairs({"first", "second"}) do
    features[id] = ns.Settings.Schema.Feature({id = id, sections = {
        {id = "settings", kind = "custom", render = RenderCard},
        {id = "after", kind = "custom", render = function(host) host:SetHeight(30); return 30 end},
    }})
end
ns.Settings.Registry = {GetFeature = function(_, id) return features[id] end}
ns.QUI_Options.PADDING = 15
local wrapperCode = source:sub((assert(source:find("local function MergeOptions(", 1, true))))
local wrappers = assert(compile("return function(ns, QUI, CreateFrame)\n" .. wrapperCode
    .. "\nreturn BuildFeatureTabPage, BuildFeatureStackPage\nend"))
local BuildPage, BuildStack = wrappers()(ns, _G.QUI, Frame)
local page = Frame()
page:SetWidth(800)
BuildPage(page, "first")
Flush()
local pageHost = page.children[1]
local initialPageHeight = page:GetHeight()
local runtime = pageHost._quiSettingsRuntime
local sectionInitial = runtime.sectionHeights.settings
local afterInitialY = select(5, runtime.sectionHosts.after:GetPoint(1))
page:SetWidth(480)
cards[1].frame.scripts.OnSizeChanged()
Flush()
local delta = runtime.sectionHeights.settings - sectionInitial
assert(delta > 0, "schema must update the resized section height")
assert(select(2, runtime.sectionHosts.after:GetPoint(1)) == runtime.sectionHosts.settings
    and select(3, runtime.sectionHosts.after:GetPoint(1)) == "BOTTOMLEFT"
    and select(5, runtime.sectionHosts.after:GetPoint(1)) == afterInitialY,
    "schema must follow the resized section bottom without changing its gap")
assert(page:GetHeight() == initialPageHeight + delta, "outer scroll extent must track deep schema height changes")
page:SetWidth(800)
cards[1].frame.scripts.OnSizeChanged()
Flush()
assert(page:GetHeight() == initialPageHeight, "deep schema wrappers must shrink without height drift")
local stack = Frame()
stack:SetWidth(800)
BuildStack(stack, {"first", "second"})
Flush()
local stackHeight = stack:GetHeight()
local secondHeader = stack.children[3]
local function AnchorY(frame)
    if frame == stack then return 0 end
    local _, relative, relativePoint, _, y = frame:GetPoint(1)
    return AnchorY(relative) + y - (relativePoint == "BOTTOMLEFT" and relative:GetHeight() or 0)
end
local secondHeaderY = AnchorY(secondHeader)
local firstStackCard = cards[2]
local stackCardHeight = firstStackCard.frame:GetHeight()
stack:SetWidth(480)
firstStackCard.frame.scripts.OnSizeChanged()
Flush()
local stackDelta = firstStackCard.frame:GetHeight() - stackCardHeight
assert(stack:GetHeight() == stackHeight + stackDelta, "stacked feature scroll extent must grow")
assert(AnchorY(secondHeader) == secondHeaderY - stackDelta, "following feature header must move")
stack:SetWidth(800)
firstStackCard.frame.scripts.OnSizeChanged()
Flush()
assert(stack:GetHeight() == stackHeight and AnchorY(secondHeader) == secondHeaderY, "stacked feature extents must restore")
features.short = ns.Settings.Schema.Feature({id = "short", sections = {
    {id = "setting", kind = "custom", render = function(host) host:SetHeight(22); return 22 end},
}})
local shortStack = Frame()
shortStack:SetWidth(800)
BuildStack(shortStack, {"short", "second"})
Flush()
local shortHost = shortStack.children[2]
local followingHeader = shortStack.children[3]
assert(shortHost:GetHeight() < 80, "short settings must retain their measured height instead of a blank 80-unit slot")
assert(select(2, followingHeader:GetPoint(1)) == shortHost
    and select(3, followingHeader:GetPoint(1)) == "BOTTOMLEFT"
    and select(5, followingHeader:GetPoint(1)) == -12,
    "following feature starts after measured content and the standard section gap")

local builders = Read("core/settings_builders.lua")
local start = assert(builders:find("local function GetInitialLayoutY(", 1, true))
local finish = assert(builders:find("local function RenderWithTileChrome(", start, true))
local builderLoader = assert(compile("return function(CreateFrame, C_Timer, ns)\nlocal CARD_ROW_HEIGHT = 32\nlocal dualColumnSequence = 0\n"
    .. builders:sub(start, finish - 1) .. "\nreturn ApplyDualColumnLayoutWhenReady\nend"))
local applyColumns = builderLoader()(Frame, timer, ns)
local legacyParent = Frame()
legacyParent:SetWidth(900)
local legacySection = Frame(nil, nil, legacyParent)
local legacyBody = Frame(nil, nil, legacySection)
legacyBody:SetWidth(900)
legacySection._body = legacyBody
function legacySection:SetExpanded() end
local legacyCells = {}
for i = 1, 6 do
    local cell = Frame(nil, nil, legacyBody)
    cell:SetHeight(32)
    cell:SetPoint("TOPLEFT", legacyBody, "TOPLEFT", 0, -32 * i)
    cell.label = {}
    cell.track = Region(cell)
    cell.track:SetWidth(26)
    legacyCells[i] = cell
end
applyColumns(legacySection)
Flush()
assert(select(2, legacyCells[1]:GetPoint(1)) == select(2, legacyCells[3]:GetPoint(1)),
    "legacy forms must pack three consecutive compact toggles into one row")
local legacyHeight = legacyBody._contentHeight
legacyBody:SetWidth(520)
for _, fn in ipairs(legacyBody.hooks.OnSizeChanged) do fn(legacyBody, 520) end
Flush()
assert(select(2, legacyCells[1]:GetPoint(1)) ~= select(2, legacyCells[3]:GetPoint(1)),
    "legacy forms must restore two columns when narrowed")
assert(legacyBody._contentHeight > legacyHeight, "legacy scroll extent must follow the responsive row count")
legacyBody:SetWidth(900)
for _, fn in ipairs(legacyBody.hooks.OnSizeChanged) do fn(legacyBody, 900) end
Flush()
assert(legacyBody._contentHeight == legacyHeight, "legacy reflow must shrink without height drift")

print("OK: options_settings_card_responsive_test")

local delayedContent = Frame()
delayedContent:SetWidth(900)
delayedContent:SetHeight(400)
local delayedCard = options.CreateSettingsCardGroup(delayedContent, -44)
for i = 1, 3 do
    local first, second = Cell("Compact A"), Cell("Compact B")
    first._widget:SetWidth(30)
    second._widget:SetWidth(30)
    delayedCard.AddRow(first, second)
end
local measuredHeight = delayedCard.frame.height
delayedCard.frame.GetHeight = function() return measuredHeight + 32 end
assert(delayedCard.Finalize() == measuredHeight,
    "finalizing a compact card must return its calculated height even while native bounds are stale")

local schemaSource = Read("QUI_Nameplates/nameplates/settings/nameplates_schema.lua")
local builderStart = assert(schemaSource:find("local function CreateSectionBuilder(", 1, true))
local builderCode = schemaSource:sub(builderStart, assert(schemaSource:find("local function RefreshNameplates(", builderStart, true)) - 1)
local sectionHost = Frame()
sectionHost:SetWidth(760)
local builderLoader = assert(compile("return function(GetOptionsAPI, PrepareSectionHost, SetSearchContext, HEADER_GAP, DESCRIPTION_TEXT_COLOR, SECTION_BOTTOM_PAD)\n" .. builderCode .. "\nreturn CreateSectionBuilder end"))
local createBuilder = builderLoader()(function() return options end, function() end, function() end, 22, {}, 6)
local builder = createBuilder(sectionHost, {}, {})
builder.Spacer(44)
local mixedCard = builder.Card()
for i = 1, 4 do
    local first, second = Cell("Compact A"), Cell("Compact B")
    first._widget:SetWidth(30)
    second._widget:SetWidth(i == 4 and 216 or 30)
    mixedCard.AddRow(first, second)
end
builder.CloseCard(mixedCard)
sectionHost:SetHeight(builder.Height())
assert(sectionHost:GetHeight() == 158, "nameplate cards must compact at ordinary docked widths before resize")
sectionHost:SetWidth(900)
Flush()
assert(sectionHost:GetHeight() == 158,
    "nameplate sections must settle to the compact card height after deferred width layout")

local coreSchema = Read("core/settings/schema.lua")
local flowStart = assert(coreSchema:find("local function LayoutSections(", 1, true))
local flowCode = coreSchema:sub(flowStart, assert(coreSchema:find("local function RenderSection(", flowStart, true)) - 1)
local layoutSections = assert(compile(flowCode .. "\nreturn LayoutSections"))()
local flowHost = Frame()
flowHost:SetWidth(900)
local firstSection, secondSection, thirdSection = Frame(nil, nil, flowHost), Frame(nil, nil, flowHost), Frame(nil, nil, flowHost)
local flow = {host = flowHost, surface = {padding = 10, topPadding = 6, bottomPadding = 16, sectionGap = 10},
    sectionOrder = {"first", "second", "third"}, sectionHosts = {first = firstSection, second = secondSection, third = thirdSection},
    sectionsById = {first = {gapAfter = 7}, second = {}, third = {}}, sectionHeights = {first = 126, second = 158, third = 158}}
layoutSections(flow)
local point, relative, relativePoint, x, y = secondSection:GetPoint(1)
assert(point == "TOPLEFT" and relative == firstSection and relativePoint == "BOTTOMLEFT" and x == 0 and y == -7,
    "sections must flow from the previous section bottom with the configured gap")
flow.sectionHeights.first = 90
layoutSections(flow)
assert(select(2, secondSection:GetPoint(1)) == firstSection and select(5, secondSection:GetPoint(1)) == -7,
    "compacting an earlier section must retain the same anchor and gap")
assert(flowHost:GetHeight() == 6 + 90 + 7 + 158 + 10 + 158 + 10 + 16,
    "flow pages must retain a measured scroll extent")

local flowingContent = Frame()
flowingContent:SetWidth(900)
flowingContent:SetHeight(400)
local flowing = options.CreateSettingsCardGroup(flowingContent, -10)
local flowingCells = {}
for i = 1, 6 do
    flowingCells[i] = Cell("Ordinary setting " .. i)
    flowingCells[i]._widget:SetWidth(200)
end
flowing.AddRow(flowingCells[1])
flowing.AddRow(flowingCells[2], flowingCells[3])
flowing.AddRow(flowingCells[4])
flowing.AddRow(flowingCells[5], flowingCells[6])
flowing.Finalize()
Flush()
assert(flowingCells[1]:GetParent() == flowingCells[2]:GetParent(),
    "ordinary settings must fill the available second column after a single field")
assert(flowingCells[3]:GetParent() == flowingCells[4]:GetParent(),
    "flow preserves field order across source row boundaries")
local flowingHeight = flowing.frame:GetHeight()
local visibleRows = 0
for _, child in ipairs({flowing.frame:GetChildren()}) do
    if child:IsShown() then visibleRows = visibleRows + 1 end
end
assert(visibleRows == 3, "six ordinary fields use three rows without empty full-width rows")
flowingContent:SetWidth(480)
flowing.frame.scripts.OnSizeChanged()
Flush()
for _, cell in ipairs(flowingCells) do assert(cell:IsVisible(), "narrow reflow retains every field") end
flowingContent:SetWidth(900)
flowing.frame.scripts.OnSizeChanged()
Flush()
assert(flowing.frame:GetHeight() == flowingHeight, "density reflow returns without height drift")

local groupSource = Read(arg[1] or "QUI_GroupFrames/groupframes/settings/group_frames_schema.lua")
local groupBuilderStart = assert(groupSource:find("local function CreateSectionBuilder(", 1, true))
local groupBuilderCode = groupSource:sub(groupBuilderStart,
    assert(groupSource:find("local function GetFontListWithDefault", groupBuilderStart, true)) - 1)
local groupBuilderLoader = assert(compile("return function(GetOptionsAPI, PrepareSectionHost, SetSearchContext, GetSearchProviderKey, GetRenderContextMode, SECTION_BOTTOM_PAD)\n"
    .. groupBuilderCode .. "\nreturn CreateSectionBuilder end"))
local createGroupBuilder = groupBuilderLoader()(function() return options end, function() end,
    function() end, function() return "groupFrames" end, function() return "party" end, 10)

for _, case in ipairs({{count = 1, trailing = 0}, {count = 1, trailing = 31}, {count = 3, trailing = 31}}) do
    local count = case.count
    local host = Frame()
    host:SetWidth(800)
    local build = createGroupBuilder(host, {}, {})
    build.Spacer(22)
    local groups, heights, offsets = {}, {}, {}
    for index = 1, count do
        local group = build.Card()
        group.AddRow(Cell("First setting"), Cell("Second setting"))
        build.CloseCard(group)
        groups[index], heights[index] = group, group.frame:GetHeight()
        offsets[index] = select(5, group.frame:GetPoint())
        if index < count then build.Spacer(7) end
    end
    local trailing = Frame(nil, nil, host)
    trailing:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -build.Height(0))
    build.Spacer(case.trailing)
    local initialHeight = build.Height(case.trailing == 0 and nil or 17)
    host:SetHeight(initialHeight)
    local trailingY = select(5, trailing:GetPoint())
    Flush()
    for cycle = 1, 3 do
        for _, width in ipairs({480, 800}) do
            host:SetWidth(width)
            local totalDelta = 0
            for index, group in ipairs(groups) do
                group.frame.scripts.OnSizeChanged()
                Flush()
                local delta = group.frame:GetHeight() - heights[index]
                if width == 480 then assert(delta > 0, "real group cards must grow when stacked") end
                assert(select(5, group.frame:GetPoint()) == offsets[index] - totalDelta,
                    "later group cards retain their gap after earlier cards resize")
                totalDelta = totalDelta + delta
            end
            assert(host:GetHeight() == initialHeight + totalDelta,
                ("group section extent must apply each shared LayoutRows delta exactly once (expected %s, got %s)")
                    :format(initialHeight + totalDelta, host:GetHeight()))
            assert(select(5, trailing:GetPoint()) == trailingY - totalDelta,
                "trailing editor must follow all card deltas without losing spacing")
            for _, group in ipairs(groups) do group.frame.scripts.OnSizeChanged() end
            Flush()
            assert(host:GetHeight() == initialHeight + totalDelta,
                "zero-delta layout must preserve the absolute group extent")
        end
    end
    createGroupBuilder(host, {}, {})
    assert(host._quiMeasureSettingsHeight == nil, "rebuilding must discard the previous card measurement")
end
print("OK: real Group Frames builder and shared responsive card extents")

local sectionStart = assert(groupSource:find("local function RenderGeneralEnableSection", 1, true))
local sectionEnd = assert(groupSource:find("local function RenderGeneralCopySettingsSection", sectionStart, true))
local controls = {}
function GUI:CreateFormCheckbox(parent, label, key)
    local widget = Frame(nil, nil, parent)
    widget:SetWidth(30)
    widget:SetHeight(24)
    widget._quiCompactKind = "toggle"
    controls[key] = widget
    return widget
end
function GUI:CreateFormDropdown(parent, label, choices, key)
    local widget = Frame(nil, nil, parent)
    widget:SetWidth(180)
    widget:SetHeight(30)
    controls[key] = widget
    return widget
end
local groupNS = {L = setmetatable({}, {__index = function(_, key) return key end})}
local sectionLoader = assert(compile("return function(ns, GetGUI, ResolveGroupFramesDB, SetSearchContext, CreateSearchContext, GetOptionsAPI, CreateSectionBuilder)\n"
    .. groupSource:sub(sectionStart, sectionEnd - 1) .. "\nreturn RenderGeneralEnableSection end"))
local renderEnable = sectionLoader()(groupNS, function() return GUI end,
    function() return {gfdb = {}, contextMode = "party"} end,
    function() end, function() return {} end, function() return options end,
    createGroupBuilder)
local groupHost = Frame()
groupHost:SetWidth(900)
groupHost:SetHeight(400)
local enableHeight = renderEnable(groupHost, {options = {contextMode = "party"}})
Flush()
local enableCell = controls.enabled:GetParent()
local skinningCell = controls.externalSkinning:GetParent()
assert(enableCell ~= groupHost and enableCell:GetParent() == skinningCell:GetParent(),
    "Group Frames enable and external skinning controls must share a measured row")
assert(enableHeight < 110, "Group Frames general settings must not reserve the old 142-unit gap")
local enableCard = enableCell:GetParent():GetParent()
local nextGroupSection = Frame(nil, nil, groupHost)
nextGroupSection:SetPoint("TOPLEFT", groupHost, "TOPLEFT", 0, -enableHeight - 14)
local initialGroupHeight = enableCard:GetHeight()
local initialGroupY = select(5, nextGroupSection:GetPoint())
groupHost:SetWidth(480)
enableCard.scripts.OnSizeChanged()
Flush()
assert(enableCard:GetHeight() > initialGroupHeight, "narrow Group Frames settings must stack")
assert(select(5, nextGroupSection:GetPoint()) == initialGroupY - (enableCard:GetHeight() - initialGroupHeight),
    "the next Group Frames section must follow the measured settings height")

local pinnedSource = Read(os.getenv("QUI_PINNED_SOURCE") or "QUI_ActionBars/actionbars/settings/action_bars_per_bar.lua")
local pinnedStart = assert(pinnedSource:find("local function BuildPinnedBarSection(", 1, true))
local pinnedCode = pinnedSource:sub(pinnedStart, assert(pinnedSource:find("local function PinnedLayoutRender(", pinnedStart, true)) - 1)
local prepareStart = pinnedSource:find("local function PrepareSettingsHost(", 1, true)
local prepareCode = prepareStart and pinnedSource:sub(prepareStart,
    assert(pinnedSource:find("local function RenderSettingsSection(", prepareStart, true)) - 1) or ""
local pinnedBuilder = assert(compile("return function(Schema, GetPerBarBuilder)\n" .. prepareCode .. pinnedCode .. "\nreturn BuildPinnedBarSection\nend"))()
local receivedWidth, receivedKey
local makePinned = pinnedBuilder({Section = function(section) return section end}, function()
    return function(host, key, width)
        assert(host.width == 880, "pinned action bar hosts must have explicit bounds before building controls")
        receivedWidth, receivedKey = width, key
        return 176
    end
end)
for _, key in ipairs({"totemBar", "raidMarkersBar", "bagBar", "extraActionButton", "zoneAbility"}) do
    local host = Frame()
    assert(makePinned("settings", key).build(host, {width = 900, surface = {padding = 10}}) == 176)
    assert(receivedWidth == 880 and receivedKey == key, "pinned pages must pass their actual content width to the existing builder")
end

local nativeParent = Frame()
nativeParent:SetWidth(900)
nativeParent:SetHeight(500)
function nativeParent:GetTop() return 500 end
local nativeCard = options.CreateSettingsCardGroup(nativeParent, -20)
nativeCard.frame:ClearAllPoints()
nativeCard.frame:SetPoint("TOPLEFT", nativeParent, "TOPLEFT", 15, -20)
nativeCard.frame:SetPoint("TOPRIGHT", nativeParent, "TOPRIGHT", -15, -20)
nativeCard.AddRow(Cell("Native layout setting"))
nativeCard.Finalize()
Flush()
local nativeFrame = nativeCard.frame
function nativeFrame:GetTop() if self.lostBounds then return nil end; return 480 end
local nativeGetWidth = nativeFrame.GetWidth
function nativeFrame:GetWidth() return self.lostBounds and 0 or nativeGetWidth(self) end
function nativeFrame:SetWidth(value) self.width = value; self.lostBounds = false end
local nativeShow = nativeFrame.Show
function nativeFrame:Show() self.showCount = (self.showCount or 0) + 1; nativeShow(self) end
if nativeFrame.scripts.OnUpdate then nativeFrame.scripts.OnUpdate(nativeFrame) end
nativeFrame.lostBounds = true
if nativeFrame.scripts.OnUpdate then nativeFrame.scripts.OnUpdate(nativeFrame) end
Flush()
assert(nativeFrame:GetWidth() == 870 and nativeFrame:GetTop() == 480,
    "a card that loses native bounds must recover the parent's inset width")
assert(nativeFrame:GetNumPoints() == 1 and nativeFrame.showCount == 1,
    "recovered cards must invalidate clipping with explicit bounds")
assert(nativeFrame.scripts.OnUpdate == nil, "native layout verification must remove its frame callback")
nativeParent:SetWidth(700)
for _, fn in ipairs(nativeParent.hooks.OnSizeChanged) do fn(nativeParent, 700) end
Flush()
assert(nativeFrame:GetWidth() == 670, "recovered cards must follow parent resizing")

local nativePage = Frame()
nativePage:SetWidth(900)
nativePage:SetHeight(500)
function nativePage:GetTop() return 500 end
ns.Settings.Schema:RenderFeature(features.first, nativePage, {surface = "tile"})
local nativeRuntime = nativePage._quiSettingsRuntime
Flush()
local nativeSection = nativeRuntime.sectionHosts.settings
function nativeSection:GetTop() if self.lostBounds then return nil end; return 480 end
local sectionGetWidth = nativeSection.GetWidth
function nativeSection:GetWidth() return self.lostBounds and 0 or sectionGetWidth(self) end
function nativeSection:SetWidth(value) self.width = value; self.lostBounds = false end
if nativeSection.scripts.OnUpdate then nativeSection.scripts.OnUpdate(nativeSection) end
nativeSection.lostBounds = true
if nativeSection.scripts.OnUpdate then nativeSection.scripts.OnUpdate(nativeSection) end
Flush()
assert(nativeSection:GetWidth() == 880 and nativeSection:GetTop() == 480,
    "a schema section that loses native bounds must recover its inset width")
assert(nativeSection:GetNumPoints() == 1 and nativeSection.scripts.OnUpdate == nil,
    "recovered schema sections must retain the previous-section flow and stop frame verification")
nativePage:SetWidth(700)
for _, fn in ipairs(nativePage.hooks.OnSizeChanged) do fn(nativePage, 700) end
Flush()
assert(nativeSection:GetWidth() == 680, "recovered schema sections must follow parent resizing")

local singleCard = options.CreateSettingsCardGroup(denseContent, -300)
local singleCell = Cell("Standalone toggle")
singleCell._widget:SetWidth(30)
singleCard.AddRow(singleCell)
singleCard.Finalize()
Flush()
assert(select(3, singleCell:GetPoint(2)) == "TOP", "a single setting must end at its column boundary")
assert(singleCell._label:GetWidth() < 450, "single settings must not stretch their label across the card")

local tailCard = options.CreateSettingsCardGroup(denseContent, -350)
local tailCells = {}
for i=1,4 do
    local cell=Cell("Toggle "..i)
    cell._widget:SetWidth(26)
    tailCells[i]=cell
    tailCard.AddRow(cell)
end
tailCard.Finalize()
Flush()
assert(tailCells[4]:GetWidth()==tailCells[1]:GetWidth(), "an unmatched toggle after three columns must retain that column width")

assert(singleCell:GetParent()._centerDivider:IsShown(), "a singleton card setting retains its column-ending divider")
assert(tailCells[4]:GetParent()._centerDivider:IsShown(), "a trailing third-column setting retains its divider")
assert(not tailCells[4]:GetParent()._thirdDivider:IsShown(), "empty columns do not acquire extra dividers")

local actionCard = options.CreateSettingsCardGroup(denseContent, -400)
local actions = Frame()
actions._quiFullWidth = true
local actionWidth
actions.Layout = function(self, width) actionWidth = width; return 28 end
actionCard.AddRow(actions)
actionCard.Finalize()
Flush()
assert(actionWidth > denseContent:GetWidth() * .8, "full-width actions must use the complete card row")
assert(not actions:GetParent()._centerDivider:IsShown(), "full-width actions must not show a half-column divider")

local dockedContent = Frame()
dockedContent:SetWidth(660)
dockedContent:SetHeight(400)
local dockedCard = options.CreateSettingsCardGroup(dockedContent, -10)
local compactCells = {}
for i = 1, 6 do
    compactCells[i] = Cell("Short toggle " .. i)
    compactCells[i]._widget:SetWidth(26)
end
for i = 1, 6, 2 do dockedCard.AddRow(compactCells[i], compactCells[i + 1]) end
dockedCard.Finalize()
Flush()
assert(dockedCard.frame._quiColumnCount == 3, "docked-width compact controls must use three columns")
assert(compactCells[1]:GetParent() == compactCells[3]:GetParent(), "docked cards must pack three controls in reading order")
local compactHeight = dockedCard.frame:GetHeight()
compactCells[2]._label.GetStringWidth = function() return 260 end
dockedCard.frame.scripts.OnSizeChanged()
Flush()
assert(compactCells[1]:GetParent() ~= compactCells[3]:GetParent(), "long translated labels must keep two-column space")
assert(dockedCard.frame:GetHeight() > compactHeight, "long-label fallback must update the content height")
assert(not ns.QUI_SettingsLayoutShared.FitsThreeColumns(compactCells[1]._label, left._widget, 660), "wide controls must retain two-column space")
legacyBody:SetWidth(660)
for _, fn in ipairs(legacyBody.hooks.OnSizeChanged) do fn(legacyBody, 660) end
Flush()
assert(select(2, legacyCells[1]:GetPoint(1)) == select(2, legacyCells[3]:GetPoint(1)), "legacy toggle forms must also use three columns at docked width")
print("OK: docked three-column cards and legacy forms")

local moduleSource = Read(os.getenv("QUI_MODULES_SOURCE") or "core/settings/content/modules_page.lua")
local moduleStart = assert(moduleSource:find("local function BuildModuleCell(", 1, true))
local moduleEnd = assert(moduleSource:find("local function RelayoutVisibleRows(", moduleStart, true))
local moduleLoader = assert(compile("return function(Shared, GUI, CreateModuleTogglePill)\n" .. moduleSource:sub(moduleStart, moduleEnd - 1) .. "\nreturn BuildModuleCell end"))
local moduleCellBuilder = moduleLoader()(options, GUI, function(parent)
    local pill = Frame(nil, nil, parent)
    pill:SetSize(26, 14)
    return pill
end)
local moduleCard = options.CreateSettingsCardGroup(dockedContent, -150)
local moduleCells = {}
for i = 1, 6 do
    moduleCells[i] = moduleCellBuilder(moduleCard.frame, { id = "module" .. i, label = "Module " .. i, entry = {} })
    assert(moduleCells[i]._label and moduleCells[i]._widget == moduleCells[i]._pill, "module toggles must participate in shared responsive setting rows")
end
for i = 1, 6, 2 do moduleCard.AddRow(moduleCells[i], moduleCells[i + 1]) end
moduleCard.Finalize()
Flush()
assert(moduleCard.frame._quiColumnCount == 3, "General module toggles must use three columns at docked width")
print("OK: General uses shared three-column module cells")

local dualCard = options.CreateSettingsCardGroup(dockedContent, -200, { maxColumns = 2 })
local dualCells = {}
for i = 1, 6 do
    dualCells[i] = Cell("Toggle " .. i)
    dualCells[i]._widget:SetWidth(26)
    dualCard.AddRow(dualCells[i])
end
dualCard.Finalize()
Flush()
assert(dualCard.frame._quiColumnCount == 2, "two-column flyouts must retain two columns even when three would fit")
assert(dualCells[1]:GetParent() == dualCells[2]:GetParent(), "flyout rows must pair controls in reading order")
assert(dualCells[1]:GetParent() ~= dualCells[3]:GetParent(), "third flyout control must start the next row")
print("OK: explicit dual-column card layout")
