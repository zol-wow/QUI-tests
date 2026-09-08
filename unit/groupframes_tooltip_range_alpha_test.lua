local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local createFrame = CreateFrame
CreateFrame = function(...)
    local frame = createFrame(...)
    frame.SetSize = function() end
    frame.SetPoint = function() end
    frame.SetClampedToScreen = function() end
    return frame
end
assert(loadfile("modules/qol/tooltip_provider.lua"))("QUI", ns)

local provider = assert(ns.TooltipProvider)
local alpha = 0.4
local owner = {
    _quiDecorated = true,
    GetEffectiveAlpha = function() return alpha end,
}

local file = assert(io.open("modules/qol/tooltip.lua", "r"))
local source = file:read("*a")
file:close()
local startPos = assert(source:find("local function ShouldHideOwnedTooltip(", 1, true))
local endPos = assert(source:find("local gtTooltipHadUnit", startPos, true))
local chunk = assert(loadstring(source:sub(startPos, endPos - 1) .. "\nreturn ShouldHideOwnedTooltip"))
local inCombat = false
local allowTooltips = true
setfenv(chunk, {
    Provider = provider,
    IsTooltipFrameOwner = function() return false end,
    InCombatLockdown = function() return inCombat end,
    ResolveTooltipVisibilityContext = function() return "frames" end,
})
provider.ShouldShowTooltip = function() return allowTooltips end
local shouldHide = chunk()
local tooltip = { GetOwner = function() return owner end }

for _, combat in ipairs({ false, true }) do
    inCombat = combat
    for _, opacity in ipairs({ 0.1, 0.4, 0.5, 1 }) do
        alpha = opacity
        assert(not shouldHide(tooltip), "range-dimmed group frames must retain player tooltips")
    end
    alpha = 0
    assert(shouldHide(tooltip), "fully transparent group frames must still suppress tooltips")
    owner._quiDecorated = nil
    alpha = 0.4
    assert(shouldHide(tooltip), "unrelated faded owners must still suppress tooltips")
    alpha = 0.5
    assert(not shouldHide(tooltip), "the existing fade threshold must remain unchanged")
    owner._quiDecorated = true
end

inCombat = false
alpha = 0.4
allowTooltips = false
assert(shouldHide(tooltip), "group frame tooltip visibility settings must still apply")
allowTooltips = true
ns.Helpers.IsSecretValue = function(value) return value == alpha end
assert(not shouldHide(tooltip), "secret alpha must remain treated as visible")

print("OK: groupframes_tooltip_range_alpha_test")
