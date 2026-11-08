local function noop() end
local function Frame(_, _, parent)
    local f = {children={},scripts={},width=0,height=0,parent=parent}
    if parent then parent.children[#parent.children+1]=f end
    function f:SetWidth(w) self.width=w; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,self.height) end end
    function f:SetHeight(h) self.height=h; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self.width,h) end end
    function f:SetSize(w,h) self.width=w;self:SetHeight(h) end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:SetScript(k,v) self.scripts[k]=v end
    f.HookScript=f.SetScript
    function f:CreateTexture() return setmetatable({}, {__index=function(_,k) return noop end}) end
    return f
end
CreateFrame=Frame
QUI={GUI={Colors={},CreateLabel=function(_,_,text)
    return {SetPoint=noop,SetAlpha=noop,SetText=noop,GetStringWidth=function() return #text*5 end}
end}}
local ns={L=setmetatable({}, {__index=function(_,k)return k end})}
assert(loadfile('modules/trackers/settings/aura_displays_pickers.lua'))('QUI',ns)
local data={}
for i=1,13 do
 local d={classFile='CLASS'..i,className='Class '..i,specs={}};data[i]=d
 for j=1,(i==11 and 4 or 3) do d.specs[j]={specID=i*10+j,name=j==4 and 'Restoration' or 'Specialization '..j} end
end
local P=ns.QUI_AuraDisplayPickers;P.ClassSpecData=function() return data end
local selected={}
local frame=P.BuildSpecPicker(Frame(),520,function()return selected end,noop,true,noop)
assert(#frame.children==41,'all 40 specs plus header must be created; never discard columns')
for _,width in ipairs({520,365,548,330,520}) do
 frame:SetWidth(width)
 local occupied={}
 for i=2,#frame.children do
  local btn=frame.children[i];local x,y=btn.point[4],-btn.point[5]
  assert(x>=0 and x+btn.width<=width,'every specialization must stay in viewport')
  assert(y+btn.height<=frame.height,'height must include wrapped fourth specialization')
  for _,r in ipairs(occupied) do assert(y~=r.y or x>=r.right or x+btn.width<=r.x,'spec buttons must not overlap') end
  occupied[#occupied+1]={x=x,y=y,right=x+btn.width}
 end
end
frame.children[35].scripts.OnClick()
assert(selected[114],'wrapped Restoration option remains selectable')
local classes=P.BuildClassPicker(Frame(),520,function()return {}end,noop)
classes:SetWidth(330)
assert(classes:GetHeight()>26,'classes must wrap at narrow width')
for _,btn in ipairs(classes.children) do assert(btn.point[4]+btn.width<=330,'every class must remain reachable') end
print('OK: aura_display_picker_bounds_test')
