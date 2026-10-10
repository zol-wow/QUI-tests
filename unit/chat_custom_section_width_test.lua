local sourcePath = os.getenv("QUI_CHAT_SOURCE") or "QUI_Chat/chat/settings/chat_frame1_provider.lua"
local file = assert(io.open(sourcePath, "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("        local function CreateChatCustomSection", 1, true))
local last = assert(source:find("        local function ShowChatModuleReloadPrompt", first, true))
local chunk = assert((loadstring or load)("return function(content, L, PAD, CreateFrame, ShouldRenderSection)\n" .. source:sub(first, last - 1) .. "\nreturn CreateChatCustomSection\nend"))
local parent = { GetWidth = function() return 900 end }
local frame = { width = 0 }
function frame:SetPoint() end
function frame:SetHeight(height) self.height = height end
function frame:SetWidth(width) self.width = width end
function frame:GetWidth() return self.width end
local placedHeight
local layout = {
    headerAt = function() end,
    getY = function() return -36 end,
    placeCustom = function(_, height) placedHeight = height end,
}
local build = chunk()(parent, layout, 15, function() return frame end, function() return true end)
local returned = build("filters", "Filters", function(body)
    assert(body:GetWidth() == 870, "custom sections must establish inset width before measuring responsive cards")
    local columns = body:GetWidth() >= 840 and 3 or 2
    return math.ceil(48 / columns) * 32 + 60
end, 200)
assert(returned == frame and placedHeight == 572, "custom section must reserve only the measured compact card height")
print("OK: chat_custom_section_width_test")
