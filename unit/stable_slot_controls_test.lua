local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinStable = true
ns.Client = { isForever = true }
local root = env.NewFrame("Frame")
root.CloseButton = false
_G.PetStableFrame = root
local records = { [1] = { icon = 123, name = "Wolf", level = 20, familyName = "Wolf" } }
local unlocked, pickups, clears, events = 0, {}, 0, {}
_G.C_StableInfo = {
    GetStablePetInfo = function(id) return records[id] end,
    GetNumStableSlots = function() return unlocked end,
    PickupStablePet = function(id) pickups[#pickups + 1] = id end,
}
_G.EventRegistry = { TriggerEvent = function(_, ...) events[#events + 1] = {...} end }
_G.format = string.format
_G.UNIT_LEVEL_TEMPLATE = "Level %d"
_G.EMPTY_STABLE_SLOT = "Empty"
local cursorType, cursorID
_G.GetCursorInfo = function() return cursorType, cursorID end
_G.ClearCursor = function() clears = clears + 1 end
_G.GameTooltip = { SetOwner = function(self, owner) self.owner = owner end,
    SetText = function(self, text) self.text = text end, AddLine = function(self, text) self.subtext = text end,
    Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
_G.SetItemButtonTexture = function(slot, texture) _G[slot:GetName() .. "IconTexture"]:SetTexture(texture) end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_StableUI/Camelot/Blizzard_StableUI.lua"))()
local names = { "PetStableCurrentPet", "PetStableStabledPet1", "PetStableStabledPet2" }
local slots, masks = {}, 0
for id, name in ipairs(names) do
    local b = env.NewFrame("CheckButton", name, root)
    b:SetID(id); b:SetSize(37, 37)
    for _, key in ipairs({ "lockedBackground", "unlockedBackground", "currentBackground", "lockIcon", "genericPetIcon", "currentGlow" }) do
        b[key] = b:CreateTexture()
        b[key]:Hide()
    end
    b.highlightTexture = b:CreateTexture()
    b.checkedTexture = b:CreateTexture()
    b.pushedTexture = b:CreateTexture()
    b.checkedTexture:SetShown(id == 1)
    b.highlightTexture:Hide(); b.pushedTexture:Hide()
    function b:GetCheckedTexture() return self.checkedTexture end
    function b:GetPushedTexture() return self.pushedTexture end
    local icon = b:CreateTexture()
    icon:SetSize(37, 37); icon:SetTexCoord(0, 1, 0, 1)
    _G[name .. "IconTexture"] = icon
    function b:CreateMaskTexture() masks = masks + 1; return env.NewTexture(self, "MaskTexture") end
    for _, t in ipairs({icon, b.highlightTexture, b.checkedTexture, b.pushedTexture}) do
        function t:AddMaskTexture(mask) self.mask = mask end
    end
    for key, value in pairs(_G.PetStableSlotMixin) do b[key] = value end
    for _, script in ipairs({"OnClick", "OnDragStart", "OnReceiveDrag", "OnEnter", "OnLeave"}) do
        b:SetScript(script, b[script])
    end
    _G[name] = b; slots[id] = b
    b:OnLoad(); b:Update()
end
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
local click = slots[1]:GetScript("OnClick")
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callbacks.Blizzard_StableUI()
local function border(id) return skin.GetFrameData(_G[names[id] .. "IconTexture"], "iconBorder") end
assert(border(1) and border(1)._quiRoundedSurface, "Stable slots must receive shared rounded borders")
assert(border(1)._quiBorderR == env.colors[1] and border(2)._quiBorderR == env.colors[1]
    and border(2)._quiBorderG == env.colors[2], "stable borders must use the shared neutral theme")
assert(_G.PetStableCurrentPetIconTexture.texture == 123 and _G.PetStableCurrentPetIconTexture.texCoord[1] == 0,
    "pet artwork and native UVs must remain")
for id, b in ipairs(slots) do
    local current = id == 1
    assert(b.lockedBackground:IsShown() == not current and b.lockIcon:IsShown() == not current
        and not b.unlockedBackground:IsShown() and b.currentBackground:IsShown() == current
        and b.genericPetIcon:IsShown() == current and b.currentGlow:IsShown() == current,
        "native locked and current slot indicators must survive styling")
    assert(b:GetNormalTexture() == nil and b:GetWidth() == 37,
        "current native slot structure and geometry must remain")
    assert(b.checkedTexture.mask and b.highlightTexture.mask and b.pushedTexture.mask,
        "checked, hover and pressed surfaces must retain rounded native state textures")
end
assert(masks == 12, "each native icon/state must receive one cached mask")
assert(slots[1].checkedTexture:IsShown() and not slots[2].checkedTexture:IsShown()
    and not slots[1].highlightTexture:IsShown() and not slots[1].pushedTexture:IsShown(),
    "styling must retain native state texture visibility")
slots[1]:Fire("OnClick"); slots[1]:Fire("OnDragStart")
cursorType, cursorID = "pet", 1
slots[2]:Fire("OnReceiveDrag"); slots[3]:Fire("OnClick")
assert(events[1][1] == "StableFrameMixin.PetSelected" and events[1][2] == 1
    and events[2][1] == "StableFrameMixin.PetSwapRequested" and events[2][3] == 2
    and events[3][3] == 3 and clears == 2 and pickups[1] == 1,
    "native selection, pickup and drop must retain event/slot ownership")
slots[1]:Fire("OnEnter"); assert(_G.GameTooltip.text == "Wolf" and _G.GameTooltip.shown)
slots[1]:Fire("OnLeave"); assert(not _G.GameTooltip.shown)
unlocked = 2; records[1] = nil
for _, b in ipairs(slots) do b:Update() end
assert(border(2)._quiBorderG == env.colors[2] and border(3)._quiBorderG == env.colors[2]
    and _G.PetStableCurrentPetIconTexture.texture == 0 and slots[1].tooltip == "Empty",
    "native update must reset unlocked/empty presentation")
for id, b in ipairs(slots) do
    assert(not b.lockedBackground:IsShown() and not b.lockIcon:IsShown()
        and b.unlockedBackground:IsShown() == (id ~= 1) and b.currentBackground:IsShown() == (id == 1)
        and b.genericPetIcon:IsShown() and b.currentGlow:IsShown() == (id == 1),
        "native updates must retain unlocked and current slot indicators")
end
local oldBorder = border(1)
registry.skinStable.refresh()
assert(border(1) == oldBorder and masks == 12 and slots[1]:GetScript("OnClick") == click,
    "theme/update must retain masks and native handlers")
env.profile.general.skinStable = false; unlocked = 0
slots[2]:Update()
assert(border(2)._quiBorderG == env.colors[2] and slots[2].lockIcon:IsShown()
    and slots[2].lockedBackground:IsShown() and not slots[2].unlockedBackground:IsShown(),
    "disabled skin must retain native lock updates without changing the border")
env.profile.general.skinStable = true
slots[2].IsForbidden = function() return true end
slots[2]:Update()
assert(border(2)._quiBorderG == env.colors[2], "forbidden slots must stop styling")
print("Stable native slot lifecycle passed")
