local path = os.getenv("QUI_BAGS_SOURCE") or "QUI_Bags/bags/settings/bags_providers.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("        local exclAddInput =", 1, true))
local last = assert(source:find("        L.closeSection(s4)", first, true))
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
local chunk = assert((loadstring or load)("return function(GUI, s4, ns, row, CreateFrame)\n" .. source:sub(first, last - 1) .. "\nend"))
chunk()(gui, section, { L = setmetatable({}, { __index = function(_, k) return k end }) }, row,
    function(_, _, parent) return frame(parent) end)
assert(added and added.label == "Add Exclusion by ID", "junk exclusions must register the item ID input row with the settings card")
assert(input.parent == added.widget and button.parent == added.widget, "input and Add button must share the row control container")
assert(added.widget.width == 260 and input.points[2][2] == button, "item ID input must leave space for its Add button")
print("OK: bags_exclusion_row_test")
