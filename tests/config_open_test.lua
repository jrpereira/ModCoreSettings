package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local C=require('init_config')
-- The open adapter adds missing keys before DMM opens a page, fails closed on a config it
-- cannot complete, recovers after a failed write and leaves ordinary providers working.
local schema='[Setting.Count]\nId=Count\n'
local function settings()
    return {{id='Count',key='Count',section='General',default=2,file='config.ini',kind='picker'}}
end
local choices={index=function(_,v) return v==1 or v==2 end}
local files={['Mod/mod_settings.ini']=schema,['Mod/config.ini']='[General]\nOther=0\n'}
local writes,failWrite=0,false
local fs={read=function(p) return files[p] end,
    write=function(p,v) if failWrite then error('disk unavailable') end;writes=writes+1;files[p]=v end,
    rename=function(a,b) assert(files[a] and not files[b]);files[b]=files[a];files[a]=nil end,
    remove=function(p) files[p]=nil end}
choices.fs=fs
choices.parse=function() return settings() end
choices.open=function(provider)
    local m={}
    local base=assert(provider.path:match('^(.*)[/\\][^/\\]+$'))
    local text=choices.fs.read(base..'/config.ini') or ''
    m.value=tonumber(text:match('\nCount=(%d+)'))
    function m:set(v) if not self.error then self.value=v end end
    function m:apply() if self.error then return false,self.error end;return true end
    return m
end
assert(C.install(choices,fs) and not C.install(choices,fs))
local provider={id='Example',path='Mod/mod_settings.ini',choices=choices.parse(schema)}
local model=choices.open(provider)
assert(not model.error and model.value==2 and model:apply() and writes==1,'the missing key is added with its default')
assert(files['Mod/config.ini']=='[General]\nOther=0\nCount=2\n','other keys keep their bytes')
assert(not choices.open(provider).error and writes==1,'a complete config is not written again')
files['Mod/config.ini']='[General]\nOther=0\nOther=1\n'
model=choices.open(provider)
assert(model.error:find('Configuration initialization failed',1,true) and not model:apply(),'a broken config fails closed')
model:set(1);assert(model.value==nil and writes==1)
files['Mod/config.ini']='[General]\nOther=0\n';failWrite=true
model=choices.open(provider);assert(model.error and not model:apply())
assert(files['Mod/config.ini']=='[General]\nOther=0\n','a failed write leaves the config as it was')
failWrite=false;assert(not choices.open(provider).error,'failed attempt must not poison subsequent opens')
files['Missing/metadata.ini']='[Setting.Unrelated]\n'
local before=writes
local unrelated={path='Missing/metadata.ini',choices=choices.parse(files['Missing/metadata.ini'])}
local unrelatedModel=choices.open(unrelated)
assert(not unrelatedModel.error,'ordinary provider initialization failed: '..tostring(unrelatedModel.error))
assert(writes==before+1 and files['Missing/config.ini'],'ordinary provider config was not created')
print('PASS config open adapter: missing defaults, fail-closed broken configs, write recovery, ordinary providers')
