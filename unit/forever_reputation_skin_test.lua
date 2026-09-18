local function noop() end
local function loadIn(path, env)
    if setfenv then
        return setfenv(assert(loadfile(path)), env)
    end
    return assert(loadfile(path, "t", env))
end

local function textRegion()
    return {
        SetFont = function(self, path, size) self.font, self.fontSize = path, size end,
        SetTextColor = function(self, ...) self.color = { ... } end,
        SetText = function(self, value) self.text = value end,
    }
end

local acquired
local initialized
local backdropCount = 0
local env = setmetatable({ CharacterFrame = {}, ReputationFrame = { ScrollBox = {} } }, { __index = _G })
env._G = env
env.CreateFrame = function()
    backdropCount = backdropCount + 1
    return { SetFrameLevel = noop, Show = noop }
end
local ns = {
    Helpers = {
        CreateStateTable = function() return {} end,
        GetCore = function() return { db = { profile = { general = { skinCharacterFrame = true } } } } end,
        CreateSkinColorGetter = function() return function() return 0.3, 0.6, 0.9, 1 end end,
        GetGeneralFont = function() return "skin-font" end,
    },
    UIKit = { DisablePixelSnap = function(region) region.pixelSnapDisabled = true end },
    SkinBase = {
        CHROME = { BORDER_PX = 1 },
        GetFrameData = function(frame, key) return frame[key] end,
        SetFrameData = function(frame, key, value) frame[key] = value end,
        GetDepthColor = function() return 0, 0, 0, 1 end,
        ApplyPixelBackdrop = noop,
        SetExpandedPixelPoints = noop,
        LockPooledRowText = noop,
        HookScrollBoxAcquired = function(_, callback) acquired = callback end,
        OnAddOnLoaded = function(_, callback) initialized = callback end,
    },
}
loadIn("modules/skinning/frames/character.lua", env)("QUI", ns)
initialized()
assert(acquired, "character initialization must install the reputation row callback")

loadIn("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXML/Camelot/ProgressBars/ColoredProgressBar.lua", env)()
local bar = {
    Fill = {
        SetTexture = function(self, texture) self.texture = texture end,
        SetWidth = function(self, width) self.width = width end,
        SetTexCoord = function(self, ...) self.coords = { ... } end,
    },
    Mask = {},
    Text = textRegion(),
    GetWidth = function() return 160 end,
    GetParent = function() return env.CharacterFrame end,
    GetFrameLevel = function() return 5 end,
}
setmetatable(bar, { __index = env.ColoredProgressBarMixin })
local mask = bar.Mask
bar:SetFillPercent(0.25)
bar:SetText("Friendly")
bar.Fill.color = { 0.1, 0.8, 0.2 }
local color = bar.Fill.color
local row = { Content = { ReputationBar = bar, Name = textRegion() } }
acquired(row)
assert(bar.Fill.texture == "Interface\\Buttons\\WHITE8x8", "Forever Frame must skin its Fill texture")
assert(bar.Fill.width == 40 and bar.Fill.coords[2] == 0.25, "skinning must preserve native progress")
assert(bar.Mask == mask and bar.Fill.color == color, "native mask and reputation color must survive")
assert(bar.Text.text == "Friendly" and bar.Text.font == "skin-font", "skin native Text without replacing its value")
assert(bar.Text.fontSize == 10 and row.Content.Name.fontSize == 11)
assert(bar.Fill.pixelSnapDisabled, "disable snapping on the actual Fill texture")
bar:SetFillPercent(0.75)
bar:SetText("4,500 / 6,000")
assert(bar.Fill.width == 120 and bar.Fill.coords[2] == 0.75, "native progress must still update after skinning")
assert(bar.Text.text == "4,500 / 6,000", "native hover text must still update")
acquired(row)
assert(backdropCount == 1, "reacquiring a pooled row must not duplicate its backdrop")

local retail = {
    SetStatusBarTexture = function(self, texture) self.texture = texture end,
    GetParent = bar.GetParent,
    GetFrameLevel = bar.GetFrameLevel,
    BarText = textRegion(),
}
acquired({ Content = { ReputationBar = retail } })
assert(retail.texture == "Interface\\Buttons\\WHITE8x8", "Retail must retain its StatusBar texture route")
assert(retail.BarText.font == "skin-font" and retail.BarText.fontSize == 10)
assert(retail.pixelSnapDisabled and backdropCount == 2)
print("OK: forever_reputation_skin_test")
