local file = assert(io.open("QUI_UnitFrames/unitframes/castbar.lua", "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function UpdateSpellText(", 1, true))
local stop = assert(source:find("local function UpdateTimeTextColor(", start, true))
local secretText, secretName, secretID = {}, {}, {}
local lastTruncated
local chunk = assert(loadstring(source:sub(start, stop - 1) .. "\nreturn UpdateSpellText"))
local env = setmetatable({
    OPENING = "Opening",
    IsSecretValue = function(value)
        return rawequal(value, secretText) or rawequal(value, secretName) or rawequal(value, secretID)
    end,
    GetGeneralSettings = function() return {} end,
    TruncateName = function(value, limit)
        lastTruncated = value
        if rawequal(value, secretText) or rawequal(value, secretName) then return value end
        return value:sub(1, limit)
    end,
}, { __index = _G })
env._G = env
setfenv(chunk, env)
local UpdateSpellText = chunk()
local label = {
    SetText = function(self, text) self.text = text end,
    SetTextColor = function() end,
}
local function Check(text, name, expected, limit, spellID)
    UpdateSpellText({ spellText = label, channelSpellID = spellID }, text, name, { maxLength = limit }, "player")
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
Check("", "Opening - No Text", "Opening", nil, 22810)
Check("Opening - No Text", "Opening - No Text", "Opening", nil, 22810)
Check("Collecting Supplies", "Opening - No Text", "Collecting Supplies", nil, 22810)
Check("", "Opening - No Text", "Opening - No Text", nil, 999)
Check("", "Opening - No Text", "Opening - No Text", nil, secretID)
Check(secretText, "Opening - No Text", secretText, nil, 22810)
Check("", secretName, secretName, nil, 22810)
env.OPENING = "Ouvrir"
Check("", "Ouverture - Sans texte", "Ouvrir", nil, 22810)
Check("", "Ouverture - Sans texte", "Ouv", 3, 22810)
env.OPENING = nil
Check("", "Opening - No Text", "Opening - No Text", nil, 22810)
UpdateSpellText({}, "", "Opening", {}, "player")
print("OK: castbar empty display text fallback")
