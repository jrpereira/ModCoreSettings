package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Config=require('init_config')
local function fails(fn,pattern)
    local ok,err=pcall(fn)
    assert(not ok and tostring(err):find(pattern,1,true),tostring(err))
end
local choices={index=function(s,value) return type(value)=='number' and value>=0 and value<=255 end}
-- os.tmpname always uses /tmp; honour TMPDIR so the suite runs in sandboxes too.
local emptyPath=os.getenv('TMPDIR') and (os.getenv('TMPDIR'):gsub('/+$','')..'/mcs_init_config_'..os.time()..'.ini')
    or os.tmpname()
local emptyFile=assert(io.open(emptyPath,'wb'));assert(emptyFile:close())
assert(Config.fs.read(emptyPath)=='','empty files must be valid configuration metadata')
assert(os.remove(emptyPath))
local settings={
    {key='Key',section='Bindings',default=82,file='config.ini'},
    {key='Mode',section='Bindings',default=1,file='config.ini'},
    {key='Enabled',section='General',default=1,file='config.ini'},
}
local merged=Config.overlay({a=true,b=1,c='default',d=7},{a=false,b=0,c='',other=9})
assert(merged.a==false and merged.b==0 and merged.c=='' and merged.d==7 and merged.other==9)
assert(Config.merge(nil,settings,choices)=='[Bindings]\nKey=82\nMode=1\n[General]\nEnabled=1\n')
local partial=';personal\r\n[Bindings]\r\nKey = 0 ; unbound\r\nUnknown=abc\r\n[Other]\r\nUnrelated=false'
local complete=Config.merge(partial,settings,choices)
assert(complete==';personal\r\n[Bindings]\r\nKey = 0 ; unbound\r\nUnknown=abc\r\nMode=1\r\n[Other]\r\nUnrelated=false\r\n[General]\r\nEnabled=1\r\n')
assert(Config.merge(complete,settings,choices)==complete,'unchanged config must be byte-identical')
assert(Config.merge('[Bindings]\nKey=false\nMode=\n[General]\nEnabled=0\n',settings,choices)
    =='[Bindings]\nKey=false\nMode=\n[General]\nEnabled=0\n','merge must not filter existing values')
local global={{key='Key',default=82,file='config.ini'}}
assert(Config.merge('[Bindings]\nKey=0',global,choices)=='[Bindings]\nKey=0','unqualified key can live in a section')
assert(Config.merge('[Other]\nThing=2',global,choices)=='Key=82\n[Other]\nThing=2')
fails(function() Config.merge('[A]\nKey=1\n[B]\nKey=2',global,choices) end,'ambiguous')
fails(function() Config.merge('[Bindings]\nKey=0\nKey=1',settings,choices) end,'duplicate')
fails(function() Config.merge('[Bindings]\n[Bindings]',settings,choices) end,'duplicate config section')
fails(function() Config.merge('[Bad',settings,choices) end,'malformed')
fails(function() Config.merge('',{{key='Bad\nKey',default=0}},choices) end,'invalid ConfigKey')

local function memory(initial)
    local files={};for k,v in pairs(initial or {}) do files[k]=v end
    local fs={writes=0}
    function fs.read(path) return files[path] end
    function fs.write(path,text) fs.writes=fs.writes+1;files[path]=text end
    function fs.remove(path) files[path]=nil end
    function fs.rename(a,b) assert(files[a]~=nil,'source missing');assert(files[b]==nil,'destination exists');files[b]=files[a];files[a]=nil end
    return fs,files
end
local plan={path='config.ini',content=complete}
local fs,files=memory()
assert(Config.commit(plan,fs));assert(files['config.ini']==complete and fs.writes==1)
assert(not Config.commit({path=plan.path,original=complete,content=complete},fs) and fs.writes==1)
fs,files=memory({['config.ini']=partial})
plan.original=partial
assert(Config.commit(plan,fs));assert(files['config.ini']==complete and not files['config.ini.mc-init.bak'])
for _,phase in ipairs({'write','verify','backup','install'}) do
    fs,files=memory({['config.ini']=partial})
    local write,rename=fs.write,fs.rename
    if phase=='write' then fs.write=function(path,text) write(path,'partial');error('injected write') end
    elseif phase=='verify' then fs.write=function(path) write(path,'wrong bytes') end
    else fs.rename=function(a,b)
        if (phase=='backup' and b:match('%.bak$')) or (phase=='install' and a:match('%.tmp$')) then error('injected '..phase) end
        rename(a,b)
    end end
    assert(not pcall(Config.commit,plan,fs))
    assert(files['config.ini']==partial,'original must survive '..phase)
    assert(not files['config.ini.mc-init.tmp'])
end
fs,files=memory({['config.ini']=partial})
local write=fs.write
fs.write=function(path,text) write(path,text);files['config.ini']='external edit' end
fails(function() Config.commit(plan,fs) end,'changed during')
assert(files['config.ini']=='external edit')
fs,files=memory({['config.ini']=partial,['config.ini.mc-init.bak']='recovery'})
fails(function() Config.commit(plan,fs) end,'needs review')
assert(fs.writes==0 and files['config.ini.mc-init.bak']=='recovery')
fs,files=memory({['config.ini']=partial})
local rename=fs.rename
fs.rename=function(a,b)
    if a:match('%.tmp$') then files[b]='external edit';error('install failed') end
    rename(a,b)
end
fails(function() Config.commit(plan,fs) end,'rollback failed')
assert(files['config.ini']=='external edit' and files['config.ini.mc-init.bak']==partial)
fs,files=memory()
write=fs.write
fs.write=function(path,text) write(path,text);files['config.ini']='created externally' end
fails(function() Config.commit({path='config.ini',content='defaults'},fs) end,'changed during')
assert(files['config.ini']=='created externally' and not files['config.ini.mc-init.tmp'])

-- Plan validates paths and DMM compatibility before any writes, restoring its
-- private parser's fs even when DMM throws.
choices.parse=function() return settings end
choices.open=function() return {} end
local saved={};choices.fs=saved
fs,files=memory({['Mods/Example/config.ini']=partial})
local provider={id='Example',path='Mods/Example/mod_settings.ini'}
plan=Config.plan(provider,'schema',choices,fs)
assert(plan.content==complete and fs.writes==0 and choices.fs==saved)
settings[1].file='../outside.ini'
fails(function() Config.plan(provider,'schema',choices,fs) end,'invalid ConfigFile')
settings[1].file='config.ini'
choices.open=function() error('unsupported DMM') end
fails(function() Config.plan(provider,'schema',choices,fs) end,'unsupported DMM')
assert(choices.fs==saved and fs.writes==0)
choices.open=function() return {error='invalid user value'} end
fails(function() Config.plan(provider,'schema',choices,fs) end,'invalid user value')
assert(fs.writes==0)
choices.open=function() return {} end
-- Files left by a crashed commit are cleaned up only when provably redundant.
local base='Mods/Example/config.ini'
-- Staged but never installed: the staged bytes are this run's output.
fs,files=memory({[base]=partial,[base..'.mc-init.tmp']=complete})
plan=Config.plan(provider,'schema',choices,fs)
assert(not files[base..'.mc-init.tmp'] and plan.original==partial and plan.content==complete,'a staged copy of this run is removed')
assert(Config.commit(plan,fs) and files[base]==complete)
-- Interrupted between the renames: the original is put back, then the staged copy goes.
fs,files=memory({[base..'.mc-init.bak']=partial,[base..'.mc-init.tmp']=complete})
plan=Config.plan(provider,'schema',choices,fs)
assert(files[base]==partial and not files[base..'.mc-init.bak'] and not files[base..'.mc-init.tmp']
    and plan.original==partial,'a moved-aside original is restored')
-- Installed but not cleaned up: the config is exactly the merged original.
fs,files=memory({[base]=complete,[base..'.mc-init.bak']=partial})
plan=Config.plan(provider,'schema',choices,fs)
assert(not files[base..'.mc-init.bak'] and plan.original==complete,'a backup the config was built from is removed')
-- Anything that does not match stays, and the page asks for review in plain words.
fs,files=memory({[base]=partial,[base..'.mc-init.bak']='older edits'})
plan=Config.plan(provider,'schema',choices,fs)
assert(files[base..'.mc-init.bak']=='older edits')
fails(function() Config.commit(plan,fs) end,'an interrupted config write left '..base..'.mc-init.bak and it needs review')
fs,files=memory({[base]=partial,[base..'.mc-init.tmp']='other bytes'})
plan=Config.plan(provider,'schema',choices,fs)
assert(files[base..'.mc-init.tmp']=='other bytes','an unrelated staged file stays')
fails(function() Config.commit(plan,fs) end,'needs review')
-- DMM's own transaction files are never touched.
fs,files=memory({[base]=partial,[base..'.dmm-toggle.tmp']=complete})
plan=Config.plan(provider,'schema',choices,fs)
assert(files[base..'.dmm-toggle.tmp']==complete)
fails(function() Config.commit(plan,fs) end,'.dmm-toggle.tmp and it needs review')
for _,setting in ipairs(settings) do setting.file='nested/preferences.ini' end
local nested=Config.plan(provider,'schema',choices,fs)
assert(nested.path=='Mods/Example/nested/preferences.ini')

-- The DMM-owned wrapper initializes every ordinary provider, even when it has
-- no migration metadata. Test-only providers remain memory-only.
local ordinarySettings={{id='Enabled',kind='toggle',values={0,1},labels={'Off','On'},key='Enabled',section='General',default=1,file='config.ini'}}
local wrapped={}
function wrapped.parse() return ordinarySettings end
function wrapped.index(setting,value)
    for i,candidate in ipairs(setting.values or {}) do if candidate==value then return i end end
end
function wrapped.open(opened)
    if wrapped.fs then
        local config=opened.path:gsub('mod_settings%.ini$','config.ini')
        assert(wrapped.fs.read(config)=='[General]\nEnabled=1\n')
    end
    return {provider=opened,items=opened.choices or {},error=nil}
end
fs,files=memory({['Mods/Ordinary/mod_settings.ini']='[Setting.Enabled]\nId=Enabled\n'})
assert(Config.install(wrapped,fs))
local ordinary={id='Ordinary',path='Mods/Ordinary/mod_settings.ini',choices=ordinarySettings}
assert(not wrapped.open(ordinary).error)
assert(files['Mods/Ordinary/config.ini']=='[General]\nEnabled=1\n','ordinary provider was not initialized')
local writes=fs.writes
wrapped.open({id='Test',path='missing',choices=ordinarySettings,testOnly=true})
assert(fs.writes==writes,'test-only provider touched configuration')
local contributed={id='MCT.page',path='Mods/Contributed/mod_settings.ini',choices=ordinarySettings,
    mcManifest='[Setting.Enabled]\nId=Enabled\n'}
wrapped.fs=nil
assert(files['Mods/Contributed/mod_settings.ini']==nil)
local opened=wrapped.open(contributed)
assert(not opened.error,'contributed pages use their in-memory manifest: '..tostring(opened.error))
assert(files['Mods/Contributed/config.ini']=='[General]\nEnabled=1\n','contributed provider was not initialized')
assert(wrapped.open({id='NoFile',path='Mods/Missing/mod_settings.ini',choices=ordinarySettings}).error
    :find('configuration metadata unavailable',1,true),'a missing manifest still fails without mcManifest')
print('PASS in-state config planning preserves bytes, validates paths and recovers transactions')
