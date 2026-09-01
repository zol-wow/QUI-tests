-- incoming_casts_collapse_test.lua
-- Behavioral test for the personal incoming-cast display's collapse mode
-- (modules/trackers/incoming_casts.lua): secret target verdicts routed
-- through C_CurveUtil.EvaluateColorValueFromBoolean into SetScale, chain
-- anchoring per growth direction, free-slot scale parking, the
-- gap-layout fallback when the curve probe fails, and the fail-open latch
-- when a live secret SetScale errors.

local function fail(msg)
    print("FAIL: incoming_casts_collapse_test - " .. msg)
    os.exit(1)
end

local function eq(got, want, what)
    if got ~= want then
        fail(what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end

---------------------------------------------------------------------------
-- Secret-value simulation: marker registry, errors on arithmetic/compare.
---------------------------------------------------------------------------
local secrets = setmetatable({}, { __mode = "k" })
local function MakeSecret(label)
    local s = setmetatable({}, {
        __add = function() error("secret arithmetic") end,
        __concat = function() error("secret concat") end,
        __tostring = function() error("secret tostring") end,
    })
    secrets[s] = label or true
    return s
end
issecretvalue = function(v) return secrets[v] ~= nil end -- luacheck: ignore

---------------------------------------------------------------------------
-- Widget stub: records SetPoint/SetScale/SetAlpha calls per frame.
---------------------------------------------------------------------------
local function NewStubRegion(kind, parent, capture, scaleBehavior)
    local f = {
        _kind = kind, _parent = parent, _points = {},
        _alpha = 1, _shown = false, _scaleLog = {},
    }
    function f:SetSize(w, h) self._w, self._h = w, h end
    function f:SetPoint(point, rel, relPoint, x, y)
        self._points[#self._points + 1] =
            { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
    end
    function f:ClearAllPoints() self._points = {} end
    function f:Hide() self._shown = false end
    function f:Show() self._shown = true end
    function f:IsShown() return self._shown end
    function f:SetAlpha(a) self._alpha = a end
    function f:SetAlphaFromBoolean(v, hi, lo) self._alphaBool = { v = v, hi = hi, lo = lo } end
    function f:SetScale(s)
        if scaleBehavior == "reject-secrets" and secrets[s] then
            error("attempted to set scale to a secret value")
        end
        self._scaleLog[#self._scaleLog + 1] = s
    end
    function f:GetFrameLevel() return 1 end
    function f:SetFrameLevel() end
    function f:SetBackdrop() end
    function f:SetBackdropBorderColor() end
    function f:RegisterEvent() end
    function f:SetScript() end
    function f:SetAllPoints() end
    function f:SetDrawEdge() end
    function f:SetSwipeColor() end
    function f:SetReverse() end
    function f:SetDrawSwipe() end
    function f:SetHideCountdownNumbers() end
    function f:SetCooldown() end
    function f:CreateTexture()
        local t = {}
        function t:SetAllPoints() end
        function t:SetTexCoord() end
        function t:SetTexture(tex) self._tex = tex end
        return t
    end
    if capture then capture[#capture + 1] = f end
    return f
end

---------------------------------------------------------------------------
-- Environment builder: loads the module fresh with configurable stubs.
---------------------------------------------------------------------------
local curveMeta = setmetatable({}, { __mode = "k" }) -- curve output -> {input, ifTrue, ifFalse}
local targetVerdicts = {} -- "<caster>target" -> verdict (plain or secret)

local function LoadDisplay(opts)
    opts = opts or {}
    local capture = {}
    local db = opts.db or { enabled = true }

    UIParent = NewStubRegion("Frame", nil, nil, opts.scaleBehavior) -- luacheck: ignore
    InCombatLockdown = function() return false end -- luacheck: ignore
    CreateFrame = function(kind, _, parent) -- luacheck: ignore
        return NewStubRegion(kind, parent, capture, opts.scaleBehavior)
    end
    UnitIsUnit = function(unit, other) -- luacheck: ignore
        if other ~= "player" then fail("UnitIsUnit compared against " .. tostring(other)) end
        return targetVerdicts[unit]
    end
    C_CurveUtil = { -- luacheck: ignore
        EvaluateColorValueFromBoolean = function(b, ifTrue, ifFalse)
            if opts.quantizingCurve then
                return b == true and math.floor(ifTrue) or math.floor(ifFalse)
            end
            if secrets[b] then
                local out = MakeSecret("curve-output")
                curveMeta[out] = { input = b, ifTrue = ifTrue, ifFalse = ifFalse }
                return out
            end
            return b == true and ifTrue or ifFalse
        end,
    }
    SlashCmdList = {} -- luacheck: ignore

    local subscriber
    local ns = {
        Helpers = {
            CreateDBGetter = function() return function() return db end end,
            IsSecretValue = function(v) return secrets[v] ~= nil end,
            GetSkinBorderColor = function() return 0, 0, 0, 1 end,
        },
        IncomingCasts = {
            Subscribe = function(_, o) subscriber = o; return true end,
            Unsubscribe = function() subscriber = nil end,
            ResetSubscriber = function() end,
        },
        WhenLoggedIn = function(fn) fn() end,
    }
    assert(loadfile("core/safecall.lua"))("QUI", ns)
    assert(loadfile("modules/trackers/incoming_casts.lua"))("QUI", ns)

    local host = ns.QUI_IncomingCasts.GetFrame()
    local env = { ns = ns, db = db, host = host, capture = capture }
    function env.icons()
        local out = {}
        for i = 1, #capture do
            local f = capture[i]
            if f._kind == "Frame" and f._parent == host then out[#out + 1] = f end
        end
        return out
    end
    function env.driver()
        if not subscriber then fail("engine subscriber not registered") end
        return subscriber
    end
    return env
end

local CAST = { texture = 135812, startMS = 0, endMS = 2000 }
local lastScale = function(icon) return icon._scaleLog[#icon._scaleLog] end
local lastPoint = function(icon) return icon._points[#icon._points] end

local function checkPoint(icon, point, rel, relPoint, x, y, what)
    local p = lastPoint(icon)
    if not p then fail(what .. ": no point set") end
    eq(p.point, point, what .. " point")
    if p.rel ~= rel then fail(what .. ": wrong relative frame") end
    eq(p.relPoint, relPoint, what .. " relPoint")
    eq(p.x, x, what .. " x")
    eq(p.y, y, what .. " y")
end

---------------------------------------------------------------------------
-- A: default CENTER, collapse on — chain shape, secret scale sink, parking
---------------------------------------------------------------------------
local env = LoadDisplay()
local icons = env.icons()
eq(#icons, 5, "A: pooled icons")
for i = 1, 5 do
    eq(lastScale(icons[i]), 0.01, "A: free slot " .. i .. " parked collapsed")
end

-- CENTER seam: odd slots pack leftward, even rightward (spacing 4)
checkPoint(icons[1], "RIGHT", env.host, "CENTER", -2, 0, "A: icon1")
checkPoint(icons[2], "LEFT", env.host, "CENTER", 2, 0, "A: icon2")
checkPoint(icons[3], "RIGHT", icons[1], "LEFT", -4, 0, "A: icon3")
checkPoint(icons[4], "LEFT", icons[2], "RIGHT", 4, 0, "A: icon4")
checkPoint(icons[5], "RIGHT", icons[3], "LEFT", -4, 0, "A: icon5")

-- secret verdict: scale comes from the curve helper, ifTrue=1 / ifFalse=0.01
local verdict = MakeSecret("aimed-at-me")
targetVerdicts["np1target"] = verdict
env.driver().onShow("np1", nil, CAST)
local s = lastScale(icons[1])
if not secrets[s] then fail("A: secret verdict must yield a secret scale") end
local meta = curveMeta[s]
if not meta or meta.input ~= verdict then fail("A: curve fed with wrong verdict") end
eq(meta.ifTrue, 1, "A: curve ifTrue")
eq(meta.ifFalse, 0.01, "A: curve ifFalse")
if not icons[1]._alphaBool or icons[1]._alphaBool.v ~= verdict then
    fail("A: alpha sink not fed with verdict")
end

-- plain verdicts (open world): direct scale writes
targetVerdicts["np2target"] = true
targetVerdicts["np3target"] = false
env.driver().onShow("np2", nil, CAST)
env.driver().onShow("np3", nil, CAST)
eq(lastScale(icons[2]), 1, "A: plain true -> full scale")
eq(lastScale(icons[3]), 0.01, "A: plain false -> collapsed")

-- release re-parks the slot
env.driver().onHide("np2")
eq(lastScale(icons[2]), 0.01, "A: released slot parked collapsed")
eq(icons[2]._shown, false, "A: released slot hidden")

---------------------------------------------------------------------------
-- B: grow RIGHT — single chain with uniform leading offsets
---------------------------------------------------------------------------
env = LoadDisplay({ db = { enabled = true, growDirection = "RIGHT", spacing = 6, maxIcons = 3 } })
icons = env.icons()
eq(#icons, 3, "B: pooled icons")
checkPoint(icons[1], "LEFT", env.host, "LEFT", 6, 0, "B: icon1")
checkPoint(icons[2], "LEFT", icons[1], "RIGHT", 6, 0, "B: icon2")
checkPoint(icons[3], "LEFT", icons[2], "RIGHT", 6, 0, "B: icon3")

---------------------------------------------------------------------------
-- C: collapse disabled — absolute gap layout, slots at full scale
---------------------------------------------------------------------------
env = LoadDisplay({ db = { enabled = true, collapseGaps = false, growDirection = "RIGHT", maxIcons = 2 } })
icons = env.icons()
eq(lastScale(icons[1]), 1, "C: free slot at full scale")
checkPoint(icons[1], "LEFT", env.host, "LEFT", 0, 0, "C: icon1 absolute")
checkPoint(icons[2], "LEFT", env.host, "LEFT", 44, 0, "C: icon2 absolute stride")
targetVerdicts["np4target"] = MakeSecret("gap-mode")
env.driver().onShow("np4", nil, CAST)
for _, sc in ipairs(icons[1]._scaleLog) do
    if secrets[sc] then fail("C: no secret may reach SetScale with collapse off") end
end

---------------------------------------------------------------------------
-- D: curve helper quantizes floats — probe fails, gap layout from the start
---------------------------------------------------------------------------
env = LoadDisplay({ quantizingCurve = true, db = { enabled = true, growDirection = "RIGHT", maxIcons = 2 } })
icons = env.icons()
eq(lastScale(icons[1]), 1, "D: quantizing curve -> slots at full scale")
checkPoint(icons[2], "LEFT", env.host, "LEFT", 44, 0, "D: absolute layout")

---------------------------------------------------------------------------
-- E: SetScale rejects secrets at runtime — latch off, fail open to gaps
---------------------------------------------------------------------------
env = LoadDisplay({ scaleBehavior = "reject-secrets",
    db = { enabled = true, growDirection = "RIGHT", maxIcons = 2 } })
icons = env.icons()
eq(lastScale(icons[1]), 0.01, "E: collapse initially engaged")
targetVerdicts["np5target"] = MakeSecret("rejected")
env.driver().onShow("np5", nil, CAST)
for i = 1, #icons do
    eq(lastScale(icons[i]), 1, "E: icon " .. i .. " failed open to full scale")
end
checkPoint(icons[2], "LEFT", env.host, "LEFT", 44, 0, "E: re-laid out absolutely")
-- and the latch holds for later casts
targetVerdicts["np6target"] = MakeSecret("rejected-2")
env.driver().onShow("np6", nil, CAST)
eq(lastScale(icons[2]), 1, "E: latched — later casts stay full scale")

print("PASS: incoming_casts_collapse_test")
