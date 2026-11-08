local function noop() end

local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local function method(source, mixin, name)
    return (assert(source:match("(function " .. mixin .. ":" .. name .. "%b().-\nend)"), name))
end

local function texture()
    return {
        SetShown = function(self, shown) self.shown = not not shown end,
        Hide = function(self) self.shown = false end,
        SetAtlas = function(self, atlas) self.atlas, self.texture = atlas, nil end,
        SetTexture = function(self, value) self.texture, self.atlas = value, nil end,
        SetTexCoord = noop,
        SetVertexColor = noop,
        SetAllPoints = noop,
        SetColorTexture = noop,
    }
end

local failures = 0
local function check(label, ok)
    if not ok then failures = failures + 1 end
    print((ok and "  ok  " or "FAIL  ") .. label)
end

_G.InCombatLockdown = function() return false end
_G.GetItemButtonIconTexture = function(button) return button.icon end
_G.SetItemButtonCount = noop
_G.SetItemButtonDesaturated = noop
_G.SetItemButtonOverlay = noop
_G.ClearItemButtonOverlay = noop
_G.CooldownFrame_Set = noop
_G.C_Container = {
    GetContainerItemCooldown = function() return 0, 0, 0 end,
    GetContainerItemInfo = function() return { isLocked = false } end,
}

for _, client in ipairs({
    { name = "Retail", root = "tests/framexml", bags = { 0, 6, 12 } },
    { name = "Forever", root = "tests/clients/forever/framexml", bags = { 0, -1, 6, 12 } },
}) do
    _G.ItemButtonMixin = {}
    _G.ContainerFrameItemButtonMixin = {}
    local root = client.root .. "/Interface/AddOns/"
    local source = read(root .. "Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua")
    local first = assert(source:find("local function GetItemButtonBackgroundTexture_Base", 1, true))
    local last = assert(source:find("local function SetItemButtonTextureVertexColor_Base", first, true))
    assert(loadstring(table.concat({
        "local backgroundTextureIsAtlas = true",
        source:sub(first, last - 1),
        method(source, "ItemButtonMixin", "SetItemButtonTexture"),
        method(source, "ItemButtonMixin", "GetItemButtonBackgroundTexture"),
    }, "\n")))()

    source = read(root .. "Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua")
    local methods = { "SetHasItem", "HasItem" }
    if client.name == "Forever" then
        for _, name in ipairs({ "GetItemButtonBackgroundTexture", "IsCombined",
            "SetAppearanceToEmptyBagSlot", "SyncAppearanceWithHasItem" }) do
            methods[#methods + 1] = name
        end
    end
    for _, name in ipairs(methods) do
        assert(loadstring("local backgroundTextureIsAtlas = true\n"
            .. method(source, "ContainerFrameItemButtonMixin", name)))()
    end
    if client.name == "Forever" then
        source = read(root .. "Blizzard_UIPanels_Game/Camelot/ContainerFrame.lua")
        assert(loadstring(method(source, "ContainerFrameItemButtonMixin", "ShouldUseBagIconForEmptySlot")))()
    end

    _G.CreateFrame = function(_, _, _, template)
        assert(template == "ContainerFrameItemButtonTemplate")
        local button = {
            icon = texture(), Cooldown = texture(), EmptyBagIcon = texture(),
            emptyBackgroundAtlas = client.name == "Retail" and "bags-item-slot64" or nil,
            SetBagID = function(self, bagID) self.bagID = bagID end,
            GetBagID = function(self) return self.bagID end,
            GetID = function() return 1 end,
            CreateTexture = texture,
            HookScript = noop,
            SetAlpha = noop,
            ClearNormalTexture = noop,
        }
        for name, fn in pairs(_G.ItemButtonMixin) do button[name] = fn end
        for name, fn in pairs(ContainerFrameItemButtonMixin) do button[name] = fn end
        return button
    end
    local settings = { behavior = {} }
    local ns = {
        UIKit = { CreateBorderLines = noop, UpdateBorderLines = noop },
        Helpers = {
            CreateDBGetter = function() return function() return settings end end,
            ApplyIconStyle = noop,
            GetWindowColors = function() return 1, 1, 1, 1 end,
        },
    }
    assert(loadfile("QUI_Bags/bags/views/item_buttons.lua"))("QUI", ns)
    local buttons = ns.Bags.ItemButtons

    for _, bagID in ipairs(client.bags) do
        local label = client.name .. " bag " .. bagID
        local button = buttons.CreateLive({}, bagID)
        button:SetHasItem(true)
        buttons.Dress(button, { icon = 123 }, true)
        check(label .. " displays occupied item", button.icon.shown and button.icon.texture == 123)

        button:SetHasItem(false)
        buttons.Dress(button, nil, true)
        check(label .. " hides empty slot artwork", button.icon.shown == false and button.icon.atlas == nil)
        if button.SyncAppearanceWithHasItem then
            button:SyncAppearanceWithHasItem()
            check(label .. " stays empty after native appearance refresh",
                button.icon.shown == false and button.icon.atlas == nil and button.EmptyBagIcon.shown == false)
        end

        button:SetHasItem(true)
        buttons.Dress(button, { icon = 456 }, true)
        if button.SyncAppearanceWithHasItem then button:SyncAppearanceWithHasItem() end
        check(label .. " restores a replacement item", button.icon.shown and button.icon.texture == 456)
    end

    local native = CreateFrame("ItemButton", nil, {}, "ContainerFrameItemButtonTemplate")
    native:SetHasItem(false)
    SetItemButtonTexture(native, nil)
    if native.SyncAppearanceWithHasItem then native:SyncAppearanceWithHasItem() end
    check(client.name .. " untouched Blizzard button retains default artwork",
        native.icon.shown and native.icon.atlas == "bags-item-slot64")
end

assert(failures == 0, ("FAILED %d check(s)"):format(failures))
print("PASS bags_empty_slot_native_art_test")
