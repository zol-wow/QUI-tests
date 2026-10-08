local f = assert(io.open(os.getenv("QUI_INFOBAR_SOURCE") or "modules/infobar/settings/infobar_content.lua"))
local source = f:read("*a"); f:close()
local first = assert(source:find('        L.headerAt(ns.L["Arrangement"])', 1, true), "Info Bar must expose a unified Arrangement editor")
local last = assert(source:find('        L.headerAt(ns.L["Widget Overrides"])', first, true))
local nodes, buttons, dropdowns, lists = {}, {}, {}, {}
local function node(parent)
    local n = {parent=parent, width=660, scripts={}}
    setmetatable(n, {__index=function() return function() end end})
    function n:GetWidth() return self.width end
    function n:SetWidth(w) self.width=w end
    function n:SetSize(w,h) self.width,self.height=w,h end
    function n:SetHeight(h) self.height=h end
    function n:SetEnabled(v) self.enabled=v end
    function n:SetScript(k,v) self.scripts[k]=v end
    nodes[#nodes+1]=n
    return n
end
CreateFrame=function(_,_,parent) return node(parent) end
local ns={L=setmetatable({}, {__index=function(_,k)return k end}), Addon={InfoBar={}}}
(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("core/infobar_shared.lua"))("QUI",ns)
assert(loadfile("modules/infobar/contextmenu.lua"))("QUI",ns)
assert(loadfile("modules/infobar/dragreorder.lua"))("QUI",ns)
local db={zones={left={"gold","time"},center={"travel"},right={}}}
local state={arrangementScroll={}}
local refreshes, structural=0,0
local gui={Colors={}}
function gui:CreateLabel(parent) return node(parent) end
function gui:CreateButton(parent,label,_,_,callback)
    local b=node(parent);b.click=callback;buttons[label]=b;return b
end
function gui:CreateFormDropdown(parent,_,options,_,_,callback)
    local d=node(parent);d.options=options;d.choose=callback;dropdowns[#dropdowns+1]=d;return d
end
ns.UIKit={CreateRoundedSurface=function() end}
ns.QUI_ReorderList={Build=function(host,_,spec)
    lists[#lists+1]=spec
    return node(host), math.max(44,#spec.items*32+4)
end}
local zones={{key="left",label="Left Zone"},{key="center",label="Center Zone"},{key="right",label="Right Zone"}}
local env=setmetatable({ns=ns,GUI=gui,content=node(),db=db,QUICore=ns.Addon,ZONE_DEFS=zones,
    InfoBarPageState=state,placedSet={},L={headerAt=function()end,placeCustom=function(f,h) f:SetHeight(h) end},
    RefreshInfoBar=function() refreshes=refreshes+1 end,
    NotifyStructuralRefresh=function() structural=structural+1 end,
    GetWidgetDef=function()return true end,GetWidgetDisplayName=function(_,id)return id end,
    GetAvailableWidgetOptions=function()return {{value="new",text="New"}} end},{__index=_G})
local function build()
    buttons, dropdowns, lists = {}, {}, {}
    local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
end
build()
assert(#lists==3 and lists[1].zone=="left" and lists[3].zone=="right","all zones must share one editor")
assert(lists[1].cards and lists[1].actionsInToolbar and lists[1].dragGroup==lists[3].dragGroup,"zones must share card and drag behavior")
assert(buttons["Remove"].enabled==false,"selection actions must start disabled")
lists[1].onSelect("gold")
build()
buttons["Move down"].click()
assert(table.concat(db.zones.left,",")=="time,gold","toolbar must reuse gap-aware reorder semantics")
lists[1].onDrop("gold",lists[3],1)
assert(db.zones.right[1]=="gold" and #db.zones.left==1,"cross-zone drop must move without duplication")
build()
buttons["Remove"].click()
assert(#db.zones.right==0,"remove selected widget")
build()
buttons["Undo removal"].click()
assert(db.zones.right[1]=="gold","undo must restore original zone and position")
build()
dropdowns[1].choose("center")
assert(db.zones.center[2]=="gold" and #db.zones.right==0,"zone dropdown must move selected widget")
dropdowns[2].choose("new")
assert(db.zones.left[2]=="new","zone add picker must add to its own zone")
assert(refreshes==6 and structural>=7,"mutations must refresh runtime and settings")
print("OK: Info Bar unified Arrangement editor")
