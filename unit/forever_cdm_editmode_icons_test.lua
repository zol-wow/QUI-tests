local root = "tests/clients/forever/framexml/Interface/AddOns/"
local function read(path)
    local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close(); return source
end
local function noop() end
local function run(extraCount, delayed, isForever, build)
    local world = setmetatable({}, { __index = _G }); world._G = world
    local function evaluate(source, name)
        local chunk = assert(loadstring(source, name)); setfenv(chunk, world); return chunk()
    end
    local function nativeFunction(source, name)
        return assert(source:match("(function " .. name:gsub("%.", "%%.") .. "%b().-\nend)"), name)
    end
    world.EnumUtil = { MakeEnum = function(...)
        local values = {}; for i, key in ipairs({...}) do values[key] = i end; return values
    end }
    world.GetValuesArray = function(t) local out = {}; for _, value in pairs(t) do out[#out + 1] = value end; return out end
    world.GetKeysArray = function(t) local out = {}; for key in pairs(t) do out[#out + 1] = key end; return out end
    world.tContains = function(t, v) for _, value in ipairs(t) do if value == v then return true end end; return false end
    world.GetLooseMacroIcons = function(t) t[#t + 1] = 111111 end
    world.GetLooseMacroItemIcons, world.GetMacroIcons, world.GetMacroItemIcons = noop, noop, noop
    world.Enum = { SpellBookSpellBank = { Player = 0 } }
    world.Constants = { TalentTierConstants = { MAX_TALENT_TIERS = 0 }, TalentConsts = { NumTalentColumns = 0 } }
    world.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { numSpellBookItems = extraCount, itemIndexOffset = 0 } end,
        GetSpellBookItemType = function() return "SPELL", 1 end,
        GetSpellBookItemTexture = function(index) return 200000 + index end,
    }
    world.GetNumSpecGroups = function() return 0 end
    world.C_SpecializationInfo = { GetPvpTalentSlotInfo = function() return nil end }
    world.CreateAndInitFromMixin = function(mixin, ...)
        local value = {}; for key, method in pairs(mixin) do value[key] = method end; value:Init(...); return value
    end
    evaluate(read(root .. "Blizzard_FrameXMLBase/IconDataProvider.lua"), "@IconDataProvider.lua")
    evaluate(read(root .. "Blizzard_FrameXMLBase/Mainline/IconDataProviderOverrides.lua"), "@IconDataProviderOverrides.lua")
    local providerLookup = world.IconDataProviderMixin.GetIconByIndex
    local source = read(root .. "Blizzard_CooldownViewer/CooldownViewer.lua")
    local helper = assert(source:match("(local EditModeIconDataProvider = nil;.-)\nlocal function GetEditModeDuration"))
    world.CooldownViewerItemMixin, world.CooldownViewerMixin, world.CooldownViewerItemDataMixin = {}, {}, {}
    evaluate(helper .. "\n" .. nativeFunction(source, "CooldownViewerItemMixin:GetFallbackSpellTexture"), "@CooldownViewer.lua")
    for _, method in ipairs({ "SetEditModeData", "ClearEditModeData", "HasEditModeData" }) do
        evaluate(nativeFunction(source, "CooldownViewerItemMixin:" .. method), "@CooldownViewer.lua")
    end
    evaluate(nativeFunction(source, "CooldownViewerMixin:OnAcquireItemFrame"), "@CooldownViewer.lua")
    local itemSource = read(root .. "Blizzard_CooldownViewer/CooldownViewerItemData.lua")
    local nativeTexture = "local " .. nativeFunction(itemSource, "GetSpellTextureForSpellID")
    evaluate(nativeTexture .. "\n" .. nativeFunction(itemSource, "CooldownViewerItemDataMixin:GetSpellTexture"), "@CooldownViewerItemData.lua")
    world.C_Spell = { GetSpellTexture = function() return 345678, 456789, 567890 end }
    world.ItemUtil = { GetEquipSlotTexture = function() return nil end }
    local fallback = world.CooldownViewerItemMixin.GetFallbackSpellTexture
    local getTexture = world.CooldownViewerItemDataMixin.GetSpellTexture
    local function item()
        local value = {}
        for key, method in pairs(world.CooldownViewerItemMixin) do value[key] = method end
        value.GetSpellTexture = getTexture
        value.GetSpellCategoryIcon = function(self) return self.categoryIcon end
        value.UsesDynamicAppearance, value.PreferAuraDataOverSpellData = function() return false end, function() return false end
        value.GetEquipSlot, value.GetCooldownInfo = noop, noop
        value.GetBaseSpellID = function(self) return self.spellID end
        value.RefreshData = function(self) self.texture = self:GetSpellTexture() end
        value.SetViewerFrame = function(self, viewer) self.viewer = viewer end
        value.SetScale, value.SetTimerShown, value.SetTooltipsShown, value.SetHideWhenInactive, value.SetIsEditing = noop, noop, noop, noop, noop
        return value
    end
    local unpatched = item()
    local ok, err = pcall(unpatched.SetEditModeData, unpatched, extraCount + 2)
    assert(not ok and tostring(err):find("BaseIconFilenames", 1, true), "native source must reproduce the reported missing-cache error")
    local viewers = {}
    local names = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
    local function createViewers()
        for _, name in ipairs(names) do
            local active = item()
            local viewer = { active = active, OnAcquireItemFrame = world.CooldownViewerMixin.OnAcquireItemFrame }
            viewer.itemFramePool = { EnumerateActive = function()
                local done = false
                return function() if not done then done = true; return active end end
            end }
            viewers[#viewers + 1] = viewer; world[name] = viewer
        end
    end
    local onLoaded, registrations, acquireHooks = nil, 0, 0
    world.EventUtil = { ContinueOnAddOnLoaded = function(addon, callback)
        assert(addon == "Blizzard_CooldownViewer")
        registrations = registrations + 1
        if delayed then onLoaded = callback else callback() end
    end }
    world.hooksecurefunc = function(target, key, callback)
        assert(key == "OnAcquireItemFrame", "workaround must hook only native item acquisition")
        acquireHooks = acquireHooks + 1
        local original = assert(target[key]); target[key] = function(...) original(...); callback(...) end
    end
    world.CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end
    if not delayed then createViewers() end
    local policy = assert(loadfile("QUI_CDM/cdm/cdm_editmode_policy.lua")); setfenv(policy, world)
    policy("QUI_CDM", { Client = { isForever = isForever, build = build } })
    if delayed then
        assert(not next(viewers), "viewers absent before delayed native load")
        createViewers()
        if onLoaded then onLoaded() end
    end
    local expectedGuard = isForever and tostring(build) == "69893"
    if not expectedGuard then
        assert(registrations == 0 and acquireHooks == 0, "Retail and unverified builds must remain untouched")
        for _, viewer in ipairs(viewers) do assert(viewer.active.GetFallbackSpellTexture == fallback) end
        return
    end
    assert(registrations == 1 and acquireHooks == 4, "all four native viewers must receive the compatibility boundary")
    assert(world.IconDataProviderMixin.GetIconByIndex == providerLookup, "global icon provider must remain untouched")
    assert(world.CooldownViewerItemMixin.GetFallbackSpellTexture == fallback, "global native item mixin must remain untouched")
    local function check(value)
        assert(value.GetSpellTexture == getTexture, "native real spell texture resolution must remain intact")
        for _, index in ipairs({ 1, 2, 12, 13, 1000 }) do
            value:SetEditModeData(index)
            assert(value.editModeIndex == index, "preview index must retain its native timing/layout meaning")
            assert(value.texture == [[INTERFACE\ICONS\INV_MISC_QUESTIONMARK]]
                or (type(value.texture) == "number" and value.texture > 200000 and value.texture <= 200000 + extraCount),
                "placeholder lookup must stay within available icons")
        end
        value.spellID = 123
        value:RefreshData()
        assert(value.texture == 456789, "real spell icon takes precedence over placeholder")
        value.categoryIcon = 987654
        value:RefreshData()
        assert(value.texture == 987654, "native category icon precedence must remain intact")
        value.spellID, value.categoryIcon = nil, nil
        value:ClearEditModeData()
        assert(value:GetSpellTexture() == nil, "non-preview empty item keeps native nil fallback")
    end
    for _, viewer in ipairs(viewers) do
        check(viewer.active)
        local acquired = item()
        viewer:OnAcquireItemFrame(acquired)
        assert(acquired.viewer == viewer, "original acquisition must still run")
        check(acquired)
        local method = acquired.GetFallbackSpellTexture
        viewer:OnAcquireItemFrame(acquired)
        assert(acquired.GetFallbackSpellTexture == method, "pooled item reacquisition must not stack replacements")
        check(acquired)
    end
    local macro = world.CreateAndInitFromMixin(world.IconDataProviderMixin, world.IconDataProviderExtraType.Spellbook)
    viewers[1].active:SetEditModeData(extraCount + 2)
    assert(viewers[1].active.texture == 111111, "populated native base icon cache remains usable")
    macro:Release()
    for _, viewer in ipairs(viewers) do check(viewer.active) end
end

run(10, false, true, "69893")
run(0, true, true, "69893")
run(1, true, true, "69893")
run(10, false, false, "69893")
run(10, true, true, "69900")
print("OK forever_cdm_editmode_icons_test")
