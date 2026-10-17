local f=assert(io.open("modules/layout/layoutmode.lua"));local source=f:read("*a");f:close()
local mode={_handles={},_elements={},isActive=true}
local shown,hidden,selected=0,0
local settings={Show=function(_,key)shown=shown+1;selected=key end,
 Hide=function(_,keep)assert(keep);hidden=hidden+1 end,Reset=function()end}
local ns={L=setmetatable({},{__index=function(_,k)return k end}),QUI_LayoutMode_Settings=settings}
local env=setmetatable({QUI_LayoutMode=mode,ns=ns,LibStub=function()end,
 GetCursorPosition=function()return 150,150 end,InCombatLockdown=function()return false end},{__index=_G})
local function LoadBetween(first,last)
 local a=assert(source:find(first,1,true));local b=assert(source:find(last,a+1,true))
 local chunk=assert(loadstring(source:sub(a,b-1)));setfenv(chunk,env);chunk()
end
LoadBetween("function QUI_LayoutMode:SelectMover(","GetFrameAnchoring = function()")
LoadBetween("function QUI_LayoutMode:GetMoversAtCursor()","AddHandleScripts = function(")
local function Handle(scale,left,right,visible)
 return {IsShown=function()return visible end,GetEffectiveScale=function()return scale end,
 GetLeft=function()return left end,GetRight=function()return right end,
 GetBottom=function()return 100/scale end,GetTop=function()return 200/scale end,
 _settingsButton={Show=function()end,Hide=function()end}}
end
mode._handles={a=Handle(1,100,200,true),b=Handle(2,50,100,true),
 hidden=Handle(1,100,200,false),outside=Handle(1,300,400,true)}
mode._elements={a={label="Zulu"},b={label="Alpha"}}
local keys=mode:GetMoversAtCursor()
assert(#keys==2 and keys[1]=="b" and keys[2]=="a", "overlap picker must respect effective scale, visibility, and stable label order")
mode:SelectMover("a",false)
assert(hidden==1 and shown==0 and mode._selectedKey=="a", "selection alone must not open settings")
mode:SelectMover("a");mode:SelectMover("a")
assert(shown==2 and selected=="a", "explicit settings access must remain open on repeated clicks")
local buttons={}
env.MenuUtil={CreateContextMenu=function(_,build)
 build(nil,{CreateTitle=function()end,CreateButton=function(_,label,click)buttons[#buttons+1]={label,click}end})
end}
mode:OpenMoverSettings(mode._handles.a)
assert(#buttons==2 and buttons[1][1]=="Alpha", "right-click overlap must offer every visible mover")
buttons[1][2]()
assert(selected=="b", "picker entry must open the chosen mover rather than the topmost mover")
mode.isActive=false;buttons[2][2]()
assert(selected=="b", "an old menu must not change selection after Layout Mode closes")
print("OK: layoutmode selection and overlap picker")

-- Exercise the production mouse-up dispatch, including drag release.
local mouseUp
env.handle={_barKey="a",SetScript=function(_,event,fn)if event=="OnMouseUp" then mouseUp=fn end end}
LoadBetween('    handle:SetScript("OnClick", nil)', '    handle:SetScript("OnDragStart",')
mode.isActive=true
buttons={};mouseUp(env.handle,"LeftButton")
assert(#buttons==2, "left click must show the overlap chooser too")
buttons={};mouseUp(env.handle,"RightButton")
assert(#buttons==2, "right click must still show the overlap chooser")
buttons={};env.handle._justDragged=true;mouseUp(env.handle,"LeftButton")
assert(#buttons==0, "drag release must not open the overlap chooser")
env.handle._justDragged=nil
mode._handles.b=nil
local priorShown,priorHidden=shown,hidden
mouseUp(env.handle,"LeftButton")
assert(shown==priorShown and hidden==priorHidden+1, "single mover left click must select without settings")
mouseUp(env.handle,"RightButton")
assert(shown==priorShown+1, "single mover right click must open settings")
print("OK: either click overlap chooser and single mover behavior")

-- Use the real gear callback; only the matching open panel toggles closed.
local gearClick,visible
local gearCreations=0
env.UIKit={CreateIconButton=function(_,opts)
 gearCreations=gearCreations+1
 gearClick=opts.onClick
 return {SetPoint=function()end,SetFrameLevel=function()end,
  Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
end}
env.handle.GetFrameLevel=function()return 100 end
settings.IsShown=function()return visible end
settings.Show=function(_,key)visible=true;settings._currentKey=key;selected=key end
settings.Hide=function(_,keep)assert(keep);visible=false end
LoadBetween('    local gear = ','    handle:SetScript("OnEnter",')
local originalGear=env.handle._settingsButton
originalGear:Show()
LoadBetween('    local gear = ','    handle:SetScript("OnEnter",')
assert(gearCreations==1 and env.handle._settingsButton==originalGear,
 "reused mover handles must keep one gear instead of accumulating child buttons")
assert(not originalGear.shown, "reusing a mover must hide its previously visible gear")
visible=false;gearClick()
assert(visible and settings._currentKey=="a", "gear must open its mover settings")
gearClick()
assert(not visible and mode._selectedKey=="a", "gear must close its open panel without deselecting the mover")
gearClick()
assert(visible, "gear must reopen the closed panel")
settings._currentKey="anotherMover";gearClick()
assert(visible and settings._currentKey=="a", "gear must switch another mover's panel to its own")
env.InCombatLockdown=function()return true end;gearClick()
assert(visible, "gear must not toggle during combat")
print("OK: gear toggles its panel while preserving selection")
