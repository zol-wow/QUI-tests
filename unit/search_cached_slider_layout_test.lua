-- Reopening a cached search result must refresh its slider after restoring
-- anchors. WoW can coalesce the temporary width change while those anchors
-- are cleared, so OnSizeChanged alone does not repair the custom thumb.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert((loadstring or load)(source:sub(1, cut - 1), "@gen-preamble"))()

local GUI = assert(QUI.GUI)
local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, ...)
    local frame = createFrame(kind, name, parent, ...)
    if kind == "Slider" then
        frame.GetThumbTexture = function() return createFrame("Texture", nil, frame) end
    end
    return frame
end

-- Routing is independently covered; exercise the actual search renderer,
-- actual slider constructor, and their shared widget cache here.
GUI.GetSearchBreadcrumb = nil
GUI.ResolveSearchNavigation = nil
local content = CreateFrame("Frame")
content:SetWidth(600)
local db = { width = 210 }
local changes, builds = 0, 0
local widget, anchored, thumbX
local entry = {
    label = "Width", tabName = "Nameplates", subTabName = "Frame",
    contextLabel = "Enemy NPCs", widgetType = "slider",
    widgetBuilder = function(parent)
        builds = builds + 1
        widget = GUI:CreateFormSlider(parent, "Width", 60, 300, 1, "width", db,
            function() changes = changes + 1 end)
        widget.Refresh = false -- native Frames have no generated-stub fallback
        -- Model native geometry when cached anchors are temporarily cleared.
        -- Deliberately omit intermediate OnSizeChanged events: the final
        -- resolved width is unchanged on a repeated query.
        local setPoint, clearPoints = widget.SetPoint, widget.ClearAllPoints
        widget.ClearAllPoints = function(self)
            anchored = false
            return clearPoints(self)
        end
        widget.SetPoint = function(self, point, ...)
            if point == "RIGHT" then anchored = true end
            return setPoint(self, point, ...)
        end
        widget.slider.GetWidth = function() return anchored and 350 or 120 end
        widget.thumbFrame.SetPoint = function(_, _, _, _, x) thumbX = x end
        return widget
    end,
}
local results = {{ data = entry }}
GUI:RenderSearchResults(content, results, "Enemy NPCs Width")
widget.UpdateVisual(widget.GetValue()) -- first native layout settles
assert(thumbX == 218.75, "initial 210/60..300 thumb position")
for _ = 1, 3 do
    GUI:RenderSearchResults(content, results, "Enemy NPCs Width")
    assert(thumbX == 218.75,
        "cached search slider refreshed before final anchors: " .. tostring(thumbX))
end
assert(builds == 1, "repeated search must reuse its existing control")
assert(db.width == 210 and changes == 0, "layout must not change settings or notify providers")
print("OK: cached search slider keeps its value, thumb position and identity")
