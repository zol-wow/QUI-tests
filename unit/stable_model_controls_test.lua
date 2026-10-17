local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinStable = true
ns.Client = { isForever = true }
_G.CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do result[key] = value end end
    return result
end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXML/ModelSceneControlFrame.lua"))()
_G.ZOOM_IN = "Zoom in"; _G.ZOOM_OUT = "Zoom out"
_G.KEY_MOUSEWHEELDOWN = "Wheel down"; _G.KEY_MOUSEWHEELUP = "Wheel up"
_G.ROTATE_LEFT = "Rotate left"; _G.ROTATE_RIGHT = "Rotate right"
_G.ROTATE_TOOLTIP = "Rotate help"; _G.RESET_POSITION = "Reset"
local sounds, zooms, rotations, stops, resets = 0, {}, {}, 0, 0
_G.SOUNDKIT = { IG_INVENTORY_ROTATE_CHARACTER = 1 }
_G.PlaySound = function() sounds = sounds + 1 end
_G.GetCVar = function() return "1" end
local tooltip = { Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
_G.GetAppropriateTooltip = function() return tooltip end
_G.GetAppropriateTopLevelParent = function() return _G.UIParent end
_G.GameTooltip_SetDefaultAnchor = function(t, owner) t.owner = owner end
_G.GameTooltip_SetTitle = function(t, text) t.title = text end
_G.GameTooltip_AddBodyLine = function(t, text) t.body = text end
local root = env.NewFrame("Frame"); root.CloseButton = false
_G.PetStableFrame = root
local scene = env.NewFrame("ModelScene", nil, root); root.modelScene = scene
local zoomAvailable = true
function scene:GetActiveCamera() return { GetZoomAvailable = function() return zoomAvailable end } end
function scene:OnMouseWheel(amount) zooms[#zooms + 1] = amount end
function scene:AdjustCameraYaw(direction, amount) rotations[#rotations + 1] = { direction, amount } end
function scene:StopCameraYaw() stops = stops + 1 end
function scene:Reset() resets = resets + 1 end
scene.Background = scene:CreateTexture(); scene.Background:SetAtlas("native-pet-scene")
scene.PetShadow = scene:CreateTexture(); scene.PetShadow:SetAtlas("perks-char-shadow")
local controls = env.NewFrame("Frame", nil, scene); scene.ControlFrame = controls
controls:SetAlpha(.5); controls:Hide()
controls.enableZoom = true; controls.enableRotate = true; controls.enableReset = true
controls.buttonHorizontalPadding = -6
for key, value in pairs(_G.ModelSceneControlFrameMixin) do controls[key] = value end
controls:SetScript("OnShow", controls.OnShow)
local keys = { "zoomInButton", "zoomOutButton", "rotateLeftButton", "rotateRightButton", "resetButton" }
local mixins = { _G.ModelSceneZoomButtonMixin, _G.ModelSceneZoomButtonMixin,
    _G.ModelScenelRotateButtonMixin, _G.ModelScenelRotateButtonMixin, _G.ModelSceneResetButtonMixin }
for i, key in ipairs(keys) do
    local b = env.NewFrame("Button", nil, controls); controls[key] = b
    b:SetSize(32, 32); b:SetHitRectInsets(4, 4, 4, 4)
    b.RegisterForWidgetSet = false; b.DisabledTexture = false
    b.Icon = b:CreateTexture(); b.Icon:SetSize(16, 16); b.Icon:SetAlpha(.8)
    function b.Icon:AdjustPointsOffset(x, y) self.offsetX = (self.offsetX or 0) + x; self.offsetY = (self.offsetY or 0) + y end
    b.NormalTexture = b:CreateTexture(); b.NormalTexture:SetAtlas("common-button-square-gray-up")
    b.normalTexture = b.NormalTexture
    b.PushedTexture = b:CreateTexture(); b.PushedTexture:SetAtlas("common-button-square-gray-down")
    b.HighlightTexture = b:CreateTexture(); b.highlightTexture = b.HighlightTexture
    for name, value in pairs(mixins[i]) do b[name] = value end
    for _, script in ipairs({"OnClick", "OnMouseDown", "OnMouseUp", "OnEnter", "OnLeave"}) do
        b:SetScript(script, b[script])
    end
end
controls:OnLoad(); controls:SetModelScene(scene)
local nativeAtlas = controls.zoomInButton.Icon.atlas
local click = controls.zoomInButton:GetScript("OnClick")
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
env.profile.general.skinStable = false
callbacks.Blizzard_StableUI()
assert(not skin.GetBackdrop(controls.resetButton), "disabled stable must leave model controls native")
env.profile.general.skinStable = true
root.IsForbidden = function() return true end
callbacks.Blizzard_StableUI()
assert(not skin.GetBackdrop(controls.resetButton), "forbidden root must exclude model controls")
root.IsForbidden = function() return false end
callbacks.Blizzard_StableUI()
for _, key in ipairs(keys) do
    local b = controls[key]
    assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface,
        "Stable model controls must receive rounded button chrome")
    assert(b.Icon:GetAlpha() == .8 and b.Icon:GetWidth() == 16 and b:GetWidth() == 32,
        "native functional icon, opacity and control size must remain")
    assert(b.NormalTexture:GetAlpha() == 0 and b.PushedTexture:GetAlpha() == 0,
        "native model button chrome must be suppressed")
end
assert(not controls:IsShown() and controls:GetAlpha() == .5 and controls.zoomInButton.Icon.atlas == nativeAtlas,
    "native toolbar visibility/fade and initialized glyph must remain")
assert(scene.Background.atlas == "native-pet-scene" and scene.PetShadow:GetAlpha() == 1,
    "native model scene art must remain")
controls:Show()
assert(controls:GetWidth() == 132 and controls:GetHeight() == 32, "native toolbar layout must remain")
controls.zoomInButton:Fire("OnClick"); controls.zoomOutButton:Fire("OnClick")
assert(zooms[1] == 1 and zooms[2] == -1, "native zoom increments must remain")
for _, key in ipairs({"rotateLeftButton", "rotateRightButton"}) do
    controls[key]:Fire("OnMouseDown")
    assert(controls.buttonDown == controls[key] and controls[key].Icon.offsetX == 1,
        "native pressed offset and rotation ownership must remain")
    controls[key]:Fire("OnMouseUp")
    assert(controls.buttonDown == nil and controls[key].Icon.offsetX == 0,
        "native mouse release must restore icon and ownership")
end
assert(rotations[1][1] == "left" and rotations[2][1] == "right" and rotations[1][2] == .05 and stops == 2,
    "native rotation/release callbacks must run once")
controls.resetButton:Fire("OnClick")
assert(resets == 1 and sounds == 5, "native reset and action sounds must remain")
controls.rotateLeftButton:Fire("OnEnter")
assert(controls:GetAlpha() == 1 and tooltip.title == "Rotate left" and tooltip.body == "Rotate help" and tooltip.shown)
controls.rotateLeftButton:Fire("OnLeave")
assert(controls:GetAlpha() == .5 and not tooltip.shown, "native fade and tooltip dismissal must remain")
zoomAvailable = false; controls:UpdateLayout()
assert(not controls.zoomInButton:IsShown() and not controls.zoomOutButton:IsShown() and controls:GetWidth() == 80,
    "native unavailable zoom eligibility/layout must remain")
local backdrop = skin.GetBackdrop(controls.resetButton)
registry.skinStable.refresh()
assert(skin.GetBackdrop(controls.resetButton) == backdrop and sounds == 5 and resets == 1
    and controls.zoomInButton:GetScript("OnClick") == click and not controls.zoomInButton:IsShown(),
    "theme must reuse controls without native callbacks or eligibility changes")
controls.IsForbidden = function() return true end
controls.resetButton.Icon:SetAlpha(.6)
registry.skinStable.refresh()
assert(controls.resetButton.Icon:GetAlpha() == .6, "forbidden controls must stop styling")
print("Stable model controls native lifecycle passed")
