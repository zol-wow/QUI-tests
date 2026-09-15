local function noop() end
local frames, buttons, dropdowns = {}, {}, {}
local Frame = {}
Frame.__index = Frame
local function NewFrame(parent)
    local frame = setmetatable({ parent = parent, scripts = {}, height = 24, shown = true }, Frame)
    frames[#frames + 1] = frame
    return frame
end
for _, method in ipairs({
    "SetPoint", "ClearAllPoints", "SetAllPoints", "SetWidth", "SetFont", "SetTextColor",
    "SetJustifyH", "SetTexCoord", "SetTexture", "SetColorTexture", "SetAlpha", "SetEnabled",
    "SetOptions", "RegisterForClicks", "SetFrameStrata", "SetFrameLevel", "SetToplevel",
    "SetBackdropColor", "SetBackdropBorderColor", "EnableMouse", "SetAutoFocus", "HasFocus", "ClearFocus", "HookScript", "RegisterEvent", "UnregisterAllEvents",
}) do Frame[method] = noop end
function Frame:SetHeight(height) self.height = height end
function Frame:GetHeight() return self.height end
function Frame:SetSize(_, height) self.height = height end
function Frame:SetParent(parent) self.parent = parent end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:SetShown(shown) self.shown = shown end
function Frame:CreateTexture() return NewFrame(self) end
function Frame:CreateFontString() return NewFrame(self) end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:SetText(value)
    self.value = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Frame:GetText() return self.value end

CreateFrame = function(_, _, parent) return NewFrame(parent) end
local cursor
GetCursorInfo = function() if cursor then return unpack(cursor) end end
ClearCursor = function() cursor = nil end
C_Spell = { GetOverrideSpell = function(id) return id end, GetSpellName = function() return "Flash Heal" end }
C_Item = { GetItemInfo = function() return "Healthstone" end }
local macroName, macroBody = "Élan / mouseover", "#showtooltip\n/cast [@mouseover,help] Flash Heal"
GetMacroInfo = function(index)
    assert(index == 123)
    return macroName, 134400, macroBody
end

local GUI = { Colors = { accent = { 1, 1, 1 }, bg = { 0, 0, 0 }, textMuted = { 1, 1, 1 }, text = { 1, 1, 1 } } }
function GUI:CreateLabel(parent, text)
    local label = NewFrame(parent)
    label:SetText(text)
    return label
end
function GUI:CreateButton(parent, text, _, _, callback)
    local button = NewFrame(parent)
    button.text = self:CreateLabel(button, text)
    button:SetScript("OnClick", callback)
    buttons[text] = button
    return button
end
function GUI:CreateFormDropdown(parent, _, _, key, data, callback)
    local dropdown = NewFrame(parent)
    dropdown.SetValue = function(value, silent)
        if value == dropdown then return end
        data[key] = value
        if not silent and callback then callback(value) end
    end
    dropdowns[key] = dropdown
    return dropdown
end
QUI = { GUI = GUI }
local bindings = {}
local ns = {
    Helpers = { FoldUTF8 = string.lower },
    QUI_Options = {
        PADDING = 10, CreateAccentDotLabel = noop,
        CreateSettingsCardGroup = function(parent)
            return { frame = NewFrame(parent), AddRow = noop, Finalize = noop }
        end,
        BuildSettingRow = function(parent) return NewFrame(parent) end,
    },
    QUI_GroupFrameClickCast = {
        GetEditableBindingSetID = function() return "shared" end,
        GetBindingSetSources = function() return {} end,
        GetButtonNames = function() return { LeftButton = "Left Click" } end,
        GetModifierLabels = function() return {} end,
        GetEditableBindings = function() return bindings end,
        AddBinding = function(_, binding) bindings[#bindings + 1] = binding return true end,
    },
}
(dofile("tests/helpers/locale.lua"))(ns)
ns.L["Macro"] = "Makro"
assert(loadfile(arg[1] or "QUI_GroupFrames/groupframes/settings/click_cast_content.lua"))("QUI", ns)
local function Upvalue(fn, name, replacement)
    for index = 1, math.huge do
        local key, value = debug.getupvalue(fn, index)
        assert(key, "missing upvalue: " .. name)
        if key == name then
            if replacement then debug.setupvalue(fn, index, replacement) end
            return value
        end
    end
end
local build = Upvalue(ns.QUI_GroupFramesOptions.BuildClickCastContent, "BuildClickCastBindings")
local browse = { popup = NewFrame() }
Upvalue(build, "EnsureBrowsePopup", function() return browse end)
local state = {}
build({ headerAt = noop, offset = function() return 0 end, placeCustom = noop }, NewFrame(), {}, noop, state)
local drop = assert(buttons["Drop Spell or Item Here / Makro"])
local add = assert(buttons["Add Binding"])
local function Drop(kind)
    cursor = kind == "spell" and { "spell", 1, "spell", false, 2061 } or { kind, 123 }
    assert(drop.scripts.OnReceiveDrag())
    assert(cursor == nil, "successful drop must clear the cursor")
end
local function AssertRow(index, expectedLabel)
    for _, frame in ipairs(frames) do
        if frame.bindingIndex == index and frame.spellText then
            assert(frame.spellText:GetText() == expectedLabel, "binding list must show the saved macro name or localized fallback")
            return
        end
    end
    error("saved macro must have a visible binding row")
end
local function Save(expectedName, expectedBody)
    local count = #bindings
    add.scripts.OnClick()
    assert(#bindings == count + 1, "Add Binding must save the macro")
    local binding = bindings[#bindings]
    assert(binding.actionType == "macro")
    assert(binding.spell == (expectedName or "Macro"), "saved macro name: expected " .. tostring(expectedName) .. ", got " .. tostring(binding.spell))
    assert(binding.macroName == expectedName, "macro name metadata must retain the exact imported name")
    assert(binding.macro == expectedBody, "macro body must be preserved exactly")
    AssertRow(#bindings, expectedName or ns.L["Macro"])
end

Drop("macro")
Save(macroName, macroBody)
state.macroInput:SetText("/say second")
Save(nil, "/say second")
browse.onPick("Flash Heal")
dropdowns.actionType.SetValue("macro")
state.macroInput:SetText("/say typed")
Save(nil, "/say typed")
for _, kind in ipairs({ "spell", "item" }) do
    Drop("macro")
    Drop(kind)
    dropdowns.actionType.SetValue("macro")
    state.macroInput:SetText("/say after " .. kind)
    Save(nil, "/say after " .. kind)
end
Drop("macro")
browse.onPick("Flash Heal")
Save(macroName, macroBody)
macroName = "Macro"
Drop("macro")
Save("Macro", macroBody)
macroName = nil
Drop("macro")
Save(nil, macroBody)
for _, legacyName in ipairs({ false, "", 123 }) do
    bindings[#bindings + 1] = {
        actionType = "macro", button = "LeftButton", spell = "Macro", macro = macroBody,
        macroName = legacyName or nil,
    }
    state.RefreshBindingList()
    AssertRow(#bindings, ns.L["Macro"])
end
print("groupframes_clickcast_macro_names_test: ok")
