package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Sound=require('mcs_choice_sound')

-- Event paths: under /Game/, the object name added when left out.
assert(Sound.path('/Game/Audio/UI/Play_Click')=='/Game/Audio/UI/Play_Click.Play_Click')
assert(Sound.path(' /Game/Audio/UI/Play_Click.Play_Click ')=='/Game/Audio/UI/Play_Click.Play_Click')
for _,bad in ipairs({'/Script/Engine.Default__GameplayStatics','Game/A','/Game/','/Game//A','/Game/A B',
    '/Game/A/','/Game/A.B.C','/Game/'..('a'):rep(260)}) do
    assert(Sound.path(bad)==nil,bad)
end

local picker={kind='picker',values={0,1,2}}
local sounds=Sound.parse('1:/Game/Audio/One; 2 : none',picker)
assert(sounds[1]=='/Game/Audio/One.One' and sounds[2]==false and sounds[0]==nil,
    'a listed choice has its sound, none silences one, an unlisted choice keeps DMM\'s')
assert(Sound.parse(nil,picker)==nil)
for _,bad in ipairs({'1:/Game/A;1:/Game/B','3:/Game/A','1:','1:/Script/A.B','x:/Game/A','/Game/A'}) do
    assert(not pcall(Sound.parse,bad,picker),bad)
end
assert(not pcall(Sound.parse,'1:none',{kind='toggle',values={0,1}}),'pickers only')
print('PASS mcChoiceSounds parse')

-- The player loads an event once, posts it at the player's character, spaces sounds
-- 0.06 s apart, stops the last sound before the next and reports each path's first failure.
local function object(name) return {name=name,IsValid=function() return true end} end
local posted,stopped,loads,reports,now={},{},0,{},0
local present={}
local wwise=object('wwise')
function wwise:PostEventAtLocation(event,location,rotation,context)
    posted[#posted+1]={event=event.name,x=location.X,context=context.name}
    return 100+#posted
end
local controller=object('controller')
function controller:K2_GetActorLocation() return {X=5,Y=0,Z=0} end
local pawn=object('pawn')
function pawn:K2_GetActorLocation() return {X=9,Y=0,Z=0} end
local statics=object('statics')
local hasPawn=true
function statics:GetPlayerPawn() return hasPawn and pawn or nil end
local engine={
    StaticFindObject=function(name)
        if name=='/Script/AkAudio.Default__AkGameplayStatics' then return wwise end
        if name=='/Script/Engine.Default__GameplayStatics' then return statics end
        local found=present[name]
        if found and not found.ExecuteAction then
            function found:ExecuteAction(action,actor,id,fade,curve)
                stopped[#stopped+1]={event=self.name,action=action,actor=actor,id=id,fade=fade,curve=curve}
                return 1
            end
        end
        return found
    end,
    FindFirstOf=function() return controller end,
    LoadAsset=function(name) loads=loads+1;if name~='/Game/Missing.Missing' then present[name]=object(name) end end,
    clock=function() return now end,
}
local player=Sound.player(engine,function(event,detail) reports[#reports+1]=event..' '..detail end)
player:play('/Game/A.A')
assert(#posted==1 and posted[1].event=='/Game/A.A' and posted[1].x==9 and posted[1].context=='controller' and loads==1)
assert(#stopped==0,'nothing to stop before the first sound')
now=0.03;player:play('/Game/A.A')
assert(#posted==1,'a change within 0.06 s plays nothing')
now=0.1;player:play('/Game/A.A')
assert(#posted==2 and loads==1,'a loaded event is kept')
assert(#stopped==1 and stopped[1].id==101 and stopped[1].action==0 and stopped[1].actor==nil
    and stopped[1].fade==100 and stopped[1].curve==4,'the last sound stops by its playing id, 100 ms linear fade')
now=0.15;player:stop()
assert(#stopped==2 and stopped[2].id==102,'stop() stops the last sound')
player:stop()
assert(#stopped==2,'a stopped sound is not stopped again')
hasPawn=false
now=0.17;player:play('/Game/A.A')
assert(posted[3].x==5,'without a character it plays at the controller')
now=0.25;player:play('/Game/Missing.Missing')
now=0.35;player:play('/Game/Missing.Missing')
assert(#posted==3 and #reports==1 and reports[1]:find('CHOICE_SOUND_FAILED /Game/Missing.Missing',1,true),
    'a missing event is reported once')
print('PASS choice sound player')
