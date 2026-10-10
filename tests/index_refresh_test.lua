package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Refresh=require('index_refresh')

-- Widgets: parents, children, visibility.
local function widget(name)
    local w={name=name,children={},visibility=0}
    function w:GetParent() return self.parent end
    function w:RemoveFromParent()
        local parent=self.parent
        if not parent then return end
        for i,child in ipairs(parent.children) do if child==self then table.remove(parent.children,i);break end end
        self.parent=nil
    end
    function w:AddChild(child)
        child:RemoveFromParent();child.parent=self;self.children[#self.children+1]=child
        return {SetHorizontalAlignment=function() end,SetVerticalAlignment=function() end}
    end
    function w:SetContent(child)
        for _,old in ipairs(self.children) do old.parent=nil end
        self.children={}
        return self:AddChild(child)
    end
    function w:SetVisibility(value) self.visibility=value end
    return w
end

local builds,applied,reports,fail=0,{},{},false
local function setup()
    builds=0
    local pages={build=function(_,providers,_,api)
        assert(not fail,'build failed')
        builds=builds+1
        local root,box,switcher=widget('root'..builds),widget('box'..builds),widget('switcher'..builds)
        root:SetContent(box);box:SetContent(switcher)
        local page={n=builds,root=root,switcher=switcher,mode='browser',revision=builds==1 and 7 or 1,
            compatibleOnly=api.compatibleOnly,api=api,providers=providers}
        function page:setInputMode(mode) self.inputMode=mode;self.modeCalls=(self.modeCalls or 0)+1 end
        function page:showDetail() self.mode='detail' end
        function page:showBrowser() self.mode='browser' end
        return page
    end}
    assert(Refresh.install(pages,function(event,detail) reports[#reports+1]=event..': '..detail end))
    assert(not Refresh.install(pages),'installs once')
    local api={construct=function(class) return widget(class) end,need=function(value) return value end,
        applied=function(provider,event) applied[#applied+1]=provider..':'..event end,compatibleOnly=true}
    return pages.build('tree',{'p'},nil,api),api
end

local page,api=setup()
assert(builds==1 and page.n==1 and page.compatibleOnly==true,'DMM gets a stand-in for its page')
local first=page.root
-- Nothing applied: ticks never rebuild.
page:setInputMode('keyboard')
assert(builds==1 and page.inputMode=='keyboard')
-- Applied on a page: DMM still hears it; the browser rebuilds once it shows on a tick.
page:showDetail()
page.api.applied('ModCoreSettings','applied')
assert(applied[1]=='ModCoreSettings:applied')
page:setInputMode('keyboard')
assert(builds==1,'no rebuild while a page is open')
-- A link passes through the browser to another page within one tick: no rebuild.
page:showBrowser();page:showDetail()
page:setInputMode('keyboard')
assert(builds==1,'a link through the browser does not rebuild')
page:showBrowser()
page.compatibleOnly=false
page:setInputMode('xbox')
assert(builds==2 and page.n==2,'the browser rebuilds on the next tick it shows')
assert(page.inputMode=='xbox' and page.modeCalls==1,'the tick reaches the rebuilt page')
assert(page.api.compatibleOnly==false,'the filter carries over')
assert(page.revision==8,'queued input for the old rows is dropped')
assert(page.root==first,'DMM keeps its root widget')
local holder=first.children[1].children[1]
assert(#holder.children==2 and holder.children[1].name=='switcher1' and holder.children[1].visibility==1
    and holder.children[2].name=='switcher2' and holder.children[2].visibility==0,
    'the rebuilt switcher replaces the old one, which stays parented and collapsed')
page:setInputMode('xbox')
assert(builds==2,'one rebuild per apply')
page.mode='newfield'
assert(rawget(page,'mode')==nil,'writes reach the current page')
page.mode='browser'
-- A second apply stacks the next build in the same holder.
page:showDetail();page.api.applied('X','applied');page:showBrowser()
page:setInputMode('xbox')
assert(builds==3 and #holder.children==3 and holder.children[2].visibility==1 and holder.children[3].name=='switcher3')
-- A failed rebuild is reported; the current page stays and still takes the tick.
page:showDetail();page.api.applied('X','applied');page:showBrowser()
local current=page.n
fail=true
page:setInputMode('ps')
fail=false
assert(page.n==current and page.inputMode=='ps' and #reports==1 and reports[1]:find('^INDEX_REFRESH_FAILED: '),
    'a failed rebuild keeps the current page')
page:setInputMode('ps')
assert(page.n==current,'a failed rebuild is not retried every tick')
print('PASS the mod browser rebuilds after an Apply, the next time it shows')
