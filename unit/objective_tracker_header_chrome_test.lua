local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function SkinTrackerHeader(", 1, true))
local last = assert(source:find("local function UpdateMinimizeButtonGlyph", first, true))
local combat = false
local chunk = assert(loadstring("local pendingProtectedLayoutUpdate = false\n"
    .. source:sub(first, last - 1)
    .. "\nreturn SkinTrackerHeader, function() return pendingProtectedLayoutUpdate end"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase, Helpers = env.ns.Helpers,
    InCombatLockdown = function() return combat end,
    GetFontPath = function() return "QUIFont.ttf" end,
    GetFontFlags = function() return "" end,
    CJKFont = function(fs, path, size, flags) fs:SetFont(path, size, flags) end,
}, { __index = _G }))
local style, hasPendingLayout = chunk()
local owner = env.NewFrame("Frame")
owner.collapsed = false
function owner:IsCollapsed() return self.collapsed end
local header = env.NewFrame("Frame", nil, owner)
header.Background = header:CreateTexture()
header.Shine = header:CreateTexture()
header.Glow = header:CreateTexture()
header.Text = header:CreateFontString()
header.Text:SetText("Quests")
header.MinimizeButton = env.NewFrame("Button", nil, header)
local button = header.MinimizeButton
button:SetSize(16, 16)
button.DisabledTexture = false
button.normalTexture = button:CreateTexture()
button.pushedTexture = button:CreateTexture()
function button:GetPushedTexture() return self.pushedTexture end
button.highlightTexture = button:CreateTexture()
local click = function() error("styling must not invoke native collapse action") end
button:SetScript("OnClick", click)
local f = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua"))
local native = f:read("*a"); f:close()
local setCollapsed = assert(native:match("function ObjectiveTrackerModuleHeaderMixin:SetCollapsed%(collapsed%).-\nend"))
assert(loadstring("ObjectiveTrackerModuleHeaderMixin = {}\n" .. setCollapsed))()
header.SetCollapsed = _G.ObjectiveTrackerModuleHeaderMixin.SetCollapsed
style(header)
local divider = env.SkinBase.GetFrameData(header, "qTrackerDivider")
assert(divider and divider:GetHeight() == 1, "tracker headers need a thin physical-pixel accent divider")
local glyph = env.SkinBase.GetFrameData(button, "qTrackerCollapseGlyph")
assert(glyph and glyph:GetText() == "-", "expanded header needs a QUI collapse glyph")
assert(button.normalTexture:GetAlpha() == 0 and button.pushedTexture:GetAlpha() == 0,
    "native gold collapse art must not coexist with QUI glyph")
owner.collapsed = true
header:SetCollapsed(true)
assert(glyph:GetText() == "-", "styling must defer outside native header update")
env.RunTimers()
assert(glyph:GetText() == "+", "native collapse must refresh glyph on next frame")
owner.collapsed = false
header:SetCollapsed(false)
env.RunTimers()
assert(glyph:GetText() == "-" and header.Text:GetText() == "Quests",
    "native expansion must restore minus without changing section data")
style(header)
assert(env.SkinBase.GetFrameData(header, "qTrackerDivider") == divider
    and env.SkinBase.GetFrameData(button, "qTrackerCollapseGlyph") == glyph,
    "theme refresh must reuse divider and glyph")
assert(button:GetScript("OnClick") == click and button:GetWidth() == 16 and button:GetHeight() == 16,
    "tracker styling must preserve native click action and hit geometry")
assert(header.Background:GetAlpha() == 0 and header.Shine:GetAlpha() == 0 and header.Glow:GetAlpha() == 0,
    "header ornaments must yield to QUI section styling")
local unstyledHeader = env.NewFrame("Frame", nil, owner)
unstyledHeader.Text = unstyledHeader:CreateFontString()
unstyledHeader.MinimizeButton = env.NewFrame("Button", nil, unstyledHeader)
local function guardGeometry(target)
    for _, method in ipairs({ "CreateTexture", "CreateFontString", "CreateMaskTexture",
        "ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight",
        "SetFrameLevel", "SetParent", "SetFont" }) do
        local original = rawget(target, method)
        if original then
            target[method] = function(self, ...)
                assert(not combat, "header styling must not create or change geometry in combat: " .. method)
                return original(self, ...)
            end
        end
    end
end
for _, frame in ipairs(env.frames) do guardGeometry(frame) end
for _, texture in ipairs(env.textures) do guardGeometry(texture) end
local frameCount, textureCount = #env.frames, #env.textures
combat = true
owner.collapsed = true
header:SetCollapsed(true)
assert(glyph:GetText() == "-", "combat collapse styling must remain deferred")
env.RunTimers()
assert(glyph:GetText() == "+", "native combat collapse must refresh the existing glyph")
owner.collapsed = false
header:SetCollapsed(false)
env.RunTimers()
assert(glyph:GetText() == "-", "native combat expansion must refresh the existing glyph")
local secret = {}
env.ns.Helpers.IsSecretValue = function(value) return value == secret end
owner.collapsed = secret
style(header)
assert(glyph:GetText() == "-", "secret collapsed state must retain the readable glyph")
owner.collapsed = false
style(unstyledHeader)
assert(not env.SkinBase.GetFrameData(unstyledHeader.MinimizeButton, "qTrackerCollapseGlyph"),
    "an unstyled combat header must defer glyph creation")
assert(#env.frames == frameCount and #env.textures == textureCount and hasPendingLayout(),
    "combat styling must defer geometry without creating frames or regions")
print("OK: objective_tracker_header_chrome_test")

combat=false
style(header)
button.normalTexture:SetAtlas("ui-questtrackerbutton-secondary-expand",true)
button.normalTexture:SetAlpha(1)
button.pushedTexture:SetAtlas("ui-questtrackerbutton-secondary-expand-pressed",true)
button.pushedTexture:SetAlpha(1)
button.highlightTexture:SetAlpha(1)
assert(button.normalTexture:GetAlpha()==0 and button.pushedTexture:GetAlpha()==0
 and button.highlightTexture:GetAlpha()==0, "native refresh must never restore art behind the QUI glyph")
