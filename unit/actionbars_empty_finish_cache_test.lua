local file = assert(io.open("QUI_ActionBars/actionbars/actionbars_skinning.lua", "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find("SkinButton = function", 1, true))
local finish = assert(source:find("UpdateKeybindText = function", start, true))
local function noop() end
local icon = {
    SetTexture = function(self, value) self.texture = value end,
    SetTexCoord = noop, ClearAllPoints = noop, SetAllPoints = noop,
    SetAlpha = noop, Show = noop,
}
local button = {
    icon = icon, state = {}, barKey = "bar1", action = 1,
    GetName = function(self) return self.name end,
    GetPushedTexture = noop,
}
local db = { global = {} }
local env = setmetatable({
    ns = {}, ActionBarsOwned = { skinnedButtons = {} },
    InCombatLockdown = function() return false end,
    UpdateButtonProfessionQuality = noop,
    GetDB = function() return db end,
    GetFrameState = function(b) return b.state end,
    GetButtonIconTexture = function(b) return b.icon end,
    GetBarKeyFromButton = function(b) return b.barKey end,
    GetSafeActionSlot = function(b) return b.action end,
    HasButtonContent = function(b) return b.content end,
    StripBlizzardArtwork = noop, SuppressButtonProcVisuals = noop,
    Helpers = { ApplyIconStyle = function(_, _, skin) icon.finish = skin ~= "Empty" and skin ~= "External" end },
}, { __index = _G })
local chunk = assert(loadstring(source:sub(start, finish - 1)))
setfenv(chunk, env)
chunk()
local settings = { skinEnabled = true, showBorders = false }
env.SkinButton(button, settings)
assert(not icon.finish, "empty slots must have no Satin finish")
env.SkinButton(button, settings)
assert(not icon.finish, "cached skinning must keep empty finishes disabled")
button.content = true
env.SkinButton(button, settings)
assert(icon.finish, "adding an action must restore its finish on the cached path")
button.content = false
env.SkinButton(button, settings)
assert(not icon.finish, "removing an action must disable its finish on the cached path")
for _, barKey in ipairs({ "pet", "stance" }) do
    button.barKey = barKey
    env.SkinButton(button, settings)
    assert(icon.finish, barKey .. " icons must retain their finish")
end
button.barKey = "bar1"
for _, name in ipairs({ "SpellFlyoutButton1", "SpellFlyoutPopupButton1" }) do
    button.name = name
    env.SkinButton(button, settings)
    assert(icon.finish, "flyout icons must retain their finish")
end
button.name = nil
button.content = true
db.global.externalSkinning = true
env.ns.ExternalSkinBridge = { IsAvailable = function() return true end }
env.SkinButton(button, settings)
assert(not icon.finish, "external skinning must retain control of the icon finish")
print("OK: actionbars_empty_finish_cache_test")
