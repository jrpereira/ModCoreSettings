package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Keys=require('standard_keys')
local function object(path)
    local value={valid=true,path=path,full='InputAction '..path}
    function value:IsValid() return self.valid end
    return value
end
local game=object('/Game/_Dawnwalker/Player/Input/Actions/IA_Toggle.IA_Toggle')
local copy=object('/Game/Mods/Other/IA_Toggle.IA_Toggle')
local actions={game,copy}
local profile={valid=true,PlayerMappedKeys={}}
local e={
    valid=function(value) return value~=nil and value.valid==true end,
    full=function(value) return value and value.full end,
    path=function(value) return value and value.path end,
    property=function(value,key) return value and value[key] end,
    name=function(value) return value end,
    each=function(values,callback)
        for key,value in pairs(values or {}) do
            if type(key)=='number' then callback(value,key) else callback(key,value) end
        end
        return true
    end,
    actions=function() return actions end,
    profile=function() return profile end,
}

-- One rule picks the action: the only one, or the one in the game's input folder.
assert(Keys.action(e,'IA_Toggle')==game,'the game folder wins over a mod action of the same name')
actions={copy}
assert(Keys.action(e,'IA_Toggle')==copy,'a single action is chosen wherever it lives')
local second=object('/Game/Mods/Third/IA_Toggle.IA_Toggle')
actions={copy,second}
local action,why=Keys.action(e,'IA_Toggle')
assert(action==nil and why=='standard input action ambiguous: 2 actions: IA_Toggle',tostring(why))
actions={}
action,why=Keys.action(e,'IA_Toggle')
assert(action==nil and why=='standard input action unavailable: IA_Toggle')
print('PASS one action is chosen by name, preferring the game input folder')

-- Keys: entries naming the action and entries naming its mapping, together.
actions={game,copy}
game.PlayerMappableKeySettings={Name='Toggle'}
profile.PlayerMappedKeys={
    Toggle={Mappings={
        {AssociatedInputAction=game,CurrentKey={KeyName='LeftAlt'}},
        {AssociatedInputAction=game,CurrentKey={KeyName='Gamepad_FaceButton_Top'}},
        {MappingName='Toggle',CurrentKey={KeyName='Q'}},
        {AssociatedInputAction=copy,CurrentKey={KeyName='Z'}},
        {AssociatedInputAction=game,CurrentKey={KeyName='None'}}}},
}
local keys
keys,why,action=Keys.resolve(e,'IA_Toggle')
assert(keys and #keys==2 and keys[1]=='LeftAlt' and keys[2]=='Q' and action==game,
    'action and mapping-name entries together; gamepad keys, None and other actions left out')
-- A plain list of rows reads the same as a map.
profile.PlayerMappedKeys={profile.PlayerMappedKeys.Toggle}
keys=Keys.resolve(e,'IA_Toggle')
assert(keys and #keys==2)
-- Why nothing resolves.
profile.PlayerMappedKeys={}
keys,why=Keys.resolve(e,'IA_Toggle')
assert(keys==nil and why=='standard control unavailable: IA_Toggle')
profile.valid=false
keys,why=Keys.resolve(e,'IA_Toggle')
assert(keys==nil and why=='key profile unavailable: IA_Toggle')
profile.valid=true
local each=e.each
e.each=function() return false end
keys,why=Keys.resolve(e,'IA_Toggle')
assert(keys==nil and why=='key profile could not be read: IA_Toggle')
e.each=each
print('PASS keys come from action and mapping-name entries, keyboard only')
