local path=os.getenv('QUI_BUFF_SOURCE') or 'QUI_ActionBars/actionbars/settings/action_bars_buffdebuff_content.lua'
local f=assert(io.open(path));local source=f:read('*a');f:close()
local body=assert(source:match('(local function BuildBuffDebuffTab.-)\nns.QUI_BuffDebuffOptions'))
local function frame()
 local f={height=0}
 function f:SetPoint(point,_,_,_,y) if point=='TOPLEFT' then self.y=y end end
 function f:ClearAllPoints() end
 function f:SetHeight(h) self.height=h end
 return f
end
local settings={};local editors={};local callbacks={}
local opts={PADDING=15,CreateAccentDotLabel=function() return frame() end,CreateSettingsCardGroup=function() return {frame=frame(),Finalize=function() end} end}
local function section(_,headerAt)
 local header,y=headerAt('Section');return header,y,frame(),y-26
end
local function editor(parent,pad,gap,y,_,key)
 local f=frame();f.y=y;f.height=60;editors[key]=f
 return y-60-gap,f,60,function(fn) callbacks[key]=fn end
end
local ns={L=setmetatable({},{__index=function(_,k) return k end})}
local env=setmetatable({ns=ns,Opts=opts,GUI={SetSearchContext=function() end},GetBuffBordersSettings=function() return settings end,BuildSharedSection=section,BuildAuraSection=section,BuildAuraEditorSection=editor},{__index=_G})
local chunk=assert(loadstring(body..'\nreturn BuildBuffDebuffTab'));setfenv(chunk,env);local build=chunk()
local tab=frame();build(tab)
local function verify() local last=editors.debuffAuras;assert(tab.height==-last.y+last.height+10,'buff/debuff scroll extent must end ten pixels after the last editor') end
verify()
callbacks.buffAuras(120);verify()
editors.debuffAuras.height=140;callbacks.debuffAuras(140);verify()
print('OK: buff_editor_footer_test')
