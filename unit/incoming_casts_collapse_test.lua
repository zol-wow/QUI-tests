local function fail(msg)
    print("FAIL: incoming_casts_collapse_test - " .. msg)
    os.exit(1)
end

local function eq(got, want, what)
    if got ~= want then
        fail(what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end

local secrets = setmetatable({}, { __mode = "k" })

local function MakeSecret()
    local value = setmetatable({}, {
        __add = function() error("secret arithmetic") end,
        __concat = function() error("secret concat") end,
        __tostring = function() error("secret tostring") end,
    })
    secrets[value] = true
    return value
end

issecretvalue = function(value) return secrets[value] ~= nil end -- luacheck: ignore

local function NewRegion(kind, parent, capture)
    local frame = {
        _kind = kind,
        _parent = parent,
        _points = {},
        _scaleLog = {},
        _shown = false,
    }
    function frame:SetSize(width, height) self._width, self._height = width, height end
    function frame:SetPoint(point, relative, relativePoint, x, y)
        self._points[#self._points + 1] = {
            point = point,
            relative = relative,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end
    function frame:ClearAllPoints() self._points = {} end
    function frame:Hide() self._shown = false end
    function frame:Show() self._shown = true end
    function frame:IsShown() return self._shown end
    function frame:SetAlpha(alpha) self._alpha = alpha end
    function frame:SetAlphaFromBoolean(value, high, low)
        self._alphaBoolean = { value = value, high = high, low = low }
    end
    function frame:SetScale(scale)
        if secrets[scale] then
            error("SetScale refuses secret arguments from addon execution")
        end
        self._scaleLog[#self._scaleLog + 1] = scale
    end
    function frame:GetFrameLevel() return 1 end
    function frame:SetFrameLevel() end
    function frame:SetBackdrop() end
    function frame:SetBackdropBorderColor() end
    function frame:RegisterEvent(event)
        self._events = self._events or {}
        self._events[event] = true
    end
    function frame:SetScript(script, handler)
        self._scripts = self._scripts or {}
        self._scripts[script] = handler
    end
    function frame:SetAllPoints() end
    function frame:SetDrawEdge() end
    function frame:SetSwipeColor() end
    function frame:SetReverse() end
    function frame:SetDrawSwipe() end
    function frame:SetHideCountdownNumbers() end
    function frame:SetCooldown() end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetTexCoord() end
        function texture:SetTexture(value) self._texture = value end
        return texture
    end
    if capture then
        capture[#capture + 1] = frame
    end
    return frame
end

local function LoadDisplay(db)
    local capture = {}
    local targets = {}
    local subscriber
    local inCombat = false
    db = db or { enabled = true }

    UIParent = NewRegion("Frame") -- luacheck: ignore
    InCombatLockdown = function() return inCombat end -- luacheck: ignore
    CreateFrame = function(kind, _, parent) -- luacheck: ignore
        return NewRegion(kind, parent, capture)
    end
    UnitIsUnit = function(unit, other) -- luacheck: ignore
        if other ~= "player" then
            fail("UnitIsUnit compared against " .. tostring(other))
        end
        return targets[unit]
    end
    SlashCmdList = {} -- luacheck: ignore

    local ns = {
        Helpers = {
            CreateDBGetter = function() return function() return db end end,
            IsSecretValue = function(value) return secrets[value] ~= nil end,
            GetSkinBorderColor = function() return 0, 0, 0, 1 end,
        },
        IncomingCasts = {
            Subscribe = function(_, callbacks)
                subscriber = callbacks
                return true
            end,
            Unsubscribe = function() subscriber = nil end,
            ResetSubscriber = function() end,
        },
        WhenLoggedIn = function(callback) callback() end,
    }

    assert(loadfile("core/safecall.lua"))("QUI", ns)
    assert(loadfile("modules/trackers/incoming_casts.lua"))("QUI", ns)

    local host = ns.QUI_IncomingCasts.GetFrame()
    local env = { db = db, targets = targets, host = host, ns = ns }
    function env.setCombat(value)
        inCombat = value
    end
    function env.frameCount()
        return #capture
    end
    function env.fire(event)
        for i = 1, #capture do
            local frame = capture[i]
            if frame._events and frame._events[event] and frame._scripts and frame._scripts.OnEvent then
                frame._scripts.OnEvent(frame, event)
            end
        end
    end
    function env.icons()
        local icons = {}
        for i = 1, #capture do
            local frame = capture[i]
            if frame._kind == "Frame" and frame._parent == host then
                icons[#icons + 1] = frame
            end
        end
        return icons
    end
    function env.driver()
        if not subscriber then
            fail("engine subscriber not registered")
        end
        return subscriber
    end
    return env
end

local function lastScale(icon)
    return icon._scaleLog[#icon._scaleLog]
end

local function checkPoint(icon, point, relative, relativePoint, x, y, what)
    local got = icon._points[#icon._points]
    if not got then
        fail(what .. ": no point set")
    end
    eq(got.point, point, what .. " point")
    if got.relative ~= relative then
        fail(what .. ": wrong relative frame")
    end
    eq(got.relativePoint, relativePoint, what .. " relative point")
    eq(got.x, x, what .. " x")
    eq(got.y, y, what .. " y")
end

local cast = { texture = 135812, startMS = 0, endMS = 2000 }

local env = LoadDisplay()
local icons = env.icons()
eq(#icons, 150, "nameplate-sized pool")
for i = 1, 5 do
    eq(lastScale(icons[i]), 0.01, "free slot " .. i)
    eq(icons[i]._inUse, false, "preallocated slot " .. i .. " is free")
end
checkPoint(icons[1], "CENTER", env.host, "CENTER", 0, 0, "center icon 1")
checkPoint(icons[2], "LEFT", icons[1], "RIGHT", 4, 0, "center icon 2")
checkPoint(icons[3], "RIGHT", icons[1], "LEFT", -4, 0, "center icon 3")
checkPoint(icons[4], "LEFT", icons[2], "RIGHT", 4, 0, "center icon 4")
checkPoint(icons[5], "RIGHT", icons[3], "LEFT", -4, 0, "center icon 5")

env = LoadDisplay({ enabled = true, maxIcons = false, borderSize = false })
icons = env.icons()
eq(env.host._width, 216, "invalid max icons uses default")
eq(icons[1]._borderSize, 1, "invalid border size uses default")

local secretTarget = MakeSecret()
env.targets.nameplate1target = secretTarget
env.driver().onShow("nameplate1", nil, cast)
eq(lastScale(icons[1]), 1, "restricted target keeps a fixed gap")
if not icons[1]._alphaBoolean or icons[1]._alphaBoolean.value ~= secretTarget then
    fail("restricted target was not sent to the alpha sink")
end
for i = 1, #icons[1]._scaleLog do
    if secrets[icons[1]._scaleLog[i]] then
        fail("secret target reached SetScale")
    end
end

env.targets.nameplate2target = true
env.targets.nameplate3target = false
env.driver().onShow("nameplate2", nil, cast)
env.driver().onShow("nameplate3", nil, cast)
eq(lastScale(icons[2]), 1, "readable player target")
eq(lastScale(icons[3]), 0.01, "readable hidden target")
env.driver().onHide("nameplate2")
eq(lastScale(icons[2]), 0.01, "released slot")
eq(icons[2]._shown, false, "released slot hidden")
eq(icons[2]._inUse, false, "released slot keeps reusable bookkeeping")

env = LoadDisplay({ enabled = true, growDirection = "RIGHT", spacing = 6, maxIcons = 3 })
icons = env.icons()
checkPoint(icons[1], "LEFT", env.host, "LEFT", 0, 0, "right icon 1")
checkPoint(icons[2], "LEFT", icons[1], "RIGHT", 6, 0, "right icon 2")
checkPoint(icons[3], "LEFT", icons[2], "RIGHT", 6, 0, "right icon 3")

env = LoadDisplay({ enabled = true, collapseGaps = false, growDirection = "RIGHT", maxIcons = 2 })
icons = env.icons()
eq(lastScale(icons[1]), 1, "fixed-layout free slot")
checkPoint(icons[1], "LEFT", env.host, "LEFT", 0, 0, "fixed icon 1")
checkPoint(icons[2], "LEFT", env.host, "LEFT", 44, 0, "fixed icon 2")
env.targets.nameplate4target = MakeSecret()
env.driver().onShow("nameplate4", nil, cast)
eq(lastScale(icons[1]), 1, "fixed-layout restricted target")

env = LoadDisplay({ enabled = true, maxIcons = 1 })
icons = env.icons()
eq(#icons, 150, "layout max does not cap cast capacity")
for i = 1, 150 do
    env.driver().onShow("nameplate" .. i, nil, cast)
end
env.setCombat(true)
local framesBeforeOverflow = env.frameCount()
env.driver().onShow("nameplate151", nil, cast)
eq(env.frameCount(), framesBeforeOverflow, "combat overflow creates no regions")
eq(#env.icons(), 150, "combat overflow defers pool growth")
env.setCombat(false)
env.fire("PLAYER_REGEN_ENABLED")
eq(#env.icons(), 151, "deferred pool growth runs after combat")

print("PASS: incoming_casts_collapse_test")
