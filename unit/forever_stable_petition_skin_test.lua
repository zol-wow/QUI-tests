local callbacks, registry, state = {}, {}, {}
local settings = { skinStable = false, skinGuildRegistrar = false }
local SkinBase = {
    OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end,
    IsSkinned = function(frame) return state[frame] end,
    MarkSkinned = function(frame) state[frame] = true end,
    SkinWindow = function(frame) frame.themed = true end,
    SkinFrameText = function(frame) frame.fonted = true end,
    LockFrameTextObjects = function(frame) frame.fontLocked = true end,
    SkinButton = function(frame) frame.themed = true end,
    KillNineSlice = function(frame) frame.hidden = true end,
    RefreshFrameBackdropColors = function(frame) if frame then frame.refreshed = true end end,
    RefreshWidget = function(frame) frame.refreshed = true end,
}
local ns = {
    Client = { isForever = true },
    Helpers = { GetCore = function() return { db = { profile = { general = settings } } } end,
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end },
    SkinBase = SkinBase,
    Registry = { Register = function(_, key, entry) registry[key] = entry end },
}
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
assert(loadfile(corpus .. "Blizzard_StableUI/Camelot/Blizzard_StableUI.lua"))()
local PetStableSlotMixin = _G.PetStableSlotMixin
local PetStablePurchaseButtonMixin = _G.PetStablePurchaseButtonMixin
local pet = { icon = 123, name = "Wolf", level = 20, familyName = "Wolf" }
C_StableInfo = { GetStablePetInfo = function() return pet end, GetNumStableSlots = function() return 0 end }
SetItemButtonTexture = function(slot, icon) slot.icon = icon end
format = string.format
UNIT_LEVEL_TEMPLATE = "Level %d"
local slot = { background = { SetVertexColor = function(self, ...) self.color = { ... } end } }
slot.GetID = function() return 3 end
slot.Update = PetStableSlotMixin.Update
slot.OnClick = PetStableSlotMixin.OnClick
slot.OnDragStart = PetStableSlotMixin.OnDragStart
local originalClick, originalDrag = slot.OnClick, slot.OnDragStart
local stable = {
    purchaseButton = { OnClick = PetStablePurchaseButtonMixin.OnClick },
    modelScene = { Inset = { NineSlice = {} }, Background = { artwork = true } },
    petSlot = slot,
    footer = { gamepad = true },
}
local petition = { sign = function() return "signed" end }
local registrar = {}
_G.PetStableFrame, _G.PetitionFrame, _G.GuildRegistrarFrame = stable, petition, registrar
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
assert(callbacks.Blizzard_StableUI, "exposed Forever pet stable must have a skin lifecycle")
callbacks.Blizzard_StableUI()
assert(not stable.themed, "disabled pet stable must retain native presentation")
settings.skinStable = true
callbacks.Blizzard_StableUI()
assert(stable.themed and stable.purchaseButton.themed,
    "enabled stable skin must cover its shell and purchase button")
assert(stable.fonted and stable.fontLocked,
    "stable labels must follow the global font across native resets")
assert(stable.modelScene.Inset.NineSlice.hidden and stable.modelScene.Background.artwork,
    "stable skin must suppress frame chrome while retaining the pet scene")
slot:Update()
assert(slot.icon == pet.icon and slot.background.color[2] == 0.1,
    "native pet icons and locked-slot red indication must survive skinning")
assert(slot.OnClick == originalClick and slot.OnDragStart == originalDrag and stable.footer.gamepad,
    "stable selection, dragging, and controller ownership must remain native")
registry.skinStable.refresh()
assert(stable.refreshed and stable.purchaseButton.refreshed,
    "stable shell and purchase button must follow theme refresh")
callbacks.Blizzard_UIPanels_Game()
assert(not petition.themed, "disabled guild skin must retain the native charter")
settings.skinGuildRegistrar = true
callbacks.Blizzard_UIPanels_Game()
assert(registrar.themed and petition.themed and petition.sign() == "signed",
    "guild registrar skin must include the charter and preserve signatures")
registry.skinPetition.refresh()
assert(petition.refreshed, "charter skin must follow theme refresh")

print("OK: Forever stable and guild charter skins preserve native interaction ownership")
