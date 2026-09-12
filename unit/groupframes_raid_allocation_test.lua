local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = read(os.getenv("QUI_GROUPFRAMES_SOURCE") or "QUI_GroupFrames/groupframes/groupframes.lua")
local nativeSource = read("tests/framexml/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua")
local failures = 0
local function check(name, condition, detail)
    if condition then
        print("  ok  " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name .. (detail and (": " .. tostring(detail)) or ""))
    end
end

local function harness(groupBy)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local function chunk(text, name)
        return setfenv(assert(loadstring(text, name)), env)
    end
    local state = { roster = {}, combat = false, widgets = {}, timers = {}, styles = 0 }
    local function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
    env.wipe = wipe
    env.table = setmetatable({ wipe = wipe }, { __index = table })
    env.string = setmetatable({ trim = function(s) return s:match("^%s*(.-)%s*$") end }, { __index = string })
    env.strsplit = function(sep, text)
        local parts = {}
        for part in (text .. sep):gmatch("(.-)" .. sep) do parts[#parts + 1] = part end
        return unpack(parts)
    end
    env.strtrim = env.string.trim
    env.scrub = function(value) return value end
    env.format = string.format
    env.InCombatLockdown = function() return state.combat end
    env.IsInRaid = function() return #state.roster > 0 end
    env.IsInGroup = env.IsInRaid
    env.GetNumGroupMembers = function() return #state.roster end
    env.GetNumSubgroupMembers = function() return 0 end
    local function member(unit)
        local index = unit and tonumber(unit:match("^raid(%d+)$"))
        return index and state.roster[index] or (unit == "player" and state.roster[1])
    end
    env.UnitExists = function(unit) return unit == "player" or member(unit) ~= nil end
    env.UnitName = function(unit) local m = member(unit); return m and m.name or "Player", nil end
    env.UnitClass = function(unit) local m = member(unit); return "Mage", m and m.class or "MAGE" end
    env.UnitGroupRolesAssigned = function(unit) local m = member(unit); return m and m.role or "DAMAGER" end
    env.UnitIsUnit = function(a, b) return a == b or (member(a) and member(a) == member(b)) end
    env.UnitGUID = function(unit) local m = member(unit); return m and m.name or unit end
    env.UnitIsPlayer = function() return true end
    env.UnitIsConnected = function() return true end
    env.GetPartyAssignment = function() return false end
    env.GetRaidRosterInfo = function(i)
        local m = state.roster[i]
        if m then return m.name, 0, m.group, 80, m.class, m.class, "", true, false, nil, false, m.role end
    end
    env.GetInstanceInfo = function() return "Raid", "raid", 14 end
    env.GetTime = function() return 10 end
    env.issecretvalue = function() return false end
    env.RAID_CLASS_COLORS = { MAGE = { r = 1, g = 1, b = 1 } }
    env.C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end }
    env.RegisterUnitWatch = function() end
    env.UnregisterUnitWatch = function() end
    env.RegisterStateDriver = function() end
    env.UnregisterStateDriver = function() end
    env.GetFrameHandle = function(frame) return frame end
    env.GetManagedEnvironment = function() return env end
    env.CallRestrictedClosure = function(_, _, _, _, code, frame)
        chunk("local self = ...\n" .. code, "secure header initialization")(frame)
    end
    local Frame = {}
    Frame.__index = Frame
    function Frame:GetName() return self.name end
    function Frame:GetParent() return self.parent end
    function Frame:SetParent(parent) self.parent = parent end
    function Frame:GetAttribute(key) return self.attrs[key] end
    function Frame:SetAttribute(key, value)
        if self.attrs[key] == value then return end
        self.attrs[key] = value
        if self.secure then env.SecureGroupHeader_OnAttributeChanged(self, key, value) end
    end
    function Frame:CallMethod(method, ...) return self[method](self, ...) end
    function Frame:SetScript(key, fn) self.scripts[key] = fn end
    function Frame:GetScript(key) return self.scripts[key] end
    function Frame:IsShown() return self.shown end
    function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    local function reveal(frame)
        if not frame:IsVisible() then return end
        if frame.secure then env.SecureGroupHeader_Update(frame) end
        for _, child in ipairs(frame.children) do reveal(child) end
    end
    function Frame:Show()
        if self.shown then return end
        self.shown = true
        reveal(self)
    end
    function Frame:Hide() self.shown = false end
    function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function Frame:SetSize(w, h) self.width, self.height = w, h end
    function Frame:SetWidth(w) self.width = w end
    function Frame:SetHeight(h) self.height = h end
    function Frame:GetWidth() return self.width or 100 end
    function Frame:GetHeight() return self.height or 40 end
    function Frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function Frame:ClearAllPoints() wipe(self.points) end
    function Frame:GetNumPoints() return #self.points end
    function Frame:GetPoint(i) return unpack(self.points[i or 1] or {}) end
    function Frame:SetFrameLevel(level) self.level = level end
    function Frame:GetFrameLevel() return self.level or 1 end
    function Frame:GetEffectiveScale() return 1 end
    function Frame:GetScale() return 1 end
    function Frame:SetAlpha(alpha) self.alpha = alpha end
    function Frame:GetAlpha() return self.alpha or 1 end
    function Frame:GetLeft() return 0 end
    function Frame:GetRight() return self:GetWidth() end
    function Frame:GetTop() return self:GetHeight() end
    function Frame:GetBottom() return 0 end
    function Frame:GetCenter() return 0, 0 end
    for _, method in ipairs({ "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "EnableMouse", "SetMovable", "SetClampedToScreen", "SetAllPoints", "SetOrientation", "SetScale", "SetText", "SetFont", "SetTextColor", "SetJustifyH", "SetDrawLayer" }) do
        Frame[method] = function() end
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = setmetatable({ kind = kind, name = name, parent = parent, attrs = {}, scripts = {}, children = {}, points = {}, shown = true }, Frame)
        state.widgets[#state.widgets + 1] = frame
        if name then env[name] = frame end
        if parent then parent.children[#parent.children + 1] = frame end
        frame.secure = template == "SecureGroupHeaderTemplate"
        if frame.secure then frame.shown = false end
        if frame.secure then env.SecureGroupHeader_OnLoad(frame) end
        return frame
    end
    function Frame:CreateFontString() return env.CreateFrame("FontString", nil, self) end
    env.UIParent = env.CreateFrame("Frame", "UIParent")
    chunk(nativeSource, "@SecureGroupHeaders.lua")()
    local db = {
        enabled = true,
        party = { dimensions = { partyWidth = 200, partyHeight = 40 }, layout = {}, general = {}, power = {} },
        raid = { dimensions = { smallRaidWidth = 100, smallRaidHeight = 40, mediumRaidWidth = 90, mediumRaidHeight = 35, largeRaidWidth = 80, largeRaidHeight = 30 }, layout = { groupBy = groupBy }, general = {}, power = {} },
    }
    env.QUI = { db = { profile = { hudLayering = { groupFrames = 7 } } } }
    local ns = {
        Addon = { GetHUDFrameLevel = function(_, level) return level * 10 end },
        QUI_GroupFrameIconLayout = {},
        Helpers = {
            IsSecretValue = env.issecretvalue,
            SafeValue = function(value, default) if value == nil then return default end; return value end,
            SafeToNumber = tonumber,
            NameListContains = function(names, name) return names and names[name] or false end,
            CreateDBGetter = function() return function() return db end end,
            GetCore = function() return env.QUI end,
            CreateStateTable = function()
                local values = {}
                return values, function(frame) values[frame] = values[frame] or {}; return values[frame] end
            end,
        },
        SafeCallMethod = function(_, obj, method, ...) return obj[method](obj, ...) end,
    }
    chunk(read("core/group_frame_chrome.lua"), "@core/group_frame_chrome.lua")("QUI", ns)
    ns.QUI_GroupFrameChrome.ResizeHealthForPower = function(frame)
        state.styles = state.styles + 1
        frame.styleWrites = (frame.styleWrites or 0) + 1
    end
    ns.QUI_GroupFrameChrome.ApplyStatusBarTexture = function() end
    local api = chunk(source .. [[
return { create = CreateHeaders, visibility = UpdateHeaderVisibility, scale = UpdateFrameScaling,
    layout = ApplyChildFrameLayout, state = _state, pending = _pending }
]], "@groupframes.lua")("QUI", ns)
    local gf = ns.QUI_GroupFrames
    local function decorate(child)
        if child._quiDecorated then return end
        child._quiDecorated = true
        child._isRaid = child.parent ~= gf.headers.party and child.parent ~= gf.headers.self
        child.healthBar = env.CreateFrame("StatusBar", nil, child)
        child.powerBar = env.CreateFrame("StatusBar", nil, child)
        gf.allFrames[#gf.allFrames + 1] = child
    end
    gf.HeaderChildCreated = function(_, name) decorate(env[name]) end
    gf.InitializeHeaderChild = function(_, child) decorate(child) end
    state.db, state.gf, state.api, state.env = db, gf, api, env
    function state:raid(n)
        self.roster = {}
        for i = 1, n do self.roster[i] = { name = "Member" .. i, group = math.ceil(i / 5), class = "MAGE", role = "DAMAGER" } end
    end
    function state:count()
        local count = 0
        for _, widget in ipairs(self.widgets) do
            if widget.kind == "Button" and widget.parent and widget.parent.secure then count = count + 1 end
        end
        return count
    end
    function state:refresh()
        api.visibility(true)
        api.scale()
    end
    return state
end

for _, mode in ipairs({ "GROUP", "NONE" }) do
    local h = harness(mode)
    h.api.create()
    check(mode .. " initializes only 40 raid and six party/self buttons", h:count() == 46, h:count())
    local selectedHeader = mode == "GROUP" and h.gf.raidGroupHeaders[1] or h.gf.headers.raid
    check(mode .. " selected header children retain the pingable template", selectedHeader:GetAttribute("template"):find("PingableUnitFrameTemplate", 1, true) ~= nil)
    h:raid(10)
    h:refresh()
    h.api.scale(true)
    local styles = h.styles
    h:raid(11)
    h:refresh()
    check(mode .. " same-size roster update performs no full child restyle", h.styles == styles, h.styles - styles)
    h.combat = true
    h:refresh()
    check(mode .. " same-size combat roster performs no child restyle", h.styles == styles, h.styles - styles)
    h.combat = false
    h:raid(20)
    h:refresh()
    check(mode .. " size-tier change still refreshes child layout", h.styles > styles)
    local child = mode == "GROUP" and h.gf.raidGroupHeaders[1]:GetAttribute("child1") or h.gf.headers.raid:GetAttribute("child1")
    check(mode .. " size-tier change applies medium dimensions", child:GetWidth() == 90 and child:GetHeight() == 35)
    styles = h.styles
    h.db.raid.dimensions.mediumRaidWidth = 111
    h.api.scale(true)
    check(mode .. " forced settings layout refreshes retained children", h.styles > styles and child:GetWidth() == 111)
    h.db.raid.layout.groupBy = mode == "GROUP" and "NONE" or "GROUP"
    h:refresh()
    local count, first = h:count(), h.gf.raidGroupHeaders[1]
    check(mode .. " first alternate layout adds only its 40 raid buttons", count == 86, count)
    check(mode .. " late-created raid headers receive current HUD layering", first:GetFrameLevel() == 70 and h.gf.headers.raid:GetFrameLevel() == 70)
    local hidden = mode == "GROUP" and first:GetAttribute("child1") or h.gf.headers.raid:GetAttribute("child1")
    local hiddenStyles = hidden.styleWrites or 0
    h.db.raid.dimensions.mediumRaidWidth = 123
    h.api.scale(true)
    check(mode .. " settings update styles hidden retained layout for later reuse", hidden:GetWidth() == 123 and (hidden.styleWrites or 0) > hiddenStyles)
    h.db.raid.layout.groupBy = mode
    h:refresh()
    h.db.raid.layout.groupBy = mode == "GROUP" and "NONE" or "GROUP"
    h:refresh()
    check(mode .. " repeated mode switches retain existing buttons", h:count() == count and h.gf.raidGroupHeaders[1] == first, h:count())
end

for _, mode in ipairs({ "ROLE", "CLASS", "NONE" }) do
    local h = harness(mode)
    h.db.raidSelfFirst = true
    h.api.create()
    check(mode .. " custom sections do not prewarm every category to 40", h:count() == 6, h:count())
    local retained = h.gf.raidGroupHeaders[1]
    h.db.raid.layout.groupBy = "GROUP"
    h:refresh()
    local ready = true
    for i = 1, 8 do
        local header = h.gf.raidGroupHeaders[i]
        ready = ready and header and header:GetAttribute("child5") ~= nil
    end
    check(mode .. " empty custom shells become eight combat-ready groups of five", ready and h:count() == 46, h:count())
    check(mode .. " grouped transition reuses the first custom header", retained == h.gf.raidGroupHeaders[1])
    h.db.raid.layout.groupBy = mode
    h:raid(40)
    h:refresh()
    local shown = 0
    for _, frame in ipairs(h.gf.allFrames) do
        if frame._isRaid and frame:IsVisible() and frame:GetAttribute("unit") then shown = shown + 1 end
    end
    check(mode .. " one custom section can display all 40 members", shown == 40, shown)
    local last = h.gf.raidGroupHeaders[1]:GetAttribute("child40")
    check(mode .. " custom section retains its fortieth actionable unit", last and last:IsVisible() and last:GetAttribute("unit") ~= nil)
end

for _, mode in ipairs({ "GROUP", "NONE" }) do
    local h = harness(mode)
    h:raid(20)
    h.api.create()
    check(mode .. " loading inside a raid still allocates only 46 buttons", h:count() == 46, h:count())
    h:refresh()
    h.combat = true
    h.db.raid.layout.groupBy = mode == "GROUP" and "NONE" or "GROUP"
    h:refresh()
    check(mode .. " first alternate layout waits until combat ends", h:count() == 46 and h.api.pending.visibilityUpdate == true, h:count())
    h.combat = false
    h:refresh()
    check(mode .. " deferred alternate layout creates its 40 buttons afterward", h:count() == 86, h:count())
end

if failures > 0 then error(failures .. " allocation/layout regression(s)") end
print("PASS groupframes_raid_allocation_test")
