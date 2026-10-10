package.path='Scripts/?.lua;'..package.path
local Info=require('mcs_folder_info')
local J=require('mcs_module_json')
local files,sizes,writes={},{},0
local function read(path) return files[path] end
local function write(path,text) writes=writes+1;files[path]=text end
local function size(path) return sizes[path] end
local function folder(name,list) return {name=name,path='/Mods/'..name,files=list} end
local function boot(now,folders,extra)
    local options={path='info',folders=folders,now=now,read=read,write=write,size=size}
    for k,v in pairs(extra or {}) do options[k]=v end
    return Info.update(options)
end
local function names(facts)
    local out={}
    for _,e in ipairs(facts) do out[#out+1]=e.name..(e.directory and '/' or '='..tostring(e.size)) end
    return table.concat(out,'|')
end

-- Facts: top-level files by name and size, top-level folders by name; run-time files don't count.
sizes['/Mods/A/mod.json']=10;sizes['/Mods/A/enabled.txt']=0;sizes['/Mods/A/tags']=3
local a=folder('A',{'Scripts/main.lua','Scripts/lib/x.lua','enabled.txt','mod.json','config.ini','cache/x.json','tags'})
assert(names(Info.facts(a,size))=='Scripts/|enabled.txt=0|mod.json=10|tags=3',names(Info.facts(a,size)))

-- Without file dates, the first file makes every folder the baseline.
local b=folder('B',{'dlls/main.dll','enabled.txt'})
local info=boot(100,{a,b})
assert(info.A.added==100 and info.A.baseline and info.B.baseline and writes==1)
local saved=J.decode(files.info)
assert(saved.schema==2 and saved.folders.A.files[4].name=='tags' and saved.folders.A.files[4].size==3,
    'facts are saved as a list, so no file name is mistaken for a field')
info=boot(200,{a,b})
assert(info.A.added==100 and info.A.baseline and writes==1,'an unchanged boot writes nothing')
local c=folder('C',{'Scripts/main.lua','enabled.txt'})
info=boot(300,{a,b,c})
assert(info.C.added==300 and not info.C.baseline and info.A.added==100)
a.files[#a.files+1]='Settings.ini';a.files[#a.files+1]='session.log'
info=boot(400,{a,b,c})
assert(info.A.added==100,'run-time files are no update')
sizes['/Mods/A/mod.json']=12
info=boot(500,{a,b,c})
assert(info.A.added==100 and info.A.updated==500,'an update keeps the install date and records the update')
a.files[#a.files+1]='docs/readme.md'
info=boot(550,{a,b,c})
assert(info.A.updated==550,'a new top-level folder is an update')
info=boot(600,{a,c})
assert(info.B==nil)
info=boot(700,{a,b,c})
assert(info.B.added==700 and not info.B.baseline,'a reinstalled folder is new')

-- With file dates: listed creation times first, Stat where unlisted, the folder's own last.
local created={['/Mods/A/mod.json']=50,['/Mods/A/enabled.txt']=40,['/Mods/A/config.ini']=900,
    ['/Mods/B']=30,['/Mods/C/enabled.txt']=20}
local stats=0
local function stat(path) stats=stats+1;return created[path] and {created=created[path]} or nil end
local function list(path) if path=='/Mods/A' then return {['mod.json']={created=60,modified=5}} end end
files.info=nil
info=boot(1000,{a,b,c},{stat=stat,list=list})
assert(info.A.added==60 and not info.A.baseline,'newest top-level file, listed first, ignoring settings files')
assert(info.B.added==30,'without top-level dates, the folder\'s own')
assert(info.C.added==20)
local A=J.decode(files.info).folders.A.files
assert(A[3].name=='enabled.txt' and A[3].created==40 and A[4].name=='mod.json' and A[4].created==60
    and A[4].modified==5,'creation and modification dates are saved')
-- A baseline folder takes its real date once dates are available.
files.info=nil
boot(1100,{a})
info=boot(1200,{a},{stat=stat,list=list})
assert(info.A.added==60 and not info.A.baseline)
-- An update in place keeps old creation times, so it is dated by the boot.
sizes['/Mods/A/mod.json']=14
info=boot(1300,{a},{stat=stat,list=list})
assert(info.A.added==60 and info.A.updated==1300)
info=boot(1350,{a},{stat=stat,list=list})
assert(info.A.updated==1300,'the last update is kept')
-- Losing dates part-way falls back to sizes alone, and now.
local reported
info=boot(1400,{a,folder('D',{'enabled.txt'})},{stat=function() error('bridge gone') end,
    report=function(what) reported=what end})
assert(info.D.added==1400 and reported=='D')
-- An unreadable file starts again.
files.info='{broken'
info=boot(1500,{a},{report=function(what) reported=what end})
assert(info.A.added==1500 and info.A.baseline and reported=='folder_info.json')
print('PASS cache/folder_info.json records each mod folder\'s top level and when it was added')
