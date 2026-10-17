-- Run: lua tests/unit/keybind_text_layering_test.lua

local function noop() end

function wipe(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function issecretvalue(value)
    return type(value) == "table" and rawget(value, "secretStrataValue") == true
end

function InCombatLockdown()
    return false
end

function GetTime()
    return 2
end

function GetSpecialization()
    return nil
end

function GetSpecializationInfo()
    return nil
end

function GetInventoryItemID()
    return nil
end

function GetActionInfo()
    return "macro", 1
end

function GetActionText()
    return "UseRank1002"
end

function GetBindingKey(bindingName)
    if bindingName == "ACTIONBUTTON1" then
        return "G"
    end
    return nil
end

function GetMacroInfo(macroIndex)
    if macroIndex == 1 then
        return "UseRank1002", nil, "/use Rank 1002"
    end
    return nil
end

function GetMacroSpell()
    return nil
end

UIParent = {}
C_Item = {
    GetItemInfo = function(itemInfo)
        if itemInfo == 1002 then
            return "Rank 1002"
        end
        if itemInfo == "Rank 1002" then
            return "Rank 1002"
        end
        return "Item " .. tostring(itemInfo)
    end,
}
C_Spell = {
    GetSpellInfo = function()
        return nil
    end,
}
C_Timer = {
    After = noop,
}
C_Widget = {
    IsFrameWidget = function(object)
        return type(object) == "table" and type(rawget(object, "GetObjectType")) == "function"
    end,
}

local createdFrames = {}
local fontStrings = {}
local strataReads, strataWrites = 0, 0
local secretStrata = { __eq = function() error("cannot compare secret frame strata") end }

local function SetNativeStrata(frame, strata, secret)
    frame.frameStrata, frame.secretStrata = strata, secret
    for _, child in ipairs(frame.children) do
        SetNativeStrata(child, strata, secret)
    end
end

local function NewFontString(parent, layer, sublevel)
    local fontString = {
        parent = parent,
        layer = layer,
        sublevel = sublevel,
        shown = false,
    }

    function fontString:GetParent()
        return self.parent
    end
    function fontString:SetShadowOffset() end
    function fontString:SetShadowColor() end
    function fontString:SetText(text)
        self.text = text
    end
    function fontString:GetText()
        return self.text
    end
    function fontString:Show()
        self.shown = true
    end
    function fontString:Hide()
        self.shown = false
    end
    function fontString:IsShown()
        return self.shown
    end
    function fontString:ClearAllPoints()
        self.point = nil
    end
    function fontString:SetPoint(...)
        self.point = { ... }
    end
    function fontString:SetFont(font, size, outline)
        self.font = font
        self.fontSize = size
        self.fontOutline = outline
    end
    function fontString:SetTextColor(r, g, b, a)
        self.textColor = { r, g, b, a }
    end

    fontStrings[#fontStrings + 1] = fontString
    return fontString
end

local function NewFrame(frameType, parent)
    local frame = {
        frameType = frameType,
        parent = parent,
        frameLevel = parent and parent.frameLevel or 1,
        frameStrata = parent and parent.frameStrata or "LOW",
        secretStrata = parent and parent.secretStrata,
        children = {},
        shown = true,
    }
    if parent then parent.children[#parent.children + 1] = frame end

    function frame:GetParent()
        return self.parent
    end
    function frame:SetAllPoints(target)
        self.allPoints = target or true
    end
    function frame:GetFrameLevel()
        return self.frameLevel
    end
    function frame:SetFrameLevel(level)
        self.frameLevel = level
    end
    function frame:GetFrameStrata()
        strataReads = strataReads + 1
        if self.secretStrata then
            return setmetatable({ secretStrataValue = true }, secretStrata)
        end
        return self.frameStrata
    end
    function frame:SetFrameStrata(strata)
        assert(not issecretvalue(strata), "addon cannot pass secret frame strata")
        strataWrites = strataWrites + 1
        SetNativeStrata(self, strata, false)
    end
    function frame:CreateFontString(_, layer, _, sublevel)
        return NewFontString(self, layer, sublevel)
    end
    function frame:RegisterEvent() end
    function frame:SetScript() end
    function frame:Show()
        self.shown = true
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:IsShown()
        return self.shown
    end

    return frame
end

function CreateFrame(frameType, _, parent)
    local frame = NewFrame(frameType, parent)
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local icon = NewFrame("Frame", nil)
icon.frameLevel = 10
icon._spellEntry = {
    type = "item",
    id = 1002,
    viewerType = "customQuality",
    _isCustomEntry = true,
}
icon.Cooldown = NewFrame("Cooldown", icon)
icon.Cooldown.frameLevel = 20
icon.TextOverlay = NewFrame("Frame", icon)
icon.TextOverlay.frameLevel = 30

_G.QUI_Bar1Button1 = {
    action = 1,
    HotKey = {
        GetText = function()
            return "F"
        end,
    },
    GetName = function()
        return "QUI_Bar1Button1"
    end,
    GetObjectType = function()
        return "CheckButton"
    end,
}

local container = {
    GetChildren = function()
        return icon
    end,
}
local viewer = {
    viewerFrame = container,
}

local core = {
    db = {
        profile = {
            keybindOverridesEnabledCDM = true,
            keybindOverridesEnabledTrackers = true,
            viewers = {},
            ncdm = {
                containers = {
                    customQuality = {
                        showKeybinds = true,
                    },
                },
            },
        },
        char = {
            keybindOverrides = {
                [0] = {},
            },
        },
    },
}

local addon = {
    QUICore = core,
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end,
    Helpers = {
        GetCore = function()
            return core
        end,
        GetCurrentSpecID = function()
            local specIndex = GetSpecialization and GetSpecialization()
            local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
            return type(specID) == "number" and specID or nil
        end,
        CanAccessTable = function()
            return true
        end,
        CanAccessValue = function()
            return true
        end,
        CreateStateTable = function()
            return setmetatable({}, { __mode = "k" })
        end,
        GetGeneralFont = function()
            return "Fonts\\FRIZQT__.TTF"
        end,
        GetGeneralFontOutline = function()
            return "OUTLINE"
        end,
    },
}

_G.QUI = addon
_G.QUI_GetCDMViewerFrame = function(viewerName)
    if viewerName == "customQuality" then
        return viewer
    end
    return nil
end

-- FormatKeybind now lives in core (core/utils.lua); in-game the core addon
-- loads before this LoadOnDemand module and sets ns.FormatKeybind on the shared
-- namespace. Mirror that ordering by grafting the real core function onto the
-- namespace (via a throwaway load) without disturbing this test's Helpers stubs.
do
    local coreNs = {}
    LibStub = function() return nil end
    assert(loadfile("core/utils.lua"))("QUI", coreNs)
    LibStub = nil
    addon.FormatKeybind = coreNs.FormatKeybind
end

assert(loadfile(arg[1] or "modules/utility/keybinds.lua"))("QUI", addon)

addon.Keybinds.UpdateViewer("customQuality")

local keybindLayer
for _, frame in ipairs(createdFrames) do
    if frame.parent == icon.TextOverlay and frame.allPoints == icon.TextOverlay then
        keybindLayer = frame
        break
    end
end

assert(keybindLayer, "CDM keybind text layer should be parented to the icon TextOverlay")
assert(fontStrings[#fontStrings] and fontStrings[#fontStrings].parent == keybindLayer,
    "CDM keybind text should be created on the TextOverlay child layer")
assert(fontStrings[#fontStrings].layer == "OVERLAY",
    "CDM keybind text should remain on the overlay draw layer")
assert(fontStrings[#fontStrings].text == "G",
    "CDM item keybind text should prefer stable bindings over transient button text")

local initialLayer, initialText = keybindLayer, fontStrings[#fontStrings]
icon.TextOverlay:SetFrameStrata("HIGH")
addon.Keybinds.UpdateViewer("customQuality")
assert(keybindLayer.frameStrata == "HIGH" and keybindLayer.frameLevel == 40,
    "reused QUI parent must retain inherited strata and cooldown-relative text level")
SetNativeStrata(icon.TextOverlay, "DIALOG", true)
local readsBefore, writesBefore = strataReads, strataWrites
addon.Keybinds.UpdateViewer("customQuality")
assert(strataReads == readsBefore and strataWrites == writesBefore,
    "native secret strata must remain inherited without addon reads or writes")
assert(initialText:IsShown() and initialText.text == "G" and keybindLayer.secretStrata,
    "secret native parent changes must preserve visible keybind text")

icon.TextOverlay = NewFrame("Frame", icon)
SetNativeStrata(icon.TextOverlay, "TOOLTIP", true)
readsBefore, writesBefore = strataReads, strataWrites
addon.Keybinds.UpdateViewer("customQuality")
keybindLayer = createdFrames[#createdFrames]
assert(keybindLayer.parent == icon.TextOverlay and keybindLayer ~= initialLayer
    and not initialLayer:IsShown() and not initialText:IsShown(),
    "changing native parents must replace and hide the old keybind layer")
assert(keybindLayer.secretStrata and keybindLayer.frameStrata == "TOOLTIP"
    and strataReads == readsBefore and strataWrites == writesBefore,
    "new keybind layers must inherit native secret strata without copying it")
icon.TextOverlay:SetFrameStrata("MEDIUM")
addon.Keybinds.UpdateViewer("customQuality")
assert(not keybindLayer.secretStrata and keybindLayer.frameStrata == "MEDIUM"
    and fontStrings[#fontStrings]:IsShown(),
    "reused layer must follow a parent returning to plain strata")

icon._spellEntry = nil
addon.Keybinds.UpdateViewer("customQuality")
assert(fontStrings[#fontStrings].text == "G" and fontStrings[#fontStrings]:IsShown(),
    "CDM keybind text should survive a transient frame-identity read failure")

print("OK: keybind_text_layering_test")
