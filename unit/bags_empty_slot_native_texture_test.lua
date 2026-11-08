local function noop() end

local function texture()
    return {
        shown = true,
        SetShown = function(self, shown) self.shown = shown end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetAtlas = function(self, atlas) self.atlas = atlas; self.texture = nil end,
        SetTexture = function(self, value) self.texture = value; self.atlas = nil end,
        SetAllPoints = noop,
        SetColorTexture = noop,
        SetTexCoord = noop,
        SetVertexColor = noop,
        SetDesaturated = noop,
    }
end

InCombatLockdown = function() return false end
CooldownFrame_Set = noop
C_Container = {
    GetContainerItemCooldown = function() return 0, 0, 0 end,
    GetContainerItemInfo = function() return { isLocked = false } end,
}

local ns = {
    UIKit = { CreateBorderLines = noop, UpdateBorderLines = noop },
    Helpers = {
        CreateDBGetter = function() return function() return { behavior = {} } end end,
        ApplyIconStyle = noop,
        GetWindowColors = function() return 1, 1, 1, 1 end,
    },
}
assert(loadfile("QUI_Bags/bags/views/item_buttons.lua"))("QUI", ns)
local ItemButtons = ns.Bags.ItemButtons

for _, client in ipairs({
    { "PTR", "tests/framexml/Interface/AddOns/" },
    { "Forever", "tests/clients/forever/framexml/Interface/AddOns/" },
}) do
    local label, root = client[1], client[2]
    assert(loadfile(root .. "Blizzard_ItemButton/Shared/ItemButtonTemplate.lua"))()
    assert(loadfile(root .. "Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua"))()
    local path = root .. "Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua"
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function ContainerFrameItemButtonMixin:ShouldUseBagIconForEmptySlot()", 1, true))
    local last = assert(source:find("function ContainerFrameItemButtonMixin:SetReadable(readable)", first, true))
    ContainerFrameItemButtonMixin = {}
    assert(loadstring(source:sub(first, last - 1), "@" .. path))()
    if label == "Forever" then
        assert(loadfile(root .. "Blizzard_UIPanels_Game/Camelot/ContainerFrame.lua"))()
    end

    CreateFrame = function(_, _, _, template)
        assert(template == "ContainerFrameItemButtonTemplate")
        local button = {
            icon = texture(), Count = texture(), Cooldown = texture(), EmptyBagIcon = texture(),
            SetBagID = function(self, bagID) self.bagID = bagID end,
            GetBagID = function(self) return self.bagID end,
            GetID = function() return 1 end,
            IsCombined = function() return false end,
            HookScript = noop, ClearNormalTexture = noop,
            CreateTexture = texture,
        }
        for key, value in pairs(_G.ItemButtonMixin) do button[key] = value end
        for key, value in pairs(ContainerFrameItemButtonMixin) do button[key] = value end
        button.SetAlpha = noop
        button.UpdateItemContextMatching = noop
        return button
    end

    local nativeButton = CreateFrame(nil, nil, nil, "ContainerFrameItemButtonTemplate")
    nativeButton:SetHasItem(false)
    nativeButton:SyncAppearanceWithHasItem()
    assert(nativeButton.icon.shown and nativeButton.icon.atlas == "bags-item-slot64",
        label .. " native control must display Blizzard's empty-slot atlas")

    for _, bagID in ipairs({ 0, 6, 12 }) do
        local button = ItemButtons.CreateLive({}, bagID)
        ItemButtons.Dress(button, { icon = 123 }, true)
        assert(button.icon.shown and button.icon.texture == 123,
            label .. " occupied slot must display its item icon")

        ItemButtons.Dress(button, nil, true)
        assert(not button.icon.shown and button.icon.atlas == nil,
            label .. " empty QUI slot must not display Blizzard's background atlas")
        assert(button._quiSlotBg.shown, label .. " empty slot must retain QUI's background")

        button:SetHasItem(false)
        button:SyncAppearanceWithHasItem()
        assert(not button.icon.shown and button.icon.atlas == nil,
            label .. " native appearance refresh must keep QUI's empty icon hidden")

        button:SetHasItem(true)
        ItemButtons.Dress(button, { icon = 456 }, true)
        button:SyncAppearanceWithHasItem()
        assert(button.icon.shown and button.icon.texture == 456,
            label .. " reused slot must retain its new item icon after native refresh")
    end

    nativeButton:SyncAppearanceWithHasItem()
    assert(nativeButton.icon.shown and nativeButton.icon.atlas == "bags-item-slot64",
        label .. " QUI must not change native Blizzard slot backgrounds")
    print("PASS " .. label .. " live bag and bank slot textures")
end
