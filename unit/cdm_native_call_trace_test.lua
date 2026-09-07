local ns = {}
local output, timers = {}, {}
local owners = setmetatable({}, { __mode = "k" })
local realPrint = print
function print(...) output[#output + 1] = table.concat({...}, " ") end
function issecretvalue() return false end
function issecurevariable(object, key)
    local owner = owners[object] and owners[object][key]
    return owner == nil, owner
end
function debugstack() return "test stack" end
C_Timer = { NewTicker = function(_, callback)
    local timer = { callback = callback, Cancel = function(self) self.cancelled = true end }
    timers[#timers + 1] = timer
    return timer
end }

local provider = { displayData = {} }
CooldownViewerSettings = { dataProvider = provider }
assert(loadfile("QUI_Debug/cdm_taint_trace.lua"))("QUI_Debug", ns)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_boot.lua"))("QUI_CDM", ns)
local trace = ns.CDMTaintTrace
local call = ns.CDMReanchorBoot._CallNativeWidget
local frame, widget, seen = {}, {}, {}
local function setter(self, ...)
    assert(self == widget)
    seen = { n = select("#", ...), ... }
end
call(frame, widget, "SetSwipeColor", setter, 1, nil, false)
assert(seen.n == 3 and seen[1] == 1 and seen[2] == nil and seen[3] == false)
assert(#output == 0 and #timers == 0, "disabled tracing must stay idle")

trace:Start()
assert(ns.CDMNativeCallTrace == trace)
call(frame, widget, "SetSwipeColor", setter, 1, nil, false)
assert(not trace.report and trace.calls == 1)
call(frame, widget, "SetUseAuraDisplayTime", function()
    owners[provider] = { displayData = "QUI_CDM" }
end)
assert(trace.report[1]:find("during SetUseAuraDisplayTime", 1, true))
assert(trace.report[2]:find("provider.displayData -> QUI_CDM", 1, true))
assert(ns.CDMNativeCallTrace == nil and timers[#timers].cancelled)

trace:Start()
assert(ns.CDMNativeCallTrace == nil, "already-tainted baseline must not start")
owners[provider] = nil
trace:Start()
call(frame, widget, "SetDrawSwipe", function()
    owners[frame] = { auraInstanceID = "QUI_CDM" }
end)
assert(trace.report[2]:find("item.auraInstanceID -> QUI_CDM", 1, true),
    "nil-valued native fields must be checked too")

owners[frame] = nil
trace:Start()
owners[provider] = { displayData = "QUI_CDM" }
timers[#timers].callback()
assert(trace.report[1]:find("periodic sample", 1, true))
assert(not trace.report[1]:find("during", 1, true))

owners[provider] = nil
trace:Start()
owners[provider] = { displayData = "QUI_CDM" }
call(frame, widget, "SetDrawEdge", setter, false)
assert(trace.report[1]:find("already present on entry", 1, true))
assert(seen.n == 1 and seen[1] == false, "recording must not suppress the setter")

owners[provider] = nil
trace:Start()
call(frame, widget, "outer", function()
    call(frame, widget, "inner", function()
        owners[provider] = { displayData = "QUI_CDM" }
    end)
end)
assert(trace.report[1]:find("during inner", 1, true))
assert(trace.calls == 2 and ns.CDMNativeCallTrace == nil)

owners[provider] = nil
trace:Start()
local ok, err = pcall(call, frame, widget, "raises", function()
    owners[provider] = { displayData = "QUI_CDM" }
    error("original setter error", 0)
end)
assert(not ok and err == "original setter error", "setter errors must propagate unchanged")
assert(not trace.report, "an unfinished call must not be reported as a completed boundary")
timers[#timers].callback()
assert(trace.report[1]:find("periodic sample", 1, true))

owners[provider] = nil
trace:Start()
trace:Checkpoint("spec event entry")
assert(not trace.report and trace.lastClean == "spec event entry")
owners[provider] = { displayData = "QUI_CDM" }
trace:Checkpoint("profile restored")
assert(trace.report[1]:find("before checkpoint: profile restored", 1, true))
assert(trace.report[3]:find("spec event entry", 1, true))
assert(ns.CDMNativeCallTrace == nil)

owners[provider] = nil
trace:Start()
local timer = timers[#timers]
for _ = 1, 300 do timer.callback() end
assert(timer.cancelled and ns.CDMNativeCallTrace == nil and not trace.report)
assert(output[#output]:find("no transition captured", 1, true))
print = realPrint
print("OK: cdm_native_call_trace_test")
