local function noop() end

local function snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local entries = {}
    for key, child in pairs(value) do
        entries[#entries + 1] = tostring(key) .. "=" .. snapshot(child)
    end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
end

for _, initialValue in ipairs({ true, false }) do
    local cvar, writes, rows = initialValue, {}, {}
    local db = { profile = { minimap = {}, uiHider = {} } }
    local provider, afterLoad

    _G.C_CVar = {
        GetCVarBool = function(name)
            assert(name == "rotateMinimap", "rotation must read the native CVar")
            return cvar
        end,
        SetCVar = function(name, value)
            assert(name == "rotateMinimap", "rotation must not write other CVars")
            assert(value == "1" or value == "0", "rotation must write string booleans")
            writes[#writes + 1] = value
            cvar = value == "1"
        end,
    }
    _G.QUI = { db = db }
    _G.QUI_GetDrawerButtonNames = function() return { "TestAddon" } end

    local GUI = {
        CreateFormSlider = noop,
        CreateFormDropdown = noop,
        CreateFormColorPicker = noop,
    }
    function GUI:CreateFormCheckbox(_, _, key, settings, callback, options)
        local widget = {
            scripts = {}, events = {}, visible = initialValue,
            key = key, settings = settings, description = options.description,
        }
        function widget:SetValue(value, silent)
            self.value = value
            if not silent then
                if key and settings then settings[key] = value end
                if callback then callback(value) end
            end
        end
        function widget:HookScript(name, fn) self.scripts[name] = fn end
        function widget:SetScript(name, fn) self.scripts[name] = fn end
        function widget:RegisterEvent(name) self.events[name] = true end
        function widget:UnregisterEvent(name) self.events[name] = nil end
        function widget:IsVisible() return self.visible end
        function widget:Show()
            self.visible = true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function widget:Hide()
            self.visible = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function widget:Dispatch(event, ...)
            if self.events[event] then self.scripts.OnEvent(self, event, ...) end
        end
        return widget
    end
    GUI.CreateFormCheckboxInverted = GUI.CreateFormCheckbox

    local ns = {
        L = setmetatable({}, { __index = function(_, key) return key end }),
        Settings = { ProviderPanels = {
            RegisterAfterLoad = function(_, fn) afterLoad = fn end,
        } },
        QUI_Options = {
            BuildSettingRow = function(_, label, widget) rows[label] = widget end,
        },
        QUI_BorderControl = { Attach = noop },
        QUI_SettingsLayoutShared = {
            BuildNinePointAnchorOptions = function() return {} end,
            MakeLayout = function()
                return {
                    headerAt = noop, closeSection = noop, relayoutSections = noop,
                    sectionAt = function() return { frame = {}, AddRow = noop } end,
                }
            end,
        },
    }
    assert(loadfile("modules/minimap/settings/minimap_providers.lua"))("QUI", ns)
    assert(afterLoad, "minimap provider must register its builder")({
        GUI = GUI,
        U = {
            GetProfileDB = function() return db.profile end,
            BuildPositionCollapsible = noop,
            BuildOpenFullSettingsLink = noop,
        },
        RegisterShared = function(key, registered)
            assert(key == "minimap")
            provider = registered
        end,
    })
    provider.build({ GetHeight = function() return 80 end }, "minimap", 600)

    local widget = assert(rows["Rotate Minimap"], "minimap settings must expose Rotate Minimap")
    assert(widget.value == initialValue, "construction must reflect the existing CVar")
    assert(cvar == initialValue and #writes == 0, "construction must preserve the existing CVar")
    assert(widget.key == nil and widget.settings == nil, "rotation must not bind to a QUI profile")
    assert(widget.description:find("Edit Mode", 1, true), "tooltip must explain native layout overrides")
    assert((not not widget.events.CVAR_UPDATE) == initialValue,
        "only an initially visible widget should subscribe")
    local originalProfile = snapshot(db.profile)
    widget:Show()
    assert(widget.events.CVAR_UPDATE and #writes == 0, "show must subscribe without writing")

    widget:SetValue(true)
    assert(cvar and writes[1] == "1", "enabling rotation must write native CVar 1")
    widget:SetValue(false)
    assert(not cvar and writes[2] == "0" and #writes == 2,
        "disabling rotation must write native CVar 0 exactly once")
    assert(snapshot(db.profile) == originalProfile, "toggling must preserve the QUI profile")

    cvar = true
    widget:Dispatch("CVAR_UPDATE", "minimapZoom")
    assert(widget.value == false, "unrelated CVars must not refresh rotation")
    widget:Dispatch("CVAR_UPDATE", "rotateMinimap")
    assert(widget.value == true and #writes == 2, "external CVar changes must refresh silently")
    cvar = false
    widget:Dispatch("CVAR_UPDATE", "ROTATEMINIMAP")
    assert(widget.value == false and #writes == 2,
        "native layout CVar changes must refresh silently regardless of casing")

    widget:Hide()
    assert(not widget.events.CVAR_UPDATE, "hidden rotation widget must unsubscribe")
    cvar = true
    widget:Dispatch("CVAR_UPDATE", "rotateMinimap")
    assert(widget.value == false, "hidden widget must not receive CVar events")
    widget:Show()
    assert(widget.value == true and widget.events.CVAR_UPDATE,
        "reopening must refresh from the current CVar and resubscribe")
    assert(#writes == 2 and snapshot(db.profile) == originalProfile,
        "external changes and visibility must not write CVar or profile state")
end

print("OK: minimap_rotation_setting_test")
