local f = assert(io.open(os.getenv("QUI_INFOBAR_SOURCE") or "modules/infobar/settings/infobar_content.lua"))
local source = f:read("*a"); f:close()
local first = assert(source:find('        L.headerAt(ns.L["Arrangement"])', 1, true), "Info Bar must expose a unified Arrangement editor")
local last = assert(source:find('        L.headerAt(ns.L["Widget Overrides"])', first, true))
local nodes, buttons, dropdowns, lists = {}, {}, {}, {}
local function node(parent)
    local n = {parent=parent, width=660, height=0, heightChanges=0, heightCalls=0, scripts={}, points={}}
    setmetatable(n, {__index=function() return function() end end})
    function n:ClearAllPoints() self.points={} end
    function n:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "number" then x,y,relative,relativePoint=relative,relativePoint,self.parent,point end
        self.points[#self.points+1]={point,relative,relativePoint,x or 0,y or 0}
    end
    function n:GetHeight() return self.height end
    function n:GetWidth()
        local left,right
        for _,p in ipairs(self.points) do
            if p[1]=="TOPLEFT" then left=p end
            if p[1]=="TOPRIGHT" or p[1]=="RIGHT" then right=p end
        end
        if left and right and left[2]==right[2] then return left[2]:GetWidth()+right[4]-left[4] end
        return self.width
    end
    function n:SetWidth(w) self.width=w end
    function n:SetSize(w,h) self.width,self.height=w,h end
    function n:SetHeight(h)
        self.heightCalls=self.heightCalls+1
        if self.height==h then return end
        self.height=h
        self.heightChanges=(self.heightChanges or 0)+1
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self:GetWidth(),h) end
    end
    function n:SetParent(parent) self.parent=parent end
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
function gui:CreateLabel(parent, text) local n=node(parent);n.text=text;return n end
function gui:CreateButton(parent,label,w,h,callback)
    local b=node(parent);b:SetSize(w,h);b.click=callback;buttons[label]=b;return b
end
function gui:CreateFormDropdown(parent,_,options,_,_,callback)
    local d=node(parent);d:SetSize(180,28);d.options=options;d.choose=callback;dropdowns[#dropdowns+1]=d;return d
end
ns.QUI_Options={PADDING=15,
    CreateAccentDotLabel=function(parent,text) local n=node(parent);n.text=text;return n end,
    CreateSettingsCardGroup=function(parent)
        local frame=node(parent);frame:SetHeight(60)
        return {frame=frame,Finalize=function() end}
    end}
assert(loadfile("core/settings_layout_shared.lua"))("QUI",ns)
ns.UIKit={CreateRoundedSurface=function() end}
ns.QUI_ReorderList={Build=function(host,_,spec)
    lists[#lists+1]=spec
    return node(host), math.max(44,#spec.items*32+4)
end}
local zones={{key="left",label="Left Zone"},{key="center",label="Center Zone"},{key="right",label="Right Zone"}}
local env
env=setmetatable({ns=ns,GUI=gui,content=node(),db=db,QUICore=ns.Addon,ZONE_DEFS=zones,
    InfoBarPageState=state,placedSet={},
    RefreshInfoBar=function() refreshes=refreshes+1 end,
    NotifyStructuralRefresh=function() structural=structural+1 end,
    GetWidgetDef=function()return true end,GetWidgetDisplayName=function(_,id)return id end,
    GetAvailableWidgetOptions=function()return {{value="new",text="New"}} end},{__index=_G})
local function build()
    buttons, dropdowns, lists = {}, {}, {}
    env.L=ns.QUI_SettingsLayoutShared.MakeLayout(env.content,env.U,0)
    local ending=assert(source:find('        L.relayoutSections()',last,true))
    local finish=assert(source:find('        return content:GetHeight()',ending,true))
    local chunk=assert(loadstring(source:sub(first,last-1)..[[
        L.headerAt(ns.L["Widget Overrides"])
        local section=L.sectionAt()
        L.closeSection(section)
    ]]..source:sub(ending,finish-1)))
    setfenv(chunk,env);chunk()
end
local function bounds(frame)
    if frame == env.content then return 0,0 end
    local p=assert(frame.points[1], "frame must be anchored")
    local x,y=bounds(p[2])
    if p[3]:find("RIGHT") then x=x+p[2]:GetWidth() end
    if p[3]:find("BOTTOM") then y=y-p[2]:GetHeight() end
    if p[3] == "LEFT" or p[3] == "RIGHT" then y=y-p[2]:GetHeight()/2 end
    if p[1] == "LEFT" or p[1] == "RIGHT" then y=y+frame:GetHeight()/2 end
    return x+p[4],y+p[5]
end
local function checkLayout(width, wrapped)
    env.content:SetWidth(width+30)
    build()
    local editor=buttons["Move up"].parent
    local editorX,editorY=bounds(editor)
    local controls={buttons["Move up"],buttons["Move down"],dropdowns[1],buttons["Remove"],buttons["Undo removal"]}
    local bottom=0
    for i,control in ipairs(controls) do
        local x,y=bounds(control)
        x,y=x-editorX,y-editorY
        assert(x>=0 and x+control:GetWidth()<=width, "toolbar control "..i.." clips at editor width "..width)
        bottom=math.min(bottom,y-control:GetHeight())
        for j=1,i-1 do
            local other=controls[j]
            local ox,oy=bounds(other)
            ox,oy=ox-editorX,oy-editorY
            assert(x>=ox+other:GetWidth() or ox>=x+control:GetWidth() or y-control:GetHeight()>=oy or oy-other:GetHeight()>=y,
                "toolbar controls overlap")
        end
    end
    local _,upY=bounds(controls[1])
    local _,undoY=bounds(controls[5])
    assert((undoY<upY)==wrapped,"toolbar must wrap only at narrow widths")
    local shift=wrapped and 32 or 0
    assert(editor:GetHeight()==582+shift,"layout must reserve wrapped editor height")
    for _,n in ipairs(nodes) do
        if n.parent==editor and n.text=="Drag by the handle to reorder or move between zones." then
            local _,y=bounds(n)
            y=y-editorY
            assert(y==-142-shift and y<bottom,"hint must clear the toolbar")
        elseif n.parent==editor and n.height==410 then
            local _,y=bounds(n)
            y=y-editorY
            assert(y==-164-shift and -y+n.height+8==editor:GetHeight(),"columns must shift inside reserved editor height")
        end
    end
end
checkLayout(750-211-5-30-30,true)
checkLayout(501,true)
checkLayout(502,false)
checkLayout(660,false)
local editor=buttons["Remove"].parent
local header,section
for _,n in ipairs(nodes) do
    if n.text=="Widget Overrides" then header=n end
    if n.height==60 then section=n end
end
local _,headerY=bounds(header)
local _,sectionY=bounds(section)
local initialHeight=env.content:GetHeight()
local heightChanges=env.content.heightCalls
for index,width in ipairs({474,474,660,660,474,660}) do
    env.content:SetWidth(width+30)
    editor.scripts.OnSizeChanged(editor,width)
    local editorX,editorY=bounds(editor)
    local x,y=bounds(buttons["Undo removal"])
    assert(x-editorX+buttons["Undo removal"]:GetWidth()<=width,"resize must keep Undo inside the editor")
    assert(y-editorY==(width<502 and -138 or -106),"resize must restore the correct toolbar row")
    local shift=width<502 and 32 or 0
    assert(editor:GetHeight()==582+shift,"resize must update editor height")
    local _,hy=bounds(header)
    local _,sy=bounds(section)
    assert(hy==headerY-shift and sy==sectionY-shift,"resize must move following header and section exactly once")
    assert(hy==editorY-editor:GetHeight()-14,"following header must stay below the editor")
    assert(env.content:GetHeight()==initialHeight+shift,"resize must update total content height without drift")
    local expectedChanges=({1,1,2,2,3,4})[index]
    assert(env.content.heightCalls==heightChanges+expectedChanges,"each height transition must update content exactly once")
end
local remaining=header.parent
local tailHeight=remaining:GetHeight()
remaining:SetHeight(tailHeight+20)
assert(env.content:GetHeight()==initialHeight+20,"later section height changes must still update content height")
remaining:SetHeight(tailHeight)
assert(env.content:GetHeight()==initialHeight,"later section height changes must restore content height")
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
ns.Helpers={}
assert(loadfile("modules/layout/layoutmode_utils.lua"))("QUI",ns)
env.U=ns.QUI_LayoutMode_Utils
env.U._layoutModePositionOnly=true
build()
assert(env.content:GetHeight()==26,"position-only suppression must retain its original content height")
print("OK: Info Bar unified Arrangement editor")
