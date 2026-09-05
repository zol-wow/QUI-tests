-- tests/unit/aura_skin_text_overlay_test.lua
-- Run: lua tests/unit/aura_skin_text_overlay_test.lua
--
-- Source-text pins for the aura icon text stacking fix. The cooldown swipe
-- and the duration StatusBar are child FRAMES of the button, and child frames
-- always draw above regions created on the button itself — so duration text,
-- stack count, and the dispel symbol were rendered UNDER the swipe on every
-- shared-skin consumer (Aura Displays, Group Frames auras, ...). They must be
-- created on a dedicated overlay frame stacked above both child frames.

local function read(p)
    local h = io.open(p, "rb")
    if not h then return nil end
    local s = h:read("*a")
    h:close()
    return s
end

local fails = 0
local function check(n, ok)
    if ok then print("  ok  " .. n) else fails = fails + 1; print("FAIL  " .. n) end
end

local skin = read("core/aura_skin.lua")
local content = read("modules/trackers/settings/aura_displays_content.lua")
check("aura skin exists", skin ~= nil)
check("aura displays content exists", content ~= nil)
if not (skin and content) then
    print(("%d failures"):format(fails + 1))
    os.exit(1)
end

-- The overlay is created after the swipe + duration bar and outranks both.
check("text overlay frame is created",
    skin:find('local textOverlay = CreateFrame("Frame", nil, button)', 1, true) ~= nil)
check("text overlay outranks the swipe and the duration bar",
    skin:find("textOverlay:SetFrameLevel(math.max(cd:GetFrameLevel(), fill:GetFrameLevel()) + 1)", 1, true) ~= nil)
local overlayPos = skin:find("local textOverlay = CreateFrame", 1, true)
local cdPos = skin:find('CreateFrame("Cooldown", nil, button', 1, true)
local fillPos = skin:find('CreateFrame("StatusBar", nil, button)', 1, true)
check("overlay is created after the swipe and duration bar",
    overlayPos ~= nil and cdPos ~= nil and fillPos ~= nil
    and overlayPos > cdPos and overlayPos > fillPos)

-- All three text regions live on the overlay, not on the button.
check("duration text lives on the overlay",
    skin:find('local durText = textOverlay:CreateFontString', 1, true) ~= nil)
check("stack count lives on the overlay",
    skin:find('local count = textOverlay:CreateFontString', 1, true) ~= nil)
check("dispel symbol lives on the overlay",
    skin:find('local symbol = textOverlay:CreateFontString', 1, true) ~= nil)
check("no icon text region is created directly on the button",
    skin:find('local durText = button:CreateFontString', 1, true) == nil
    and skin:find('local count = button:CreateFontString', 1, true) == nil
    and skin:find('local symbol = button:CreateFontString', 1, true) == nil)

-- Aura Displays expose the duration decimals/hide-unit toggles the shared
-- editor gates behind caps.durationDecimals.
check("aura displays enable the duration text extras",
    content:find("durationDecimals    = true", 1, true) ~= nil)

if fails > 0 then
    print(("%d failures"):format(fails))
    os.exit(1)
end
print("OK: aura_skin_text_overlay_test")
