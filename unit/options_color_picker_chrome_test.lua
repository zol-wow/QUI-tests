local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin=env.SkinBase
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
_G.SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=1};_G.PlaySound=function()end
_G.CreateColor=function(r,g,b) return {GenerateHexColorNoAlpha=function()
 return string.format("%02x%02x%02x",math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)) end}end
_G.CreateColorFromRGBAHexString=function(hex) return {GetRGB=function()
 return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255 end}end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua"))()
local picker=frame();_G.ColorPickerFrame=picker
picker.Border=frame(nil,picker);picker.Border.art=picker.Border:CreateTexture()
picker.Header=frame(nil,picker);picker.Header.art=picker.Header:CreateTexture();picker.Header.Text=picker.Header:CreateFontString()
picker.Footer=frame(nil,picker)
picker.Footer.OkayButton=frame("Button",picker.Footer);picker.Footer.CancelButton=frame("Button",picker.Footer)
picker.Content=frame(nil,picker)
local content=picker.Content
content.ColorPicker=frame("ColorSelect",content)
local wheel=content.ColorPicker
wheel.Alpha=frame(nil,wheel);wheel.AlphaThumb=frame(nil,wheel)
content.AlphaBackground=content:CreateTexture();content.ColorSwatchCurrent=content:CreateTexture();content.ColorSwatchOriginal=content:CreateTexture()
local hex=frame("EditBox",content);content.HexBox=hex;hex.Instructions=hex:CreateFontString()
for key,value in pairs(_G.ColorPickerHexBoxMixin)do hex[key]=value end
local insets
function hex:SetTextInsets(...)insets={...}end
hex:OnLoad();hex:SetScript("OnEnterPressed",hex.OnEnterPressed)
function wheel:SetColorRGB(r,g,b)self.rgb={r,g,b};self:Fire("OnColorSelect",r,g,b)end
function wheel:GetColorRGB()return unpack(self.rgb)end
function wheel:SetColorAlpha(a)self.colorAlpha=a end
function wheel:GetColorAlpha()return self.colorAlpha end
for key,value in pairs(_G.ColorPickerFrameMixin)do picker[key]=value end
picker:SetScript("OnShow",picker.OnShow);picker:SetScript("OnHide",picker.OnHide)
picker:OnLoad();picker:Hide()
local okay=picker.Footer.OkayButton:GetScript("OnClick")
local cancel=picker.Footer.CancelButton:GetScript("OnClick")
local selectColor=wheel:GetScript("OnColorSelect")
local enter=hex:GetScript("OnEnterPressed")
local file=assert(io.open(arg[1] or "QUI_Options/framework.lua"));local source=file:read("*a");file:close()
local first=assert(source:find("-- BEGIN settings color picker chrome",1,true))
local last=assert(source:find("-- END settings color picker chrome",first,true))
local gui={};local colors={border={.3,.35,.4,1},bg={.05,.06,.07,1},optionsWindow={.06,.07,.08,1}}
local chunk=assert(loadstring(source:sub(first,last-1)))
setfenv(chunk,setmetatable({GUI=gui,SkinBase=skin,C=colors},{__index=_G}));chunk()
local nativeSetup=picker.SetupColorPickerAndShow
local nativeSizing=false
function picker:SetupColorPickerAndShow(info)nativeSizing=true;nativeSetup(self,info);nativeSizing=false end
local setWidth=picker.SetWidth
function picker:SetWidth(w)assert(nativeSizing,"QUI must not resize native color picker");setWidth(self,w)end
local selected,restored
local function open(alpha)
 gui:ShowColorPicker({r=.2,g=.4,b=.6,opacity=.4,hasOpacity=alpha,
 swatchFunc=function()selected={picker:GetColorRGB()}end,
 cancelFunc=function(prev)restored=prev end})
end
open(true)
assert(picker:GetWidth()==388 and wheel:GetWidth()==255 and wheel.Alpha:IsShown() and picker:GetColorAlpha()==.4,
 "native alpha controls and width must remain authoritative")
assert(skin.GetBackdrop(picker)._quiRoundedSurface.radius==8 and picker.Border.art:GetAlpha()==0
 and picker.Header.art:GetAlpha()==0,"native dialog chrome must be replaced by a rounded QUI shell")
assert(skin.GetBackdrop(picker.Footer.OkayButton) and skin.GetBackdrop(picker.Footer.CancelButton)
 and skin.GetBackdrop(hex),"both footer actions and hex entry must use QUI chrome")
assert(picker.Footer.OkayButton:GetScript("OnClick")==okay and picker.Footer.CancelButton:GetScript("OnClick")==cancel
 and wheel:GetScript("OnColorSelect")==selectColor and hex:GetScript("OnEnterPressed")==enter,
 "styling must preserve native accept cancel wheel and hex handlers")
assert(insets[1]==16 and insets[2]==0,"native hex-prefix spacing must remain intact")
hex:SetText("1a3355");hex:Fire("OnEnterPressed")
assert(math.abs(selected[1]-26/255)<.0001 and math.abs(selected[3]-85/255)<.0001,
 "native hex entry must still update wheel and swatch callback")
picker.Footer.CancelButton:Fire("OnClick")
assert(not picker:IsShown() and restored.r==.2 and restored.g==.4 and restored.b==.6 and restored.a==.4,
 "native Cancel must retain original values and dismiss the dialog")
local backdrop=skin.GetBackdrop(picker)
open(false)
assert(picker:GetWidth()==331 and wheel:GetWidth()==200 and not wheel.Alpha:IsShown()
 and not content.AlphaBackground:IsShown(),"no-opacity theme picker must retain native compact layout")
assert(skin.GetBackdrop(picker)==backdrop,"reopening must reuse the QUI shell")
picker.Footer.OkayButton:Fire("OnClick")
assert(not picker:IsShown() and selected[1]==.2,"native Okay must still invoke swatch callback and close")
local _,entryPoints=source:gsub("GUI:ShowColorPicker%(%{","")
assert(entryPoints==3,"all three settings color-picker paths must use the shared wrapper")
print("settings color picker chrome passed")
