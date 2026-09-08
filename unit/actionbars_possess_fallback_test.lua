local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end

local env = setmetatable({}, { __index = _G })
local function run(source, scope)
    local chunk = assert(loadstring(source))
    setfenv(chunk, scope or env)
    return chunk()
end
local function extract(path, name)
    local source = read(path)
    local first = assert(source:find("function " .. name .. "(", 1, true))
    local last = assert(source:find("\nend", first, true))
    run(source:sub(first, last + 3))
end

local flags, combat = {}, false
env.SecureCmdOptionParse = function(condition)
    for clause in condition:gmatch("[^;]+") do
        local matches, conditional = false, false
        for flag in clause:gmatch("%[([^%]]+)%]") do
            conditional = true
            matches = matches or flags[flag] == true
        end
        if not conditional or matches then
            return clause:gsub("%[[^%]]+%]", ""):match("^%s*(.-)%s*$")
        end
    end
end
env.InCombatLockdown = function() return combat end
env.UnitInVehicle = function() return flags.inVehicle end
env.HasVehicleActionBar = function() return flags.vehicle end
env.HasOverrideActionBar = function() return flags.override end
env.HasTempShapeshiftActionBar = function() return false end
env.HasBonusActionBar = function() return flags.bonus end
env.GetVehicleBarIndex = function() return 12 end
env.GetOverrideBarIndex = function() return 14 end
env.GetBonusBarIndex = function() return 7 end
env.C_PetBattles = { IsInBattle = function() return flags.petbattle end }
env.GetBindingKey = function() return "1" end
env.GetBindingAction = function() return "ACTIONBUTTON1" end
env.ClearOverrideBindings = function(frame) frame.binding = nil end
env.SetOverrideBindingClick = function(frame, _, key, name)
    frame.binding = { key, name }
end
env.BINDING_COMMANDS = { bar1 = "ACTIONBUTTON" }
env.ActionBarsOwned = { containers = {}, nativeButtons = { bar1 = {{
    GetAttribute = function() end,
    GetName = function() return "QUI_Button1" end,
}} } }
env.RegisterStateDriver = function(frame, state, condition)
    frame.drivers[state] = condition
end
env.CreateFrame = function()
    local frame = { attributes = {}, drivers = {} }
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:SetClampedToScreen() end
    function frame:HookScript() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:ChildUpdate(_, offset) self.offset = offset end
    function frame:Execute(source)
        run(source, setmetatable({ self = self }, { __index = env }))
    end
    return frame
end

local editmode = "QUI_ActionBars/actionbars/actionbars_editmode.lua"
extract("QUI_ActionBars/actionbars/actionbars_helpers.lua", "CreateBarContainer")
for _, name in ipairs({ "IsVehicleBarActive", "IsPetBattleActive",
    "ApplyBarOverrideBindings", "BuildPagingCondition", "SetupBar1Paging" }) do
    extract(editmode, name)
end
local main = env.CreateBarContainer("bar1")
local sibling = env.CreateBarContainer("bar2")
env.ActionBarsOwned.containers.bar1 = main
env.SetupBar1Paging(main)
local function update(frame, state)
    local value = env.SecureCmdOptionParse(frame.drivers[state])
    run(frame:GetAttribute("_onstate-" .. state), setmetatable({
        self = frame, control = frame, newstate = value,
    }, { __index = env }))
end

for _, case in ipairs({
    { name = "skinless vehicle possession", flags = { possessbar = true, vehicle = true, inVehicle = true }, page = 12 },
    { name = "bonus possession", flags = { possessbar = true, bonus = true }, page = 7 },
    { name = "skinless override possession", flags = { possessbar = true, override = true }, page = 14 },
}) do
    flags = case.flags
    update(main, "quioverride")
    update(sibling, "quioverride")
    update(main, "page")
    env.ApplyBarOverrideBindings("bar1")
    assert(main.shown, case.name .. ": main bar must be visible")
    assert(not sibling.shown, case.name .. ": sibling must stay hidden")
    assert(main:GetAttribute("qui-action-page") == case.page, case.name .. ": wrong page")
    assert(main.offset == (case.page - 1) * 12, case.name .. ": wrong button offset")
    assert(main.binding and main.binding[2] == "QUI_Button1", case.name .. ": binding must target owned button")
end

combat = true
flags = { possessbar = true, vehicle = true, inVehicle = true }
update(main, "quioverride")
update(main, "page")
env.ApplyBarOverrideBindings("bar1")
assert(main.shown and main.offset == 132 and main.binding, "combat possession must retain visible paged bar and bindings")
assert(env.ActionBarsOwned.pendingBindings, "combat rebinding must defer")
combat = false

for _, state in ipairs({ "vehicleui", "overridebar", "petbattle" }) do
    flags = { [state] = true }
    update(main, "quioverride")
    env.ApplyBarOverrideBindings("bar1")
    assert(not main.shown, state .. ": main bar must hide")
    assert(not main.binding, state .. ": native bindings must take over")
end
flags = {}
update(main, "quioverride")
update(main, "page")
env.ApplyBarOverrideBindings("bar1")
assert(main.shown and main.offset == 0 and main.binding, "ordinary bar must restore after exit")
main:SetAttribute("qui-user-shown", false)
main:Hide()
flags = { possessbar = true }
update(main, "quioverride")
assert(not main.shown, "possession must preserve explicit user-hidden bar")
print("OK: actionbars_possess_fallback_test")
