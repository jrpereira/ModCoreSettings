package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Listed choices: from entries in keyed pickers resolve through the mod's list file on every
-- build, with the folder listing the host gives.
local From=require('menu_from')
local MenuData=require('menu_data')

-- A fake host: list files by path, folders by root and subfolder.
local sources,folders,reports={},{},{}
local function load(path,env)
    local text=sources[path]
    if not text then return nil,'cannot open '..path end
    return load_(text,path,'t',env)
end
load_=load_ or _G.load
local heads={}
local expand=From.expander({load=load,read=function(root,path,count)
        local bytes=heads[root..'/'..path]; if not bytes then return nil,'no file' end return bytes:sub(1,count) end,
    report=function(event,detail) reports[#reports+1]=event..' '..detail end,
    files=function(root,sub) local names=folders[root..'/'..sub]; if names==false then return nil,'boom' end return names or {} end})

local LIST=[[return function(context)
    local names,why=context.files('sounds')
    if not names then return nil,why end
    local out={}
    for _,name in ipairs(names) do
        local key=name:match('^cue_([%w_]+)%.wav$')
        if key then out[#out+1]={key=key,label=key:upper(),note='cue'} end
    end
    table.sort(out,function(a,b) return a.key<b.key end)
    return out
end]]
sources['Mods/P/Scripts/choices/cues.lua']=LIST
local function menu(values,default,extra)
    local field={id='Sound',group='G',label='Sound',values=values,default=default}
    local fields={field}
    for _,item in ipairs(extra or {}) do fields[#fields+1]=item end
    return {storage={file='config.ini',section='S'},groups={{id='G'}},fields=fields}
end
local function keys(result)
    local out={}
    for _,choice in ipairs(result.fields[1].values) do out[#out+1]=choice.key..'='..choice.label end
    return table.concat(out,' ')..' default '..tostring(result.fields[1].default)
end
local FROM={from='choices/cues.lua',root='Mods/P'}

-- A menu without from entries comes back as itself.
local plain=menu({{key='none',label='None'},{key='chime',label='Chime'}},'none')
assert(expand(plain)==plain,'nothing to resolve')

-- Spliced where the entry stands, fixed choices around it; sorted by the list file.
folders['Mods/P/sounds']={'cue_ping.wav','cue_bell.wav','readme.txt'}
local m=menu({{key='none',label='None'},FROM,{key='last',label='Last'}},'ping')
local result=expand(m)
assert(keys(result)=='none=None bell=BELL ping=PING last=Last default ping','spliced in place')
assert(result.fields[1].values[2].note=='cue','notes carried')
assert(m.fields[1].values[2]==FROM,'the source menu is untouched')
-- The result compiles into a manifest: every key is a valid keyed choice.
local manifest=MenuData.manifest(result)
assert(manifest:find('mcKeys=none|bell|ping|last',1,true),'compiled with the listed keys')

-- Files added while the game runs show on the next build.
folders['Mods/P/sounds'][#folders['Mods/P/sounds']+1]='cue_angel.wav'
assert(keys(expand(m))=='none=None angel=ANGEL bell=BELL ping=PING last=Last default ping','re-listed per build')

-- A fixed key wins over a listed one wherever it stands; between lists the first wins.
sources['Mods/P/Scripts/choices/more.lua']=[[return function() return {{key='bell',label='Other'},{key='zed',label='Zed'}} end]]
local dup=menu({FROM,{from='choices/more.lua',root='Mods/P'},{key='ping',label='Fixed Ping'}},'ping')
assert(keys(expand(dup))=='angel=ANGEL bell=BELL zed=Zed ping=Fixed Ping default ping','fixed wins, first list wins')

-- A missing default shows the first choice.
assert(keys(expand(menu({{key='none',label='None'},FROM},'gone')))=='none=None angel=ANGEL bell=BELL ping=PING default none',
    'a default no longer offered shows the first choice')

-- A failing or empty list keeps its last good result, reported once.
folders['Mods/P/sounds']=false
local kept=expand(m)
assert(keys(kept)=='none=None angel=ANGEL bell=BELL ping=PING last=Last default ping','the last good list stays')
expand(m)
local failed=0
for _,line in ipairs(reports) do if line:find('boom',1,true) then failed=failed+1 end end
assert(failed==1,'reported once')
folders['Mods/P/sounds']={}
assert(keys(expand(m))=='none=None angel=ANGEL bell=BELL ping=PING last=Last default ping','an empty list keeps the last good one')

-- Fewer than two choices: the default as a placeholder, labelled as last listed or by its key.
sources['Mods/Q/Scripts/choices/cues.lua']=LIST
local fresh={from='choices/cues.lua',root='Mods/Q'}
local single=expand(menu({{key='off',label='Off'},fresh},'fiend'))
assert(keys(single)=='off=Off fiend=fiend default fiend','the default stands in, by its key')
local known=expand(menu({{key='off',label='Off'},fresh},'angel'))
assert(keys(known)=='off=Off angel=ANGEL default angel','labelled as last listed')
-- Still under two: the field and every rule naming it leave the page.
local dependent={id='Volume',group='G',label='Volume',values={min=0,max=10},default=5,
    conditions={visible={field='Sound',values={'off'},playerExists=true}}}
local gone=expand(menu({fresh},'off',{dependent}))
assert(#gone.fields==1 and gone.fields[1].id=='Volume','a field left with one choice is dropped')
assert(gone.fields[1].conditions.visible.field==nil and gone.fields[1].conditions.visible.playerExists==true,
    'rules naming it go; the player rule stays')
MenuData.manifest(gone)

-- Broken list files and choices: reported, never raised.
sources['Mods/P/Scripts/choices/bad.lua']=[[return function() return {{key='1',label='Number'},{key='ok',label='Ok'},{key='x',label='a|b'}} end]]
local bad=expand(menu({{key='none',label='None'},{from='choices/bad.lua',root='Mods/P'}},'none'))
assert(keys(bad)=='none=None ok=Ok default none','invalid choices are skipped')
sources['Mods/P/Scripts/choices/raises.lua']=[[return function() error('nope') end]]
assert(keys(expand(menu({{key='none',label='None'},{key='b',label='B'},{from='choices/raises.lua',root='Mods/P'}},'none')))
    =='none=None b=B default none','a raising list adds nothing')
-- List files are pure: no UE4SS or io globals.
sources['Mods/P/Scripts/choices/impure.lua']=[[return function() return {{key=type(io)..'_'..type(FindFirstOf),label='L'}} end]]
assert(keys(expand(menu({{key='none',label='None'},{from='choices/impure.lua',root='Mods/P'}},'none')))
    =='none=None nil_nil=L default none','the sandbox has no io and no UE4SS globals')
sources['Mods/P/Scripts/choices/escape.lua']=[[return function(context) return context.files('../other') end]]
expand(menu({{key='none',label='None'},{key='b',label='B'},{from='choices/escape.lua',root='Mods/P'}},'none'))
local escaped=false
for _,line in ipairs(reports) do if line:find('invalid subfolder',1,true) then escaped=true end end
assert(escaped,'a subfolder may not leave the mod folder')

-- context.head gives a file's first bytes, inside the mod folder only.
heads['Mods/P/images/a.png']='HEADERBYTES'
sources['Mods/P/Scripts/choices/head.lua']=[[return function(context)
    local bytes=context.head('images/a.png',6)
    local missing=context.head('images/none.png',4)
    return {{key='h_'..bytes..'_'..tostring(missing),label='H'}}
end]]
assert(keys(expand(menu({{key='none',label='None'},{from='choices/head.lua',root='Mods/P'}},'none')))
    =='none=None h_HEADER_nil=H default none','a list file reads a file\'s first bytes')
sources['Mods/P/Scripts/choices/headescape.lua']=[[return function(context) return {{key=context.head('../x',4),label='X'}} end]]
expand(menu({{key='none',label='None'},{key='b',label='B'},{from='choices/headescape.lua',root='Mods/P'}},'none'))
local headEscaped=false
for _,line in ipairs(reports) do if line:find('invalid path',1,true) then headEscaped=true end end
assert(headEscaped,'head may not leave the mod folder')

-- Entry checks.
assert(pcall(From.entry,FROM,'x'))
for _,bad in ipairs({{from='../x.lua',root='M'},{from='/x.lua',root='M'},{from='x.txt',root='M'},
    {from='x.lua',root='M/../N'},{from='x.lua'},{from='x.lua',root='M',key='k'}}) do
    assert(not pcall(From.entry,bad,'x'),'a bad entry is refused')
end
-- Unresolved from entries never reach DMM.
assert(not pcall(MenuData.manifest,m),'menu data refuses a from entry it did not resolve')

-- The game host lists through UE4SS's directory tree.
local tree={Game={Binaries={Win64={ue4ss={Mods={P={sounds={__files={{__name='cue_a.wav'},{__name='b.txt'}}},
    deep={inner={__files={{__name='x'}}}}}}}}}}}
local files=From.gameFiles(function() return tree end)
local names=files('C:/Game/ue4ss/Mods/P','sounds')
table.sort(names)
assert(table.concat(names,' ')=='b.txt cue_a.wav','names directly inside')
assert(files('Mods/P/','deep/inner')[1]=='x','nested subfolders')
assert(#files('Mods/P','missing')==0,'a missing folder is empty')
assert(files('Mods/Z','sounds')==nil,'an unknown mod folder fails')
assert(From.gameFiles(function() error('x') end)('Mods/P','sounds')==nil,'a failing tree fails')
-- A sound that is a WAV file in the mod becomes its full path; others are dropped.
sources['Mods/P/Scripts/choices/sounds.lua']=[[return function() return {{key='a',label='A',sound='sounds/cue_a.wav'},
    {key='b',label='B',sound='../x.wav'},{key='c',label='C',sound='/Game/X/Y'}} end]]
local withSounds=expand(menu({{key='none',label='None'},{from='choices/sounds.lua',root='Mods/P'}},'none'))
local byKey={}
for _,choice in ipairs(withSounds.fields[1].values) do byKey[choice.key]=choice end
assert(byKey.a.sound=='Mods/P/sounds/cue_a.wav' and byKey.b.sound==nil and byKey.c.sound=='/Game/X/Y',
    'WAV sounds resolve against the mod; outside ones are dropped; events stay')
print('PASS menu_from: listed choices splice per build, keep the last good list, and stay pure')
