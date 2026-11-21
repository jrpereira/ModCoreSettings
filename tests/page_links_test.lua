package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Links=require('page_links')

local function setup(dirty)
    local calls,texts={}, {}
    local providers={
        {id='Source',choices={{id='Link',mcNavigation=true,mcLinkPage='Target'},{id='Plain'}}},
        {id='Empty',noSettings=true,choices={}},
        {id='Target',choices={{id='X'}}},
    }
    local page={rows={{providerIndex=1},{providerIndex=3}},controlStatus={}}
    local model={saved={}}
    function model:set(index,value) self.saved[index]=value end
    function model:dirty() return dirty end
    page.controls={show=function(self) self.model=model;calls[#calls+1]='show' end,
        tick=function() calls[#calls+1]='tick';return false end}
    function page:showBrowser() calls[#calls+1]='browser' end
    function page:showDetail(row) calls[#calls+1]='detail '..row end
    local pages={build=function() return page end}
    assert(Links.install(pages) and not Links.install(pages))
    local built=pages.build({},providers,nil,{setText=function(_,copy) texts[#texts+1]=copy end})
    return built,model,calls,texts,providers
end

-- Resetting a link row opens nothing: navigation rows have nothing to reset.
do
    local Navigation=require('navigation')
    local function open(provider)
        local m={items=provider.choices,pending={},committed={}}
        for i,choice in ipairs(provider.choices) do m.pending[i],m.committed[i]=choice.default,choice.default end
        function m:set(i,value) self.pending[i]=value end
        function m:reset(i) self:set(i,self.items[i].default) end
        function m:dirty() return false end
        return m
    end
    local providers={{id='Source',choices={{id='Link',mcNavigation=true,mcLinkPage='Target',default=0},
        {id='Plain',default=0}}},{id='Target',choices={{id='X'}}}}
    local calls={}
    local page={rows={{providerIndex=1},{providerIndex=2}},controlStatus={}}
    page.controls={show=function(self) self.model=Navigation.open(providers[1],open) end,tick=function() return false end}
    function page:showBrowser() calls[#calls+1]='browser' end
    function page:showDetail(row) calls[#calls+1]='detail '..row end
    local pages={build=function() return page end}
    Links.install(pages)
    local built=pages.build({},providers,nil,{})
    built.controls:show(1)
    local model=built.controls.model
    model:reset(1)
    assert(built.controls:tick()==false and #calls==0,'a reset link row opens nothing')
    model:set(2,1);model:reset(2)
    assert(model.pending[2]==0,'other rows still reset')
end

local page,model,calls,texts=setup(false)
page.controls:show(1)
model:set(2,1)
assert(model.saved[2]==1,'ordinary settings still save')
-- Left and Right on a link row set it without activating: nothing opens.
model:set(1,0)
assert(page.controls:tick()==false and #calls==2,'Left and Right do not open a link')
-- A click or Enter marks the activation first.
model.mcActivateLink=true
model:set(1,0)
assert(model.saved[1]==nil and model.mcActivateLink==nil,'link activation saves nothing')
assert(page.controls:tick()==true)
assert(table.concat(calls,',')=='show,tick,tick,browser,detail 2','links open through the browser')
assert(page.controls:tick()==false,'a link fires once')

-- A page that fails to open never reaches DMM's tick: the status says so and it is reported.
do
    local providers={{id='Source',choices={{id='Link',mcNavigation=true,mcLinkPage='Target'}}},
        {id='Target',choices={{id='X'}}}}
    local failing={rows={{providerIndex=1},{providerIndex=2}},controlStatus={}}
    local linkModel={}
    function linkModel:set() end
    function linkModel:dirty() return false end
    failing.controls={show=function(self) self.model=linkModel end,tick=function() return false end}
    function failing:showDetail() error('detail broke') end
    local statuses,reports={},{}
    Links.wrap(failing,providers,{setText=function(_,copy) statuses[#statuses+1]=copy end},nil,
        function(event,detail) reports[#reports+1]=event..' '..detail end)
    failing.controls:show(1)
    linkModel.mcActivateLink=true
    linkModel:set(1,0)
    local ok,result=pcall(failing.controls.tick,failing.controls)
    assert(ok and result==true,'the failure stays in the wrapper: '..tostring(result))
    assert(statuses[#statuses]=='Target page is unavailable.' and reports[1]
        and reports[1]:find('PAGE_LINK_FAILED Target',1,true),tostring(reports[1]))
end

page,model,calls,texts=setup(true)
page.controls:show(1)
model.mcActivateLink=true
model:set(1,0)
assert(page.controls:tick()==true and texts[1]=='Apply or discard changes before leaving this page.')
assert(not table.concat(calls,','):find('detail'))

local providers
page,model,calls,texts,providers=setup(false)
providers[1].choices[1].mcLinkPage='Empty'
page.controls:show(1)
model.mcActivateLink=true
model:set(1,0)
assert(page.controls:tick()==true and texts[1]=='Empty page is unavailable.')
-- A page left out of the browser list opens through DMM's full row list; the listed rows return.
page,model,calls,texts,providers=setup(false)
providers[3].mcBrowserHidden=true
local listed={{providerIndex=1}}
page.rows,page.allRows=listed,{{providerIndex=1},{providerIndex=3}}
local opened
function page:showDetail(row) opened=self.rows[row];calls[#calls+1]='detail '..row end
page.controls:show(1)
model.mcActivateLink=true
model:set(1,0)
assert(page.controls:tick()==true and opened==page.allRows[2] and page.rows==listed
    and table.concat(calls,',')=='show,tick,browser,detail 1','a hidden page opens through its link')
providers[3].mcBrowserHidden=nil
calls,opened={},nil
page.controls:show(1)
model.mcActivateLink=true
model:set(1,0)
assert(page.controls:tick()==true and opened==nil and texts[#texts]=='Target page is unavailable.',
    'only pages hidden from the browser open outside the listed rows')
-- A slot link opens its host page and sets the navigation pickers that gate the slot.
do
    local calls={}
    local items={
        {id='MCC_Page',mcNavigation=true,values={0,1,2},visibility={}},
        {id='Gate',mcNavigation=true,values={0,1},visibility={{target=1,values={[1]=true}}}},
        {id='Speed',visibility={}},
        {id='MCT_Template',mcSlotName='visuals',visibility={{target=2,values={[1]=true}}}},
    }
    local model={items=items,pending={0,0,3,5},sets={}}
    function model:set(index,value) self.pending[index]=value;self.sets[#self.sets+1]=items[index].id..'='..value end
    local providers={{id='Fangdango',mcLinkSlot={host='ModCoreControls',slot='visuals'},choices={}},
        {id='ModCoreControls',choices=items},{id='Other',mcLinkSlot={address='x:y'},choices={}}}
    local page={rows={{providerIndex=1},{providerIndex=2},{providerIndex=3}},controlStatus={}}
    page.controls={model=model,show=function() end,tick=function() return false end,
        refresh=function() calls[#calls+1]='refresh' end,
        select=function(_,index,keyboard) calls[#calls+1]='select '..index..tostring(keyboard) end}
    function page:showDetail(row) calls[#calls+1]='detail '..row end
    local pages={build=function() return page end}
    Links.install(pages)
    local built=pages.build({},providers,nil,{})
    built:showDetail(1)
    assert(table.concat(calls,',')=='detail 2,refresh,select 4true',table.concat(calls,','))
    assert(table.concat(model.sets,',')=='MCC_Page=1,Gate=1','parents first, smallest allowed value')
    calls,model.sets={},{}
    built:showDetail(1)
    assert(#model.sets==0,'already visible: nothing changes')
    calls={}
    built:showDetail(3)
    assert(table.concat(calls,',')=='detail 3','an unresolved link opens normally')
    calls={}
    built:showDetail(2)
    assert(table.concat(calls,',')=='detail 2','ordinary pages are untouched')
    page.rows={{providerIndex=1}}
    calls={}
    built:showDetail(1)
    assert(table.concat(calls,',')=='detail 1','missing host row falls back to the ordinary open')
end

-- mcLinkPage=<provider>:<slot> opens the slot's host page with the slot showing.
do
    local Contributions=require('menu_contributions')
    local function open(slots)
        local f={calls={},texts={}}
        local hostItems={
            {id='MCC_Page',mcNavigation=true,values={0,1},visibility={}},
            {id='MCT_Template',mcSlotName='visuals',visibility={{target=1,values={[1]=true}}}},
        }
        f.host={items=hostItems,pending={0,0},sets={}}
        function f.host:set(index,value) self.pending[index]=value;self.sets[#self.sets+1]=hostItems[index].id..'='..value end
        f.source={saved={}}
        function f.source:set(index,value) self.saved[index]=value end
        function f.source:dirty() return false end
        local providers={
            {id='ModCoreTemplates.module.Fangdango',
                choices={{id='Merged',mcNavigation=true,mcLinkPage='controls:visuals'}}},
            {id='Fangdango',mcLinkSlot={host='ModCoreControls',slot='visuals'},choices={}},
            {id='ModCoreControls',choices=hostItems},
        }
        local page={rows={{providerIndex=1},{providerIndex=2},{providerIndex=3}},controlStatus={}}
        page.controls={show=function(self) self.model=f.source end,tick=function() return false end,
            refresh=function() f.calls[#f.calls+1]='refresh' end,
            select=function(_,index) f.calls[#f.calls+1]='select '..index end}
        function page:showBrowser() f.calls[#f.calls+1]='browser' end
        function page:showDetail(row)
            f.calls[#f.calls+1]='detail '..row
            if row==3 then self.controls.model=f.host end
        end
        local pages={build=function() return page end}
        Links.install(pages,slots)
        f.page=pages.build({},providers,nil,{setText=function(_,copy) f.texts[#f.texts+1]=copy end})
        f.page.controls:show(1)
        f.page.controls.model.mcActivateLink=true
        f.page.controls.model:set(1,1)
        return f
    end
    local f=open({address=Contributions.address,provider=Contributions.provider})
    assert(f.source.saved[1]==nil,'a slot link saves nothing')
    assert(f.page.controls:tick()==true)
    assert(table.concat(f.calls,',')=='browser,detail 3,refresh,select 2',table.concat(f.calls,','))
    assert(table.concat(f.host.sets,',')=='MCC_Page=1','the host navigation reveals the slot')
    -- Without a slot controller the address is an ordinary, unknown page id.
    f=open(nil)
    assert(f.page.controls:tick()==true and f.texts[1]=='controls:visuals page is unavailable.')
end

-- Back on a page a link opened returns to the link's page, revealing and selecting its row;
-- a chain unwinds in order, and a page opened from the browser forgets the trail.
do
    local calls={}
    local function items(link)
        return {
            {id='Tab',mcNavigation=true,values={0,1},visibility={}},
            {id='Link',mcNavigation=true,mcLinkPage=link,visibility={{target=1,values={[1]=true}}}},
        }
    end
    local providers={
        {id='Main',choices=items('Main.inner')},
        {id='Main.inner',mcBrowserHidden=true,choices=items('Deep')},
        {id='Deep',choices={{id='X',visibility={}}}},
        {id='Other',choices={{id='Y',visibility={}}}},
    }
    local page={rows={{providerIndex=1},{providerIndex=3},{providerIndex=4}},controlStatus={},mode='browser'}
    page.allRows={page.rows[1],{providerIndex=2},page.rows[2],page.rows[3]}
    local models={}
    page.controls={tick=function() return false end,
        show=function(self,index)
            local model={items=providers[index].choices,pending={0,0},sets={}}
            function model:set(i,value) self.pending[i]=value;self.sets[#self.sets+1]=self.items[i].id..'='..value end
            function model:dirty() return false end
            self.model=model;models[index]=model
        end,
        refresh=function() calls[#calls+1]='refresh' end,
        select=function(_,index,keyboard) calls[#calls+1]='select '..index..tostring(keyboard) end}
    function page:showBrowser() self.mode='browser';calls[#calls+1]='browser' end
    function page:showDetail(row)
        local index=self.rows[row].providerIndex
        self.mode='detail';calls[#calls+1]='detail '..providers[index].id
        self.controls:show(index)
    end
    local reports={}
    local built=Links.wrap(page,providers,{},nil,function(event,detail) reports[#reports+1]=event..' '..detail end)
    local function follow()
        local model=built.controls.model
        model.mcActivateLink=true;model:set(2,0)
        assert(built.controls:tick()==true)
    end
    built:showDetail(1)
    models[1]:set(1,1)
    follow()
    assert(built.controls.model==models[2],'the inner page opens')
    follow()
    assert(built.controls.model==models[3],'a link on the inner page opens the next one')
    calls={}
    -- DMM's Back: showBrowser, then the page is back in detail.
    built:showBrowser()
    assert(built.mode=='detail' and built.controls.model==models[2],table.concat(calls,','))
    assert(built.rows[1].providerIndex==1,'the listed rows return after a hidden page reopens')
    built.controls:tick()
    assert(table.concat(calls,',')=='browser,browser,detail Main.inner,refresh,select 2true',table.concat(calls,','))
    assert(table.concat(models[2].sets,',')=='Tab=1','the link row is revealed again')
    calls={}
    built:showBrowser()
    built.controls:tick()
    assert(built.controls.model==models[1] and table.concat(calls,',')=='browser,browser,detail Main,refresh,select 2true',
        table.concat(calls,','))
    calls={}
    built:showBrowser()
    assert(built.mode=='browser' and table.concat(calls,',')=='browser','Back on the first page reaches the browser')
    -- Opened from the browser, a page starts a new trail.
    built:showDetail(1)
    follow()
    built:showBrowser()
    built:showDetail(3)
    calls={}
    built:showBrowser()
    assert(built.mode=='browser' and table.concat(calls,',')=='browser','a page opened from the browser goes back to it')
    -- A page that cannot reopen leaves the browser showing and is reported.
    built:showDetail(1)
    follow();follow()
    page.allRows={page.rows[1],page.rows[2],page.rows[3]}
    calls={}
    built:showBrowser()
    assert(built.mode=='browser' and table.concat(calls,',')=='browser',table.concat(calls,','))
    assert(reports[1] and reports[1]:find('PAGE_LINK_FAILED return to Main.inner',1,true),tostring(reports[1]))
    calls={}
    built:showBrowser()
    assert(table.concat(calls,',')=='browser','the trail is dropped after a failed return')
end

print('PASS page links open targets through the browser and refuse dirty pages')
