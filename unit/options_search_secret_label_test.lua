local secret = dofile("tests/helpers/secret_sentinel.lua")
local originalLoadfile = loadfile
local instrumented = false
_G.loadfile = function(path)
    if path == "QUI_Options/framework.lua" then
        secret.InstallSecretStub()
        instrumented = true
        return secret.LoadInstrumented(path)
    end
    return originalLoadfile(path)
end

local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert((loadstring or load)(source:sub(1, cut - 1), "@gen-preamble"))()
_G.loadfile = originalLoadfile
secret.InstallSecretStub()
assert(instrumented, "the actual options framework must use secret comparison instrumentation")

local GUI = assert(_G.QUI.GUI)
local root = CreateFrame("Frame")
local preview = CreateFrame("Frame", nil, root)
local count = preview:CreateFontString(nil, "OVERLAY")
count.GetObjectType = function() return "FontString" end
local secretText = secret.MakeSecretSentinel()
local reads = 0
count.GetText = function()
    reads = reads + 1
    return secretText
end
local target = CreateFrame("Frame", nil, root)
target._widgetLabel = "Anchor"

assert(GUI:_findWidgetByLabel(root, "Anchor") == target,
    "secret preview text must not prevent finding a later settings widget")
assert(reads == 1, "each candidate FontString must be read only once")

target._widgetLabel = nil
local label = target:CreateFontString(nil, "OVERLAY")
label.GetObjectType = function() return "FontString" end
label.GetText = function() return "Anchor" end
assert(GUI:_findWidgetByLabel(root, "Anchor") == target,
    "plain FontString labels must remain searchable after a secret preview")
assert(GUI:_findWidgetByLabel(root, "Missing") == nil,
    "a secret preview must not become a false label match")

local plain = preview:CreateFontString(nil, "OVERLAY")
plain.GetObjectType = function() return "FontString" end
plain.GetText = function() return "Anchor" end
assert(GUI:_findWidgetByLabel(root, "Anchor") == preview,
    "a secret region must not hide a later plain region in the same frame")

print("OK: options_search_secret_label_test")
