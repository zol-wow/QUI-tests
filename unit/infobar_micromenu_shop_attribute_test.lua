local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]unit[/\\]") or "./"

local registered
local buttons = {}
local useCatalogShop = true
local kioskEnabled = false
local closeAllWindowsCalls = 0

local function NewStoreFrame()
    local frame = { attributes = {} }
    function frame:GetAttribute(name) return self.attributes[name] end
    function frame:SetAttribute(name, value) self.attributes[name] = value end
    return frame
end

local catalogShopFrame = NewStoreFrame()
local storeFrame = NewStoreFrame()
local oldCreateFrame = _G.CreateFrame
local oldInCombatLockdown = _G.InCombatLockdown
local oldCatalogShop = _G.C_CatalogShop
local oldCatalogShopFrame = _G.CatalogShopFrame
local oldStoreFrame = _G.StoreFrame
local oldToggleStoreUI = _G.ToggleStoreUI
local oldKiosk = _G.Kiosk
local oldDisallowFrameToggling = _G.DISALLOW_FRAME_TOGGLING
local oldGlue = _G.C_Glue
local oldCloseAllWindows = _G.CloseAllWindows
local oldSecureCall = _G.securecall

_G.CreateFrame = function()
    return { SetAllPoints = function() end }
end
_G.InCombatLockdown = function() return false end
_G.C_CatalogShop = {
    IsShop2Enabled = function() return useCatalogShop end,
}
_G.CatalogShopFrame = catalogShopFrame
_G.StoreFrame = storeFrame
_G.ToggleStoreUI = function()
    error("Shop must not enter the protected EventStoreUISetShown path")
end
_G.Kiosk = { IsEnabled = function() return kioskEnabled end }
_G.DISALLOW_FRAME_TOGGLING = false
_G.C_Glue = { IsOnGlueScreen = function() return false end }
_G.CloseAllWindows = function() error("Shop must close panels through Blizzard's securecall") end
_G.securecall = function(name)
    assert(name == "CloseAllWindows")
    closeAllWindowsCalls = closeAllWindowsCalls + 1
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
local shop = buttons.Shop
if shop then
    assert(shop.combatGuard == true, "Shop must remain disabled during combat lockdown")

    shop.onClick()
    assert(catalogShopFrame.attributes.contextkey == "StoreMicroButton")
    assert(catalogShopFrame.attributes.action == "Show")
    assert(closeAllWindowsCalls == 1)

    catalogShopFrame.attributes.isshown = true
    shop.onClick()
    assert(catalogShopFrame.attributes.action == "Hide")
    assert(closeAllWindowsCalls == 1)

    useCatalogShop = false
    shop.onClick()
    assert(storeFrame.attributes.contextkey == "StoreMicroButton")
    assert(storeFrame.attributes.action == "Show")
    assert(closeAllWindowsCalls == 2)

    storeFrame.attributes = {}
    _G.DISALLOW_FRAME_TOGGLING = true
    shop.onClick()
    assert(storeFrame.attributes.action == nil)
    assert(closeAllWindowsCalls == 2)

    _G.DISALLOW_FRAME_TOGGLING = false
    kioskEnabled = true
    shop.onClick()
    assert(storeFrame.attributes.action == nil)
    assert(closeAllWindowsCalls == 2)
end

_G.CreateFrame = oldCreateFrame
_G.InCombatLockdown = oldInCombatLockdown
_G.C_CatalogShop = oldCatalogShop
_G.CatalogShopFrame = oldCatalogShopFrame
_G.StoreFrame = oldStoreFrame
_G.ToggleStoreUI = oldToggleStoreUI
_G.Kiosk = oldKiosk
_G.DISALLOW_FRAME_TOGGLING = oldDisallowFrameToggling
_G.C_Glue = oldGlue
_G.CloseAllWindows = oldCloseAllWindows
_G.securecall = oldSecureCall

print("OK: infobar_micromenu_shop_attribute_test")
