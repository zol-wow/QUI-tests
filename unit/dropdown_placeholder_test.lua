local path = os.getenv("QUI_DROPDOWN_SOURCE") or "QUI_Options/framework.lua"
local f = assert(io.open(path)); local source = f:read("*a"); f:close()
local first = assert(source:find("    local function UpdateVisual(val)", assert(source:find("function GUI:CreateFormDropdown(", 1, true)), true))
local last = assert(source:find("    local function SetValue(val, skipOnChange)", first, true))
local selected = { text = "Old" }
function selected:SetText(text) self.text = text end
local build = assert((loadstring or load)("return function(dropdown, container, opts)\n" .. source:sub(first,last-1) .. "\nreturn UpdateVisual end"))()
local update = build({selected = selected}, {options = {{value = "Quazii", text = "Quazii"}}}, {placeholder = "Global Font"})
update("Quazii"); assert(selected.text == "Quazii")
update(nil); assert(selected.text == "Global Font", "inherited fonts must clear stale text and show the inherited choice")
update(""); assert(selected.text == "Global Font")
update("Removed Font"); assert(selected.text == "Removed Font", "unavailable selected values must remain identifiable")
print("OK: dropdown_placeholder_test")
local startOptions=assert(source:find('    local function SetOptions(newOptions)',first,true))
local endOptions=assert(source:find('    container.GetValue = GetValue',startOptions,true))
local optionsBuild=assert((loadstring or load)('return function(dropdown, container, opts, GetValue)\n' .. source:sub(startOptions,endOptions-1) .. '\nreturn SetOptions end'))()
local setOptions=optionsBuild({selected=selected},{},{placeholder='Global Font'},function() return nil end)
setOptions({{value='Quazii',text='Quazii'}})
assert(selected.text=='Global Font','refreshing font choices must retain the inheritance label')
print('OK: dropdown placeholder option refresh')

local dropdownStart = assert(source:find("function GUI:CreateFormDropdown(", 1, true))
local sizingStart = assert(source:find("    local text\n", dropdownStart, true))
local sizingEnd = assert(source:find("    if opts.compact then", sizingStart, true))
local sizing = assert((loadstring or load)("return function(container, label, FORM_ROW_HEIGHT)\n"
    .. source:sub(sizingStart, sizingEnd - 1) .. "\nend"))()
local control = {}
function control:SetSize(width, height) self.width, self.height = width, height end
sizing(control, nil, 28)
assert(control._quiPreferredControlWidth == 180 and control._quiMinimumControlWidth == 140,
    "dropdowns must expose adaptive widths to shared setting rows")
print("OK: dropdown adaptive sizing")
