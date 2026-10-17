local harness = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(arg[1] or "modules/skinning/character_pane/character.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function ShowCharacterSidebarPane(", 1, true))
local last = assert(source:find("local function RestoreCharacterPanePopouts()", first, true))
local panel = harness.NewFrame("Frame")
local pane = harness.NewFrame("Frame")
local row = harness.NewFrame("Button", nil, pane)
pane.ScrollBox = harness.NewFrame("Frame", nil, pane)
local text, truncated = "Champion of the Dragonflights", true
row.text = {
    SetWordWrap = function() end, SetMaxLines = function() end,
    IsTruncated = function() return truncated end,
    GetText = function() return text end,
}
local state, tooltip = {}, {}
function tooltip:SetOwner(owner) self.owner = owner end
function tooltip:SetText(value) self.text = value end
function tooltip:Show() self.visible = true end
function tooltip:Hide() self.visible = false end
function tooltip:IsOwned(owner) return self.owner == owner end
local world = setmetatable({
    statsPanel = panel, frameState = state, EMPTY = {}, GameTooltip = tooltip,
    GetSettings = function() return { enabled = true } end,
    GetSkinBase = function() return { HookScrollBoxAcquired = function(_, callback) callback(row) end } end,
    GetState = function(frame) state[frame] = state[frame] or {}; return state[frame] end,
}, { __index = _G })
world._G = world
local loader = assert(loadstring(source:sub(first, last - 1) .. "\nreturn ShowCharacterSidebarPane"))
setfenv(loader, world)
loader()(pane, false)
row:Fire("OnEnter")
assert(tooltip.visible and tooltip.text == text, "clipped titles must expose their full text on hover")
row:Fire("OnLeave")
assert(not tooltip.visible, "leaving a title must hide its tooltip")
text = "Champion of the Frozen Wastes"
row:Fire("OnEnter")
assert(tooltip.text == text, "recycled title rows must show their current title")
row:Fire("OnLeave")
truncated = false
row:Fire("OnEnter")
assert(not tooltip.visible, "short titles must not open redundant tooltips")
print("OK: character_title_tooltip_test")
