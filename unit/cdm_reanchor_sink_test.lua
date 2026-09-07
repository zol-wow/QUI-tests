local ns = {}
assert(loadfile("QUI_CDM/cdm/cdm_reanchor.lua"))("QUI", ns)

local calls = {}
local raw = {
    ClearAllPoints = function(frame) frame.points = {} end,
    SetPoint = function(frame, point, relativeTo, relativePoint, x, y)
        frame.points[point] = { relativeTo, relativePoint, x, y }
    end,
    SetAlpha = function(frame, alpha) frame.alpha = alpha end,
}
local function hook(owner, method, callback)
    local original = owner[method]
    owner[method] = function(...)
        original(...)
        callback(...)
    end
end
local function newFrame()
    return {
        points = {},
        shown = true,
        alpha = 1,
        ClearAllPoints = raw.ClearAllPoints,
        SetPoint = raw.SetPoint,
        SetAlpha = raw.SetAlpha,
        Hide = function() error("suppression must preserve the native shown lifecycle") end,
        SetParent = function() error("suppression must preserve native parent ownership") end,
        Cooldown = {
            SetDrawSwipe = function() calls[#calls + 1] = "swipe" end,
        },
    }
end
local screen, container = {}, {}
local bridge = ns.CDMReanchor.New({
    raw = raw,
    sinkAnchor = screen,
    hooksecurefunc = hook,
    securecall = function(fn, ...) return fn(...) end,
})
local function isOnScreen(frame)
    if not frame.shown or frame.alpha == 0 then return false end
    for _, point in pairs(frame.points) do
        if point[1] == container or (math.abs(point[3]) < 1000 and math.abs(point[4]) < 1000) then
            return true
        end
    end
    return false
end
local frame = newFrame()
bridge:InstallAnchorGuard(frame)
bridge:Overlay(frame, container)
assert(isOnScreen(frame), "a claimed cooldown must render over its QUI container")
bridge:Sink(frame)
assert(not bridge:IsClaimed(frame), "sinking releases the placement claim")
assert(frame.alpha == 0 and frame.shown, "sinking hides pixels while preserving native activity")
raw.SetAlpha(frame, 1)
assert(not isOnScreen(frame), "an unclaimed cooldown must stay offscreen when opacity is reset without a SetAlpha hook")
frame:SetPoint("CENTER", screen, "CENTER", 0, 0)
raw.SetAlpha(frame, 1)
assert(not isOnScreen(frame), "native layout must not move an unclaimed cooldown back onscreen")
bridge:OverlayRect(frame, container, "TOPLEFT", 4, -6, "TOPLEFT", 44, -46)
assert(isOnScreen(frame), "reclaiming a parked cooldown restores visible pixels")
assert(frame.points.TOPLEFT[1] == container and frame.points.TOPLEFT[3] == 4,
    "reclaiming restores the requested rectangle")
assert(frame.points.CENTER == nil, "reclaiming removes old native grid and parking anchors")
assert(#calls == 0, "suppression must not alter Blizzard cooldown timing or swipe state")

local unclaimed = newFrame()
bridge:Sink(unclaimed)
unclaimed:SetPoint("CENTER", screen, "CENTER", 0, 0)
raw.SetAlpha(unclaimed, 1)
assert(not isOnScreen(unclaimed), "sinking a never-claimed frame must also guard later native layout")

local buff = newFrame()
bridge:InstallAnchorGuard(buff)
bridge:Overlay(buff, container)
bridge:Sink(buff, true)
assert(buff.alpha == 0 and buff.points.TOPLEFT[1] == container,
    "buff suppression keeps native layout geometry while hiding the icon")
buff:SetPoint("CENTER", screen, "CENTER", 0, 0)
assert(buff.points.CENTER[1] == screen and buff.alpha == 0,
    "buff layout keeps its own anchors while an unclaimed buff stays transparent")
bridge:Overlay(buff, container)
assert(isOnScreen(buff), "a suppressed buff can be reclaimed")

local recursiveRaw = {
    ClearAllPoints = function(f) f:ClearAllPoints() end,
    SetPoint = function(f, ...) f:SetPoint(...) end,
    SetAlpha = raw.SetAlpha,
}
local recursive = ns.CDMReanchor.New({
    raw = recursiveRaw,
    sinkAnchor = screen,
    hooksecurefunc = hook,
    securecall = function(fn, ...) return fn(...) end,
})
local recycled = newFrame()
recursive:InstallAnchorGuard(recycled)
recursive:Sink(recycled)
recycled:SetPoint("CENTER", screen, "CENTER", 0, 0)
raw.SetAlpha(recycled, 1)
assert(not isOnScreen(recycled), "a hooked raw setter must park without recursive layout calls")

print("OK: cdm_reanchor_sink_test")
