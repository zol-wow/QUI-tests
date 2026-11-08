local file = assert(io.open("QUI_UnitFrames/unitframes/castbar.lua", "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function UpdateSpellText(", 1, true))
local stop = assert(source:find("local function UpdateTimeTextColor(", start, true))
local secretText, secretName = {}, {}
local lastTruncated
local chunk = assert(loadstring(source:sub(start, stop - 1) .. "\nreturn UpdateSpellText"))
setfenv(chunk, setmetatable({
    IsSecretValue = function(value) return rawequal(value, secretText) or rawequal(value, secretName) end,
    GetGeneralSettings = function() return {} end,
    TruncateName = function(value, limit)
        lastTruncated = value
        if rawequal(value, secretText) or rawequal(value, secretName) then return value end
        return value:sub(1, limit)
    end,
}, { __index = _G }))
local UpdateSpellText = chunk()
local label = {
    SetText = function(self, text) self.text = text end,
    SetTextColor = function() end,
}
local function Check(text, name, expected, limit)
    UpdateSpellText({ spellText = label }, text, name, { maxLength = limit }, "player")
    assert(rawequal(label.text, expected), "cast labels must use the first available nonempty display or spell name")
end
Check("", "Opening", "Opening")
Check(nil, "Gathering", "Gathering")
Check("Collecting Supplies", "Opening", "Collecting Supplies")
Check("", "", "Casting...")
Check(nil, nil, "Casting...")
Check("", "Gathering", "Gath", 4)
assert(lastTruncated == "Gathering", "truncation must follow fallback selection")
Check(secretText, "Opening", secretText)
Check("", secretName, secretName)
Check(nil, secretName, secretName, 4)
assert(rawequal(lastTruncated, secretName), "restricted names must reach the existing secret-aware truncation path")
UpdateSpellText({}, "", "Opening", {}, "player")
print("OK: castbar empty display text fallback")
