local Harness = assert(loadfile("tests/helpers/character_chrome_harness.lua"))()
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local function slice(source, first, after)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(after, start + #first, true), after)
    return source:sub(start, finish - 1)
end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/"
local source = read(arg[1] or "modules/skinning/character_pane/character.lua")
local harness = Harness.Build()
local character = harness.BuildCharacterFrame()
local nativeSource = read(corpus .. "CharacterFrame.lua")
local env = setmetatable({ CharacterFrameMixin = {}, CharacterFrame = character }, { __index = _G })
env._G = env
local constants = read(corpus .. "CharacterFrameConstants.lua")
local loadConstants = assert(loadstring(constants:match("(CHARACTERFRAME_SUBFRAMES = [^\n]+)")))
setfenv(loadConstants, env)()
local native = assert(loadstring(slice(nativeSource, "function CharacterFrameMixin:ShowSubFrame(", "local CharacterFrameEvents =")))
setfenv(native, env)()
character.ShowSubFrame = env.CharacterFrameMixin.ShowSubFrame
local states, elements = {}, {}
for _, name in ipairs(env.CHARACTERFRAME_SUBFRAMES) do
    env[name] = harness.NewFrame("Frame", name, character)
    env[name]:Hide()
end
for _, key in ipairs({ "ilvlDisplay", "centerILvl", "gearBtn", "settingsPanel" }) do
    states[key] = harness.NewFrame("Frame", nil, character)
    elements[#elements + 1] = states[key]
end
local stats = harness.NewFrame("Frame", nil, character)
local overlay = harness.NewFrame("Frame", nil, env.PaperDollFrame)
elements[#elements + 1] = stats
local backgroundExtended, scale, restoreCalls = true, 1.3, 0
env.statsPanel, env.slotOverlays = stats, { overlay }
env.frameState, env.EMPTY = { [character] = states }, {}
env.RestoreCharacterPanePopouts = function() restoreCalls = restoreCalls + 1 end
env.IsSkinningHandlingBackground = function() return true end
env.QUI_CharacterFrameSkinning = { SetExtended = function(value) backgroundExtended = value end }
local settings = { panelScale = 1.15 }
env.GetSettings = function() return settings end
env.SetCharacterFrameScale = function(value) scale = value end
env.AnchorCharacterFrameBottomTabs = function() end
env.hooksecurefunc = hooksecurefunc
local hooks = assert(loadstring(slice(source, "    local function AdjustForNonCharacterTab()", "    if PaperDollFrame then")))
setfenv(hooks, env)()
for _, name in ipairs(env.CHARACTERFRAME_SUBFRAMES) do
    if name ~= "PaperDollFrame" then
        env.PaperDollFrame:Show()
        for _, element in ipairs(elements) do element:Show() end
        overlay:Show()
        scale, backgroundExtended = 1.3, true
        character:ShowSubFrame(name)
        for _, element in ipairs(elements) do
            assert(not element:IsShown(), name .. " must hide custom CharacterFrame elements")
        end
        assert(not overlay:IsShown(), name .. " must hide equipment overlays")
        assert(math.abs(scale - 1.3 * settings.panelScale) < .00001, name .. " must preserve the configured Character panel zoom")
        assert(backgroundExtended == false, name .. " must retain native shell bounds")
    end
end
assert(restoreCalls >= 5, "every non-PaperDoll mode must restore popouts")
print("OK: forever_character_mode_lifecycle_test")
