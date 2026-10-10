local function Node()
 local n={height=80}
 return setmetatable(n,{__index=function(_,k)
  if k=='GetHeight' then return function() return n.height end end
  if k=='CreateFontString' then return function() return Node() end end
  return function() end
 end})
end
CreateFrame=function() return Node() end
local db={bags={appearance={},behavior={}},alts={}}
local providers,headers={},{}
local ns={L=setmetatable({},{__index=function(_,k)return k end}),Settings={ProviderPanels={}},QUI_Options={},QUI_SettingsLayoutShared={}}
function ns.Settings.ProviderPanels:RegisterAfterLoad(fn)
 fn({GUI=setmetatable({},{__index=function()return function()return Node()end end}),
 U={GetProfileDB=function()return db end},NotifyProviderFor=function()end,
 RegisterShared=function(k,p)providers[k]=p end})
end
ns.QUI_Options.BuildSettingRow=function(_,label,widget)return {label=label,widget=widget}end
ns.QUI_SettingsLayoutShared.MakeLayout=function()
 return {headerAt=function(h)headers[#headers+1]=h end,
 sectionAt=function()return {frame=Node(),AddRow=function()end}end,
 closeSection=function()end,placeCustom=function()end,relayoutSections=function()end}
end
local root=os.getenv('QUI_PAGES_ROOT') or '.'
assert(loadfile(root..'/QUI_Bags/bags/settings/bags_providers.lua'))('QUI',ns)
assert(loadfile(root..'/modules/alts/settings/alts_providers.lua'))('QUI',ns)
local expected={bags={general={'General','Appearance'},corners={'Icon Corners'},behavior={'Behavior','Auto-Open'},junk={'Junk'},currency={'Currency Bar'},cache={'Cached Data'}},alts={general={'Alts Module','Scanners'},columns={'Roster Columns'},currency={'Currencies Tab'},reputation={'Reputations Tab'},cache={'Cache'}}}
for id,pages in pairs(expected)do
 for page,want in pairs(pages)do
  headers={};providers[id].build(Node(),id,1000,{providerPage=page})
  assert(table.concat(headers,'|')==table.concat(want,'|'),id..' '..page..' must construct only its own sections, got '..table.concat(headers,'|'))
 end
 headers={};providers[id].build(Node(),id,1000)
 assert(#headers==(id=='bags' and 8 or 6),'unfiltered provider must preserve all sections')
end
local registered={}
ns.QUI_Options.RegisterFeatureTile=function(_,config)registered[config.id]=config end
for _,id in ipairs({'bags','alts'})do
 assert(loadfile(root..'/QUI_Options/tiles/'..id..'.lua'))('QUI',ns)
 ns[id=='bags' and 'QUI_BagsTile' or 'QUI_AltsTile'].Register(Node())
 assert(#registered[id].subPages==(id=='bags' and 6 or 5),'focused pages must be registered')
 for _,page in ipairs(registered[id].subPages)do
  assert(page.renderOptions.providerPage and page.searchSections and not page.sectionNav)
 end
end
local f=assert(io.open(root..'/QUI_Options/framework.lua'));local source=f:read('*a');f:close()
local block=assert(source:match('(function GUI:ResolveV2SectionNavigation.-)\nfunction GUI:ResolveV2Navigation'))
local GUI={MainFrame={}}
function GUI:ResolveV2Navigation(tab)return {tileId=tab==19 and 'bags' or 'alts'}end
function GUI:FindV2TileByID(_,id)return {config=registered[id]}end
local env=setmetatable({GUI=GUI},{__index=_G});local chunk=assert(loadstring(block));setfenv(chunk,env);chunk()
for id,config in pairs(registered)do
 for i,page in ipairs(config.subPages)do
  for _,section in ipairs(page.searchSections)do
   local route=GUI:ResolveV2SectionNavigation(id=='bags' and 19 or 20,section)
   assert(route.tileId==id and route.subPageIndex==i,'legacy section search must reach its focused page')
  end
 end
end
assert(GUI:ResolveV2SectionNavigation(19,'Unknown')==nil,'unrecognized sections retain legacy routing')
print('OK: options_provider_pages_test')
