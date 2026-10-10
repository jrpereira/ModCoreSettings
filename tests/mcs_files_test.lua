package.path='Scripts/?.lua;'..package.path
local Files=require('mcs_files')
assert(Files.open(nil,nil)==nil,'no bridge, no files')

-- A fake bridge: environments carry grants; operations return value or nil, code, message.
local disk,grants,made={},{},{}
local function environment(granted)
    local env={}
    function env.AddPath(path,options) local next={};for k,v in pairs(granted) do next[k]=v end;next[path]=options;return environment(next) end
    function env.Path(name,...) return table.concat({'/'..name,...},'/') end
    function env.Stat(path) if disk[path] then return {type='file',size=#disk[path],created=7} end return nil,'not_found','missing' end
    function env.ReadText(path) if disk[path] then return disk[path] end return nil,'not_found','missing' end
    function env.WriteText(path,text) if path:find('denied') then return nil,'denied','no grant' end disk[path]=text;return true end
    function env.List(path) if path=='/dir' then return {{name='a.txt',type='file',size=1,created=9}} end return nil,'not_found','missing' end
    function env.MakeDir(path) made[#made+1]=path;return true end
    grants=granted
    return env
end
local bridge=setmetatable({GetCapabilities=function() return {api=1} end},{__call=function() return environment({}) end})
local files=assert(Files.open(nil,bridge))
assert(next(grants)==nil,'the safe set is enough: MCS writes only inside its own folder')
local path='/mod/cache/folder_info.json'
files.mkdir('/mod/cache');assert(made[1]=='/mod/cache')
files.write(path,'{}')
assert(files.read(path)=='{}' and files.size(path)==2 and files.stat(path).created==7)
assert(files.read('/nothing')==nil and files.size('/nothing')==nil,'missing is nil')
assert(select(2,pcall(files.write,'/denied','x')):find('no grant',1,true),'failures raise with the bridge message')

local reported
local old=setmetatable({GetCapabilities=function() return {api=2} end},{__call=function() return environment({}) end})
assert(Files.open(function(_,why) reported=why end,old)==nil and reported:find('API',1,true),'another API is reported, not used')
assert(files.list('/dir')['a.txt'].created==9 and files.list('/none')==nil,'listings by name')
print('PASS MCS uses UE4SSLuaFileBridge when it speaks API 1')
