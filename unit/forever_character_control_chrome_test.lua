local Harness = dofile("tests/helpers/character_chrome_harness.lua")
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local function slice(s, first, after)
    local a = assert(s:find(first, 1, true)); local b = assert(s:find(after, a + #first, true)); return s:sub(a, b - 1)
end
local source = read(arg[1] or "modules/skinning/frames/character.lua")
local h = Harness.Build()
local env = setmetatable({ ns = { Client = { isForever = true } }, SkinBase = h.SkinBase,
    GetWindowColors = function() return .3,.6,.9,1,.03,.03,.03,1 end,
    GetTextAccent = function() return .3,.6,.9,1 end,
    SkinToggleCollapseButton = function() end,
    TextureKitConstants = { UseAtlasSize = true },
}, { __index = _G })
local chunk = assert(loadstring(slice(source, "local FOREVER_CHARACTER_CHROME", "local function SkinReputationEntry") .. "\nreturn SkinForeverCharacterDecorations"))
setfenv(chunk, env)
local style = chunk()
local root = "tests/clients/forever/framexml/Interface/AddOns/"
setfenv(assert(loadfile(root .. "Blizzard_SharedXML/Camelot/ProgressBars/ColoredProgressBar.lua")), env)()
local function texture(frame, atlas)
    local region = frame:CreateTexture(nil, "BACKGROUND"); region:SetAtlas(atlas)
    function region:GetAtlas() return self.atlas end
    return region
end
local bar = h.NewFrame("Frame")
for key, value in pairs(env.ColoredProgressBarMixin) do bar[key] = value end
bar:SetWidth(160)
bar.Fill = texture(bar, "common-stat-bar-green")
bar.Fill:SetHeight(15)
bar.Mask = texture(bar, "common-stat-bar-Mask")
bar.Text = bar:CreateFontString(nil,"ARTWORK")
local bg = texture(bar, "common-stat-bar-BG")
bar:SetFillPercent(.25); bar:SetText("Friendly")
style(bar, 0)
assert(bg:GetAlpha() == 0, "unnamed native track art must be hidden")
assert(bar.Fill:GetAtlas() == "common-stat-bar-green" and bar.Fill:GetAlpha() == 1, "native faction-colored fill must survive")
assert(bar.Fill:GetWidth() == 40 and bar.Mask:GetAlpha() == 1 and bar.Text:GetText() == "Friendly", "native progress, mask and caption must survive")
assert(h.SkinBase.GetBackdrop(bar):GetHeight() == 17, "QUI track must fit native fill plus its one-pixel border")
bar:SetFillPercent(.75); bar:SetFillTextureByColorType(env.ColoredProgressBarMixin.ColorType.Blue)
local blueTexture = bar.Fill.texture
style(bar, 0)
assert(bar.Fill:GetWidth() == 120 and bar.Fill.texture == blueTexture, "reused bars retain native updates")
local skills = read(root .. "Blizzard_UIPanels_Game/Camelot/SkillsFrame.lua")
setfenv(assert(loadstring(slice(skills, "SkillsHeaderMixin =", "SkillsEntryMixin ="))), env)()
local collapsed
local headers = { CollapseSkillHeader = function(index) collapsed = index end }
env.C_SkillInfo = headers
local header = h.NewFrame("Button")
for key,value in pairs(env.SkillsHeaderMixin) do header[key] = value end
header.Name = header:CreateFontString(nil, "OVERLAY")
header.StateIcon = texture(header, "common-button-list-minus")
local headerBg = texture(header, "common-button-list-collapseExpand")
header:Initialize({ name = "Weapons", skillIndex = 7, isCollapsed = false })
style(header, 0)
header:OnClick()
assert(collapsed == 7, "native category collapse handler must retain its skill index")
assert(headerBg:GetAlpha() == 0 and header.StateIcon:GetAlpha() == 1, "header art hides while native state icon survives")
assert(header.Name:GetText() == "Weapons", "category caption survives")
env.ns.Client.isForever = false
local retail = h.NewFrame("Frame")
local art = texture(retail, "common-stat-bar-BG")
style(retail, 3)
assert(art:GetAlpha() == 1 and not h.SkinBase.GetBackdrop(retail), "Forever chrome must not touch Retail")
print("OK: Forever native bar/header art and update/collapse contracts")
