local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
env.profile.general.skinCharacterFrame = true
env.profile.general.skinMacro = false
local function frame(kind, parent)
    local f = env.NewFrame(kind or "Frame", nil, parent)
    f.RegisterForWidgetSet, f.DisabledTexture = false, false
    return f
end
local popup = frame()
_G.GearManagerPopupFrame = popup
popup.BG = popup:CreateTexture()
popup.BorderBox = frame(nil, popup)
local box = popup.BorderBox
box.NineSlice = frame(nil, box)
box.IconSelectorEditBox = frame("EditBox", box)
box.IconTypeDropdown = frame("DropdownButton", box)
box.OkayButton, box.CancelButton = frame("Button", box), frame("Button", box)
box.OkayButton.Text = box.OkayButton:CreateFontString()
box.CancelButton.Text = box.CancelButton:CreateFontString()
box.OkayButton.Text:SetText("Okay")
box.CancelButton.Text:SetText("Cancel")
local save, cancel = function() error("must not save a set") end, function() end
box.OkayButton:SetScript("OnClick", save)
box.CancelButton:SetScript("OnClick", cancel)
popup.IconSelector = frame(nil, popup)
local selector = popup.IconSelector
selector.ScrollBar = frame("Slider", selector)
selector.ScrollBar.ThumbTexture = selector.ScrollBar:CreateTexture()
local setupCalls = 0
selector.RunSetup = function() setupCalls = setupCalls + 1 end
popup.Update = function() end
local callbacks = {}
skin.OnAddOnLoaded = function(name, callback) callbacks[name] = callback end
assert(loadfile("modules/skinning/frames/interaction.lua"))("QUI", env.ns)
callbacks.Blizzard_UIPanels_Game()
assert(skin.GetBackdrop(popup)._quiRoundedSurface, "Character icon picker must use QUI window chrome even when Macro skin is disabled")
assert(skin.GetBackdrop(box.IconSelectorEditBox), "name field must have QUI edit chrome")
assert(popup.BG:GetAlpha() == 0 and box.NineSlice:GetAlpha() == 0, "ornate dialog shell must be suppressed")
assert(box.OkayButton:GetScript("OnClick") == save and box.CancelButton:GetScript("OnClick") == cancel, "native save and cancel handlers must be unchanged")
local row = frame("Button", selector)
row.Icon = row:CreateTexture()
row.Icon:SetTexture("native-equipment-icon")
row.Highlight = row:CreateTexture()
selector:RunSetup(row)
assert(setupCalls == 1 and row.Icon.texture == "native-equipment-icon", "pooled native icon setup and item art must survive styling")
assert(skin.GetBackdrop(row)._quiRoundedSurface, "recycled picker icons must have rounded chrome")
print("OK: equipment_icon_picker_test")
