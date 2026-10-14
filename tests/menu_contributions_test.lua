package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Menu=require('menu_contributions')

local function shared()
    local values={}
    return {values=values,
        GetSharedVariable=function(_,key) return values[key] end,
        SetSharedVariable=function(_,key,value) values[key]=value end}
end
local function files()
    local store={}
    return store,function(path,content) store[path]=content end,
        function(path) local had=store[path]~=nil;store[path]=nil;return had end
end
local function fails(pattern,contributor,contribution)
    local ok,err=Menu.validate(contributor,contribution)
    assert(not ok and err:find(pattern,1,true),'expected '..pattern..', got '..tostring(err))
end

local manifest='[Setting.Speed]\nId=Speed\nType=picker\nConfigFile=config.ini\n'
local pages={
    {id='MCT',name='ModCore Templates',attach='3_ModCore_Templates',description='Line one\nLine \\two'},
    {id='MCT.vehicles',name='Vehicles',under='MCT',manifest=manifest,configDirectory='C:/Mods/MCT/Scripts/cache'},
    {id='MCT.module.Visual',name='Visual',attach='Visual',group='module',author='A',version='1.2',
        manifest=manifest,configDirectory='/mods/visual',visible=false},
}
assert(Menu.validate('MCT',{pages=pages}))
fails('not owned','MCT',{pages={{id='Other',name='x'}}})
fails('not owned','MCT',{pages={{id='MCTX',name='x'}}})
fails('duplicate page id','MCT',{pages={{id='MCT',name='a'},{id='MCT',name='b'}}})
fails('unknown field mcLinkProvider','MCT',{pages={{id='MCT',name='a',mcLinkProvider='x'}}})
fails('under must name an earlier page','MCT',{pages={{id='MCT.a',name='a',under='MCT'},{id='MCT',name='b'}}})
fails('exclusive','MCT',{pages={{id='MCT',name='a'},{id='MCT.b',name='b',under='MCT',attach='x'}}})
fails('configDirectory','MCT',{pages={{id='MCT',name='a',manifest=manifest}}})
fails('must be absolute','MCT',{pages={{id='MCT',name='a',manifest=manifest,configDirectory='cache'}}})
fails('configDirectory needs a manifest','MCT',{pages={{id='MCT',name='a',configDirectory='/x'}}})
fails('folder name','MCT',{pages={{id='MCT',name='a',attach='Mods/x'}}})
fails('invalid page 1 group','MCT',{pages={{id='MCT',name='a',group='core'}}})
assert(Menu.validate('MCD',{pages={{id='MCD.sounds',name='Sounds Explorer',group='tool'}}}),'tool pages are valid')
fails('invalid page 1 name','MCT',{pages={{id='MCT',name='a\nb'}}})
fails('unknown contribution field','MCT',{pages={},aggregate={}})

-- Round trip through descriptor and manifest files.
local descriptor,written=Menu.encode('MCT',4,{pages=pages})
assert(#written==2 and written[1].name=='mcs_menu.4.1.ini' and written[2].name=='mcs_menu.4.2.ini')
local byName={}
for _,file in ipairs(written) do byName[file.name]=file.content end
local decoded=Menu.decode(descriptor,function(name) return assert(byName[name]) end)
assert(decoded.id=='MCT' and decoded.generation==4 and #decoded.pages==3)
for n,page in ipairs(pages) do
    for key,value in pairs(page) do
        assert(decoded.pages[n][key]==value,'round trip '..n..'.'..key)
    end
end
assert(not pcall(Menu.decode,descriptor:gsub('contract=1','contract=2'),function() end))
assert(not pcall(Menu.decode,descriptor:gsub('%[Page%.2%]','[Page.3]'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor:gsub('mcs_menu%.4%.1','../x'),function(name) return byName[name] end))

-- Rows target another provider's slot from one of the contributor's own manifest pages.
local rows={{page='MCT.vehicles',slot='controls:visuals',settings={'MCT_Template','Other one'}}}
assert(Menu.validate('MCT',{pages=pages,rows=rows}))
local function row(fields)
    local out={page='MCT.vehicles',slot='ModCoreControls:visuals',settings={'A'}}
    for key,value in pairs(fields) do out[key]=value end
    return {pages=pages,rows={out}}
end
fails('page must name a page with settings','MCT',row({page='MCT'}))
fails('page must name a page with settings','MCT',row({page='Other'}))
fails('slot must belong to another provider','MCT',row({slot='MCT.vehicles:x'}))
fails('invalid row 1 slot address','MCT',row({slot='controls:a-b'}))
fails('invalid row 1 slot address','MCT',row({slot='visuals'}))
fails('invalid row 1 slot address','MCT',row({slot='a:b:c'}))
assert(Menu.address('controls:visuals')=='controls' and select(2,Menu.address('ModCoreControls:visuals'))=='visuals')
assert(Menu.address('ModCoreControls:visuals')=='controls' and Menu.address('Fangdango:x')=='Fangdango')
assert(Menu.provider('ModCoreTemplates.player')=='ModCoreTemplates.player','only whole ModCore<Name> ids shorten')
fails('slot must belong to another provider','ModCoreControls',
    {pages={{id='ModCoreControls',name='C',manifest=manifest,configDirectory='/c'}},
     rows={{page='ModCoreControls',slot='controls:visuals',settings={'A'}}}})
fails('settings must list','MCT',row({settings={}}))
fails('duplicate setting A','MCT',row({settings={'A','A'}}))
fails('cannot contain |','MCT',row({settings={'A|B'}}))
fails('unknown field label','MCT',row({label='x'}))
fails('rows must be a list','MCT',{pages=pages,rows={x={}}})
descriptor,written=Menu.encode('MCT',5,{pages=pages,rows=rows})
assert(descriptor:find('contract=2',1,true),'rows need contract 2')
byName={}
for _,file in ipairs(written) do byName[file.name]=file.content end
decoded=Menu.decode(descriptor,function(name) return assert(byName[name]) end)
assert(#decoded.rows==1 and decoded.rows[1].slot=='controls:visuals'
    and table.concat(decoded.rows[1].settings,',')=='MCT_Template,Other one' and decoded.rows[1].page=='MCT.vehicles')
assert(not pcall(Menu.decode,descriptor:gsub('contract=2','contract=1'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor:gsub('%[Row%.1%]','[Row.2]'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor..'[Page.4]\nid=MCT.late\nname=Late\n',function(name) return byName[name] end),
    'pages come before rows')
assert(Menu.decode(Menu.encode('MCT',6,{pages={pages[1]}}),function() end).rows==nil)

-- Link pages open another provider's slot; they carry no manifest or children.
local linked={pages={{id='MCT',name='Templates'},
    {id='MCT.module.Fangdango',name='Fangdango',attach='Fangdango',group='module',link='controls:visuals'}}}
assert(Menu.validate('MCT',linked))
fails('invalid page 1 link address','MCT',{pages={{id='MCT',name='a',link='visuals'}}})
fails('cannot have a manifest','MCT',{pages={{id='MCT',name='a',link='controls:visuals',
    manifest=manifest,configDirectory='/c'}}})
fails('link must open another provider','ModCoreControls',{pages={{id='ModCoreControls',name='a',link='controls:x'}}})
fails('a link page cannot have children','MCT',{pages={{id='MCT',name='a',link='controls:visuals'},
    {id='MCT.b',name='b',under='MCT'}}})
descriptor=Menu.encode('MCT',7,linked)
assert(descriptor:find('contract=2',1,true) and descriptor:find('link=controls:visuals',1,true))
decoded=Menu.decode(descriptor,function() end)
assert(decoded.pages[2].link=='controls:visuals' and decoded.rows==nil)
assert(not pcall(Menu.decode,descriptor:gsub('contract=2','contract=1'),function() end))

-- Publishing flips the channel only after files are written and keeps one older generation.
local host=shared()
local store,write,remove=files()
local writes={}
local publisher=Menu.publisher(host,{id='MCT',directory='/mods/MCT/cache/',write=function(path,content)
    writes[#writes+1]=path
    local generation=path:match('mcs_menu%.(%d+)%.')
    assert(Menu.slot(host.values[Menu.prefix..Menu.hex('MCT')])~=tonumber(generation),'channel moved early')
    write(path,content)
end,remove=remove})
assert(publisher:publish({pages=pages})==1)
local key=Menu.prefix..Menu.hex('MCT')
assert(host.values[key]=='1\n/mods/MCT/cache/mcs_menu.1.ini')
assert(host.values[Menu.index]==Menu.hex('MCT'))
assert(writes[#writes-1]=='/mods/MCT/cache/mcs_menu.1.ini' and writes[#writes]=='/mods/MCT/cache/mcs_menu.generation',
    'descriptor is written after manifests, the counter after the channel moves')
assert(publisher:publish({pages=pages})==2 and publisher:publish({pages={pages[1]}})==3)
assert(store['/mods/MCT/cache/mcs_menu.1.ini']==nil and store['/mods/MCT/cache/mcs_menu.1.1.ini']==nil)
assert(store['/mods/MCT/cache/mcs_menu.2.ini'] and store['/mods/MCT/cache/mcs_menu.3.ini'])
assert(host.values[Menu.index]==Menu.hex('MCT'),'index registers each contributor once')
local before=host.values[key]
assert(not pcall(publisher.publish,publisher,{pages={{id='Other',name='x'}}}))
assert(host.values[key]==before,'a failed publish leaves the previous generation')

-- A restarted publisher continues the generation sequence; withdraw keeps it monotonic.
local again=Menu.publisher(host,{id='MCT',directory='/mods/MCT/cache',write=write,remove=remove})
assert(again:publish({pages={pages[1]}})==4)
again:withdraw()
assert(host.values[key]=='4\n' and store['/mods/MCT/cache/mcs_menu.4.ini']==nil)
assert(again:publish({pages={pages[1]}})==5)
assert(Menu.slot('5\n/x')==5 and select(2,Menu.slot('4\n'))=='' and Menu.slot('junk')==nil)

-- A new launch resets shared variables; the counter file continues generations and cleanup.
local fresh=shared()
local relaunch=Menu.publisher(fresh,{id='MCT',directory='/mods/MCT/cache',write=write,remove=remove,
    read=function(path) return store[path] end})
assert(store['/mods/MCT/cache/mcs_menu.generation']=='5')
assert(relaunch:publish({pages={pages[1]}})==6 and relaunch:publish({pages={pages[1]}})==7)
assert(store['/mods/MCT/cache/mcs_menu.5.ini']==nil,'earlier launch files are cleaned up')
local blank=Menu.publisher(shared(),{id='MCT',directory='/nowhere',write=function() end,remove=remove,
    read=function() return 'garbage' end})
assert(blank:publish({pages={pages[1]}})==1,'an unreadable counter starts from scratch')

local other=Menu.publisher(host,{id='MCC',directory='C:\\Mods\\MCC',write=write,remove=remove})
other:publish({pages={{id='MCC',name='Controls'}}})
assert(host.values[Menu.index]==Menu.hex('MCT')..' '..Menu.hex('MCC'))
assert(not pcall(Menu.publisher,host,{id='MCT',directory='relative'}))
print('PASS menu contribution client validates, round-trips and publishes generations')

-- Menu data travels in its own file, read back without globals, under contract 4.
local menu={storage={file='config.ini',section='S'},groups={{id='G',label='A "quoted"\\label'}},
    fields={{id='F',group='G',label='F',default=0.5,range={min=0,max=1}},
        {id='T',group='G',label='T',default=0,choices={{value=0,label='No'},{value=1,label='Yes'}},tabs=true}},
    [7]='sparse',[-1]=false}
local menuPages={{id='MCT',name='Templates',attach='3_ModCore_Templates',menu=menu,configDirectory='/mods/MCT'},
    {id='MCT.raw',name='Raw',under='MCT',manifest=manifest,configDirectory='/mods/MCT'}}
assert(Menu.validate('MCT',{pages=menuPages}))
assert(Menu.contractFor({pages=menuPages})==Menu.menuContract)
descriptor,written=Menu.encode('MCT',9,{pages=menuPages})
assert(descriptor:find('contract=4',1,true) and descriptor:find('menuFile=mcs_menu.9.1.lua',1,true))
assert(written[1].name=='mcs_menu.9.1.lua' and written[2].name=='mcs_menu.9.2.ini')
byName={}
for _,file in ipairs(written) do byName[file.name]=file.content end
decoded=Menu.decode(descriptor,function(name) return assert(byName[name]) end)
local back=decoded.pages[1].menu
assert(back.groups[1].label=='A "quoted"\\label' and back.fields[1].default==0.5 and back.fields[2].tabs==true
    and back.fields[2].choices[2].label=='Yes' and back[7]=='sparse' and back[-1]==false
    and decoded.pages[1].menuFile==nil and decoded.pages[2].manifest==manifest,'menu data round-trips')
assert(not pcall(Menu.decode,descriptor:gsub('contract=4','contract=3'),function(name) return byName[name] end))
local sandboxed=Menu.deserialize('{x=os,y=print}')
assert(sandboxed.x==nil and sandboxed.y==nil,'menu data sees no globals')
assert(not pcall(Menu.deserialize,'return 1'),'menu data is a table constructor')
fails('menu must be a table','MCT',{pages={{id='MCT',name='a',menu='x',configDirectory='/x'}}})
fails('a menu page cannot have a manifest','MCT',{pages={{id='MCT',name='a',menu={},manifest=manifest,
    configDirectory='/x'}}})
fails('configDirectory','MCT',{pages={{id='MCT',name='a',menu={}}}})
assert(Menu.validate('MCT',{pages=menuPages,rows={{page='MCT',slot='controls:visuals',settings={'F'}}}}),
    'a menu page can source slot rows')
assert(not pcall(Menu.serialize,{f=function() end}),'menu data holds only plain values')
assert(not pcall(Menu.serialize,{0/0}),'menu numbers are finite')
-- Cleanup removes menu files beside manifests.
local menuHost=shared()
local menuStore,menuWrite,menuRemove=files()
local menuPublisher=Menu.publisher(menuHost,{id='MCT',directory='/m',write=menuWrite,remove=menuRemove})
for _=1,3 do menuPublisher:publish({pages=menuPages}) end
assert(menuStore['/m/mcs_menu.1.1.lua']==nil and menuStore['/m/mcs_menu.1.2.ini']==nil
    and menuStore['/m/mcs_menu.3.1.lua'] and menuStore['/m/mcs_menu.3.2.ini'],'older menu files are removed')
print('PASS menu data pages round-trip under contract 4')

-- textTable decodes an mcTable row as ModCoreSettings does, for offline checks.
local entries,columns=Menu.textTable(' 2190 : ← | U+25CF:● |a:b:c')
assert(columns==1 and #entries==3 and entries[1].code=='2190' and entries[1].text=='←'
    and entries[2].code=='U+25CF' and entries[3].code=='a' and entries[3].text=='b:c','codes end at the first colon')
assert(select(2,Menu.textTable('A:a','4'))==4 and select(2,Menu.textTable('A:a',6))==6)
local many={}
for n=1,256 do many[n]='C:x' end
assert(#Menu.textTable(table.concat(many,'|'))==256)
many[257]='C:x'
for _,bad in ipairs({{'',nil},{'A',nil},{':a',nil},{'A:',nil},{'A:a|',nil},{'A:a||B:b',nil},{'A\t:a',nil},
        {'ABCDEFGHI:a',nil},{'A:123456789',nil},{'\xff:a',nil},{table.concat(many,'|'),nil},
        {'A:a','0'},{'A:a','7'},{'A:a','2.0'},{'A:a',' 2'},{'A:a',2.5},{'A:a','x'}}) do
    assert(not pcall(Menu.textTable,bad[1],bad[2]),tostring(bad[1])..' / '..tostring(bad[2]))
end
print('PASS textTable decodes mcTable entries and columns')
-- unfold expands value lists: each value takes its list's entry, and appears once.
do
    local map=Menu.unfold({[{1,2}]='A',[3]='B'},'labels')
    assert(map[1]=='A' and map[2]=='A' and map[3]=='B','value lists unfold')
    local again=Menu.unfold(map,'labels')
    assert(again[1]=='A' and again[3]=='B','unfolding twice changes nothing')
    for _,bad in ipairs({{{[1]='A',[{1}]='B'},'appears twice'},{{[{}]='A'},'empty value list'},
            {{[{x=1}]='A'},'must be a list'},{{['a']='A'},'invalid value'}}) do
        local ok,err=pcall(Menu.unfold,bad[1],'labels')
        assert(not ok and tostring(err):find(bad[2],1,true),bad[2]..': '..tostring(err))
    end
    local ok,err=pcall(Menu.serialize,{values={[{1,2}]='A'}})
    assert(not ok and tostring(err):find('unfold value lists',1,true),'folded keys never travel')
end
print('PASS unfold expands value lists')
