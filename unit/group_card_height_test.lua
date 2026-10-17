local path=os.getenv('QUI_GROUP_SCHEMA_SOURCE') or 'QUI_GroupFrames/groupframes/settings/group_frames_schema.lua'
local f=assert(io.open(path));local source=f:read('*a');f:close()
local body=assert(source:match('(local function CreateSectionBuilder.-)\nlocal function GetFontListWithDefault'))
local options={};local host={SetHeight=function(self,h) self.height=h end}
local build=assert((loadstring or load)('return function(GetOptionsAPI,PrepareSectionHost,SetSearchContext,GetRenderContextMode,SECTION_BOTTOM_PAD)\n'..body..'\nreturn CreateSectionBuilder end'))()(function() return options end,function() end,function() end,function() end,10)
local builder=build(host,{})
local card={frame={height=240}}
function card.Finalize() end
function card.frame:GetHeight() return self.height end
function card.frame:HookScript(_,fn) self.changed=fn end
builder.CloseCard(card)
assert(builder.Height()==250)
assert(not card.frame.changed, 'shared card layout must own parent height updates')
card.frame.height=160
assert(host._quiMeasureSettingsHeight()==170,'absolute measurement must shrink with the card')
card.frame.height=220
assert(host._quiMeasureSettingsHeight()==230,'absolute measurement must grow with the card')
builder.Spacer(7)
assert(builder.Height(17)==264)
assert(host._quiMeasureSettingsHeight()==244,'measurement must retain trailing spacing and custom bottom padding')
print('OK: group_card_height_test')
local first=assert(source:find('local function CreateSingleSectionTabFeature',1,true))
local last=assert(source:find('local GENERAL_TAB_FEATURE',first,true))
local factories=assert((loadstring or load)('return function(Schema)\n'..source:sub(first,last-1)..'\nreturn CreateSingleSectionTabFeature,CreateMultiSectionTabFeature end'))()
local single,multi=factories({Feature=function(v) return v end,Section=function(v) return v end})
assert(single('test','settings',1,function() end).surfaces.groupFrameTab.bottomPadding==0,'embedded tabs must not reserve a forty pixel footer')
assert(multi('test',{{id='settings',minHeight=1,render=function() end}}).surfaces.groupFrameTab.bottomPadding==0,'multi-section tabs must not reserve a forty pixel footer')
print('OK: embedded group tab footer spacing')
