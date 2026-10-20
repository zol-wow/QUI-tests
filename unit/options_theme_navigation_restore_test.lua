local file=assert(io.open(os.getenv("QUI_FRAMEWORK_SOURCE") or "QUI_Options/framework.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("function GUI:RefreshAccentColor()",1,true))
local last=assert(source:find("local function StyleScrollBar(",first,true))
local function scenario(surfaceTab)
    local applied,ready={},{}
    local oldOwner={_scrollFrame={GetVerticalScroll=function()return 640 end}}
    local oldTile={_activeSubPageIndex=4,_subPageBodies={[4]=oldOwner}}
    if surfaceTab then oldTile._surfacePagesByPage={[4]={
        getActiveTab=function()return "text" end,getPage=function()return oldOwner end}} end
    local original={_lastTileIndex=2,_tiles={[2]=oldTile},
        IsShown=function()return true end,GetPoint=function()return "CENTER",nil,"CENTER",15,25 end}
    local gui={MainFrame=original}
    local newOwner={_scrollFrame={},_contentBody={}}
    local activeKey="general"
    local newTile={_subPageBodies={[4]=newOwner},_settingsNavigationToken=1}
    if surfaceTab then newTile._surfacePagesByPage={[4]={
        getActiveTab=function()return activeKey end,
        selectTab=function(key)activeKey=key end,
        getPage=function()return newOwner end}} end
    local rebuilt={_tiles={[2]=newTile},ClearAllPoints=function()end,SetPoint=function()end,
        Show=function(self)self.shown=true end}
    function gui:TeardownFrameTree(old)assert(old==original)end
    function gui:InitializeOptions()self.MainFrame=rebuilt end
    function gui:SelectFeatureTile(f,index,opts)
        assert(f==rebuilt and index==2 and opts.noHistory,"theme reconstruction must not create a spurious Back destination")
        newTile._activeSubPageIndex=opts.subPageIndex;newTile._isActive=true
    end
    function gui:RunWhenSettingsLayoutReady(owner,target,callback,isCurrent)
        assert(owner==newOwner and target==newOwner._contentBody)
        ready.callback,ready.isCurrent=callback,isCurrent
    end
    local env=setmetatable({GUI=gui,UIParent={},JumpScrollTo=function(scroll,offset)
        assert(scroll==newOwner._scrollFrame);applied[#applied+1]=offset end},{__index=_G})
    local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
    gui:RefreshAccentColor()
    assert(#applied==0,"theme restoration must wait for selected page layout")
    assert(not surfaceTab or activeKey=="text","theme must restore the selected embedded tab first")
    assert(rebuilt.shown and ready.isCurrent(),"rebuilt selected page must remain the restore target")
    ready.callback()
    assert(applied[1]==640,"theme change must retain the user's settings scroll position")
    newTile._settingsNavigationToken=2
    assert(not ready.isCurrent(),"newer navigation must cancel the pending theme restore")
    newTile._settingsNavigationToken=1;newTile._activeSubPageIndex=3
    assert(not ready.isCurrent(),"changing page must cancel the pending restore")
    newTile._activeSubPageIndex=4
    if surfaceTab then
        activeKey="other"
        assert(not ready.isCurrent(),"changing embedded tab must cancel pending restore")
        activeKey="text"
    end
    if not surfaceTab then
        newTile._subPageBodies[4]={}
        assert(not ready.isCurrent(),"replacing the active variant body must cancel restoration")
    end
    gui.MainFrame={}
    assert(not ready.isCurrent(),"another rebuilt window must invalidate stale restoration")
end
scenario(false);scenario(true)
print("theme navigation restoration passed")
