local libraryPath = arg[1] or "libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"
local assetPath = "Interface\\AddOns\\QUI\\assets\\"
local locale

GetLocale = function() return locale end
getfenv = getfenv or function() return _G end
strmatch = string.match
securecallfunction = function(fn, ...) return fn(...) end
bit = { band = function(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end }

for _, path in ipairs({ "tests/api-docs/blizzard", "tests/clients/forever/api-docs/blizzard" }) do
    local docs
    APIDocumentation = { AddDocumentationTable = function(_, value) docs = value end }
    assert(loadfile(path .. "/UIFileAssetAPIDocumentation.lua"))()
    assert(docs.Namespace == "C_UIFileAsset" and docs.Environment == "All")
    local contract
    for _, fn in ipairs(docs.Functions) do
        if fn.Name == "IsKnownFile" then contract = fn end
    end
    assert(contract and contract.Arguments[1].Type == "FileAsset")
    assert(contract.Returns[1].Type == "bool" and not contract.Returns[1].Nilable)
end
APIDocumentation = nil

local function exists(path)
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
end

C_UIFileAsset = { IsKnownFile = function(data)
    if data == "Interface\\Buttons\\WHITE8X8" or data == 123456 then return true end
    if type(data) ~= "string" then return false end
    if data:sub(1, #assetPath) ~= assetPath then return false end
    local path = "assets/" .. data:sub(#assetPath + 1):gsub("\\", "/")
    return exists(path) or exists(path .. ".tga")
end }

for _, currentLocale in ipairs({ "enUS", "ruRU", "koKR", "zhCN", "zhTW" }) do
    locale, LibStub = currentLocale, nil
    assert(loadfile("libs/LibStub/LibStub.lua"))()
    assert(loadfile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
    assert(loadfile(libraryPath))()
    local lsm = LibStub("LibSharedMedia-3.0")
    local callbacks = {}
    lsm.RegisterCallback("registration-test", "LibSharedMedia_Registered", function(event, kind, key)
        assert(event == "LibSharedMedia_Registered")
        callbacks[#callbacks + 1] = { kind, key }
    end)
    for _, kind in ipairs({ "font", "background", "border", "statusbar", "sound" }) do
        local missing = assetPath .. (kind == "sound" and "missing.ogg" or "missing.ttf")
        assert(not lsm:Register(kind, "Missing", missing, 255), kind .. " must reject unknown assets")
        assert(not lsm:IsValid(kind, "Missing"))
        assert(lsm:Fetch(kind, "Missing", true) == nil)
    end
    assert(#callbacks == 0, "Rejected assets must not fire callbacks")

    local ns = { LSM = lsm, Helpers = { AssetPath = assetPath } }
    assert(loadfile("core/icon_skin.lua"))("QUI", ns)
    QUI = { Print = function() error("Western media registration must succeed") end }
    assert(loadfile("core/media.lua"))("QUI", ns)
    local expectedCount = locale == "enUS" and 53 or 47
    assert(#callbacks == expectedCount, "All eligible QUI media must register for " .. locale)
    local counts = {}
    for _, entry in ipairs(callbacks) do
        local kind, key = entry[1], entry[2]
        counts[kind] = (counts[kind] or 0) + 1
        local data = lsm:Fetch(kind, key, true)
        if kind == "qui-iconskin" then
            assert(ns.IconSkin.Resolve(key) and data == key)
        else
            assert(_G.C_UIFileAsset.IsKnownFile(data), "Missing shipped QUI asset: " .. tostring(data))
        end
    end
    assert(counts.background == 14 and counts.border == 13 and counts.statusbar == 16)
    assert(counts["qui-iconskin"] == #ns.IconSkin.GetSkinList())
    assert((counts.font or 0) == (locale == "enUS" and 6 or 0))
    assert(lsm:Fetch("statusbar", "QUI Stripes", true) == assetPath .. "absorb_stripe")
    if locale == "enUS" then QUI:CheckMediaRegistration() end

    local oldCount = #callbacks
    assert(loadfile("core/media.lua"))("QUI", ns)
    assert(#callbacks == oldCount, "Duplicate registrations must not fire callbacks")
    assert(lsm:Register("sound", "Known file ID", 123456))
    assert(lsm:Fetch("sound", "Known file ID", true) == 123456)
    local mask = lsm["LOCALE_BIT_" .. locale] or lsm.LOCALE_BIT_western
    assert(lsm:Register("font", "Local glyphs", assetPath .. "Quazii.ttf", mask))
    assert(not lsm:Register("font", "Wrong glyphs", assetPath .. "Quazii.ttf", 255 - mask))
    assert(not lsm:IsValid("font", "Wrong glyphs"))
    local list = lsm:List("font")
    assert(lsm:Register("font", "A new known font", assetPath .. "Quazii.ttf", mask))
    assert(lsm:List("font") == list)
    for i = 2, #list do assert(list[i - 1] < list[i]) end
    assert(#callbacks == oldCount + 3, "Only successful new registrations fire callbacks")
end

print("OK: LibSharedMedia rejects unknown assets and preserves every eligible QUI registration across five locales")
