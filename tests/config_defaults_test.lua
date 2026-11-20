package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Config=require('init_config')
-- Storage a row leaves out comes from its page: config.ini beside the page, the page's
-- [Mod] ConfigSection, else its [Mod] Id (only when the row also leaves out ConfigFile).
local function fails(fn,pattern)
    local ok,err=pcall(fn)
    assert(not ok and tostring(err):find(pattern,1,true),tostring(err))
end
local function rows(...)
    local out={}
    for _,spec in ipairs({...}) do out[#out+1]={id=spec[1],key=spec[1],file=spec.file,section=spec.section} end
    return out
end

local bare=Config.defaults('[Mod]\nId=Demo\nName=Demo\n',rows({'Flag'}))[1]
assert(bare.file=='config.ini' and bare.section=='Demo' and bare.key=='Flag','A1: defaults to config.ini [<Id>]')
local packed=Config.defaults('[Mod]\nId=Demo\nConfigSection = Pack.Demo \n',rows({'Flag'}))[1]
assert(packed.file=='config.ini' and packed.section=='Pack.Demo','A2: [Mod] ConfigSection names the section')
local stated=Config.defaults('[Mod]\nId=Demo\n',rows({'Flag',file='settings.ini',section='Settings'}))[1]
assert(stated.file=='settings.ini' and stated.section=='Settings','A4: stated storage is kept')
-- R4: a row naming its file but no section keeps matching any section, as before.
local fileOnly=Config.defaults('[Mod]\nId=Demo\n',rows({'Flag',file='settings.ini'}))[1]
assert(fileOnly.file=='settings.ini' and fileOnly.section==nil,'a row with ConfigFile keeps no section')
-- A page that names its section gives it to every row without one, stated file or not.
local both=Config.defaults('[Mod]\nId=Demo\nConfigSection=Pack\n',rows({'A',file='x.ini'},{'B',section='Own'}))
assert(both[1].section=='Pack' and both[1].file=='x.ini' and both[2].section=='Own' and both[2].file=='config.ini')
-- No [Mod] Id: no section, as before.
assert(Config.defaults('',rows({'Flag'}))[1].section==nil)
for _,bad in ipairs({'ConfigSection=\n','ConfigSection=A]B\n','ConfigSection=A=B\n'}) do
    fails(function() Config.defaults('[Mod]\nId=Demo\n'..bad,rows({'Flag'})) end,'invalid [Mod] ConfigSection')
end
-- A5 at merge level: the key in another section is not taken for it.
local index={index=function(_,v) return type(v)=='number' end}
local resolved=Config.defaults('[Mod]\nId=Demo\n',{{id='Flag',key='Flag',default=0}})
assert(Config.merge('[Other]\nFlag=1\n',resolved,index)=='[Other]\nFlag=1\n[Demo]\nFlag=0\n')
assert(Config.merge('[Demo]\nFlag=1\n',resolved,index)=='[Demo]\nFlag=1\n','a present key is not duplicated')

-- End to end through DMM's own parser and Apply, when available.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP config defaults (DMM): DMM_CHOICES_PATH is not set')
else
    local Choices=dofile(choicesPath)
    local files={}
    local fs={read=function(p) return files[p] end,write=function(p,v) files[p]=v end,
        rename=function(a,b) assert(files[a] and not files[b]);files[b]=files[a];files[a]=nil end,
        remove=function(p) files[p]=nil end}
    Choices.fs,Choices.sessions=fs,Choices.sessions or {}
    assert(Config.install(Choices,fs))
    local row='[Setting.Flag]\nId=Flag\nType=toggle\nPresetValues=0|1\nDefault=0\n'
    local function page(folder,mod)
        local manifest='[Mod]\n'..mod..'Name=Demo\n'..row
        local provider={id=folder,path=folder..'/mod_settings.ini',choices=Choices.parse(manifest)}
        local model=Choices.open(provider)
        assert(not model.error,tostring(model.error))
        model.fs=fs
        return model,provider
    end
    local function toggled(folder,mod)
        local model,provider=page(folder,mod)
        assert(model.pending[1]==0)
        model:set(1,1)
        assert(model:apply())
        assert(Choices.open(provider).pending[1]==1,'reopening reads the applied value')
        return files[folder..'/config.ini']
    end
    assert(toggled('A1','Id=Demo\n')=='[Demo]\nFlag=1\n','A1 through DMM')
    assert(toggled('A2','Id=Demo\nConfigSection=Pack.Demo\n')=='[Pack.Demo]\nFlag=1\n','A2 through DMM')
    -- A3's fallback: a prefixed id with ConfigKey and no section, under [Mod] Id.
    local manifest='[Mod]\nId=UE4SSLuaEXtensions.Events\nName=E\n[Setting.Events_EnableHooks]\nId=Events_EnableHooks\nType=toggle\nPresetValues=0|1\nConfigKey=EnableHooks\n'
    local provider={id='A3',path='A3/mod_settings.ini',choices=Choices.parse(manifest)}
    assert(not Choices.open(provider).error)
    assert(files['A3/config.ini']=='[UE4SSLuaEXtensions.Events]\nEnableHooks=0\n')
    -- A4: stated storage is untouched.
    files['A4/settings.ini']='[Settings]\nFlag=1\n'
    local stated4={id='A4',path='A4/mod_settings.ini',choices=Choices.parse(
        '[Mod]\nId=Demo\nName=Demo\n'..row..'ConfigFile=settings.ini\nConfigSection=Settings\n')}
    local model4=Choices.open(stated4)
    assert(not model4.error and model4.pending[1]==1 and files['A4/config.ini']==nil,'A4 through DMM')
    -- A5: the same key in another section is neither read nor rewritten.
    files['A5/config.ini']='[Elsewhere]\nFlag=1\n'
    local model5=page('A5','Id=Demo\n')
    assert(model5.pending[1]==0 and files['A5/config.ini']=='[Elsewhere]\nFlag=1\n[Demo]\nFlag=0\n','A5 through DMM')
end
print('PASS rows without storage keys store in config.ini under the page section')
