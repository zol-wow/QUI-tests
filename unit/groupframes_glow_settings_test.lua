local ns = {L = setmetatable({}, {__index = function(_, k) return k end})}
assert(loadfile("core/group_frame_chrome.lua"))("QUI", ns)
local file = assert(io.open("QUI_GroupFrames/groupframes/settings/group_frames_schema.lua"))
local source = file:read("*a"); file:close()
local start = assert(source:find('    local glow = EnsureSubTable(healer, "cleanseGlow")', 1, true))
local stop = assert(source:find("    return builder.Height()", start, true))
local render = assert(loadstring("return function(ns, healer, dispel, gui, builder, optionsAPI, refresh, EnsureSubTable)\n" .. source:sub(start, stop - 1) .. "\nend"))()
local function renderContext(healer)
    local controls, rows = {}, {}
    local gui = {}
    local function control(kind, key, db, changed, values, options)
        local w = {kind=kind,key=key,db=db,changed=changed,values=values,options=options}
        controls[#controls+1]=w; return w
    end
    function gui:CreateFormCheckbox(_,_,key,db,changed) return control("checkbox",key,db,changed) end
    function gui:CreateFormDropdown(_,_,values,key,db,changed) return control("dropdown",key,db,changed,values) end
    function gui:CreateFormColorPicker(_,_,key,db,changed,options) return control("color",key,db,changed,nil,options) end
    function gui:CreateFormSlider(_,_,min,max,step,key,db,changed) return control("slider",key,db,changed,{min,max,step}) end
    local api={}
    function api.BuildSettingRow(_, label, widget)
        local row={label=label,widget=widget}; function row:SetAlpha(a) self.alpha=a end
        rows[#rows+1]=row; return row
    end
    local count=0
    local builder={Header=function() end,CloseCard=function() end}
    function builder.Card() return {frame={},AddRow=function() count=count+1 end} end
    local refreshes=0
    render(ns,healer,{colors=ns.QUI_GroupFrameChrome.GLOW_TYPE_COLORS},gui,builder,api,
        function() refreshes=refreshes+1 end,function(t,k) t[k]=t[k] or {}; return t[k] end)
    local byKey={}; for _,w in ipairs(controls) do byKey[w.key]=w end
    assert(count==7 and #controls==12, "settings must include mode, scope, opacity, animation period and all five colors")
    assert(byKey.scope.values[2].value=="ALL_TYPED" and byKey.animation.values[3].value=="MOVING")
    assert(healer.cleanseGlow.opacity==0.7 and healer.cleanseGlow.animation=="NONE", "old opacity and static behavior migrate intact")
    assert(byKey.Bleed.options.noAlpha and byKey.Poison.db==healer.cleanseGlow.colors)
    healer.cleanseGlow.colorMode="TYPE"; byKey.colorMode.changed()
    assert(refreshes==1 and byKey.Bleed.db.Bleed[1]==0.8)
    return byKey
end
local party={cleanseGlow={enabled=true,color={0.2,0.8,0.3,0.7}}}
local raid={cleanseGlow={enabled=true,color={0.5,0.4,0.2,0.7}}}
local p,r=renderContext(party),renderContext(raid)
p.Bleed.db.Bleed={0.1,0.2,0.3,1}
assert(r.Bleed.db.Bleed[1]==0.8, "party and raid glow palettes must stay independent")
print("OK: groupframes_glow_settings_test")
