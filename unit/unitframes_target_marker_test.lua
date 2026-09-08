local file = assert(io.open("QUI_UnitFrames/unitframes/unitframes.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match("local function UpdateTargetMarker%(frame%)(.-)\nlocal function UpdateLeaderIcon"))
local secret = {}
local index, reject
local settings = { targetMarker = { enabled = true } }
local marker = { shown = false }
function marker:Show() self.shown = true end
function marker:Hide() self.shown = false end
local frame = { unitKey = "focus", targetMarker = marker }
local env = setmetatable({
    QUI_UF = { GetFrameUnit = function(f) return f.unitKey end },
    GetUnitSettings = function() return settings end,
    IsSecretValue = function(value) return value == secret end,
    GetRaidTargetIndex = function(unit)
        assert(unit == frame.unitKey)
        return index
    end,
    SetRaidTargetIconTexture = function(texture, value)
        if reject then error("sink rejected marker") end
        assert(texture == marker and value == index)
        texture.index = value
    end,
}, { __index = _G })
local chunk = assert(loadstring("return function(frame)" .. body))
setfenv(chunk, env)
local update = chunk()

for _, unit in ipairs({ "focus", "target", "player", "targettarget", "pet", "boss1" }) do
    frame.unitKey = unit
    for value = 1, 8 do
        index = value
        update(frame)
        assert(marker.shown and marker.index == value, unit .. ": visible marker")
    end
    index = secret
    update(frame)
    assert(marker.shown and marker.index == secret, unit .. ": secret marker must reach texture")
    reject = true
    update(frame)
    assert(not marker.shown, unit .. ": failed texture must hide")
    reject = false
    index = nil
    update(frame)
    assert(not marker.shown, unit .. ": unmarked unit must hide")
    index = secret
    settings.targetMarker.enabled = false
    update(frame)
    assert(not marker.shown, unit .. ": disabled marker must hide")
    settings.targetMarker.enabled = true
end
print("OK: unitframes_target_marker_test")
