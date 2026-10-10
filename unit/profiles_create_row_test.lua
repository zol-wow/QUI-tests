local path = os.getenv("QUI_PROFILES_SOURCE") or "core/settings/content/profiles_content.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("    local newProfileInput =", 1, true))
local last = assert(source:find("    manageCard.AddRow(", first, true))
local function frame(parent)
    local f = { parent = parent, points = {} }
    function f:SetParent(value) self.parent = value end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    return f
end
local card, added = frame(), nil
local section = { frame = card, AddRow = function(cell) added = cell end }
local input, button
local gui = {
    CreateFormEditBox = function(_, parent) input = frame(parent); return input end,
    CreateButton = function(_, parent) button = frame(parent); return button end,
}
local row = function(parent, label, widget)
    local cell = frame(parent)
    cell.label, cell.widget = label, widget
    widget:SetParent(cell)
    return cell
end
local chunk = assert((loadstring or load)("return function(GUI, manageCard, ns, Shared, CreateFrame)\n" .. source:sub(first, last - 1) .. "\nmanageCard.AddRow(createCell)" .. "\nend"))
chunk()(gui, section, { L = setmetatable({}, { __index = function(_, k) return k end }) }, { BuildSettingRow = row },
    function(_, _, parent) return frame(parent) end)
assert(added and added.label == "New Profile", "profiles must register the create row")
assert(input.parent == added.widget and button.parent == added.widget, "input and Add button must share the row control container")
assert(added.widget.width == 260 and input.points[2][2] == button, "profile input must leave space for its Create button")
print("OK: profiles_create_row_test")
