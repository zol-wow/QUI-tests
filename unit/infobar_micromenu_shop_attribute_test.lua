local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]unit[/\\]") or "./"

local registered
local buttons = {}
local oldCreateFrame = _G.CreateFrame

_G.CreateFrame = function()
    return { SetAllPoints = function() end }
end

local ns = {
    Addon = {
        Datatexts = {
            Register = function(_, id, definition)
                registered = { id = id, definition = definition }
            end,
        },
    },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    UIKit = {
        CreateIconButton = function(_, opts)
            buttons[opts.tooltip] = opts
            return {
                SetSize = function() end,
                SetPoint = function() end,
                GetWidth = function() return opts.size end,
            }
        end,
    },
}

assert(loadfile(ROOT .. "modules/infobar/micromenu.lua"))("QUI", ns)
assert(registered and registered.id == "micromenu")
registered.definition.OnEnable({
    GetHeight = function() return 24 end,
})

assert(buttons.Character, "Micro Menu buttons must be created")
assert(buttons.Shop == nil, "the custom Shop button must not bypass Blizzard's store protocol")

_G.CreateFrame = oldCreateFrame

print("OK: infobar_micromenu_shop_attribute_test")
