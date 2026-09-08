local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = readAll("modules/qol/lusttimer.lua")
for _, forbidden in ipairs({
    "GetPlayerAuraBySpellID",
    "GetAuraDuration",
    "activeInstanceID",
    "AuraEvents",
    "RegisterEvent(",
    "RegisterUnitEvent(",
    "PLAYER_REGEN_ENABLED",
    "UNIT_AURA",
    "ScanForLust",
    "SetTimerDuration",
    "SetCooldownFromDurationObject",
}) do
    assert(not source:find(forbidden, 1, true), forbidden .. " must not drive the native Lust Timer")
end

local created = {}
local auraContainers = {}
local slots = {}
local loggedIn
local restricted = false
local deferredOwner
local deferredRefresh
local settings = {
    enabled = true,
    width = 160,
    height = 22,
    xOffset = 0,
    yOffset = -120,
    showLabel = true,
    borderSize = 1,
}

local function NewFrame(kind, name, parent, template)
    local frame = {
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        shown = true,
    }
    function frame:SetPoint(...) self.point = { ... } end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetAllPoints() self.allPoints = true end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetFrameStrata(strata) self.strata = strata end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:GetFrameLevel() return self.level or 1 end
    function frame:SetColorTexture(...) self.colorTexture = { ... } end
    function frame:SetStatusBarTexture(texture) self.statusBarTexture = texture end
    function frame:SetStatusBarColor(...) self.statusBarColor = { ... } end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:SetValue(value) self.value = value end
    function frame:SetDrawSwipe(value) self.drawSwipe = value end
    function frame:SetDrawEdge(value) self.drawEdge = value end
    function frame:SetHideCountdownNumbers(value) self.hideCountdownNumbers = value end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(value) self.shown = value end
    function frame:GetParent() return self.parent end
    function frame:CreateFontString()
        return NewFrame("FontString", nil, self)
    end
    function frame:CreateTexture()
        return NewFrame("Texture", nil, self)
    end
    function frame:SetFont(...) self.font = { ... } end
    function frame:SetTextColor(...) self.textColor = { ... } end
    function frame:SetText(text) self.text = text end
    if kind == "AuraContainer" then
        function frame:SetUnit(unit) self.unit = unit end
        function frame:SetEnabled(value) self.enabled = value end
        function frame:AddAuraSlot(key, filter, options)
            local button = NewFrame("AuraButton", nil, self)
            function button:SetDurationBar(bar, opts)
                self.durationBar = bar
                self.durationBarOptions = opts
            end
            function button:SetDurationCooldown(cooldown)
                self.durationCooldown = cooldown
            end
            slots[#slots + 1] = {
                key = key,
                filter = filter,
                options = options,
                button = button,
            }
            options.initializeFrame(button)
            return button
        end
        auraContainers[#auraContainers + 1] = frame
    end
    created[#created + 1] = frame
    return frame
end

_G.UIParent = NewFrame("Frame", "UIParent")
_G.Enum = {
    StatusBarTimerDirection = { RemainingTime = 11 },
    StatusBarInterpolation = { Immediate = 22 },
}
_G.CreateFrame = NewFrame
_G.C_Secrets = {
    ShouldAurasBeSecret = function() return restricted end,
}

local ns = {
    QUI = {},
    Addon = { db = { profile = { general = {}, lustTimer = settings } } },
    Helpers = {
        CreateDBGetter = function()
            return function() return settings end
        end,
        ApplyFontWithFallback = function(fontString, path, size, flags)
            fontString:SetFont(path, size, flags)
        end,
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetSkinBorderColor = function() return 0, 0, 0, 1 end,
        BorderRegistry = { Register = function() end },
    },
    UIKit = {
        Pixels = function(value) return value end,
        ResolveFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
    },
    L = setmetatable({ Lust = "Lust" }, { __index = function(_, key) return key end }),
    WhenLoggedIn = function(callback) loggedIn = callback end,
    Registry = { Register = function() end },
    AuraGlue = {
        QueueRegenWork = function(owner, callback)
            deferredOwner = owner
            deferredRefresh = callback
        end,
    },
}

assert(loadfile("modules/qol/lusttimer.lua"))("QUI", ns)
assert(type(loggedIn) == "function", "Lust Timer must initialize through WhenLoggedIn")
loggedIn()

assert(#auraContainers == 1, "Lust Timer must create exactly one AuraContainer")
local container = auraContainers[1]
local host
for _, frame in ipairs(created) do
    if frame.name == "QUI_LustTimer" then host = frame end
end
assert(host and host.kind == "Frame", "QUI_LustTimer must remain the named movable host")
assert(container.parent == host and container.template == "CustomAuraContainerTemplate",
    "the host must own one CustomAuraContainerTemplate child")
assert(container.unit == "player" and container.enabled == true and container.shown == true,
    "the native player aura container must stay enabled and shown")
assert(#slots == 1 and type(slots[1].key) == "string" and slots[1].key ~= ""
    and slots[1].filter == "HELPFUL",
    "Lust Timer must register exactly one HELPFUL aura slot")

local expectedIDs = { [2825] = true, [32182] = true, [80353] = true, [264667] = true, [390386] = true, [466904] = true }
local included = slots[1].options.candidateFilters.includeSpellIDs
local includedCount = 0
for spellID, value in pairs(included) do
    includedCount = includedCount + 1
    assert(value == true and expectedIDs[spellID], "unexpected Lust candidate spell ID " .. tostring(spellID))
end
assert(includedCount == 6, "the native slot must include all six Lust spell IDs and no extras")

local button = slots[1].button
assert(button.durationBar and button.durationBar.kind == "StatusBar",
    "initializeFrame must bind a native duration StatusBar")
assert(button.durationBar.parent == button,
    "the native duration StatusBar must be created beneath the aura slot")
assert(button.durationBarOptions.direction == Enum.StatusBarTimerDirection.RemainingTime
    and button.durationBarOptions.interpolation == Enum.StatusBarInterpolation.Immediate,
    "the duration bar must use remaining-time immediate interpolation")
assert(button.durationCooldown and button.durationCooldown.kind == "Cooldown"
    and button.durationCooldown.parent == button.durationBar
    and button.durationCooldown.drawSwipe == false
    and button.durationCooldown.drawEdge == false
    and button.durationCooldown.hideCountdownNumbers == false,
    "initializeFrame must bind the native numeric countdown without swipe or edge")

assert(type(_G.QUI_RefreshLustTimer) == "function"
    and type(_G.QUI_ToggleLustTimerPreview) == "function",
    "legacy Lust Timer globals must remain callable")
assert(ns.QUI.LustTimer and ns.QUI.LustTimer.Refresh == _G.QUI_RefreshLustTimer
    and ns.QUI.LustTimer.TogglePreview == _G.QUI_ToggleLustTimerPreview,
    "QUI.LustTimer must preserve its refresh and preview API")
settings.enabled = false
_G.QUI_RefreshLustTimer()
assert(container.enabled == false and container.shown == false,
    "disabling Lust Timer must disable and hide the native container")
_G.QUI_ToggleLustTimerPreview(true)
assert(ns.QUI.LustTimer.IsPreviewMode() == true, "preview must turn on")
local previewBar
for _, frame in ipairs(created) do
    if frame.kind == "StatusBar" and frame.value == 0.66 then previewBar = frame end
end
assert(previewBar and previewBar.shown == true and previewBar.parent.shown == true and host.shown == true,
    "preview must show a separate 66% bar while the live feature is disabled")
_G.QUI_ToggleLustTimerPreview(false)
assert(ns.QUI.LustTimer.IsPreviewMode() == false, "preview must turn off")
assert(previewBar.parent.shown == false and host.shown == false,
    "leaving preview while disabled must hide the preview surface and host")
settings.enabled = true
_G.QUI_RefreshLustTimer()
assert(container.enabled == true and container.shown == true,
    "re-enabling Lust Timer must restore the native container")

local originalBarColor = button.durationBar.statusBarColor
settings.barColor = { 0.1, 0.2, 0.3, 0.4 }
restricted = true
_G.QUI_RefreshLustTimer()
assert(deferredOwner == host and type(deferredRefresh) == "function",
    "restricted appearance refreshes must queue against the movable host")
assert(button.durationBar.statusBarColor == originalBarColor,
    "restricted appearance refreshes must not mutate the native aura slot")
restricted = false
deferredRefresh(deferredOwner)
assert(button.durationBar.statusBarColor[1] == 0.1
    and button.durationBar.statusBarColor[2] == 0.2
    and button.durationBar.statusBarColor[3] == 0.3
    and button.durationBar.statusBarColor[4] == 0.4,
    "the queued appearance refresh must replay after restrictions lift")

print("OK: lusttimer_native_aura_test")
