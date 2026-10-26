local handle = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = handle:read("*a")
handle:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI = QUI.GUI
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
assert(loadfile(os.getenv("QUI_NAVIGATION_CACHE") or "QUI_Options/search_cache.lua"))("QUI", ns)
function GUI:RunWhenSettingsLayoutReady(_, _, callback, isCurrent)
    C_Timer.After(0, function() if not isCurrent or isCurrent() then callback() end end)
end
for _, path in ipairs({
    "modules/qol/sound_mute_catalog.lua",
    "QUI_ActionBars/actionbars/actionbars_env.lua", "QUI_ActionBars/actionbars/actionbars.lua",
    "QUI_ActionBars/actionbars/actionbars_helpers.lua", "QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
local profile = QUI.QUICore.db.profile
for key, value in pairs(ns.defaults.profile) do
    profile[key] = Copy(value)
end
profile.general.optionsMotion = false
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    local originalIndex = getmetatable(frame).__index
    setmetatable(frame, { __index = function(self, key)
        if key == "RegisterSection" then return nil end
        return originalIndex(self, key)
    end })
    frame._scripts = {}
    frame.SetScript = function(self, key, callback) self._scripts[key] = callback end
    frame.HookScript = function(self, key, callback)
        local previous = self._scripts[key]
        self._scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    frame.GetVerticalScroll = function(self) return self._verticalScroll or 0 end
    frame.SetVerticalScroll = function(self, offset) self._verticalScroll = offset end
    if kind == "ScrollFrame" then
        frame.GetVerticalScrollRange = function(self)
            local body = self:GetScrollChild()
            return math.max(0, (body and body:GetHeight() or 0) - self:GetHeight())
        end
    end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
ns.QUI_Options.CreateScrollableContent = function(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    return scroll, body
end
local pending = {}
_G.C_Timer.After = function(delay, callback) if delay == 0 then pending[#pending + 1] = callback end end
local function Flush()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1
        assert(passes < 100, "deferred provider updates must settle")
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
end
_G.geterrorhandler = function() return function(err) error(err, 0) end end
local frame = CreateFrame("Frame")
frame:SetWidth(1000)
frame:SetHeight(850)
frame._tiles = {}
frame.sidebar = CreateFrame("Frame", nil, frame)
frame.sidebar:SetWidth(211)
frame.contentArea = CreateFrame("Frame", nil, frame)
GUI.AddFeatureTile = function(_, owner, config)
    local tile = CreateFrame("Button", nil, owner)
    tile.id, tile.index, tile.config = config.id, #owner._tiles + 1, config
    tile.text = tile:CreateFontString()
    tile.indicator, tile.hoverBg = tile:CreateTexture(), tile:CreateTexture()
    owner._tiles[#owner._tiles + 1] = tile
    GUI:AttachTileNavigation(owner, tile)
end
GUI.MainFrame = frame

tinsert = table.insert
UISpecialFrames = {}
for _, entry in ipairs(ns.SwingTimers.entries) do
    profile.swingTimers[entry.key] = Copy(profile.swingTimers["*"])
end
for _, unit in pairs(profile.quiUnitFrames) do
    if type(unit) == "table" and unit.castbar then
        unit.castbar.empoweredStageColors = unit.castbar.empoweredStageColors or {}
        unit.castbar.empoweredFillColors = unit.castbar.empoweredFillColors or {}
    end
end
-- Observe real provider constructors and row labels; no capture overrides run.
assert(loadfile("modules/datatexts/datatexts.lua"))("QUI", ns)
assert(loadfile("modules/datatexts/providers_extra.lua"))("QUI", ns)

-- This observes actual constructors; none of the generator's capture overrides run.
local cache = dofile("tests/helpers/search_cache.lua")(os.getenv("QUI_SETTINGS_CACHE"))
local records, widgets, active = {}, {}, false
local function Context()
    return Copy(GUI._searchContext or {})
end
local depth = 0
local specs = {
    CreateFormCheckbox = {"checkbox",3,4,6}, CreateFormCheckboxOriginal = {"checkbox",3,4,6},
    CreateFormSquareCheckbox = {"checkbox",3,4,6}, CreateFormCheckboxInverted = {"checkbox_inverted",3,4,6},
    CreateFormToggle = {"toggle",3,4,6}, CreateFormToggleInverted = {"toggle_inverted",3,4,6},
    CreateFormSlider = {"slider",6,7,10}, CreateFormDropdown = {"dropdown",4,5,7},
    CreateFormColorPicker = {"colorpicker",3,4,7}, CreateFormEditBox = {"editbox",3,4,7},
    CreateCheckbox = {"checkbox",3,4}, CreateCheckboxCentered = {"checkbox",3,4},
    CreateCheckboxInverted = {"checkbox_inverted",3,4}, CreateSlider = {"slider",6,7},
    CreateDropdown = {"dropdown",4,5}, CreateDropdownFullWidth = {"dropdown",4,5},
    CreateColorPicker = {"colorpicker",3,4}, CreateColorPickerCentered = {"colorpicker",3,4},
    CreateButton = {"action_button"}, CreateAccentCheckbox = {"checkbox",3,4},
}
for name, constructor in pairs(GUI) do
    assert(type(constructor) ~= "function" or not name:match("^CreateForm") or specs[name],
        "new form constructor needs independent inventory coverage: " .. tostring(name))
end
for name, spec in pairs(specs) do
    local original = GUI[name]
    if original then
    GUI[name] = function(self, ...)
        local args, context = {...}, Context()
        depth = depth + 1
        local widget = original(self, ...)
        depth = depth - 1
        if active and depth == 0 then
            if name == "CreateAccentCheckbox" then
                local opts = args[2] or {}
                args = {args[1], opts.label, opts.dbKey, opts.dbTable}
            end
            local info = spec[4] and args[spec[4]] or {}
            local entry = {context = context, label = args[2], kind = spec[1], key = spec[2] and args[spec[2]],
                db = spec[3] and args[spec[3]], excluded = type(info) == "table" and info.searchable == false,
                constructor = name, widget = widget}
            if entry.kind == "slider" then entry.min,entry.max,entry.step=args[3],args[4],args[5] end
            if entry.kind == "dropdown" then entry.options=args[3] end
            records[#records+1] = entry
            widgets[widget] = entry
        end
        return widget
    end
end
end
local buildRow = ns.QUI_Options.BuildSettingRow
ns.QUI_Options.BuildSettingRow = function(parent, label, widget, ...)
    -- Observe the actual contents, including a composite control's descendants.
    local function Label(node)
        if widgets[node] and widgets[node].kind ~= "action_button" then
            widgets[node].label = label
        elseif node and node.GetChildren then
            for _, child in ipairs({node:GetChildren()}) do Label(child) end
        end
    end
    if active then Label(widget) end
    return buildRow(parent,label,widget,...)
end
local function CapabilityIdentity(value)
    if type(value) ~= "table" then return type(value) == "function" and "function" or tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. CapabilityIdentity(value[key]) end
    return table.concat(parts, ";")
end
local auraSamples = {}
local auraEditor = ns.QUI_AuraElementsEditor
local renderAuraEditor = auraEditor.RenderAuras
auraEditor.RenderAuras = function(host, db, spec, changed, options)
    if active then
        local context = Context()
        local caps = options and options.capabilities
        local key = (context.featureId or "") .. ":" .. CapabilityIdentity(caps)
        auraSamples[key] = {context = context, capabilities = caps}
    end
    return renderAuraEditor(host, db, spec, changed, options)
end
ns.QUI_Options.RegisterAllFeatureTiles(frame)
local descriptor
local register = GUI.RegisterTileSurfacePages
GUI.RegisterTileSurfacePages = function(self,host,spec)
    descriptor = spec
    return register(self,host,spec)
end
local failures = {}
local destinations, contexts = 0, 0
local function Render(feature, context, fn)
    local host = CreateFrame("Frame"); host:SetSize(760,720)
    GUI:ClearSearchContext(); GUI:SetSearchContext(context)
    descriptor = nil
    active = true
    local firstRecord = #records + 1
    local ok, err = xpcall(function()
        ns.Settings.SearchRoute.With(context, function() fn(host) end)
        Flush()
    end, debug.traceback)
    active = false
    for i=firstRecord,#records do
        local entry=records[i]
        if not entry.label and type(rawget(entry.widget,"_widgetLabel"))=="string" then
            entry.label=rawget(entry.widget,"_widgetLabel")
        end
        entry.widget=nil
    end
    widgets={}
    contexts = contexts + 1
    if contexts % 20 == 0 then collectgarbage("collect") end
    if not ok then failures[#failures+1] = feature.id .. ": " .. err end
end
for destination in ns.Settings.Registry:IterateDestinations() do
    destinations = destinations + 1
    local feature = assert(ns.Settings.Registry:GetFeature(destination.featureId))
    local context = Copy(destination.searchContext)
    context.providerKey = context.providerKey or feature.providerKey
    if not context.providerKey and feature.id:match("^actionBars") and feature.lookupKeys and #feature.lookupKeys == 1 then
        context.providerKey = feature.lookupKeys[1]
    end
    local function Page(host)
        local opts = {surface="tile",width=760,tileLayout=true,includePosition=true,providerKey=context.providerKey}
        for k,v in pairs(destination.renderOptions or {}) do opts[k]=v end
        ns.Settings.Renderer:RenderFeature(feature,host,opts)
    end
    Render(feature,context,Page)
    if feature.model then
        local model = type(feature.model)=="function" and feature.model() or feature.model
        -- Walk actual tab declarations and selector contexts, including hidden tabs
        -- only when their own visibility contract accepts the state.
        for _,tab in ipairs(model.GetTabDefinitions()) do
            for _,variant in ipairs(model.GetSearchContexts and model.GetSearchContexts(tab.key) or {{state={},searchContext={}}}) do
                if not tab.visible or tab.visible(variant.state,tab,model) ~= false then
                    local ctx=Copy(context)
                    for k,v in pairs(variant.searchContext or {}) do ctx[k]=v end
                    ctx.surfaceTabKey,ctx.subTabName=tab.key,tab.label
                    Render(feature,ctx,function(host) tab.render(host,variant.state) end)
                end
            end
        end
    elseif feature.getSearchContexts then
        local previous=feature.getNavigationContext and feature.getNavigationContext()
        for _,variant in ipairs(feature.getSearchContexts()) do
            assert(feature.searchNavigate(variant.searchContext),"unsupported declared context: "..feature.id)
            local ctx=Copy(context)
            for k,v in pairs(variant.searchContext or {}) do ctx[k]=v end
            Render(feature,ctx,Page)
        end
        if previous then feature.searchNavigate(previous) end
    elseif descriptor and descriptor.selectTab then
        local mounted = descriptor
        for _,tab in ipairs(mounted.getTabs()) do
            Render(feature,context,function() mounted.selectTab(tab.key) end)
        end
    end
end
-- Conditional cases come from actual provider APIs and mounted capabilities.
-- No labels or bindings are copied from the generated catalog.
local function Fixture(id, fn, extra)
    local feature = assert(ns.Settings.Registry:GetFeature(id))
    for destination in ns.Settings.Registry:IterateDestinations() do
        if destination.featureId == id then
            local context = Copy(destination.searchContext)
            for k,v in pairs(extra or {}) do context[k]=v end
            Render(feature,context,fn)
        end
    end
end
local function RenderFeature(id)
    Fixture(id,function(host)
        ns.Settings.Renderer:RenderFeature(ns.Settings.Registry:GetFeature(id),host,
            {surface="tile",width=760,tileLayout=true,includePosition=true})
    end)
end
local oldClient=ns.Client
ns.Client={isForever=true}
RenderFeature("skinningPage")
ns.Client=oldClient
local oldSlots=profile.datatext.slots
local definitions=ns.Addon.Datatexts:GetAll()
for first=1,#definitions,3 do
    profile.datatext.slots={}
    for i=first,math.min(first+2,#definitions) do profile.datatext.slots[i-first+1]=definitions[i].id end
    RenderFeature("datatextPanel")
end
profile.datatext.slots=oldSlots
local oldPerSpec=profile.chat.defaultTabPerSpec
for _,enabled in ipairs({false,true}) do
    profile.chat.defaultTabPerSpec=enabled
    RenderFeature("chatFrame1")
end
profile.chat.defaultTabPerSpec=oldPerSpec
for _,spellID in ipairs({10060,29166}) do
    local config=ns.SpellReminderModel.New(spellID)
    local options=ns.SpellReminderOptions
    for _,tab in ipairs(options.GetTabs(config)) do
        Fixture("spellRemindersPage",function(host) options.RenderTab(tab.key,host,config) end)
    end
    if config.pi then
        config.pi.whisper.mode="rotation"
        Fixture("spellRemindersPage",function(host) options.RenderTab("requests",host,config) end)
        config.pi.separateBuffs=true
        Fixture("spellRemindersPage",function(host) options.RenderTab("buffs",host,config) end)
    end
end
local elements=ns.AuraElements
local displays=ns.QUI_AuraDisplaysOptions
for _,unit in ipairs({"player","target"}) do
    local display={id="inventory",name="Inventory",enabled=true,unitMode="token",unit=unit,
        load={classes={},specs={},roles={},encounters={}},auras={}}
    for _,builder in ipairs({"_BuildGeneralTab","_BuildLoadTab","_BuildAurasTab"}) do
        Fixture("aurasDisplaysPage",function(host) displays[builder](host,nil,display) end,{providerKey="detail"})
    end
    display.auras={enabled=true,elements={["*"]={elements.NewTrackedElement({12345},"icon")}}}
    Fixture("aurasDisplaysPage",function(host) displays._BuildAlertsTab(host,nil,display) end,{providerKey="detail"})
end
local AD=ns.QUI_AuraDisplays
local group=AD.GetGroup("Inventory",true)
group._quiTransientOptionsProxy=true
Fixture("aurasDisplaysPage",function(host) displays._BuildGroupTab(host,nil,"Inventory") end,{providerKey="detail"})
local function ExpandedVariants(caps)
    local variants={}
    if not caps or not caps.elementTypes or caps.elementTypes.filterStrip then
        for _,auraType in ipairs({"HELPFUL","HARMFUL"}) do
            for _,mode in ipairs({"off","flags","classify","whitelist"}) do
                local e=elements.NewFilterStripElement(auraType)
                e.filterMode=mode
                e.casterName={showRealmName=false,useClassColors=true,fontSize=10,anchor="BOTTOM",offsetX=0,offsetY=1,color={1,1,1,1}}
                e.pandemicGlow={style="steady",color={1,0.85,0.2,1}}
                variants[#variants+1]=e
            end
        end
    end
    if not caps or not caps.elementTypes or caps.elementTypes.tracked then
        for _,shape in ipairs({"icon","square","bar","healthTint"}) do
            if not caps or not caps.trackedDisplayTypes or caps.trackedDisplayTypes[shape] then
                variants[#variants+1]=elements.NewTrackedElement({12345,67890},shape)
            end
        end
    end
    if not caps or not caps.elementTypes or caps.elementTypes.missingRaidBuff then
        for _,auto in ipairs({true,false}) do
            local e=elements.NewMissingRaidBuffElement()
            e.classDetection=auto
            variants[#variants+1]=e
        end
    end
    return variants
end
for _,sample in pairs(auraSamples) do
    local feature=assert(ns.Settings.Registry:GetFeature(sample.context.featureId))
    for _,element in ipairs(ExpandedVariants(sample.capabilities)) do
        Render(feature,sample.context,function(host)
            renderAuraEditor(host,{enabled=true,elements={["*"]={element}}},"*",function() end,
                {forceSelectedIndex=1,capabilities=sample.capabilities})
        end)
    end
end

local function Identity(context,label,path,key)
    return table.concat({context.tileId or "",tostring(context.subPageIndex or ""),context.featureId or "",

        label or "",path or "",tostring(key or "")},"|")
end
local expected, actual = {}, {}
local paths = {}
local function IndexBindings(value, path, depth)
    if type(value) ~= "table" or paths[value] or depth > 12 then return end
    paths[value] = path
    for key, child in pairs(value) do
        if type(key) == "string" and type(child) == "table" and not rawget(child,"_quiTransientOptionsProxy")
            and key ~= "_migrationBackup" and key ~= "_schemaVersion" and key ~= "_defaultsVersion" then
            IndexBindings(child,path .. "." .. key,depth + 1)
        end
    end
end
IndexBindings(profile,"profile",0)
IndexBindings(QUI.db.char,"char",0)
IndexBindings(QUI.db.global,"global",0)
local function BindingPath(entry)
    if type(entry.key) ~= "string" or type(entry.db) ~= "table" or rawget(entry.db,"_quiTransientOptionsProxy") then return end
    return paths[entry.db]
end
for _,entry in ipairs(records) do
    local label=entry.label
    if type(label)=="string" and label~="" and not entry.excluded then
        local path=BindingPath(entry)
        entry.path=path
        local id=Identity(entry.context,label,path,path and entry.key)
        entry.kinds=expected[id] and expected[id].kinds or {}
        entry.kinds[entry.kind]=true
        expected[id]=entry
    end
end
for _,entry in ipairs(cache.settings) do
    local d=entry.widgetDescriptor or {}
    actual[Identity(entry,entry.label,d.dbPath,d.dbKey)]=entry
end
local missing, count = {},0
for id,entry in pairs(expected) do
    count=count+1
    if not actual[id] then missing[#missing+1]=id.." ["..entry.constructor.."]" end
end
table.sort(missing)
print("DESTINATIONS "..destinations.." CONTEXTS "..contexts.." CONTROLS "..count.." MISSING "..#missing.." ERRORS "..#failures)
for _,err in ipairs(failures) do print("RENDER ERROR "..err) end
for _,id in ipairs(missing) do print("MISSING "..id) end

local extra={}
for id in pairs(actual) do if not expected[id] then extra[#extra+1]=id end end
table.sort(extra)
print("UNOBSERVED "..#extra)
for _,id in ipairs(extra) do print("UNOBSERVED "..id) end

local mismatches={}
local function Options(value)
    local parts={}
    for _,o in ipairs(value or {}) do parts[#parts+1]=tostring(o.value)..":"..tostring(o.text) end
    return table.concat(parts,";")
end
for id,e in pairs(expected) do
    local got=actual[id]
    if got then
        if (e.path and got.widgetType~=e.kind) or (not e.path and not e.kinds[got.widgetType]) then mismatches[#mismatches+1]=id.." kind "..tostring(got.widgetType).." expected "..e.kind end
        local d=got.widgetDescriptor
        if e.path then
            if e.kind=="slider" then
                for _,k in ipairs({"min","max","step"}) do if not d or d[k]~=e[k] then mismatches[#mismatches+1]=id.." "..k end end
            elseif e.kind=="dropdown" and (not d or Options(d.options)~=Options(e.options)) then
                mismatches[#mismatches+1]=id.." options"
            end
        end
    end
end
table.sort(mismatches)
print("MISMATCHES "..#mismatches)
for _,id in ipairs(mismatches) do print("MISMATCH "..id) end
assert(#missing==0 and #failures==0 and #mismatches==0,"actual provider inventory differs from generated search")

assert(#extra==0,"generated search contains controls not observed in actual supported providers")
local inventory=dofile("tests/helpers/settings_inventory.lua")
local sourceRows, sourceShapes, sourceKeysBySearchID={},{},{}
local function Signature(entry)
    return table.concat({entry.kind,tostring(entry.min or ""),tostring(entry.max or ""),tostring(entry.step or ""),
        entry.kind=="dropdown" and Options(entry.options) or "",entry.excluded and "excluded:metadata" or "searchable"},"|")
end
for _,entry in ipairs(records) do
    local ctx=entry.context
    local path=BindingPath(entry)
    local id=Identity(ctx,entry.label,path,path and entry.key)
    local key=table.concat({"control",id,ctx.providerKey or "",ctx.surfaceTabKey or "",ctx.surfaceUnitKey or "",
        ctx.surfaceTypeKey or "",ctx.sectionName or "",entry.constructor,entry.kind},"|")
    sourceShapes[key]=sourceShapes[key] or {}
    sourceShapes[key][Signature(entry)]=true
    sourceKeysBySearchID[id]=sourceKeysBySearchID[id] or {}
    sourceKeysBySearchID[id][key]=true
end
for key,shapes in pairs(sourceShapes) do
    local values={}
    for value in pairs(shapes) do values[#values+1]=value end
    table.sort(values)
    sourceRows[key]=table.concat(values,"\n")
end
for destination in ns.Settings.Registry:IterateDestinations() do
    sourceRows["destination|"..destination.tileId.."|"..destination.subPageIndex.."|"..destination.featureId]="registered"
end
for id,feature in ns.Settings.Registry:IterateFeatures() do
    sourceRows["feature|"..id]=feature.noSearch and "non-search alias" or "registered"
end
local output=os.getenv("QUI_SETTINGS_BASELINE_OUTPUT")
if output then inventory.Save(output,sourceRows) end
local baseline=dofile("tests/fixtures/settings_controls_inventory.lua")
local changes=inventory.Differences(baseline,sourceRows)
assert(#changes==0,"reviewed control baseline changed:\n"..table.concat(changes,"\n"))
-- Mutation checks use this run's actual provider inventory. A simultaneous
-- source and cache deletion must fail even though the two reduced sets agree.
local searchID=next(expected)
local chosen=assert(next(sourceKeysBySearchID[searchID]))
local removed=Copy(sourceRows)
for key in pairs(sourceKeysBySearchID[searchID]) do removed[key]=nil end
local function ShallowCopy(values)
    local result={}
    for key,value in pairs(values) do result[key]=value end
    return result
end
local reducedSource=ShallowCopy(expected); reducedSource[searchID]=nil
local reducedIndex=ShallowCopy(actual); reducedIndex[searchID]=nil
assert(#inventory.Missing(expected,actual)==0,"every actual control requires an index entry")
assert(#inventory.Missing(expected,reducedIndex)==1,"index deletion must fail the independent control comparison")
assert(#inventory.Missing(reducedSource,reducedIndex)==0,"the simultaneous deletion defeats a two-way comparison alone")
assert(#inventory.Differences(baseline,removed)>0,"reviewed baseline must detect simultaneous source+cache deletion")
local modified=Copy(sourceRows); modified[chosen]=modified[chosen].."|changed"
assert(#inventory.Differences(baseline,modified)>0,"baseline must detect changed control contract")
local added=Copy(sourceRows); added["destination|unreviewed|1|unknown"]="registered"
assert(#inventory.Differences(baseline,added)>0,"baseline must require review of new destinations")
print("OK: reviewed source inventory and deletion mutations across "..destinations.." destinations and "..contexts.." contexts")
