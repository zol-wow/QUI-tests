local function noop() end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = read("QUI_ActionBars/actionbars/settings/action_bars_content.lua")
local buttonSource = assert(source:match("(local keybindBtn = GUI:CreateButton.-\n    end%))"))
local combat, libraryLookups, libraryToggles, highlights, captured = false, 0, 0, 0, nil
local listener = {}
function listener:StartListening(command, slot) self.command, self.slot = command, slot end
function listener:IsListening() return self.command ~= nil end
function listener:OnKeyDown(key) captured = { command = self.command, slot = self.slot, key = key } end
local ns = {
    ActionBarsOwned = { useNativeButtons = true },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}
local callback
local library = { Toggle = function() libraryToggles = libraryToggles + 1 end }
local env = setmetatable({
    ns = ns, s3 = { frame = {} },
    GUI = { CreateButton = function(_, _, _, _, _, onClick) callback = onClick end },
    InCombatLockdown = function() return combat end,
    LibStub = function()
        libraryLookups = libraryLookups + 1
        return library
    end,
    GetCurrentBindingSet = function() return 1 end,
    Enum = { BindingSet = { Character = 2 } },
    ActionButtonUtil = {
        ShowAllActionButtonGrids = noop,
        ShowAllQuickKeybindButtonHighlights = function() highlights = highlights + 1 end,
    },
    ExtraActionBar_ForceShowIfNeeded = noop,
    KeybindListener = listener,
    GetBindingKey = function() return "ESCAPE" end,
}, { __index = _G })
env._G = env
local function evaluate(text)
    local chunk = assert(loadstring(text))
    setfenv(chunk, env)
    chunk()
end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
evaluate(read(corpus .. "Blizzard_QuickKeybind/QuickKeybind.lua"))
evaluate(assert(read(corpus .. "Blizzard_SharedXML/BindingUtil.lua"):match(
    "(function KeybindFrames_InQuickKeybindMode%b().-\nend)")))
local quick = setmetatable({
    shown = false, UseCharacterBindingsButton = { SetChecked = noop }, ClearOutputText = noop,
}, { __index = env.QuickKeybindFrameMixin })
function quick:IsShown() return self.shown end
function quick:Show()
    assert(not combat, "native keybind mode cannot open during combat")
    self.shown = true
    self:OnShow()
end
env.QuickKeybindFrame = quick
env.ShowUIPanel = function(frame) frame:Show() end
evaluate(buttonSource)
combat = true
callback()
assert(not quick.shown and libraryLookups == 0, "combat must skip both native and library keybind modes")
combat = false
callback()
assert(quick.shown and highlights == 1 and libraryLookups == 0,
    "native presentation must open Blizzard keybinding even when LibKeyBound is bundled")
local button = setmetatable({
    commandName = "ACTIONBUTTON1", scripts = {}, QuickKeybindButtonSetTooltip = noop,
    QuickKeybindHighlightTexture = { SetAlpha = noop },
}, { __index = env.QuickKeybindButtonTemplateMixin })
function button:GetScript(event) return self.scripts[event] end
function button:SetScript(event, script) self.scripts[event] = script end
assert(button.SetKey == nil and button.GetHotkey == nil,
    "native button must not gain LibKeyBound compatibility methods")
button:QuickKeybindButtonOnEnter()
quick:OnKeyDown("K")
assert(captured and captured.command == "ACTIONBUTTON1" and captured.slot == 1 and captured.key == "K",
    "native hover and key input must reach Blizzard's listener with the original binding command")
ns.ActionBarsOwned.useNativeButtons = false
quick.shown = false
callback()
assert(libraryToggles == 1 and libraryLookups == 1 and not quick.shown,
    "owned Retail buttons must retain the existing LibKeyBound mode")
combat = true
callback()
assert(libraryToggles == 1 and libraryLookups == 1, "Retail capture must remain disabled in combat")
combat = false
library = nil
callback()
assert(quick.shown and highlights == 2, "Retail without LibKeyBound must preserve its native fallback")

print("OK: native keybind settings use Blizzard hover/key dispatch; Retail retains LibKeyBound and combat guards")
