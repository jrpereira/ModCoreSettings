package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Menu=require('menu_contributions')
local Pages=require('menu_pages')
local Groups=require('browser_groups')

local function ids(providers)
    local out={}
    for n,provider in ipairs(providers) do out[n]=provider.id end
    return table.concat(out,',')
end
local function expect(providers,wanted,message)
    assert(ids(providers)==wanted,(message or 'order')..': '..ids(providers)..' ~= '..wanted)
end
local function parse(content)
    if content:find('broken') then error('bad manifest') end
    local out={}
    for id in content:gmatch('%[Setting%.([^%]]+)%]') do out[#out+1]={id=id,kind='picker'} end
    return out
end
local function mod(id,name) return {id=id,name=name or id,testOnly=false} end
local function placeholder(folder)
    return {id='detected:ue4ss:'..folder:lower(),name=folder,testOnly=false,noSettings=true,detectedKind='ue4ss'}
end
local manifest='[Setting.A]\nId=A\n'
local logs={}
local function report(event,detail) logs[#logs+1]=event..' '..detail end

-- Placement: heading attached to its own placeholder, children under it in publish order,
-- module pages replace placeholders or follow real mods, and unanchored pages sort by name.
local function base()
    return {placeholder('3_ModCore_Templates'),mod('Alpha'),placeholder('Beta'),mod('Gamma'),mod('Zeta')}
end
local mct={id='MCT',pages={
    {id='MCT',name='ModCore Templates',attach='3_ModCore_Templates'},
    {id='MCT.z',name='Zebra category',under='MCT',manifest=manifest,configDirectory='/mct/cache'},
    {id='MCT.a',name='Apple category',under='MCT',manifest=manifest,configDirectory='/mct/cache'},
    {id='MCT.a.sub',name='Sub',under='MCT.a',manifest=manifest,configDirectory='/mct/cache'},
    {id='MCT.module.Beta',name='Beta',attach='Beta',manifest=manifest,configDirectory='/mods/beta'},
    {id='MCT.module.Gamma',name='Gamma extras',attach='gamma',manifest=manifest,configDirectory='/mods/gamma'},
    {id='MCT.module.Grouped',name='Grouped',attach='Alpha',group='module',manifest=manifest,configDirectory='/g'},
    {id='MCT.module.Lost',name='Lost',attach='Missing',manifest=manifest,configDirectory='/lost'},
    {id='MCT.hidden',name='Hidden',visible=false},
    {id='MCT.hidden.child',name='Hidden child',under='MCT.hidden'},
}}
local providers,state=base(),{}
Pages.apply(providers,{mct},parse,state,report)
expect(providers,'Alpha,MCT.module.Beta,Gamma,MCT.module.Gamma,MCT.module.Grouped,MCT.module.Lost,'
    ..'MCT,MCT.z,MCT.a,MCT.a.sub,Zeta')
local byId={}
for _,provider in ipairs(providers) do byId[provider.id]=provider end
assert(byId['MCT'].noSettings and byId['MCT'].mcBrowserHeading and byId['MCT'].mcBrowserLevel==nil)
assert(byId['MCT.z'].mcBrowserIndent==20 and byId['MCT.a.sub'].mcBrowserIndent==20)
assert(byId['MCT.module.Gamma'].mcBrowserIndent==20 and byId['MCT.module.Beta'].mcBrowserIndent==nil)
assert(byId['MCT.module.Grouped'].mcBrowserGroup=='module')
assert(byId['MCT.z'].path=='/mct/cache/mod_settings.ini' and byId['MCT.z'].settingsCount==1
    and byId['MCT.z'].choicesLoaded and not byId['MCT.z'].deferred and not byId['MCT.z'].noSettings)
assert(byId['MCT.z'].author=='MCT' and byId['MCT.z'].version=='')
assert(byId['MCT.z'].mcManifest==manifest and byId['MCT'].mcManifest==nil,'pages carry their manifest in memory')
assert(#logs==0,logs[1])
-- A page replacing a placeholder becomes that mod's entry; one following a mod does not.
assert(byId['MCT.module.Beta'].mcModuleEntry and not byId['MCT.module.Gamma'].mcModuleEntry
    and byId['MCT'].mcModuleEntry,'pages standing in for a mod are marked')
-- Menu data pages are compiled by ModCoreSettings; without a compiler the contributor is skipped.
local compiled={}
local function compile(menu,page) compiled[#compiled+1]=page.id;return '[Setting.'..menu.fields[1].id..']\n' end
local menuProviders={mod('Alpha')}
Pages.apply(menuProviders,{{id='MD',pages={{id='MD',name='Menu data',attach='Alpha',
    menu={fields={{id='Size'}}},configDirectory='/md'}}}},parse,{},report,nil,nil,compile)
assert(compiled[1]=='MD' and menuProviders[2].id=='MD' and menuProviders[2].settingsCount==1
    and menuProviders[2].mcManifest=='[Setting.Size]\n','menu data compiles into the page manifest')
Pages.apply({mod('Alpha')},{{id='MD',pages={{id='MD',name='Menu data',menu={fields={}},configDirectory='/md'}}}},
    parse,{},report)
assert(logs[#logs]:find('menu data unavailable',1,true),logs[#logs])
logs={}
-- A tool page never follows the mod it attaches to; ModCore grouping places it.
local toolProviders={mod('Alpha'),mod('Zeta')}
Pages.apply(toolProviders,{{id='MCD',pages={{id='MCD.sounds',name='Sounds Explorer',attach='Alpha',group='tool',
    manifest=manifest,configDirectory='/d'}}}},parse,{},report)
expect(toolProviders,'Alpha,MCD.sounds,Zeta','tool pages are sorted by name')
assert(toolProviders[2].mcBrowserGroup=='tool' and toolProviders[2].mcBrowserIndent==nil)

-- Rebuilds are idempotent; withdrawn contributions restore the placeholders they replaced.
Pages.apply(providers,{mct},parse,state,report)
expect(providers,'Alpha,MCT.module.Beta,Gamma,MCT.module.Gamma,MCT.module.Grouped,MCT.module.Lost,'
    ..'MCT,MCT.z,MCT.a,MCT.a.sub,Zeta','rebuild')
Pages.apply(providers,{},parse,state,report)
expect(providers,ids(base()),'withdrawn')

-- A hidden page attached to a detected placeholder keeps that placeholder hidden.
providers=base()
Pages.apply(providers,{{id='MCT',pages={{id='MCT',name='ModCore Templates',attach='3_ModCore_Templates',visible=false},
    {id='MCT.real',name='Real',attach='Alpha',visible=false}}}},parse,state,report)
expect(providers,'Alpha,detected:ue4ss:beta,Gamma,Zeta','hidden page claims placeholder only')
Pages.apply(providers,{},parse,state,report)
expect(providers,ids(base()),'hidden claim released')

-- A failing contributor is skipped as a whole, other contributors still appear.
local broken={id='Bad',pages={{id='Bad',name='Bad',attach='Beta'},
    {id='Bad.page',name='Bad page',manifest='broken',configDirectory='/bad'}}}
local ambiguous={id='Amb',pages={{id='Amb',name='Amb',attach='alpha'}}}
local clash={id='Gamma',pages={{id='Gamma',name='Clash'}}}
providers=base()
table.insert(providers,mod('Other','alpha'))
Pages.apply(providers,{broken,ambiguous,clash,{id='Ok',pages={{id='Ok',name='Ok'}}}},parse,{},report)
assert(not ids(providers):find('Bad') and not ids(providers):find('Amb') and ids(providers):find('Ok'))
assert(ids(providers):find('detected:ue4ss:beta',1,true),'failed contributor must not hide placeholders')
assert(#logs==3 and logs[1]:find('Bad: ',1,true) and logs[2]:find('more than one mod')
    and logs[3]:find('already in the menu'))

-- Reader: index enumeration, generation cache, withdraw, failures logged once per generation.
local values,disk={}, {}
local host={GetSharedVariable=function(_,key) return values[key] end,
    SetSharedVariable=function(_,key,value) values[key]=value end}
local reads=0
local function read(path) reads=reads+1;return assert(disk[path],'missing '..path) end
local publisher=Menu.publisher(host,{id='MCT',directory='/c',write=function(path,content) disk[path]=content end,
    remove=function(path) local had=disk[path];disk[path]=nil;return had~=nil end})
logs={}
local readerFn=Pages.reader(Menu,host,read,report)
assert(#readerFn()==0)
publisher:publish({pages={{id='MCT',name='Templates'},{id='MCT.a',name='A',under='MCT',manifest=manifest,configDirectory='/c'}}})
local got=readerFn()
assert(#got==1 and got[1].id=='MCT' and got[1].pages[2].manifest==manifest)
local count=reads
assert(readerFn()[1]==got[1] and reads==count,'unchanged generations are cached')
publisher:withdraw()
assert(#readerFn()==0)
publisher:publish({pages={{id='MCT',name='Again'}}})
assert(readerFn()[1].pages[1].name=='Again')
local key=Menu.prefix..Menu.hex('MCT')
values[key]='99\n/c/missing.ini'
assert(#readerFn()==0 and #readerFn()==0 and #logs==1 and logs[1]:find('generation 99'))
values[key]='100\n/c/mcs_menu.7.ini'
disk['/c/mcs_menu.7.ini']=disk['/c/mcs_menu.'..(Menu.slot(values[key]) and 7)..'.ini'] or
    Menu.encode('MCT',7,{pages={{id='MCT',name='x'}}})
assert(#readerFn()==0 and logs[#logs]:find('does not match'))

-- A publish racing the read is not cached; the next build reads the new generation.
publisher:publish({pages={{id='MCT',name='Before'}}})
local racing=Pages.reader(Menu,host,function(path)
    local content=read(path)
    if not values.raced then values.raced=true;publisher:publish({pages={{id='MCT',name='After'}}}) end
    return content
end,report)
assert(#racing()==0)
assert(racing()[1].pages[1].name=='After')

-- Installed with browser groups: contributions run first, ModCore grouping after.
local api={build=function(_,items) return items end}
Groups.install(api)
local current={}
assert(Pages.install(api,parse,function() return current end,report))
assert(not Pages.install(api,parse,function() return current end,report))
current={{id='MCT',pages={{id='MCT.module.Visual',name='Visual Example',attach='Visual',group='module',
    manifest=manifest,configDirectory='/v'}}}}
local menu={mod('ModCoreControls','Controls'),mod('ModCoreSettings','Visuals'),placeholder('Visual'),mod('Zeta')}
local built=api.build({},menu,nil,{})
-- Without a shared group or author every page, ModCore's included, lists under Various Authors,
-- in load order: pages without a folder first, then mod folders by name.
expect(built,'ModCore.browser.group.various,ModCoreControls,ModCoreSettings,Zeta,MCT.module.Visual','grouped')
assert(built[5].mcBrowserIndent==20 and built[5].mcBrowserLine=='cell' and built[5].mcFolder=='Visual')
local failing={build=function(_,items) return items end}
logs={}
Pages.install(failing,parse,function() error('index unreadable') end,report)
assert(#failing.build({},{mod('A')},nil,{})==1 and logs[1]:find('index unreadable'))
failing.build({},{mod('A')},nil,{})
assert(#logs==1,'failures are logged once')

-- Slot rows: collected per target and slot from successful contributors, sourced from the
-- contributor's page even when it is hidden; the build splices them on page load.
local slotted={id='MCT',pages={{id='MCT',name='Templates',manifest=manifest,configDirectory='/c'},
    {id='MCT.hidden',name='Hidden',visible=false,manifest=manifest,configDirectory='/h'}},
    rows={{page='MCT',slot='Host:Visuals',settings={'A'}},
        {page='MCT.hidden',slot='Host:Visuals',settings={'B'}}}}
state={}
providers={mod('Host')}
Pages.apply(providers,{slotted,{id='Bad',pages={{id='Bad',name='x',manifest='broken',configDirectory='/b'}},
    rows={{page='Bad',slot='Host:Visuals',settings={'C'}}}}},parse,state,report,
    {address=Menu.address,provider=Menu.provider,declares=function() return true end})
local visuals=state.inserts.Host.Visuals
assert(#visuals==2 and visuals[1].contributor=='MCT' and visuals[1].settings[1]=='A')
local hostPage
for _,provider in ipairs(providers) do if provider.id=='MCT' then hostPage=provider end end
assert(visuals[1].source==hostPage,'visible source reuses the built page')
assert(visuals[2].source.id=='MCT.hidden' and visuals[2].source.mcManifest==manifest,'hidden source still has a provider')
local slotApi={build=function(_,items,_,api) return api end}
local loads={}
local controller={address=Menu.address,provider=Menu.provider,declares=function() return true end,outermost=function() end,load=function(self,provider,readPath) loads[#loads+1]={self=self,id=provider.id,read=readPath} end}
local dmmLoads={}
local reader=function() end
Pages.install(slotApi,parse,function() return {slotted} end,report,controller,reader)
local applied=function() end
local passed=slotApi.build({},{mod('Host')},nil,{applied=applied,loadProvider=function(p) dmmLoads[#dmmLoads+1]=p.id end})
assert(controller.inserts.Host.Visuals[1].settings[1]=='A' and controller.applied==applied)
local versionApi={build=function(_,_,_,api) return api end}
Pages.install(versionApi,parse,function() return {{id='MCT',pages={{id='MCT',name='T',version='1.0.2',visible=false},
    {id='MCT.module.X',name='X',version='0.3.1'},{id='MCT.module.Y',name='Y'}}}} end,report)
local versions=versionApi.build({},{},nil,{}).mcPageVersions
assert(versions.MCT=='1.0.2' and versions['MCT.module.X']=='0.3.1' and versions['MCT.module.Y']==nil,
    'every contributed page version reaches the inner build, hidden pages included')
passed.loadProvider({id='Host'})
assert(dmmLoads[1]=='Host' and loads[1].id=='Host' and loads[1].self==controller and loads[1].read==reader,
    'DMM loads the page first, then slots splice it')
controller.load=function() error('splice exploded') end
logs={}
passed.loadProvider({id='Host'})
assert(logs[1]:find('splice exploded',1,true),'a splice failure never escapes page load')

-- Link pages show while their host declares the slot and the slot has rows; otherwise
-- they are hidden like visible=false pages.
do
    local declared={visuals=true}
    local slots={address=Menu.address,provider=Menu.provider,
        declares=function(_,provider,name) return provider.id=='ModCoreControls' and declared[name] end}
    local link={id='MCT',pages={{id='MCT',name='Templates',manifest=manifest,configDirectory='/c'},
        {id='MCT.module.Fangdango',name='Fangdango',attach='Fangdango',group='module',link='controls:visuals'}},
        rows={{page='MCT',slot='controls:visuals',settings={'A'}}}}
    local function build(contributions,menu)
        local list=menu or {mod('ModCoreControls','Controls'),placeholder('Fangdango'),mod('Zeta')}
        Pages.apply(list,contributions,parse,{},report,slots)
        return list
    end
    local list=build({link})
    expect(list,'ModCoreControls,MCT.module.Fangdango,MCT,Zeta','link replaces its placeholder')
    local entry=list[2]
    assert(entry.mcLinkSlot.host=='ModCoreControls' and entry.mcLinkSlot.slot=='visuals')
    assert(not entry.noSettings and entry.settingsCount==0 and #entry.choices==0,'selectable without settings')
    local unfilled={id='MCT',pages=link.pages}
    expect(build({unfilled}),'ModCoreControls,MCT,Zeta','an empty slot hides the link and its placeholder')
    expect(build({link},{placeholder('Fangdango'),mod('Zeta')}),'MCT,Zeta','no host, no link')
    declared.visuals=nil
    expect(build({link}),'ModCoreControls,MCT,Zeta','undeclared slot hides the link')
    declared.visuals=true
    local list2={mod('ModCoreControls','Controls'),placeholder('Fangdango')}
    Pages.apply(list2,{link},parse,{},report)
    expect(list2,'ModCoreControls,MCT','without slot support links are hidden')
end

-- A hidden row-source page stays hidden while any of its rows has a slot; otherwise it
-- shows as an ordinary page in its declared place.
do
    local declared=true
    local slots={address=Menu.address,provider=Menu.provider,
        declares=function(_,provider,name) return declared and provider.id=='ModCoreControls' and name=='visuals' end}
    local function contribution()
        return {id='ModCoreTemplates',pages={{id='ModCoreTemplates',name='ModCore Templates'},
            {id='ModCoreTemplates.quickslots',name='Quickslots',under='ModCoreTemplates',visible=false,
                manifest=manifest,configDirectory='/c'},
            {id='ModCoreTemplates.secret',name='Secret',visible=false}},
            rows={{page='ModCoreTemplates.quickslots',slot='controls:visuals',settings={'A'}}}}
    end
    local function build(menu,withSlots)
        local list,state=menu,{}
        Pages.apply(list,{contribution()},parse,state,report,withSlots~=false and slots or nil)
        return list,state
    end
    local list,state=build({mod('ModCoreControls','Controls')})
    expect(list,'ModCoreControls,ModCoreTemplates','slot available: source stays hidden')
    assert(state.inserts.controls.visuals[1].source.id=='ModCoreTemplates.quickslots')
    list,state=build({mod('Zeta')})
    expect(list,'ModCoreTemplates,ModCoreTemplates.quickslots,Zeta','no host: fallback page under its parent')
    assert(list[2].mcBrowserIndent==20 and list[2].mcManifest==manifest)
    assert(state.inserts.controls.visuals[1].source==list[2],'rows and fallback share one provider')
    declared=false
    expect(build({mod('ModCoreControls','Controls')}),'ModCoreControls,ModCoreTemplates,ModCoreTemplates.quickslots',
        'undeclared slot: fallback')
    declared=true
    expect(build({mod('ModCoreControls','Controls')},false),'ModCoreControls,ModCoreTemplates,ModCoreTemplates.quickslots',
        'no slot support: fallback')
end

-- The real DMM parser accepts generated manifests through the installed choices chain.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if choicesPath then
    local Choices=dofile(choicesPath)
    require('navigation').install(Choices)
    local items=Choices.parse('[Setting.Link]\nId=Link\nLabel=Controls\nType=picker\nPresetValues=0|1\n'
        ..'PresetLabels=Open|Open\nDefault=0\nmcNavigation=1\nmcLinkPage=ModCoreControls\n')
    assert(items[1].mcLinkPage=='ModCoreControls' and items[1].mcNavigation)
    assert(not pcall(Choices.parse,'[Setting.Link]\nId=Link\nLabel=x\nType=picker\nPresetValues=0|1\n'
        ..'PresetLabels=Open|Open\nDefault=0\nConfigFile=c.ini\nmcLinkPage=ModCoreControls\n'),
        'mcLinkPage requires a navigation picker')
end
print('PASS menu pages read contributions, place them, and survive rebuilds and failures')
