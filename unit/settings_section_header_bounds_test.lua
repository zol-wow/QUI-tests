local ns = {}
local frames = {}
local function header(valid, parent)
    local h = { top = valid and 90 or nil, points = {}, _dot = {}, parent = parent }
    h._label = { top = valid and 90 or nil }
    function h._label:GetTop() return self.top end
    function h._label:ClearAllPoints() end
    function h._label:SetPoint(...) self.top = 90; self.point = {...} end
    function h:GetTop() return self.top end
    function h:GetParent() return self.parent end
    function h:ClearAllPoints() self.points = {} end
    function h:SetPoint(...) self.points[#self.points+1] = {...} end
    function h:GetPoint(i) return unpack(self.points[i]) end
    function h:SetWidth(w) self.width = w; self.top = 90 end
    function h:SetScript(_, fn) self.update = fn end
    function h:Hide() self.hidden = true end
    function h:Show() self.hidden = false end
    frames[#frames+1] = h
    return h
end
local valid = false
ns.QUI_Options = { PADDING = 15, CreateAccentDotLabel = function(parent) return header(valid, parent) end }
assert(loadfile(os.getenv("QUI_LAYOUT_SOURCE") or "core/settings_layout_shared.lua"))("QUI", ns)
local content = { top = nil, width = 700, sizeHooks = {} }
function content:GetTop() return self.top end
function content:GetWidth() return self.width end
function content:HookScript(script, callback)
    assert(script == "OnSizeChanged")
    self.sizeHooks[#self.sizeHooks+1] = callback
end
function content:SetWidth(width)
    self.width = width
    for _, callback in ipairs(self.sizeHooks) do callback(self, width) end
end
local layout = ns.QUI_SettingsLayoutShared.MakeLayout(content)
layout.headerAt("Objective Tracker")
local broken = frames[1]
assert(broken.update, "section title must verify its text bounds after native layout")
broken.update(broken)
assert(broken.width == 670 and broken.update, "explicit width must be set while bounds repair waits for parent position")
content.top = 100
broken.update(broken)
assert(broken.width == 670 and broken.update, "bounds repair must allow the first layout frame")
-- Simulate card reflow before repair: the current offset must be preserved.
broken.points[1][5] = -150
broken.update(broken)
assert(broken.width == 670 and broken._label:GetTop() == 90, "unpositioned title must acquire usable bounds")
assert(broken.points[1][5] == -150, "recovery must preserve card reflow offset")
assert(not broken.update and not broken.hidden, "one-time recovery must stop and leave title visible")
content:SetWidth(500)
assert(broken.width == 470, "recovered title must follow a narrower content frame")
content:SetWidth(800)
assert(broken.width == 770, "recovered title must follow a wider content frame")
valid = true
layout.headerAt("Next Section")
local good = frames[2]
good.update(good); good.update(good)
assert(good.width == 770 and #good.points == 1 and not good.update, "valid titles must use one anchor plus an explicit width")
content:SetWidth(700)
assert(good.width == 670, "all titles must follow content width after resize")
local initialHooks = #content.sizeHooks
for _ = 1, 12 do
    local detached = {}
    for _, old in ipairs(frames) do
        old.parent = nil
        detached[old] = old.width
    end
    local rebuilt = ns.QUI_SettingsLayoutShared.MakeLayout(content)
    local current = rebuilt.headerAt("Rebuilt Section")
    assert(#content.sizeHooks == initialHooks,
        "rebuilding section headers must not grow the native parent resize hook chain")
    content:SetWidth(650)
    assert(current.width == 620, "the current rebuilt header must follow its parent's width")
    for old, width in pairs(detached) do
        assert(old.width == width, "parent resize must not update detached section headers")
    end
    content:SetWidth(700)
end
print("OK: settings_section_header_bounds_test")
