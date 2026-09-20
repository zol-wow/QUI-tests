local file = assert(io.open(arg[1] or "modules/dungeon/party_keystones.lua", "r"))
local source = file:read("*a")
file:close()

local positionSource = assert(source:match("local function PositionKeyTracker%(%)\n(.-)\nend"))
local tracker = { strata = "HIGH" }
function tracker:ClearAllPoints() self.point = nil end
function tracker:SetFrameStrata(strata) self.strata = strata end
function tracker:SetPoint(...) self.point = { ... } end

local settings = {
    keyTrackerPoint = "LEFT",
    keyTrackerRelPoint = "RIGHT",
    keyTrackerOffsetX = 12,
    keyTrackerOffsetY = -8,
}
local env = {
    KeyTrackerFrame = tracker,
    GetSettings = function() return settings end,
}
local position = assert(loadstring("return function()\n" .. positionSource .. "\nend"))
setfenv(position, env)
position = position()

position()
assert(tracker.point == nil, "Tracker must tolerate the instance panel not being loaded yet")

env.PVEFrame = { GetFrameStrata = function(self) return self.strata end }
for _, strata in ipairs({ "MEDIUM", "LOW", "HIGH" }) do
    env.PVEFrame.strata = strata
    position()
    assert(tracker.strata == strata, "Attached keystone list must match instance panel strata: " .. strata)
    assert(tracker.point[1] == "LEFT" and tracker.point[2] == env.PVEFrame
        and tracker.point[3] == "RIGHT" and tracker.point[4] == 12 and tracker.point[5] == -8,
        "Matching strata must preserve the configured instance panel anchor and offsets")
end

print("OK: party_keystones_strata_test")
