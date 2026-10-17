package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local R=require('mcs_mod_registry')
local J=require('mcs_module_json')
local Tax=R.taxonomy
local real=R.loadFolderCategories()
assert(real.version==Tax.data.version and real.revision>=1 and real.folders['90days'][1]=='quests',
    'runtime loads the generated normalized M-to-C data')
assert(R.normalizeFolderName('90 Days')=='90days'
    and R.normalizeFolderName('E\204\129 STRA\225\186\158E')=='éstrasse',
    'folder normalization is case folded, Unicode aware, and separator independent')
assert(R.tokens==nil and R.match==nil,'runtime registry does not compute fingerprints')

-- Usable categories: remap fixes invalid data first, then unknown ids are dropped.
assert(table.concat(Tax:usable({'quests','retired'}),',')=='quests','invalid categories are dropped')
assert(Tax:usable({'retired'})==nil and Tax:usable({})==nil and Tax:usable('quests')==nil,
    'nothing valid is a failed step')
assert(Tax:usable({'other','skills'})==nil and Tax:usable({'niche','combat'})==nil,
    'an unclassified category beside another rejects the selection')
-- Taxonomy v3: the first 3 main categories in declaration order are kept, the rest named.
local notes={}
local kept=Tax:usable({'combat','sounds','weapons','research','movement'},{report=function(m) notes[#notes+1]=m end})
assert(table.concat(kept,',')=='combat,movement,weapons,sounds' and #notes==1 and notes[1]:find('research',1,true),
    'Actions, Media and Items are kept; research is dropped and reported')
assert(Tax:usable({'ambiguous'},{author=true})==nil and Tax:usable({'ambiguous'})[1]=='ambiguous',
    'only the classifier declares ambiguous')
local Taxonomy=require('mcs_taxonomy')
local remapped=Taxonomy.new({version=1,remap=function(C)
    for i,id in ipairs(C) do if id=='old' then C[i]='new' end end
    return C
end,sections={{id='s'}},categories={{id='new',parent='s'},{id='other',parent='s'}},tags={}})
assert(remapped:usable({'old'})[1]=='new','remap(C) converts categories the taxonomy rejects')
assert(Taxonomy.new({version=1,remap=function() error('broken') end,sections={{id='s'}},
    categories={{id='new',parent='s'}},tags={}}):usable({'old','new'})[1]=='new','a failing remap is ignored')

local folderData={version=Tax.data.version,revision=1,folders={
    reviewedmod={'quests'},othertest={'other'},declared={'skills'},stale={'retired'},
}}
local path='/mods/MCS/cache/modules_register.json'
local disk={
    ['/mods/Declared/mod.json']='{"author":"Ann","categories":["combat","retired"],'
        ..'"tags":["fix","unknown"],"preferred":"author","icon":"\226\153\158"}',
    ['/mods/Undeclared/mod.json']='{"name":"No categories","preferred":"Group"}',
    ['/mods/Broken/mod.json']='{"categories":["quests"],}',
    ['/mods/Invalid/mod.json']='{"categories":["retired"]}',
    ['/mods/Guess/Scripts/main.lua']='SkillTimeCost=0',
    ['/mods/Unknown/Scripts/main.lua']='local object={}',
    ['/mods/Stale/Scripts/main.lua']='',
}
local writes,reports=0,{}
local function scripts() return {__files={{__name='enabled.txt'}},Scripts={__files={{__name='main.lua'}}}} end
local function manifest() return {__files={{__name='enabled.txt'},{__name='mod.json'}}} end
local function enumerate()
    return {__absolute_path='/mods',['Reviewed Mod']=scripts(),OtherTest=scripts(),
        Declared=manifest(),Undeclared=manifest(),Broken=manifest(),Invalid=manifest(),
        Guess=scripts(),Unknown=scripts(),Stale=scripts(),Empty={__files={{__name='enabled.txt'}}},
        Disabled={Scripts={__files={{__name='main.lua'}}}}}
end
local options={database=folderData,mkdir=function(dir) assert(dir=='/mods/MCS/cache') end,
    read=function(file) return disk[file] end,
    write=function(file,value) assert(file==path);disk[file]=value;writes=writes+1 end,
    report=function(folder,why) reports[folder]=why end}
local index=R.boot('/mods/MCS','/mods',enumerate,options)
local m=index.modules

local d=m.Declared
assert(d.source=='module' and table.concat(d.categories,',')=='combat',
    'mod.json categories win; invalid ones are dropped')
assert(d.tags[1]=='fix' and #d.tags==1 and d.preferred=='Ann' and d.icon=='♞','module presentation fields')
assert(m.Undeclared.source=='auto' and m.Undeclared.preferred=='Group',
    'a mod.json without categories still names its preferred group')
assert(m.Broken.source=='auto' and reports.Broken,'an unreadable mod.json is reported and skipped')
assert(m.Invalid.source=='auto' and reports.Invalid,'declared categories with nothing valid fall through')

assert(m['Reviewed Mod'].source=='data' and m['Reviewed Mod'].categories[1]=='quests',
    'normalized folder name resolves through folder_categories')
assert(m.OtherTest.categories[1]=='other' and m.OtherTest.reason=='specialized','folder_categories other is specialized')
assert(m.Stale.source=='auto' and reports.Stale,'a folder_categories row the taxonomy rejects falls through')

assert(m.Guess.source=='auto' and m.Guess.confidence=='tentative' and m.Guess.categories[1]=='skills',
    'the heuristic classifies what neither mod.json nor folder_categories does')
assert(m.Unknown.categories[1]=='other' and m.Unknown.reason=='insufficient_evidence'
    and m.Unknown.confidence=='abstained','heuristic abstention is other')
assert(m.Empty==nil,'folders without scripts, dlls or mod.json are not modules')
assert(m.Disabled==nil,'only active modules, with enabled.txt, are considered')

assert(writes==1 and J.decode(disk[path]).modules.Declared.categories[1]=='combat',
    'the browser handoff is written')
index=R.boot('/mods/MCS','/mods',enumerate,options)
assert(writes==1,'an unchanged index is not rewritten')
disk['/mods/Undeclared/mod.json']='{"categories":["skills"]}'
index=R.boot('/mods/MCS','/mods',enumerate,options)
assert(writes==2 and index.modules.Undeclared.source=='module','mod.json changes apply on the next boot')
folderData.revision=2;folderData.folders.unknown={'quests'}
index=R.boot('/mods/MCS','/mods',enumerate,options)
assert(index.modules.Unknown.source=='data','nothing is cached: a folder_categories addition applies at once')

-- A folder is listed whatever words its name holds; only .bak copies are skipped.
local function folder(...) return {__files={{__name='enabled.txt'},{__name='mod.json'}},...} end
local named={}
for _,found in ipairs(R.folders({__absolute_path='/mods',SaveBackupManager=folder(),ArchiveOfLore=folder(),
    AuditTrail=folder(),['Old.bak']=folder()},'/mods')) do named[#named+1]=found.name end
assert(table.concat(named,',')=='ArchiveOfLore,AuditTrail,SaveBackupManager','mod folder names are not filtered by word')

-- An existing cache folder is found by its probe, without a shell; a missing one is made.
local temp=(os.getenv('TMPDIR') or '/tmp')..'/mcs_mkdir_'..tostring(os.time())..'_'..math.random(1e6)
local execute=os.execute
local shells=0
os.execute=function(...) shells=shells+1;return execute(...) end
R.mkdir(temp);R.mkdir(temp)
os.execute=execute
assert(shells==1 and io.open(temp..'/.mcs-probe','rb')==nil,'one shell for a missing folder, none once it exists')
os.remove(temp)

-- Module ids: mod.json's id, a plain identifier, shared per installed folder; an id two
-- folders declare goes to neither; the ready flag follows them all.
do
    local files={
        ['/ids/9_Fang/mod.json']='{"id":"Fangdango","categories":["combat"]}',
        ['/ids/Plain/mod.json']='{"categories":["combat"]}',
        ['/ids/Spaced/mod.json']='{"id":"Not an id","categories":["combat"]}',
        ['/ids/A/mod.json']='{"id":"Twin","categories":["combat"]}',
        ['/ids/B/mod.json']='{"id":"Twin","categories":["combat"]}',
    }
    local idReports={}
    local function snapshot()
        return {__absolute_path='/ids',['9_Fang']=manifest(),Plain=manifest(),Spaced=manifest(),A=manifest(),B=manifest()}
    end
    local idIndex=R.boot('/ids/MCS','/ids',snapshot,{database=folderData,mkdir=function() end,
        read=function(file) return files[file] end,write=function() end,
        report=function(folder,why) idReports[folder]=(idReports[folder] or '')..why end})
    assert(idIndex.modules['9_Fang'].id=='Fangdango' and idIndex.modules.Plain.id==nil,'mod.json id is kept')
    assert(idIndex.modules.Spaced.id==nil and idReports.Spaced:find('identifier',1,true),'an id that is not an identifier is reported')
    local shared,order={},{}
    R.publishModuleIds(idIndex,function(key,value) shared[key]=value;order[#order+1]=key end,
        function(folder,why) idReports[folder]=why end)
    assert(shared['MCS_ModuleId_v1.9_Fang']=='Fangdango' and shared['MCS_ModuleId_v1.Plain']==nil
        and shared['MCS_ModuleId_v1.Spaced']==nil,'each folder with an id is shared under its installed name')
    assert(shared['MCS_ModuleId_v1.A']==nil and shared['MCS_ModuleId_v1.B']==nil
        and idReports.A:find('A, B',1,true),'an id two folders declare goes to neither, reported')
    assert(order[#order]=='MCS_ModuleId_v1.ready' and shared['MCS_ModuleId_v1.ready']=='1','ready comes last')
end

print('PASS mod.json, folder_categories and heuristic steps, remap and invalid categories, uncached rebuild')
