-- Regression for the full Inspect viewport's default camera margin.
-- Pixel fit remains verified live; execute the actual positioning function here.
local file = assert(io.open("modules/skinning/character_pane/inspect.lua", "rb"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function PositionInspectModelScene()", 1, true))
local stop = assert(source:find("local function CalculateInspectAverageILvl", start, true))
local body = source:sub(start, stop - 1)
local function run(hasDistanceAPI)
    local calls, distance = {}, 1
    local model = {}
    for _, name in ipairs({ "ClearAllPoints", "SetPoint", "SetFrameLevel", "Show", "RefreshCamera", "ResetModel" }) do
        model[name] = function() calls[#calls + 1] = name end
    end
    if hasDistanceAPI then
        model.SetCamDistanceScale = function(_, value)
            calls[#calls + 1] = "distance"
            distance = value
        end
    end
    local env = setmetatable({ InspectModelFrame = model, InspectFrame = {} }, { __index = _G })
    local chunk = assert(loadstring(body .. "\nreturn PositionInspectModelScene"))
    setfenv(chunk, env)
    local position = chunk()
    position()
    if hasDistanceAPI then
        assert(distance == 1.2, "full Inspect default must leave room for horns, feet and weapons")
        distance = 1
        position()
        assert(distance == 1.2, "reopening/tab layout must restore the same camera margin")
        assert(calls[#calls - 1] == "distance" and calls[#calls] == "Show",
            "camera margin must be applied after native camera/zoom resets, before showing")
    end
end
run(true)
run(false)
print("Inspect model camera margin: default, repeated setup, optional API passed")
