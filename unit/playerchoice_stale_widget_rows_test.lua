-- luacheck: globals PlayerChoice_WidgetsLayout DefaultWidgetLayout
-- Replays the native PlayerChoice widget layout with recycled horizontal rows.
-- Bottom-only layouts skip the native pool clear, leaving old rows in extents.
local function read(path)
    local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local native = read("tests/framexml/Interface/AddOns/Blizzard_PlayerChoice/Blizzard_PlayerChoiceOptionBase.lua")
local chunk = assert(native:match("(local function IsTopWidget.-)\nfunction PlayerChoiceBaseOptionTemplateMixin:WidgetsLayout"))
Enum = { UIWidgetVisualizationType = { SpellDisplay = 1 } }
local layouts, releases = 0, 0
-- The native DefaultWidgetLayout's bottom-only path retains the row pool.
function DefaultWidgetLayout(c, widgets, _, skipClear)
    if not skipClear then c.horizontalRowContainerPool:ReleaseAll() end
    for _, w in ipairs(widgets) do w.parent = c end -- vertical widget
end
assert(loadstring(chunk))()
local event, hookCount = nil, 0
function CreateFrame()
    event = { RegisterEvent = function() end, UnregisterEvent = function() end,
        SetScript = function(self, _, fn) self.callback = fn end }
    return event
end
function hooksecurefunc(name, callback)
    hookCount = hookCount + 1
    local original = _G[name]
    _G[name] = function(...) original(...); callback(...) end
end
local function fixture()
    local c = { height = 800 }
    local w = { widgetType = 2, parent = c, GetParent = function(self) return self.parent end }
    local row = { childWidgets = { w }, height = 800 }
    local active = { [row] = true }
    local pool = {}
    function pool:EnumerateActive() return pairs(active) end
    function pool:Release(r)
        -- Native reset reparents everything in childWidgets; stale references
        -- must be removed first or a widget already in another row gets stolen.
        for _, child in ipairs(r.childWidgets) do child.parent = c end
        active[r] = nil; releases = releases + 1
    end
    function pool:ReleaseAll()
        local rows = {}; for r in pairs(active) do rows[#rows + 1] = r end
        for _, r in ipairs(rows) do self:Release(r) end
    end
    c.horizontalRowContainerPool = pool
    function c:Layout()
        layouts = layouts + 1; self.height = 15
        for r in pairs(active) do self.height = math.max(self.height, r.height) end
    end
    return c, w, row, active
end
local c, w = fixture()
PlayerChoice_WidgetsLayout(c, { w }, false)
assert(c.height == 800, "native fixture must reproduce stale-row inflation")
local file = io.open("modules/qol/playerchoice_layout.lua", "rb")
if file then file:close(); assert(loadfile("modules/qol/playerchoice_layout.lua"))() end
assert(hookCount == 1, "player-choice layout repair must install when already loaded")
for i = 1, 20 do
    c, w = fixture()
    PlayerChoice_WidgetsLayout(c, { w }, false)
    assert(c.height == 15, "bottom-only reopen must discard stale row extents")
    assert(w.parent == c, "native widget parent must remain intact")
end
-- Retain an actual current row and do not reparent its live widget when
-- releasing another row that still lists the same pooled widget.
local liveRow
c, w, _, liveRow = fixture()
liveRow = { childWidgets = { w }, height = 20 }
local oldLayout = DefaultWidgetLayout
DefaultWidgetLayout = function(container, widgets, _, skipClear)
    if not skipClear then container.horizontalRowContainerPool:ReleaseAll() end
    w.parent = liveRow
end
local pool = c.horizontalRowContainerPool
local originalEnumerate = pool.EnumerateActive
function pool:EnumerateActive()
    local active = {}; for r in originalEnumerate(self) do active[r] = true end
    active[liveRow] = true
    return pairs(active)
end
PlayerChoice_WidgetsLayout(c, { w }, false)
assert(w.parent == liveRow, "stale row cleanup must not steal a live widget")
assert(#liveRow.childWidgets == 1, "keep the native active horizontal row")
DefaultWidgetLayout = oldLayout
-- No stale rows: no extra Layout pass, preserving native filler allocation.
local before = layouts
c, w = fixture()
c.horizontalRowContainerPool:ReleaseAll()
PlayerChoice_WidgetsLayout(c, {}, true)
assert(layouts == before + 1, "healthy layout needs only its native pass")
-- Addon loaded later: install exactly once and ignore unrelated addon events.
local nativeLayout = PlayerChoice_WidgetsLayout
PlayerChoice_WidgetsLayout = nil
assert(loadfile("modules/qol/playerchoice_layout.lua"))()
local lateEvent = event
PlayerChoice_WidgetsLayout = nativeLayout
lateEvent.callback(lateEvent, "ADDON_LOADED", "OtherAddon")
assert(hookCount == 1)
lateEvent.callback(lateEvent, "ADDON_LOADED", "Blizzard_PlayerChoice")
lateEvent.callback(lateEvent, "ADDON_LOADED", "Blizzard_PlayerChoice")
assert(hookCount == 2, "late load should install once")
assert(releases >= 21)
print("OK: playerchoice_stale_widget_rows_test")
