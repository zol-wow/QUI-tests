local file = assert(io.open("QUI_Options/aura_elements_editor.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function RenderDetail", 1, true))
local last = assert(source:find("local function RelayoutList", first, true))
local function noop() end
local function Frame()
    local f = { points = {}, width = 0, height = 0 }
    function f:SetPoint(...) self.points[#self.points + 1] = {...}; self.unresolved = false end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints() self.points = {} end
    function f:SetWidth(w) self.width = w end
    function f:GetWidth() return self.width end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return self.height end
    function f:SetScript(event, fn) self[event] = fn end
    function f:SetParent(parent) self.parent = parent end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetTop()
        -- Retail reproduction: opposing anchors on a newly reused row may
        -- never resolve; one anchor with an explicit width resolves normally.
        if self.unresolved or #self.points ~= 1 or self.width <= 0 then return nil end
        return 700 + self.points[1][5]
    end
    return f
end
local rows, disclosure = {}, {}
local options = { BuildSettingRow = function(_, label, widget)
    local cell = Frame(); cell.label = label; cell.widget = widget
    function cell:Layout(width) self.layoutWidth = width; return 28 end
    return cell
end }
local ns = { L = setmetatable({}, {__index = function(_, k) return k end}) }
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
local env = setmetatable({
    ns = ns,
    CreateFrame = Frame, GetOptionsAPI = function() return options end,
    sectionState = function() return disclosure end,
    AddFilterStripConfig = noop, PAD = 10, COL_GAP = 10, FORM_ROW = 32,
}, {__index = _G})
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn RenderDetail"))
setfenv(chunk, env)
local render = chunk()
local ctx = { detailArea = Frame(), caps = {}, _detailRowPool = {},
    NotifyChanged = noop, rebuild = noop,
    GUI = { CreateFormCheckbox = function() return Frame() end },
    RegisterDetailWidget = function(row) rows[#rows + 1] = row end,
}
ctx.ClearDetailWidgets = function()
    for _, row in ipairs(rows) do
        row:Hide(); row:ClearAllPoints()
        ctx._detailRowPool[#ctx._detailRowPool + 1] = row
    end
    rows = {}
end
local element = { id = "debuffs", mode = "filterStrip" }
for _, width in ipairs({585, 0, 800, 480, 685, 585}) do
    ctx.detailArea.width = width
    render(ctx, element)
    local row = assert(rows[1])
    -- Retail can leave the first row unresolved even with a valid origin and
    -- width until that origin is reapplied after its host has native bounds.
    row.unresolved = true
    ctx.detailArea.points = {{"TOPLEFT", nil, "TOPLEFT", 0, 0}}
    if width == 0 then ctx.detailArea.width = 585 end
    assert(row.OnUpdate, "shared deferred bounds verification must be installed")
    row.OnUpdate(row); row.OnUpdate(row)
    assert(row:GetTop(), "first-open Element Enabled row must recover native bounds")
    assert(not row.OnUpdate, "initial repair must stop after layout settles")
    assert(row._quiLeft.label == "Element Enabled")
    if width == 0 then
        ctx.detailArea.width = 585
        ctx.detailArea.OnSizeChanged(ctx.detailArea, 585)
    end
    assert(row.width == ctx.detailArea.width, "row must use settled host width")
    assert(row._quiLeft.layoutWidth == row.width - 20, "full-width toggle remains readable")
    assert(#row.points == 1 and row.points[1][5] == -2,
        "reuse and resize preserve the row origin without opposing anchors")
end
print("OK: aura_editor_row_bounds_test")
