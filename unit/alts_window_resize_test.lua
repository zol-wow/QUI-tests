local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = readAll("modules/alts/views/window.lua")
local defaults = readAll("core/defaults.lua")
local finishStart = assert(source:find("local function FinishInteraction()", 1, true))
local finishEnd = assert(source:find('win:SetScript("OnEvent"', finishStart, true))
local eventStart = finishEnd
local eventEnd = assert(source:find("win._bg = win:CreateTexture", eventStart, true))
local pressStart = assert(source:find('resize:SetScript("OnMouseDown"', 1, true))
local releaseStart = assert(source:find('resize:SetScript("OnMouseUp"', 1, true))
local releaseEnd = assert(source:find("win._resize = resize", releaseStart, true))
local hideStart = assert(source:find('win:SetScript("OnHide"', releaseEnd, true))
local hideEnd = assert(source:find("\n    Reskin()", hideStart, true))
local finish = source:sub(finishStart, finishEnd - 1)
local event = source:sub(eventStart, eventEnd - 1)
local press = source:sub(pressStart, releaseStart - 1)
local release = source:sub(releaseStart, releaseEnd)
local hide = source:sub(hideStart, hideEnd - 1)

assert(source:find("win:SetResizable(true)", 1, true), "Alts window must be resizable")
assert(source:find("win:SetResizeBounds(MIN_W, MIN_H)", 1, true), "Alts window must enforce resize bounds")
assert(source:find('resize:SetNormalTexture("Interface\\\\ChatFrame\\\\UI-ChatIM-SizeGrabber-Up")', 1, true),
    "Alts window must expose a visible resize grip")
assert(press:find("InCombatLockdown and InCombatLockdown()", 1, true),
    "resize grip must refuse protected sizing during combat")
assert(source:find('win:StartSizing("BOTTOMRIGHT")', 1, true), "resize grip must start bottom-right sizing")
assert(press:find('interaction = "resize"', 1, true), "resize grip must latch successful sizing")
assert(release:find('interaction ~= "resize"', 1, true), "resize release must require a latched operation")
assert(release:find("FinishInteraction()", 1, true), "resize release must use guarded completion")
assert(hide:find("FinishInteraction()", 1, true), "hiding must use guarded completion")
assert(source:find('win:RegisterEvent("PLAYER_REGEN_DISABLED")', 1, true),
    "active interactions must watch for combat lockdown")
assert(event:find('event == "PLAYER_REGEN_DISABLED"', 1, true),
    "combat entry must stop an active interaction before lockdown")
assert(event:find("FinishInteraction()", 1, true),
    "combat entry must finish moving or sizing at the last safe opportunity")
assert(not finish:find("InCombatLockdown", 1, true),
    "addon-owned interaction completion must not defer the stop during combat")
assert(finish:find("interaction = nil", 1, true),
    "combat completion must clear the interaction latch immediately")
assert(finish:find('SaveGeometry(active == "resize")', 1, true),
    "deferred resize completion must persist geometry")
assert(finish:find('if active == "resize" then RefreshActiveView() end', 1, true),
    "deferred resize completion must refresh the active table")
assert(source:find("s.point, s.relativePoint, s.x, s.y", 1, true),
    "resized position must retain its relative anchor across reloads")
assert(source:find("cfg.relativePoint or cfg.point", 1, true),
    "saved geometry must restore against its original relative anchor")
assert(defaults:find('window = { point = "CENTER", relativePoint = "CENTER"', 1, true),
    "relative anchor must have a typed profile default")
assert(source:find("s.width = math.floor", 1, true), "resized width must persist")
assert(source:find("s.height = math.floor", 1, true), "resized height must persist")

print("OK: alts_window_resize_test")
