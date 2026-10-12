package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Sort=require('sort_button')

-- A press cycles Recently Added, Categories, Alphabetical, Load Order.
assert(Sort.next(2)==1 and Sort.next(1)==0 and Sort.next(0)==3 and Sort.next(3)==2 and Sort.next(9)==2)
assert(Sort.text(1)=='CATEGORIES' and Sort.text(3)=='LOAD ORDER' and Sort.text(9)=='RECENTLY ADDED')

-- config.ini keeps every other line; SortBy is replaced, added to [Modules], or [Modules] is added.
assert(Sort.config('[Modules]\nSortBy=1\nPreferredCategoryMinimum=2\n',3)
    =='[Modules]\nSortBy=3\nPreferredCategoryMinimum=2\n')
assert(Sort.config('[Other]\nA=1\n\n[Modules]\nPreferredCategoryMinimum=2\n\n[Last]\nB=2\n',2)
    =='[Other]\nA=1\n\n[Modules]\nPreferredCategoryMinimum=2\nSortBy=2\n\n[Last]\nB=2\n')
assert(Sort.config('[Other]\r\nA=1\r\n',0)=='[Other]\r\nA=1\r\n\r\n[Modules]\r\nSortBy=0\r\n','line endings kept')
assert(Sort.config(nil,1)=='[Modules]\nSortBy=1\n','no config.ini yet')

-- The label is found from the filter glyph: icon -> box -> row -> second child. Once per
-- menu "sort by" goes over it and the button moves from the footer to DMM's overlay.
local function widget(name)
    local w={name=name,children={}}
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    function w:GetChildrenCount() return #self.children end
    function w:GetChildAt(i) return self.children[i+1] end
    function w:RemoveFromParent()
        local parent=self.parent
        for i,child in ipairs(parent and parent.children or {}) do if child==self then table.remove(parent.children,i) end end
        self.parent=nil
    end
    local function slot()
        local s={}
        function s:SetPadding(p) s.padding=p end
        function s:SetVerticalAlignment(v) s.vertical=v end
        function s:SetHorizontalAlignment(h) s.horizontal=h end
        return s
    end
    function w:AddChild(child) child.parent=self;self.children[#self.children+1]=child;child.Slot=slot();return child.Slot end
    w.AddChildToOverlay=w.AddChild
    function w:SetRenderOpacity(o) self.opacity=o end
    function w:SetJustification(j) self.justification=j end
    function w:SetRenderTranslation(t) self.translation=t end
    return w
end
local function chain(parent,child) parent:AddChild(child);return child end
local overlay=widget('overlay')
local bounds=chain(overlay,widget('bounds'))
local scale=chain(bounds,widget('scale'))
local footer=chain(scale,widget('footer'))
local buttonWidget=chain(footer,widget('button'))
local row=chain(buttonWidget,widget('row'))
local box=chain(row,widget('box'))
local icon=chain(box,widget('icon'))
local label=chain(row,widget('label'))
label.Slot.Padding={Left=12,Top=0,Right=28,Bottom=0}
local native={new=function() return {records={filter={icon=icon}}} end}
local files={config='[Modules]\nSortBy=1\n'}
local reports={}
local button=Sort.install(native,'config',function(path) return files[path] end,
    function(path,text) files[path]=text end,function(event,detail) reports[#reports+1]=event..' '..detail end)
local texts={}
local fonts={}
local api={setText=function(target,text) texts[#texts+1]={target=target,text=text} end,
    construct=function(class) return widget(class) end,caption=function(_,text) local c=widget('caption');c.text=text;return c end,
    Theme={font=function(target,_,size) fonts[target]=size end,textColor=function() end},theme={}}
button:show(1,api,'tree')
assert(#texts==0,'nothing to label before DMM builds its footer')
native.new()
button:show(1,api,'tree');button:show(1,api,'tree')
assert(#texts==1 and texts[1].target==label and texts[1].text=='CATEGORIES','labelled once per value')
local stack=row.children[2]
assert(stack.name=='/Script/UMG.VerticalBox' and stack.children[1].text=='sort by' and stack.children[2]==label
    and fonts[stack.children[1]]==11 and stack.children[1].opacity==0.75 and fonts[label]==12,
    'a small, faded "sort by" over a smaller label')
assert(stack.children[1].justification==0 and label.justification==0 and stack.children[1].Slot.horizontal==1
    and label.Slot.horizontal==1,'both lines start at the left')
assert(stack.Slot.padding.Left==12 and stack.Slot.padding.Right==28,'the label keeps its place')
assert(stack.translation.X==0 and stack.translation.Y==-2,'both lines sit 2px higher')
assert(buttonWidget.parent==overlay and #footer.children==0,'the button leaves the footer for the overlay')
assert(buttonWidget.Slot.horizontal==1 and buttonWidget.Slot.padding.Left==480 and buttonWidget.Slot.padding.Bottom==84,
    'a quarter of the way across, at the footer\'s height')
button:show(2,api,'tree')
assert(#texts==2 and texts[2].text=='RECENTLY ADDED' and #row.children==2,'placed once, relabelled')
assert(button:press(1)==0 and files.config=='[Modules]\nSortBy=0\n','a press saves the next way')
local failing=Sort.install({new=function() return {} end},'config',function() return '' end,
    function() error('disk full') end,function(event,detail) reports[#reports+1]=event..' '..detail end)
assert(failing:press(1)==nil and reports[#reports]:find('disk full',1,true),'a failed save is reported')
print('PASS the mod list\'s filter button sorts, found by its glyph')
