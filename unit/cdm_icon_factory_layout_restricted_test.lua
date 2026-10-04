local function noop() end

_G.InCombatLockdown = function() return false end
_G.UIParent = {}
_G.wipe = function(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
    return tbl
end

local tooltipOwner, tooltipAnchor
_G.GameTooltip = {
    IsForbidden = function() return false end,
    SetOwner = function(_, owner, anchor)
        tooltipOwner, tooltipAnchor = owner, anchor
    end,
    SetSpellByID = noop,
    Show = noop,
    Hide = noop,
}

local function Region()
    return {
        SetAllPoints = noop,
        SetPoint = noop,
        SetTexture = noop,
        SetDesaturated = noop,
        SetVertexColor = noop,
        SetColorTexture = noop,
        SetFont = noop,
        SetText = noop,
        SetTextColor = noop,
        SetAlpha = noop,
        Show = noop,
        Hide = noop,
    }
end

local createdFrames = {}
_G.CreateFrame = function(frameType, name, parent, template)
    local frame = {
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        shown = true,
        frameLevel = 1,
    }
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetAllPoints(target) self.allPoints = target or true end
    function frame:ClearAllPoints() self.allPoints = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetParent(value) self.parent = value end
    function frame:GetChildren()
        local children = {}
        for _, child in ipairs(createdFrames) do
            if child.parent == self then children[#children + 1] = child end
        end
        return unpack(children)
    end
    function frame:SetFrameLevel(value) self.frameLevel = value end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:RegisterForClicks(...) self.registeredClicks = { ... } end
    function frame:SetScript(script, callback) self[script] = callback end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:GetAlpha() return self.alpha or 1 end
    function frame:GetEffectiveAlpha() return self.alpha or 1 end
    function frame:CreateTexture() return Region() end
    function frame:CreateFontString() return Region() end
    if frameType == "Cooldown" then
        function frame:SetDrawSwipe(value) self.drawSwipe = value end
        function frame:SetHideCountdownNumbers(value) self.hideCountdownNumbers = value end
        function frame:SetSwipeTexture(value) self.swipeTexture = value end
        function frame:SetSwipeColor(...) self.swipeColor = { ... } end
        function frame:SetDrawBling(value) self.drawBling = value end
        function frame:Clear() self.cleared = true end
    end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local ns = {
    Helpers = {
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "" end,
        IsSecretValue = function() return false end,
        SafeValue = function(value) return value end,
    },
    CDMSources = {},
    CDMResolvers = {
        GetEntryTexture = function() return nil end,
        GetSpellTexture = function() return nil end,
        ResolveCooldownState = function() return nil end,
        ResolveMacro = function() return nil end,
        IsAuraEntry = function() return false end,
    },
}

local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_icon_factory.lua", "cdm_icon_factory.lua")("QUI", ns)
local factory = assert(ns.CDMIconFactory)
local parent = CreateFrame("Frame", "Parent", UIParent)
local entry = { id = 777, spellID = 777, type = "spell" }

local plain = factory:AcquireIcon(parent, entry, false, false)
local restricted = factory:AcquireIcon(parent, entry, false, true)
assert(plain.template == nil and plain._quiLayoutRestricted == nil,
    "ordinary icons must remain unrestricted")
assert(restricted.template == "DisableUntrustedLayoutScriptsTemplate"
    and restricted._quiLayoutRestricted == true,
    "restricted icons must opt into the template at frame creation")
assert(plain.Cooldown.template == "CooldownFrameTemplate" and plain.TextOverlay.template == nil,
    "ordinary icon children must remain unrestricted")
assert(restricted.Cooldown.template
        == "CooldownFrameTemplate, DisableUntrustedLayoutScriptsTemplate"
    and restricted.TextOverlay.template == "DisableUntrustedLayoutScriptsTemplate",
    "restricted icon children must opt into the template at frame creation")

restricted._runtimeSpellID = 777
restricted.OnEnter(restricted)
assert(tooltipOwner == UIParent and tooltipAnchor == "ANCHOR_CURSOR",
    "restricted tooltips must anchor through UIParent")

factory:ReleaseIcon(restricted)
assert(factory._recycleRestrictedPool[1] == restricted
    and #factory._recyclePool == 0,
    "restricted icons must use their isolated recycle pool")
local secondPlain = factory:AcquireIcon(parent, entry, false, false)
assert(secondPlain ~= restricted,
    "ordinary acquisition must not reuse a restricted shell")
local reusedRestricted = factory:AcquireIcon(parent, entry, false, true)
assert(reusedRestricted == restricted,
    "restricted acquisition must reuse the restricted shell")

reusedRestricted.clickButton = {}
factory:ReleaseIcon(reusedRestricted)
assert(factory._recycleRestrictedProtectedPool[1] == restricted,
    "restricted protected icons must use their isolated protected pool")
assert(factory:AcquireIcon(parent, entry, true, true) == restricted,
    "clickable restricted acquisition must reuse the protected restricted shell")

for _, layoutRestricted in ipairs({ false, true }) do
    local container = CreateFrame("Frame", nil, UIParent)
    local identities, distinct = {}, 0
    local viewerType = layoutRestricted and "buff" or "utility"
    for _ = 1, 3 do
        local pool = factory:EnsurePool(viewerType)
        for i = 1, 35 do
            local icon = factory:AcquireIcon(container, entry, false, layoutRestricted)
            pool[i] = icon
            assert(not icon.clickButton and (not not icon._quiLayoutRestricted) == layoutRestricted,
                "rebuilding must preserve plain/restricted/protected pool isolation")
            if not identities[icon] then
                identities[icon] = true
                distinct = distinct + 1
            end
            icon:Show()
        end
        assert(select("#", container:GetChildren()) == 35,
            "rebuilding a 35-icon container must not accumulate abandoned child frames")
        factory:ClearPool(viewerType)
        assert(select("#", container:GetChildren()) == 0,
            "releasing more than 20 icons must detach every child before GetChildren can overflow")
        for icon in pairs(identities) do
            assert(not icon:IsShown() and icon._spellEntry == nil,
                "released icons must remain hidden and unassigned")
        end
    end
    assert(distinct == 35,
        "repeated 35-icon rebuilds must reuse all frames instead of allocating 15 more per pass")
end

local rendererFile = assert(io.open("QUI_CDM/cdm/cdm_icon_renderer.lua", "rb"))
local rendererSource = rendererFile:read("*a")
rendererFile:close()
local clickStart = assert(rendererSource:find("local function EnsureClickButton(icon)", 1, true))
local clickStop = assert(rendererSource:find("\nlocal function ClearClickButtonAttributes", clickStart, true))
local clickSource = rendererSource:sub(clickStart, clickStop - 1)
clickSource = clickSource:gsub("^local function EnsureClickButton", "return function", 1)
local clickEnv = setmetatable({
    CDMIcons = { EnsureTextOverlayLevel = noop },
    SyncClickButtonFrameLevel = noop,
}, { __index = _G })
local clickChunk = assert(loadstring(clickSource, "@cdm_icon_renderer.lua#EnsureClickButton"))
setfenv(clickChunk, clickEnv)
local ensureClickButton = clickChunk()
local plainClick = ensureClickButton({})
local restrictedClick = ensureClickButton({ _quiLayoutRestricted = true })
assert(plainClick.template == "SecureActionButtonTemplate",
    "ordinary click overlays must remain unrestricted")
assert(restrictedClick.template
        == "SecureActionButtonTemplate, DisableUntrustedLayoutScriptsTemplate",
    "restricted click overlays must opt into the template at frame creation")

local glowFile = assert(io.open("libs/LibCustomGlow-1.0/LibCustomGlow-1.0.lua", "rb"))
local glowSource = glowFile:read("*a")
glowFile:close()
assert(glowSource:find('"Frame", GlowParent, "DisableUntrustedLayoutScriptsTemplate", FramePoolResetter', 1, true)
    and glowSource:find('"Frame", GlowParent, "DisableUntrustedLayoutScriptsTemplate", ButtonGlowResetter', 1, true)
    and glowSource:find('"Frame", GlowParent, "DisableUntrustedLayoutScriptsTemplate", ProcGlowResetter', 1, true),
    "all glow frame types must have restricted template-at-birth pools")
assert(glowSource:find("r._quiLayoutRestricted and RestrictedGlowFramePool or GlowFramePool", 1, true)
    and glowSource:find("r._quiLayoutRestricted and RestrictedButtonGlowPool or ButtonGlowPool", 1, true)
    and glowSource:find("r._quiLayoutRestricted and RestrictedProcGlowPool or ProcGlowPool", 1, true),
    "glow acquisition must select restricted pools for managed-row icons")

local effectsFile = assert(io.open("QUI_CDM/cdm/cdm_effects.lua", "rb"))
local effectsSource = effectsFile:read("*a")
effectsFile:close()
local _, restrictedEffectFrames = effectsSource:gsub(
    'icon%._quiLayoutRestricted and "DisableUntrustedLayoutScriptsTemplate" or nil', "")
assert(restrictedEffectFrames == 3,
    "texture, pandemic, and cast-highlight frames must inherit the restricted layout template")

local keybindFile = assert(io.open("modules/utility/keybinds.lua", "rb"))
local keybindSource = keybindFile:read("*a")
keybindFile:close()
local _, restrictedKeybindFrames = keybindSource:gsub(
    'icon%._quiLayoutRestricted and "DisableUntrustedLayoutScriptsTemplate" or nil', "")
assert(restrictedKeybindFrames == 2,
    "keybind text and rotation overlays must inherit the restricted layout template")

print("OK: cdm_icon_factory_layout_restricted_test")
