local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = readAll("modules/alts/views/window.lua")
local releaseStart = assert(source:find('resize:SetScript("OnMouseUp"', 1, true))
local releaseEnd = assert(source:find("win._resize = resize", releaseStart, true))
local release = source:sub(releaseStart, releaseEnd)

assert(source:find("win:SetResizable(true)", 1, true), "Alts window must be resizable")
assert(source:find("win:SetResizeBounds(MIN_W, MIN_H)", 1, true), "Alts window must enforce resize bounds")
assert(source:find('resize:SetNormalTexture("Interface\\\\ChatFrame\\\\UI-ChatIM-SizeGrabber-Up")', 1, true),
    "Alts window must expose a visible resize grip")
assert(source:find('win:StartSizing("BOTTOMRIGHT")', 1, true), "resize grip must start bottom-right sizing")
assert(release:find("SaveGeometry(true)", 1, true), "resize release must persist size and position")
assert(source:find("s.point, s.relativePoint, s.x, s.y", 1, true),
    "resized position must retain its relative anchor across reloads")
assert(source:find("cfg.relativePoint or cfg.point", 1, true),
    "saved geometry must restore against its original relative anchor")
assert(source:find("s.width = math.floor", 1, true), "resized width must persist")
assert(source:find("s.height = math.floor", 1, true), "resized height must persist")
assert(release:find("RefreshActiveView()", 1, true), "resize release must refresh the active table")

print("OK: alts_window_resize_test")
