package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Input=require('editor_input')
local Hint=require('editor_hint')

-- Enter is a key bind that only counts; A and the mouse button are read from the controller.
local bound
local held={}
local input=Input.new({register=function(key,callback) bound={key=key,callback=callback} end,keys={RETURN='enter'},
    key=function(name) return {KeyName=name} end})
local api={pc={IsInputKeyDown=function(_,key) return held[key.KeyName]==true end}}
assert(bound.key=='enter')
bound.callback()
assert(input.take(false,api)==true and input.take(false,api)==false,'a press is taken once')
held.Gamepad_FaceButton_Bottom=true
assert(input.take(true,api)==false,'an A already held when reading starts is not a press')
held.Gamepad_FaceButton_Bottom=false
assert(input.take(true,api)==false)
held.Gamepad_FaceButton_Bottom=true
assert(input.take(true,api)==true and input.take(true,api)==false,'A counts once when it goes down')
held.LeftMouseButton=true
assert(input.pointer(api)==true and input.pointer({})==false)
assert(Input.new({}).take(true,api)==false,'without a key bind or key names nothing is pressed')
print('PASS Enter is bound; A and the mouse button are read from the controller')

-- The hint: Confirm's glyph and a label at the end of DMM's footer, shown on request.
local function widget(kind)
    local w={kind=kind,children={},visibility=0}
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    local function slot() return {SetPadding=function() end,SetVerticalAlignment=function() end} end
    function w:SetContent(child) self.content=child;child.parent=self;return slot() end
    function w:AddChild(child) self.children[#self.children+1]=child;child.parent=self;return slot() end
    function w:SetVisibility(v) self.visibility=v end
    function w:SetInputAction(row) self.action=row end
    for _,name in ipairs({'SetWidthOverride','SetHeightOverride'}) do w[name]=function() end end
    return w
end
local footer,button,item,box,icon=widget('HorizontalBox'),widget('Button'),widget('HorizontalBox'),widget('SizeBox'),widget('Icon')
footer:AddChild(button);button:SetContent(item);item:AddChild(box);box:SetContent(icon)
local glyphs=0
local native={new=function() return {records={apply={icon=icon},popupApply={row='confirm'}},
    glyphs=function() glyphs=glyphs+1 end} end}
local hint=Hint.install(native)
local actions=native.new('pc','tree')
local pageApi={construct=function(path) return widget(path:match('%.(%w+)$')) end,
    caption=function() return widget('TextBlock') end,setText=function(w,text) w.text=text end,
    Theme={font=function() end,textColor=function() end},theme={}}
hint.show(nil,pageApi)
assert(#footer.children==1,'nothing is built until a hint is shown')
hint.show('ADJUST',pageApi)
local shown=footer.children[2]
assert(shown and shown.visibility==4 and shown.children[1].content.action=='confirm' and shown.children[2].text=='ADJUST',
    'the hint carries Confirm\'s glyph and its label')
hint.show(nil,pageApi)
assert(shown.visibility==1 and #footer.children==2,'hidden, not rebuilt')
actions:glyphs()
assert(glyphs==1 and shown.children[1].content.action=='confirm','the glyph follows DMM\'s glyph refresh')
-- With DMM's pages, the glyph is Enter's on a keyboard (ConfirmReturn) and A's on a
-- controller (Confirm): no one action has both.
local pages={build=function() return {setInputMode=function(self,mode) self.mode=mode end} end}
local footer2,button2,item2,box2,icon2=widget('HorizontalBox'),widget('Button'),widget('HorizontalBox'),widget('SizeBox'),widget('Icon')
footer2:AddChild(button2);button2:SetContent(item2);item2:AddChild(box2);box2:SetContent(icon2)
local native2={new=function() return {records={apply={icon=icon2},popupApply={row={DataTable='CommonInput',RowName='Confirm'}}},
    glyphs=function() end} end}
local moded=Hint.install(native2,pages,function(text) return 'FName '..text end)
native2.new('pc','tree')
local page=pages.build()
moded.show('ADJUST',pageApi)
local glyph=footer2.children[2].children[1].content
assert(glyph.action.DataTable=='CommonInput' and glyph.action.RowName=='FName ConfirmReturn','Enter on a keyboard')
page:setInputMode('xbox')
assert(page.mode=='xbox' and glyph.action.RowName=='Confirm','A on a controller')
page:setInputMode('keyboard')
assert(glyph.action.RowName=='FName ConfirmReturn','back to Enter')
print('PASS the footer hint shows Confirm\'s glyph and a label at the end of DMM\'s footer')
