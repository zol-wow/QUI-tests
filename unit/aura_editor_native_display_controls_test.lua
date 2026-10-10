local file = assert(io.open("QUI_Options/aura_elements_editor.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function AddDispelTooltipWidgets", 1, true))
local last = assert(source:find("local function AddSpellMapEditor", first, true))
local controls = {}
local function noop() end
local function control(key, db, callback, options)
    local widget = { key = key, db = db, callback = callback, options = options }
    controls[key] = widget
    return widget
end
local gui = {
    CreateFormCheckbox = function(_, _, _, key, db, callback) return control(key, db, callback) end,
    CreateFormDropdown = function(_, _, _, options, key, db, callback) return control(key, db, callback, options) end,
    CreateFormSlider = function(_, _, _, _, _, _, key, db, callback) return control(key, db, callback) end,
    CreateFormColorPicker = function(_, _, _, key, db, callback) return control(key, db, callback) end,
    CreateLabel = function() return { SetJustifyH = noop } end,
}
local env = setmetatable({
    ns = { L = setmetatable({}, { __index = function(_, key) return key end }) },
    GetOptionsAPI = noop,
    NINE_POINT_OPTIONS = {},
    DISPEL_BORDER_MODE_OPTIONS = {},
}, { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1)
    .. "\nreturn AddDispelTooltipWidgets, AddTextRegionWidgets"))
setfenv(chunk, env)
local glowWidgets, textWidgets = chunk()
local notified, rebuilt = 0, 0
local ctx = {
    GUI = gui, C = {}, caps = {}, detailArea = {},
    AddFormRow = noop, AddDetailWidget = noop, onChange = noop,
    NotifyChanged = function() notified = notified + 1 end,
    rebuild = function() rebuilt = rebuilt + 1 end,
}
local function choose(key, value)
    local widget = assert(controls[key], key)
    widget.db[widget.key] = value
    widget.callback(value)
end
local element = {}
assert(env.CustomAuraButtonSharedMixin == nil)
textWidgets(ctx, element, "casterName", "Caster Name")
assert(controls._casterName and element.casterName == nil, "caster control must work without secure-environment globals")
choose("_casterName", true)
assert(element.casterName.useClassColors and not element.casterName.showRealmName)
assert(element.casterName.fontSize == 10 and element.casterName.anchor == "BOTTOM"
    and element.casterName.offsetX == 0 and element.casterName.offsetY == 1)
assert(notified == 1 and rebuilt == 1)
textWidgets(ctx, element, "casterName", "Caster Name")
assert(controls.show == nil, "caster names have one enable control")
choose("showRealmName", true)
choose("fontSize", 12)
assert(element.casterName.showRealmName and element.casterName.fontSize == 12)
controls = {}
textWidgets(ctx, element, "casterName", "Caster Name")
assert(element.casterName.showRealmName and controls._casterName, "saved names remain editable on older clients")
choose("_casterName", false)
assert(element.casterName == nil)
element.pandemicGlow = { color = { 1, 1, 1, 1 } }
controls = {}
glowWidgets(ctx, element)
assert(element.pandemicGlow.style == nil, "rendering leaves legacy steady glow unchanged")
assert(#controls.style.options == 3 and controls.style.db.style == "steady")
choose("style", "pulse")
assert(element.pandemicGlow.style == "pulse")
choose("style", "flash")
assert(element.pandemicGlow.style == "flash")
controls = {}
glowWidgets(ctx, element)
assert(#controls.style.options == 3 and controls.style.db.style == "flash",
    "saved styles remain editable without secure-environment globals")
choose("style", "steady")
assert(element.pandemicGlow.style == "steady")
print("PASS: native aura display controls, defaults, and older-client settings")
