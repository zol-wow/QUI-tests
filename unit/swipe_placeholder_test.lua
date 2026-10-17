local path = os.getenv('QUI_SWIPE_SOURCE') or 'QUI_Options/aura_elements_editor.lua'
local file = assert(io.open(path))
local source = file:read('*a')
file:close()
local first = assert(source:find('local function AddSwipeWidgets', 1, true))
local last = assert(source:find('local function AddDispelTooltipWidgets', first, true))
local make = assert(loadstring(source:sub(first, last - 1) .. '\nreturn AddSwipeWidgets'))
local received
local env = {
    ns = { L = setmetatable({}, { __index = function(_, key) return key end }) },
    SWIPE_STYLE_OPTIONS = {},
}
setfenv(make, env)
make()({
    GUI = {
        CreateFormCheckbox = function() return {} end,
        CreateFormDropdown = function(_, _, _, _, key, element, _, _, opts)
            assert(key == 'swipeStyle')
            assert(element.swipeStyle == nil)
            received = opts and opts.placeholder
            return {}
        end,
    },
    AddFormRow = function() end,
}, {})
assert(received == 'Radial', 'unset Swipe Style must describe the runtime radial default')
print('swipe_placeholder_test: passed')
