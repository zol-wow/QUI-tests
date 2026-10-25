local function NewFrame()
    return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWordWrap = function() end,
        SetHeight = function(self, height) self.height = height end,
        GetHeight = function(self) return self.height end,
    }
end

_G.CreateFrame = NewFrame
_G.LibStub = function() end
local profileMacros = {
    enabled = true,
    selectedFlask = "shared-flask",
    selectedPotion = "shared-potion",
    selectedHealth = "shared-health",
    selectedHealthstone = "shared-stone",
    selectedAugment = "shared-augment",
    selectedVantus = "shared-vantus",
    selectedWeapon = "shared-weapon",
    chatNotifications = true,
}
local charMacros = { characterSpecific = false, selectedFlask = "old-character-flask" }
local profile = { general = { consumableMacros = profileMacros } }
local widgets, labels = {}, {}
local gui = { Colors = { textMuted = {} } }
function gui:CreateLabel() return NewFrame() end
function gui:CreateFormCheckbox(_, _, key, db, callback)
    local widget = { key = key, db = db, callback = callback }
    widgets[key] = widget
    return widget
end
function gui:CreateFormDropdown(parent, label, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
function gui:CreateFormSlider(parent, label, _, _, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
_G.QUI = { GUI = gui }
local refreshCount, deleteCount = 0, 0
local ns = {
    Addon = { db = { profile = profile, char = { consumableMacros = charMacros } } },
    ConsumableMacros = {
        ForceRefresh = function() refreshCount = refreshCount + 1 end,
        DeleteMacros = function() deleteCount = deleteCount + 1 end,
    },
    QUI_Options = {
        GetDB = function() return profile end,
        CreateAccentDotLabel = function() return NewFrame() end,
        BuildSettingRow = function(_, label, widget)
            labels[widget.key] = label
            return { label = label, widget = widget }
        end,
        CreateSettingsCardGroup = function()
            local frame, rowCount = NewFrame(), 0
            return {
                frame = frame,
                AddRow = function() rowCount = rowCount + 1 end,
                Finalize = function() frame:SetHeight(rowCount * 32) end,
            }
        end,
    },
}
(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("core/utils.lua"))("QUI", ns)
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
assert(loadfile(arg[1] or "modules/qol/settings/qol_content.lua"))("QUI", ns)

local function Build()
    widgets, labels = {}, {}
    assert(ns.QUI_QoLOptions.BuildGeneralTab(NewFrame(), nil, "consumableMacros") > 0)
    assert(widgets.characterSpecific, "Quality of Life Consumables must expose Character-specific")
    assert(labels.characterSpecific == "Character-specific", "scope toggle must have a visible label")
    for key in pairs(profileMacros) do
        assert(widgets[key], "QoL must preserve the existing macro setting " .. key)
    end
end

local function Change(key, value)
    local widget = assert(widgets[key])
    widget.db[key] = value
    if widget.callback then widget.callback(value) end
end

Build()
assert(widgets.characterSpecific.db.characterSpecific == false)
Change("selectedFlask", "updated-shared-flask")
assert(profileMacros.selectedFlask == "updated-shared-flask" and charMacros.selectedFlask == "old-character-flask",
    "shared mode must change the profile without overwriting character selections")
Change("characterSpecific", true)
assert(charMacros.characterSpecific == true and profileMacros.characterSpecific == nil,
    "scope preference must be stored only on this character")
for key, value in pairs(profileMacros) do
    assert(charMacros[key] == value, "enabling character scope must seed " .. key .. " from the profile")
end
assert(ns.Helpers.GetConsumableMacrosDB() == charMacros, "macro runtime must read the newly selected character scope")
local selectionKeys = {
    "selectedFlask", "selectedPotion", "selectedHealth", "selectedHealthstone",
    "selectedAugment", "selectedVantus", "selectedWeapon",
}
for _, key in ipairs(selectionKeys) do
    local sharedValue = profileMacros[key]
    Change(key, "character-" .. key)
    assert(charMacros[key] == "character-" .. key and profileMacros[key] == sharedValue,
        "character dropdown must leave shared " .. key .. " unchanged")
end
Change("chatNotifications", false)
Change("enabled", false)
assert(not charMacros.chatNotifications and profileMacros.chatNotifications,
    "chat notifications must follow the selected scope")
assert(not charMacros.enabled and profileMacros.enabled and deleteCount == 1,
    "disabling character macros must delete them without disabling the shared profile")
Change("characterSpecific", true)
assert(charMacros.selectedFlask == "character-selectedFlask" and not charMacros.enabled,
    "repeated enabled scope must not reseed or discard character choices")
Build()
assert(widgets.characterSpecific.db.characterSpecific == true and widgets.selectedFlask.db.selectedFlask == "character-selectedFlask",
    "reopening QoL must retain the character scope and selections")
local refreshBefore = refreshCount
Change("characterSpecific", false)
assert(ns.Helpers.GetConsumableMacrosDB() == profileMacros and refreshCount == refreshBefore + 1,
    "switching back to an enabled profile must rebuild its macros")
assert(widgets.selectedFlask.db.selectedFlask == profileMacros.selectedFlask,
    "existing dropdown bindings must read shared selections immediately after switching scope")
Change("selectedPotion", "new-shared-potion")
Change("chatNotifications", false)
assert(profileMacros.selectedPotion == "new-shared-potion" and charMacros.selectedPotion == "character-selectedPotion",
    "existing dropdown bindings must write to the profile after disabling character scope")
assert(profileMacros.chatNotifications == false)
Build()
assert(widgets.characterSpecific.db.characterSpecific == false and widgets.selectedPotion.db.selectedPotion == "new-shared-potion",
    "reopening shared mode must preserve the profile selections")

local providers = {}
ns.Settings = { ProviderPanels = {
    RegisterAfterLoad = function(_, register)
        register({
            GUI = gui,
            U = {
                GetProfileDB = function() return profile end,
                BuildPositionCollapsible = function() end,
                BuildOpenFullSettingsLink = function() end,
            },
            RegisterShared = function(key, provider) providers[key] = provider end,
        })
    end,
} }
assert(loadfile("modules/qol/settings/provider_panels.lua"))("QUI", ns)
local qolWidgets = widgets
widgets, labels = {}, {}
assert(providers.consumables.build(NewFrame(), "consumables", 900) > 0)
assert(widgets.characterSpecific and labels.characterSpecific == "Character-specific",
    "Gameplay Raid Buffs must retain its existing Character-specific toggle")
local providerWidgets = widgets
Change("characterSpecific", true)
assert(qolWidgets.characterSpecific.db.characterSpecific == true and ns.Helpers.GetConsumableMacrosDB() == charMacros,
    "enabling scope on Gameplay must also switch the existing QoL bindings and runtime")
Change("selectedFlask", "gameplay-character-flask")
assert(qolWidgets.selectedFlask.db.selectedFlask == "gameplay-character-flask" and profileMacros.selectedFlask == "updated-shared-flask",
    "Gameplay character changes must be visible from QoL without overwriting the profile")
widgets = qolWidgets
Change("selectedPotion", "qol-character-potion")
assert(providerWidgets.selectedPotion.db.selectedPotion == "qol-character-potion" and charMacros.selectedPotion == "qol-character-potion",
    "QoL character changes must be visible from Gameplay and the runtime")
Change("characterSpecific", false)
assert(providerWidgets.characterSpecific.db.characterSpecific == false and ns.Helpers.GetConsumableMacrosDB() == profileMacros,
    "disabling scope on QoL must also switch the existing Gameplay bindings and runtime")
widgets = providerWidgets
Change("selectedPotion", "gameplay-shared-potion")
assert(qolWidgets.selectedPotion.db.selectedPotion == "gameplay-shared-potion" and charMacros.selectedPotion == "qol-character-potion",
    "Gameplay shared changes must reach QoL without overwriting character selections")
print("qol_consumablemacros_character_scope_test: ok")
