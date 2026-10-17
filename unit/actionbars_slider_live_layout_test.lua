local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local generator = read("tools/generate_search_cache.lua")
local cut = assert(generator:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(generator:sub(1, cut - 1) .. "\nreturn ns", "@slider-preamble"))()
local GUI = assert(QUI.GUI)
local timers, writes, layouts, skins = {}, 0, {}, {}
local combat = false
strsplit = function(_, value) return value:match("([^|]+)|([^|]+)|([^|]+)") end
InCombatLockdown = function() return combat end
C_Timer.After = function(_, callback) timers[#timers + 1] = callback end
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

local originalCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent, ...)
    local frame = originalCreateFrame(kind, name, parent, ...)
    local scripts = {}
    frame.SetScript = function(_, event, callback) scripts[event] = callback end
    frame.GetScript = function(_, event) return scripts[event] end
    frame.GetThumbTexture = function() return originalCreateFrame("Texture", nil, frame) end
    if name == "QUI_ActionBarLayoutHandler" then
        local attributes, refs = {}, {}
        frame.GetAttribute = function(_, key) return attributes[key] end
        frame.GetFrameRef = function(_, key) return refs[key] end
        frame.SetFrameRef = function(_, key, value) refs[key] = value end
        frame.SetAttribute = function(self, key, value)
            assert(not combat, "combat must not write protected layout attributes")
            attributes[key] = value
            if key == "_onattributechanged" then
                self.run = assert(loadstring("return function(self, name, value)\n" .. value .. "\nend"))()
            elseif self.run then
                self.run(self, key, value)
            end
        end
    end
    return frame
end

local bars = {
    bar1 = { ownedLayout = { columns = 3, iconCount = 6, buttonSize = 36, buttonSpacing = 2 } },
    bar2 = { ownedLayout = { columns = 3, iconCount = 6, buttonSize = 36, buttonSpacing = 2 } },
    pet = { ownedLayout = { columns = 3, iconCount = 6, buttonSize = 36, buttonSpacing = 2 } },
    stance = { ownedLayout = { columns = 3, iconCount = 6, buttonSize = 36, buttonSpacing = 2 } },
    microbar = { ownedLayout = { columns = 3, iconCount = 6, buttonSize = 36, buttonSpacing = 2 } },
}
local owned = {
    containers = {}, nativeButtons = {}, cachedLayouts = {},
    _activeButtons = {}, _activeStandardButtons = {},
}
for key in pairs(bars) do
    local container = CreateFrame("Frame")
    local setSize, setWidth, setHeight = container.SetSize, container.SetWidth, container.SetHeight
    container.SetSize = function(self, ...) writes = writes + 1; return setSize(self, ...) end
    container.SetWidth = function(self, ...) writes = writes + 1; return setWidth(self, ...) end
    container.SetHeight = function(self, ...) writes = writes + 1; return setHeight(self, ...) end
    owned.containers[key] = container
    owned.nativeButtons[key] = {}
    for i = 1, 6 do
        local button = CreateFrame("Button", nil, container)
        button:SetSize(45, 45)
        local setScale, setPoint = button.SetScale, button.SetPoint
        button.SetScale = function(self, value)
            assert(not combat, "combat must not resize protected buttons")
            writes = writes + 1
            return setScale(self, value)
        end
        button.SetPoint = function(self, ...)
            assert(not combat, "combat must not move protected buttons")
            writes = writes + 1
            return setPoint(self, ...)
        end
        owned.nativeButtons[key][i] = button
    end
end

assert(loadfile("QUI_ActionBars/actionbars/actionbars_env.lua"))("QUI", ns)
local env = ns.ActionBarsEnv
env.ActionBarsOwned = owned
env.Helpers = setmetatable({ CreateDBGetter = function() return function() end end }, { __index = ns.Helpers })
env.GetCore = function() return nil end
env.GetDB = function() return { bars = bars, global = {} } end
env.GetBarSettings = function(key) return bars[key] end
env.GetGlobalSettings = function() return {} end
env.GetEffectiveSettings = function() return {} end
env.GetFrameState = function() return {} end
env.InvalidateEffectiveSettingsCache = function() end
env.SkinButton = function(button)
    skins[button] = (skins[button] or 0) + 1
end
env.UpdateButtonText = function() end
env.UpdateEmptySlotVisibility = function() end
env.ALL_MANAGED_BAR_KEYS = { "bar1", "bar2" }
env.SKINNABLE_BAR_KEYS = { bar1 = true, bar2 = true }
env.STANDARD_BAR_KEY_SET = env.SKINNABLE_BAR_KEYS
env.BUTTON_COUNTS = { bar1 = 6, bar2 = 6, pet = 6, stance = 6, microbar = 6 }
ns.SafeCall = function(_, callback, ...) return callback(...) end

local secureSource = read("QUI_ActionBars/actionbars/actionbars.lua")
local start = assert(secureSource:find('layoutHandler = CreateFrame("Frame", "QUI_ActionBarLayoutHandler"', 1, true))
local finish = assert(secureSource:find("env.__declared.SkinButton = true", start, true))
local secureChunk = assert(loadstring(secureSource:sub(start, finish - 1), "@production-secure-layout"))
setfenv(secureChunk, env)
secureChunk()
for key, buttons in pairs(owned.nativeButtons) do
    env.layoutHandler:SetFrameRef("bar-" .. key, owned.containers[key])
    for i, button in ipairs(buttons) do env.layoutHandler:SetFrameRef("btn-" .. key .. "-" .. i, button) end
end
assert(loadfile("QUI_ActionBars/actionbars/actionbars_layout.lua"))("QUI", ns)
local nativeLayout = env.LayoutNativeButtons
env.LayoutNativeButtons = function(key)
    layouts[key] = (layouts[key] or 0) + 1
    return nativeLayout(key)
end
local sliders = {}
local realSlider = GUI.CreateFormSlider
GUI.CreateFormSlider = function(self, parent, label, min, max, step, key, ...)
    local widget = realSlider(self, parent, label, min, max, step, key, ...)
    sliders[key] = widget
    return widget
end
GUI.CreateFormCheckbox = function(_, parent) return CreateFrame("Frame", nil, parent) end
GUI.CreateFormDropdown = GUI.CreateFormCheckbox
ns.QUI_LayoutMode_Utils = {
    PlaceRow = function(_, _, y) return y - 32 end,
    StandardRelayout = function(content) content:SetHeight(300) end,
    BuildPositionCollapsible = function() end,
    BuildOpenFullSettingsLink = function() end,
    CreateCollapsible = function(parent, title, _, build)
        if title == "Layout" then build(CreateFrame("Frame", nil, parent)) end
    end,
}
assert(loadfile("QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua"))("QUI", ns)
ns.QUI_ActionBarsPerBarBuilders.EnsureInitialized()(CreateFrame("Frame"), "bar1", 420)
env.LayoutNativeButtons("bar1")
env.LayoutNativeButtons("bar2")
layouts = {}
writes = 0

local function event(frame, name, ...)
    return assert(frame:GetScript(name), "missing real slider script " .. name)(frame, ...)
end
local function drag(key, value)
    local slider = sliders[key].slider
    event(slider, "OnMouseDown")
    slider:SetValue(value)
    event(slider, "OnValueChanged", value, true)
end
local function checkSize(size)
    local first, second = owned.nativeButtons.bar1[1], owned.nativeButtons.bar1[2]
    assert(math.abs(first:GetWidth() * first:GetScale() - size) < 0.00001,
        string.format("icons must resize before slider release: expected %g, got %g", size, first:GetWidth() * first:GetScale()))
    local _, relativeTo, _, x = second:GetPoint(1)
    assert(relativeTo == owned.containers.bar1)
    assert(math.abs(x * second:GetScale() - (size + bars.bar1.ownedLayout.buttonSpacing)) < 0.00001,
        "button positions must match their live size")
    local container = owned.containers.bar1
    assert(container:GetWidth() == 3 * size + 2 * bars.bar1.ownedLayout.buttonSpacing)
    assert(container:GetHeight() == 2 * size + bars.bar1.ownedLayout.buttonSpacing)
end

drag("buttonSize", 40)
drag("buttonSize", 44)
drag("buttonSize", 48)
local pendingLayouts = #timers
flush()
checkSize(48)
assert(pendingLayouts == 1, "drag bursts must coalesce to one pending layout")
assert(layouts.bar1 == 1 and not layouts.bar2 and not next(skins),
    "live dragging must only lay out the selected bar without reskinning siblings")
drag("columns", 2)
drag("buttonSpacing", 4)
drag("iconCount", 4)
assert(#timers == 1, "the geometry sliders must share one pending bar layout")
flush()
assert(owned.containers.bar1:GetWidth() == 100 and owned.containers.bar1:GetHeight() == 100)
assert(not owned.nativeButtons.bar1[5]:IsShown(), "visible count changes must hide excess buttons while dragging")
local _, _, _, liveX = owned.nativeButtons.bar1[2]:GetPoint(1)
assert(math.abs(liveX * owned.nativeButtons.bar1[2]:GetScale() - 52) < 0.00001)
drag("columns", 3)
drag("buttonSpacing", 2)
drag("iconCount", 6)
drag("buttonSize", 52)
event(sliders.buttonSize.slider, "OnMouseUp")
flush()
checkSize(52)
assert(skins[owned.nativeButtons.bar1[1]] and skins[owned.nativeButtons.bar2[1]],
    "release must retain the existing full refresh")

sliders.buttonSize.editBox:SetText("56")
event(sliders.buttonSize.editBox, "OnEnterPressed")
checkSize(56)
for _, child in ipairs({ sliders.buttonSize:GetChildren() }) do
    if child:GetScript("OnClick") then
        for _, region in ipairs({ child:GetRegions() }) do
            if region:GetText() == "+" then
                event(child, "OnClick")
                checkSize(57)
            end
        end
    end
end
assert(bars.bar1.ownedLayout.buttonSize == 57, "the real plus nudge must commit immediately")

local before = writes
combat = true
drag("buttonSize", 60)
flush()
assert(writes == before, "combat drag must not mutate geometry")
combat = false
event(sliders.buttonSize.slider, "OnMouseUp")
checkSize(60)
drag("buttonSize", 64)
combat = true
before = writes
flush()
assert(writes == before, "a preview queued before combat must not mutate geometry during combat")
combat = false
event(sliders.buttonSize.slider, "OnMouseUp")
checkSize(64)
for _, alias in ipairs({ { "petBar", "pet" }, { "stanceBar", "stance" } }) do
    ns.QUI_ActionBarsPerBarBuilders.BuildBarSettings(CreateFrame("Frame"), alias[1], 420)
    drag("buttonSize", 40)
    flush()
    local button = owned.nativeButtons[alias[2]][1]
    assert(math.abs(button:GetWidth() * button:GetScale() - 40) < 0.00001,
        "aliased settings keys must resize the corresponding native bar")
    assert(owned.containers[alias[2]]:GetWidth() == 124)
end
ns.QUI_ActionBarsPerBarBuilders.BuildBarSettings(CreateFrame("Frame"), "microMenu", 420)
env.LayoutNativeButtons("microbar")
local foreign = CreateFrame("Frame")
for _, button in ipairs(owned.nativeButtons.microbar) do
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", foreign, "TOPLEFT", 0, 0)
end
owned._microOwnedByUI = true
before = writes
drag("buttonSize", 40)
flush()
assert(writes == before, "live preview must not mutate micro buttons owned by another UI")
owned._microOwnedByUI = false
drag("buttonSize", 44)
owned._microOwnedByUI = true
flush()
assert(writes == before, "queued preview must recheck micro button ownership")
local _, microParent = owned.nativeButtons.microbar[1]:GetPoint(1)
assert(microParent == foreign, "yielded micro buttons must retain their foreign anchors")
owned._microOwnedByUI = false
drag("buttonSize", 48)
flush()
local microButton = owned.nativeButtons.microbar[1]
assert(math.abs(microButton:GetWidth() * microButton:GetScale() - 48) < 0.00001)
local _, restoredParent = microButton:GetPoint(1)
assert(restoredParent == owned.containers.microbar and owned.containers.microbar:GetWidth() == 148,
    "live micro preview must resume after ownership returns")
print("PASS: actionbars_slider_live_layout_test")
