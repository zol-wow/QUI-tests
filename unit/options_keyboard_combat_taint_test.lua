-- tests/unit/options_keyboard_combat_taint_test.lua
-- Run: lua tests/unit/options_keyboard_combat_taint_test.lua

local inCombat = true
local focused

function InCombatLockdown()
    return inCombat
end

function GetCurrentKeyBoardFocus()
    return focused
end

function IsControlKeyDown()
    return false
end

C_Timer = {
    After = function(_, callback)
        callback()
    end,
}

local frame = {
    scripts = {},
    hidden = false,
    propagateCalls = 0,
}

function frame:EnableKeyboard() end
function frame:SetScript(script, handler) self.scripts[script] = handler end
function frame:Hide() self.hidden = true end
function frame:SetPropagateKeyboardInput()
    self.propagateCalls = self.propagateCalls + 1
    if inCombat then
        error("SetPropagateKeyboardInput called in combat", 2)
    end
end

QUI = {
    GUI = {
        CreateMainFrame = function()
            return frame
        end,
        AddSidebarSearchBar = function() end,
        AddToolsStripButton = function() end,
        SeedStaticSearchRoutesFromTiles = function() end,
        SelectFeatureTile = function() end,
        FocusSearchBox = function() end,
    },
}

-- init.lua indexes ns.L["..."] at load (post-i18n); install identity resolver.
local nsOpt = {}
local installLocale = dofile("tests/helpers/locale.lua")
installLocale(nsOpt)
assert(loadfile("QUI_Options/init.lua"))("QUI_Options", nsOpt)

QUI.GUI:InitializeOptions()
assert(type(frame.scripts.OnKeyDown) == "function", "options panel should install an OnKeyDown handler")

local ok, err = pcall(frame.scripts.OnKeyDown, frame, "ESCAPE")
assert(ok, "combat ESC path must not call SetPropagateKeyboardInput: " .. tostring(err))
assert(frame.hidden, "ESC should still hide the options panel in combat")
assert(frame.propagateCalls == 0, "combat key path must skip restricted keyboard propagation")

focused = {}
local flyoutOpen = true
QUI.GUI.HandleNavigationKey = function(_, _, key)
    if key == "ESCAPE" and flyoutOpen then
        flyoutOpen = false
        return true
    end
    return false
end
frame.hidden = false
frame.scripts.OnKeyDown(frame, "ESCAPE")
assert(not flyoutOpen and not frame.hidden, "focused search Escape closes the flyout before the window")
assert(frame.propagateCalls == 0, "focused flyout Escape skips restricted propagation in combat")
frame.scripts.OnKeyDown(frame, "ESCAPE")
assert(frame.hidden, "the next Escape closes the window")

print("OK: options_keyboard_combat_taint_test")
