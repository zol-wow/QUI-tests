local Harness = assert(loadfile("tests/helpers/character_chrome_harness.lua"))()
local harness = Harness.Build()
harness.profile.general.skinFlightMap = true
local callbacks = {}
harness.SkinBase.OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end
local frame = harness.NewFrame("Frame", "TaxiFrame")
_G.TaxiFrame = frame
_G.FlightMapFrame = nil
frame.CloseButton = harness.NewFrame("Button", nil, frame)
frame.TitleText = frame:CreateFontString(nil, "ARTWORK")
frame.InsetBg = frame:CreateTexture(nil, "BACKGROUND")
local map = frame.InsetBg
local node = harness.NewFrame("Button", "TaxiButton1", frame)
node:SetID(1)
node.normalTexture = node:CreateTexture(nil, "ARTWORK")
node.highlightTexture = node:CreateTexture(nil, "HIGHLIGHT")
_G.TaxiButton1 = node
_G.UIPanelWindows = {}
_G.FLIGHT_MAP = "Flight Map"
_G.SOUNDKIT = { IG_MAINMENU_OPEN = 1 }
_G.PlaySound = function() end
_G.UIErrorsFrame = { AddMessage = function() end }
_G.HideUIPanel = function() end
_G.NumTaxiNodes = function() return 1 end
_G.TaxiNodeGetType = function() return "CURRENT" end
_G.TaxiNodePosition = function() return 0.5, 0.5 end
_G.GetNumRoutes = function() return 0 end
_G.TaxiRouteMap = harness.NewFrame("Frame", "TaxiRouteMap", frame)
_G.SetTaxiMap = function(texture) texture:SetTexture("native-taxi-map") end
_G.floor = math.floor
function node:SetNormalTexture(texture) self.normalTexture:SetTexture(texture) end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Shared/TaxiFrame.lua"))()
_G.NUM_TAXI_BUTTONS = 1
assert(loadfile(arg[1] or "modules/skinning/frames/worldmap.lua"))("QUI", harness.ns)
assert(callbacks.Blizzard_UIPanels_Game, "Forever TaxiFrame must be handled when UIPanels loads")
callbacks.Blizzard_UIPanels_Game()
assert(harness.SkinBase.IsSkinned(frame) and harness.SkinBase.GetBackdrop(frame), "native TaxiFrame must honor skinFlightMap")
_G.TaxiFrame_OnShow(frame)
assert(frame.InsetBg == map and map.texture == "native-taxi-map" and map:GetAlpha() == 1, "Taxi map must remain Blizzard-owned and visible")
assert(node:GetID() == 1 and node:GetParent() == frame and node.normalTexture.texture == _G.TaxiButtonTypes.CURRENT.file,
    "native Taxi node IDs and availability art must survive")
local registry
harness.ns.Registry = { Register = function(_, name, spec) if name == "skinFlightMap" then registry = spec end end }
assert(loadfile(arg[1] or "modules/skinning/frames/worldmap.lua"))("QUI", harness.ns)
harness.colors[1] = 0.8
registry.refresh()
local border = harness.BorderColor(harness.SkinBase.GetBackdrop(frame))
assert(border[1] == 0.8, "flight-map theme refresh must update the actual TaxiFrame shell")
print("OK: forever_taxi_skinning_test")
