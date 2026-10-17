local function read(p)
    local f=assert(io.open(p));local s=f:read("*a");f:close();return s
end
local widgets=dofile("tests/helpers/character_chrome_harness.lua").Build()
local source=read(os.getenv("QUI_LOOT_SOURCE") or "modules/skinning/notifications/loot.lua")
local marker="-- <<< QUI_TEST_EXTRACT loot_history_timer_fill"
local a=assert(source:find(marker,1,true))
local b=assert(source:find("function Loot:ApplyResultsTheme()",a,true))
local enabled=true
local pixelSize=1
local pixelEnv={SkinBase={},Helpers={GetCore=function()return {GetPixelSize=function()return pixelSize end}end},type=type}
local pixelChunk=assert(loadstring(assert(read("core/uikit.lua"):match("(function SkinBase.GetPixelSize%(frame, default%).-\nend)"))))
setfenv(pixelChunk,pixelEnv);pixelChunk()
widgets.SkinBase.GetPixelSize=pixelEnv.SkinBase.GetPixelSize
widgets.ns.Helpers.SetFrameBackdropColor=function(frame,...)frame:SetBackdropColor(...)end
widgets.ns.Helpers.SetFrameBackdropBorderColor=function(frame,...)frame:SetBackdropBorderColor(...)end
local env=setmetatable({SkinBase=widgets.SkinBase,Helpers=widgets.ns.Helpers,frameParts={},Loot={},lootHistorySkinned=false,
 LSM={Fetch=function()return "QUITexture"end},GetDB=function()return {lootResults={enabled=enabled}}end,
 GetThemeColors=function()return {0,0,0,1},{1,1,1,1},{1,1,1,1},{1,1,1,1}end},{__index=_G})
local chunk=assert(loadstring(source:sub(a+#marker,b-1).."\nreturn SkinGroupLootHistoryFrame, Loot.ApplyLootHistoryTheme"));setfenv(chunk,env)
local skin,applyTheme=chunk()
local native=read("tests/framexml/Interface/AddOns/Blizzard_FrameXML/Mainline/LootHistory.lua")
local mixin={}
local elapsed=0
local nativeEnv=setmetatable({LootHistoryFrameMixin=mixin,C_LootHistory={
 GetSortedDropsForEncounter=function()return {{}}end,GetLootHistoryTime=function()return elapsed end}},{__index=_G})
local update=assert(loadstring(assert(native:match("(function LootHistoryFrameMixin:UpdateTimer%(%).-\nend)"))))
setfenv(update,nativeEnv);update()
local history=widgets.NewFrame("Frame")
history.Timer=widgets.NewFrame("Frame",nil,history)
history.Timer:SetSize(230,10)
local fill=history.Timer:CreateTexture()
fill:SetSize(234,13)
history.Timer.Fill=fill
history.Timer.Background=history.Timer:CreateTexture()
history.Timer.Border=history.Timer:CreateTexture()
history.encounterInfo={startTime=0,duration=100}
history.GetSelectedEncounterID=function()return 1 end
history.UpdateTimer=mixin.UpdateTimer
_G.GroupLootHistoryFrame=history
skin()
for _,px in ipairs({.5,1,2}) do
 pixelSize=px
 for _,pct in ipairs({0,.25,.5,.75,.99}) do
  elapsed=100*pct;history:UpdateTimer()
  assert(fill.height==10-2*px,"native thirteen-unit fill must fit both physical pixel insets at every UI scale")
  assert(math.abs(fill.width-(230-2*px)*(1-pct))<.00001,"native countdown ratio must fit both physical pixel insets each tick")
 end
end
elapsed=100;history:UpdateTimer();assert(not fill.shown,"finished roll must retain native hide state")
enabled=false;pixelSize=1;elapsed=50;history:UpdateTimer()
assert(fill.width==114 and fill.height==8,"installed timer skin must keep fitting countdowns until the required reload")
applyTheme()
assert(history.Timer.Background:GetAlpha()==0 and history.Timer.Border:GetAlpha()==0,
 "post-toggle theme refresh must retain installed cosmetics until reload")
assert(env.frameParts[history.Timer].bg:IsShown() and env.frameParts[history.Timer].border:IsShown(),
 "installed timer chrome must remain visible until reload")
local nativeHistory=widgets.NewFrame("Frame")
nativeHistory.NineSlice=widgets.NewFrame("Frame",nil,nativeHistory)
nativeHistory.Bg=nativeHistory:CreateTexture()
nativeHistory.Timer=widgets.NewFrame("Frame",nil,nativeHistory)
nativeHistory.Timer.Background=nativeHistory.Timer:CreateTexture()
nativeHistory.Timer.Border=nativeHistory.Timer:CreateTexture()
nativeHistory.Timer.Fill=nativeHistory.Timer:CreateTexture()
for _,region in ipairs({nativeHistory,nativeHistory.NineSlice,nativeHistory.Bg,nativeHistory.Timer,
 nativeHistory.Timer.Background,nativeHistory.Timer.Border,nativeHistory.Timer.Fill}) do
 for _,method in ipairs({"SetAlpha","ClearAllPoints","SetPoint","SetSize","SetWidth","SetHeight"}) do
  region[method]=function()error("uninitialized native history must receive no theme writes")end
 end
end
_G.GroupLootHistoryFrame=nativeHistory;env.lootHistorySkinned=false
applyTheme()
assert(source:find("SkinBase.SkinTrimScrollBar(HistoryFrame.ScrollBar)",1,true),"loot history must use shared scroll skin")
print("OK: loot_history_timer_layout_test")
