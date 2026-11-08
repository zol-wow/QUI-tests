-- Actual search renderer: wrapped descriptions must reserve their full height
-- on first render, pooled reuse, and resize without rebuilding controls.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, cut - 1)))()
local GUI = QUI.GUI
GUI.GetSearchBreadcrumb, GUI.ResolveSearchNavigation = nil, nil
local content = CreateFrame("Frame")
content:SetWidth(600)
local hooks, pending = {}, {}
content.HookScript = function(_, event, callback) hooks[event] = callback end
C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
local createText = content.CreateFontString
content.CreateFontString = function(self, ...)
    local fs = createText(self, ...)
    fs.GetStringHeight = function(self)
        -- Model native strings retaining a previous explicit clipping height.
        if self:GetHeight() > 0 then return self:GetHeight() end
        return math.ceil(#(self:GetText() or "") * 6 / math.max(1, self:GetWidth())) * 12
    end
    return fs
end
local widgets, builds = {}, 0
local function Entry(label, description)
    return {label = label, tabName = "Quality of Life", subTabName = "Bonus Roll",
        description = description, widgetBuilder = function(parent)
            builds = builds + 1
            local widget = CreateFrame("Frame", nil, parent)
            widget:SetHeight(32); widgets[label] = widget
            return widget
        end}
end
local description = string.rep("A long description must remain fully visible. ", 6)
local results = {{data = Entry("Enable Bonus Roll Filtering", description)},
    {data = Entry("Following control", "Short description.")}}
local function Check()
    local desc
    for _, fs in ipairs(content._searchRenderCache.fs) do
        if fs:GetText() == description and fs:IsShown() then desc = fs end
    end
    assert(desc and desc:GetWidth() == content:GetWidth() - 38)
    local expected = math.ceil(#description * 6 / desc:GetWidth()) * 12 + 1
    assert(desc:GetHeight() == expected, "wrapped text must be remeasured after resetting pooled height")
    local _, _, descY = desc:GetPoint(1)
    local _, _, nextY = widgets["Following control"]:GetPoint(1)
    assert(nextY <= descY - expected - 14 - 6, "following breadcrumb and control must clear every description line")
end
GUI:RenderSearchResults(content, results, "bonus roll", {})
Check()
GUI:RenderSearchResults(content, results, "bonus roll", {})
Check()
for _, width in ipairs({400, 850, 400, 600}) do
    content:SetWidth(width)
    hooks.OnSizeChanged()
    while #pending > 0 do table.remove(pending, 1)() end
    Check()
end
assert(builds == 2, "responsive search must preserve cached controls")
print("OK: search descriptions preserve content and spacing across reuse and resize")
