-- Exercise the actual form constructor and shared row at the width of a
-- docked spell-reminder editor, including its pin and narrow/wide revisits.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local originalLoadfile = loadfile
local override = os.getenv("QUI_FORM_SOURCE")
if override then
    loadfile = function(path, ...)
        return originalLoadfile(path == "QUI_Options/framework.lua" and override or path, ...)
    end
end
assert((loadstring or load)(source:sub(1, cut - 1), "@gen-preamble"))()
loadfile = originalLoadfile
local GUI, ns = QUI.GUI
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local host = CreateFrame("Frame")
host:SetWidth(280)
local db, changes = { value = "10060", _quiTransientOptionsProxy = true }, 0
local widget = GUI:CreateFormEditBox(host, nil, "value", db, function() changes = changes + 1 end)
local pin = CreateFrame("Frame")
pin:SetWidth(16)
widget._quiPinButton = pin
local row = ns.QUI_Options.BuildSettingRow(host, "New Spell ID", widget)
row:Layout(280)
assert(widget:GetWidth() == 162 and row:GetHeight() == 28,
    "edit box must share responsive row sizing instead of unnecessarily stacking in the docked editor")
row:Layout(210)
assert(widget:GetWidth() == 140 and row:GetHeight() > 28, "narrow edit rows must retain readable input width")
row:Layout(400)
assert(widget:GetWidth() == 180 and row:GetHeight() == 28, "wide revisit must restore preferred input width")
assert(db.value == "10060" and changes == 0, "layout must not mutate input values")
print("OK: actual edit-box constructor shares adaptive settings-row sizing")
