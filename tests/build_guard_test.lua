-- An error raised by a ModCoreSettings wrapper while DMM builds or uses its page falls back to
-- DMM's own page from DMM's own list, reported once, for the rest of the session. The real
-- presentation, browser groups and menu pages wrappers run over a stand-in DMM.
package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Guard=require('build_guard')
local Presentation=require('presentation')
local Groups=require('browser_groups')
local Pages=require('menu_pages')

local reports={}
local function report(event,detail) reports[#reports+1]={event=event,detail=tostring(detail)} end
local function count(event)
    local n=0
    for _,entry in ipairs(reports) do if entry.event==event then n=n+1 end end
    return n
end

-- DMM's modules. Its page carries a settings panel from controls.build, read at call time
-- as DMM's pages.lua does; the page has none of the widgets the presentation expects.
local dmmBuilds,dmmTicks=0,0
local choices={parse=function() return {} end}
local controls={}
controls.build=function()
    local ui={panels={}}
    function ui:tick() dmmTicks=dmmTicks+1;return false end
    function ui:clearPresses() end
    function ui:isPressed() return false end
    function ui:prepare() end
    function ui:show(index) self.active=index end
    function ui:hide() self.active=nil end
    function ui:refresh() end
    function ui:select(index) self.current=index end
    return ui
end
local pages={}
pages.build=function(tree,providers,_,api)
    dmmBuilds=dmmBuilds+1
    local ids={}
    for index,provider in ipairs(providers) do ids[index]=provider.id end
    return {dmm=true,ids=table.concat(ids,','),controls=controls.build(tree,providers,api)}
end
local dmmPagesBuild=pages.build

local function mod(id,name) return {id=id,name=name or id,choices={{id='x'}},settingsCount=1,testOnly=false} end
local function placeholder(folder)
    return {id='detected:ue4ss:'..folder,name=folder,choices={},settingsCount=0,testOnly=false,
        noSettings=true,detectedKind='ue4ss'}
end
-- One contributor: a page of its own, and a hidden page that claims the Visual placeholder.
local contributions={{id='MCT',pages={{id='MCT.page',name='Templates'},
    {id='MCT.hidden',name='Hidden',visible=false,attach='Visual'}}}}

-- Installed as the extension does: the guard first, the page wrappers, then the guard around them.
local guard=Guard.new(pages,controls,report)
assert(pages.build==dmmPagesBuild,'new() keeps the page build as DMM\'s')
assert(Presentation.install(choices,controls,pages,{}))
assert(Groups.install(pages,report))
assert(Pages.install(pages,function() return {} end,function() return contributions end,report))
assert(guard:install())

local menu={mod('Zeta'),placeholder('Visual'),mod('Alpha')}
local dmmList='Alpha,detected:ue4ss:Visual,Zeta'
-- The presentation asserts on DMM's widget layout after the wrappers below it changed the list.
local page=pages.build({},menu,nil,{})
assert(page.dmm and page.ids==dmmList,'a failed build returns DMM\'s page from DMM\'s own build: '..tostring(page.ids))
assert(dmmBuilds==2,'the wrapped chain ran DMM\'s build once, the fallback once more')
-- DMM's list: no contributed pages, no group headings, the hidden placeholder back, DMM's order.
local ids={}
for index,provider in ipairs(menu) do
    ids[index]=provider.id
    assert(not provider.mcContribution and not provider.mcBrowserHeading and not provider.mcBrowserMore,
        'nothing ModCoreSettings added stays in the list')
end
assert(table.concat(ids,',')==dmmList,'the list is DMM\'s again: '..table.concat(ids,','))
assert(menu.mcFolded==nil and menu.mcFoldedAt==nil and menu.mcModuleCount==nil)
assert(count('MCS_BUILD_FAILED')==1,'the failure is reported once')
assert(reports[#reports].detail:find('MCS page title',1,true) and reports[#reports].detail:find('page build',1,true),
    'the report names where and why: '..reports[#reports].detail)
local Events=require('log_events')
assert(Events.level('MCS_BUILD_FAILED')=='error','reported at ERROR')

-- Every later build goes straight to DMM's: the wrappers no longer run, the list stays DMM's.
local before=#reports
page=pages.build({},menu,nil,{})
assert(page.dmm and page.ids==dmmList and dmmBuilds==3,'the next build is DMM\'s alone')
assert(#reports==before,'nothing more is reported')

-- A settings panel method that fails falls back the same way: DMM's own method this time,
-- DMM's own page from the next build. A layout that passes the presentation's checks is not
-- needed: the wrapped chain only has to produce a panel.
local function session()
    local fresh={}
    fresh.reports={}
    local freshControls={build=controls.build}
    local freshPages={build=function(tree,providers,_,api)
        local ids={}
        for index,provider in ipairs(providers) do ids[index]=provider.id end
        return {dmm=true,ids=table.concat(ids,','),controls=freshControls.build(tree,providers,api)}
    end}
    local freshGuard=Guard.new(freshPages,freshControls,function(event,detail)
        fresh.reports[#fresh.reports+1]={event=event,detail=tostring(detail)}
    end)
    assert(Presentation.install({parse=function() return {} end},freshControls,nil,{}))
    -- A stand-in for the page wrappers: MCS's page is its own table.
    local dmmBuild=freshPages.build
    freshPages.build=function(tree,providers,status,api)
        local built=dmmBuild(tree,providers,status,api)
        built.dmm=nil
        return built
    end
    freshGuard:install()
    fresh.pages,fresh.controls=freshPages,freshControls
    return fresh
end
local s=session()
local mcsPage=s.pages.build({},{mod('A')},nil,{})
assert(not mcsPage.dmm,'without a failure the page is ModCoreSettings\'')
local panel=mcsPage.controls
dmmTicks=0
assert(panel:tick(nil,nil,false)==false and dmmTicks==1,'the wrapped tick runs DMM\'s once')
-- The presentation's tick reads the active panel's rows: a panel it cannot read raises.
panel.active,panel.model=1,{}
panel:tick(nil,nil,false)
assert(dmmTicks==2,'a failed tick runs DMM\'s own tick instead')
assert(#s.reports==1 and s.reports[1].event=='MCS_BUILD_FAILED' and s.reports[1].detail:find('settings panel tick',1,true)
    and s.reports[1].detail:find('presentation.lua',1,true),
    'the failed tick is reported once: '..tostring(s.reports[1] and s.reports[1].detail))
panel:tick(nil,nil,false)
assert(dmmTicks==3 and #s.reports==1,'later ticks go straight to DMM\'s')
local later=s.pages.build({},{mod('A')},nil,{})
assert(later.dmm,'the next build after a failed tick is DMM\'s own page')
-- A method that fails after DMM's own already ran does not run DMM's twice.
do
    local afterControls={build=controls.build}
    local afterReports=0
    local afterGuard=Guard.new({build=function() end},afterControls,function() afterReports=afterReports+1 end)
    local build=afterControls.build
    afterControls.build=function(...)
        local ui=build(...)
        local tick=ui.tick
        function ui:tick(...) tick(self,...);error('after DMM\'s tick') end
        return ui
    end
    afterGuard:install()
    local ui=afterControls.build({},{},{})
    dmmTicks=0
    ui:tick()
    assert(dmmTicks==1 and afterReports==1,'DMM\'s tick ran once')
    ui:tick()
    assert(dmmTicks==2 and afterReports==1,'then DMM\'s tick alone')
    -- A panel build that fails gives DMM's own panel.
    local failing={build=controls.build}
    local failingGuard=Guard.new({build=function() end},failing,function() afterReports=afterReports+1 end)
    failing.build=function() error('panel layout') end
    failingGuard:install()
    local own=failing.build({},{},{})
    assert(type(own)=='table' and own.tick and afterReports==2,'a failed panel build returns DMM\'s panel')
end

-- Browser groups: an arrangement that raises leaves the list as it was and is reported.
local base={build=function(_,providers) return providers end}
local groupReports={}
Groups.install(base,function(event,detail) groupReports[#groupReports+1]=event..': '..tostring(detail) end)
local list={mod('B'),mod('A'),mod('B')}
local first,second,third=list[1],list[2],list[3]
local result=base.build({},list,nil,{})
assert(result==list and #list==3 and list[1]==first and list[2]==second and list[3]==third,
    'a failed arrangement leaves the list unchanged')
assert(#groupReports==1 and groupReports[1]:find('BROWSER_GROUPS_FAILED',1,true)
    and groupReports[1]:find('duplicate browser provider',1,true),tostring(groupReports[1]))
print('PASS a failed build or panel method falls back to DMM\'s own page and list, reported once')
