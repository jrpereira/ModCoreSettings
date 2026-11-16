-- A picker's own sound per choice (mcChoiceSounds): read from its manifest, then played in
-- place of DMM's Change sound when the row changes to that choice.
local M={version=1}

local MAX_PATH=256
-- Changes closer together than this play one sound, as DMM spaces its own.
local SPACING=0.06
-- The fade, in milliseconds, of a choice's sound stopped by the next change.
local STOP_FADE=100
-- Wwise's Stop action and linear fade curve (AkActionOnEventType, AkCurveInterpolation).
local STOP,LINEAR=0,4

local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end

-- Whether a sound is a WAV file's path rather than a game event.
function M.file(text)
    return type(text)=='string' and #text<=1024 and text:lower():match('%.wav$')~=nil
        and not text:find('[;|%c]') and not text:match('^/Game/')
end

-- A sound to play: a Wwise event path under /Game/ ("/Game/A/B" or "/Game/A/B.B"), returned
-- as its full object path, or a WAV file's full path (played through UE4SSLuaSoundBridge),
-- returned as it is. nil for anything else.
function M.path(text)
    text=trim(text)
    if M.file(text) then return text end
    if #text>MAX_PATH or not text:match('^/Game/[%w_/%-]+[%w_]$') and not text:match('^/Game/[%w_/%-]+%.[%w_]+$') then
        return nil
    end
    if text:find('//',1,true) then return nil end
    if text:find('.',1,true) then return text end
    return text..'.'..text:match('([^/]+)$')
end

-- mcChoiceSounds=<value>:<event path>;... on a picker. A value maps to its event path, or
-- to false for "none" (that choice plays no sound); unlisted choices keep DMM's sound.
function M.parse(text,setting)
    if text==nil then return nil end
    assert(setting.kind=='picker','mcChoiceSounds requires a picker')
    local sounds={}
    for entry in (text..';'):gmatch('(.-);') do
        local value,sound=entry:match('^%s*([^:]+):(.+)$')
        value=tonumber(value)
        assert(value and sounds[value]==nil,'invalid mcChoiceSounds')
        local valid=false
        for _,v in ipairs(setting.values) do if v==value then valid=true end end
        assert(valid,'mcChoiceSounds value outside picker choices')
        if trim(sound):lower()=='none' then sounds[value]=false
        else sounds[value]=assert(M.path(sound),'invalid mcChoiceSounds event path') end
    end
    return sounds
end

local function valid(object)
    if object==nil then return false end
    local ok,result=pcall(function() return object:IsValid() end)
    return ok and result==true
end

-- A player of event paths. play(path) first stops the sound it played last, so one
-- choice's sound never runs on under the next; stop() only stops it. engine (optional,
-- for tests) supplies StaticFindObject, FindFirstOf, LoadAsset and clock; the UE4SS
-- globals and os.clock by default (the spacing is shorter than os.time's one-second
-- step). report(event,detail) receives the first failure of each path.
function M.player(engine,report)
    engine=engine or {}
    local find=engine.StaticFindObject or rawget(_G,'StaticFindObject')
    local first=engine.FindFirstOf or rawget(_G,'FindFirstOf')
    local load=engine.LoadAsset or rawget(_G,'LoadAsset')
    local clock=engine.clock or os.clock
    local events,failed,last,playing={},{},nil,nil
    -- WAV files play centred through UE4SSLuaSoundBridge, loaded once each.
    local bridge=engine.SoundBridge or rawget(_G,'UE4SSLuaSoundBridge')
    local files={}
    local function playFile(path)
        assert(bridge,'UE4SSLuaSoundBridge is not installed')
        local sounds=bridge()
        local sound=files[path]
        if not sound or sound.released then
            local why
            sound,why=sounds.Load(path,{max_seconds=10})
            files[path]=assert(sound,tostring(why))
        end
        local id=assert(sound:Play({}),'sound bridge refused the play')
        playing={file=sound,id=id,sounds=sounds}
    end
    local function object(name)
        local found=find(name)
        return valid(found) and found or nil
    end
    local function post(path)
        assert(find and first,'UE4SS unavailable')
        local event=events[path]
        if not valid(event) then
            event=object(path)
            if not event and load then pcall(load,path);event=object(path) end
            events[path]=assert(event,'sound event unavailable')
        end
        local wwise=assert(object('/Script/AkAudio.Default__AkGameplayStatics'),'Wwise unavailable')
        local controller=first('PlayerController')
        assert(valid(controller),'player unavailable')
        -- At the player's character, where the live probes were heard; else at the
        -- controller (the main menu has no character), else at the origin.
        local location={X=0,Y=0,Z=0}
        if not pcall(function()
            local statics=assert(object('/Script/Engine.Default__GameplayStatics'))
            local pawn=statics:GetPlayerPawn(controller,0)
            assert(valid(pawn))
            location=pawn:K2_GetActorLocation()
        end) then pcall(function() location=controller:K2_GetActorLocation() end) end
        local id=wwise:PostEventAtLocation(event,location,{Pitch=0,Yaw=0,Roll=0},controller)
        assert(type(id)=='number' and id~=0,'Wwise returned no playing id')
        playing={event=event,id=id}
    end
    -- Stops the last sound by its playing id, through its event: no actor is needed, and
    -- the game's own sounds go on (checked live, 2026-10-13).
    local function stop()
        local sound=playing
        playing=nil
        if sound and sound.file then pcall(sound.sounds.Stop,sound.id)
        elseif sound and valid(sound.event) then pcall(function() sound.event:ExecuteAction(STOP,nil,sound.id,STOP_FADE,LINEAR) end) end
    end
    return {stop=function() stop() end,play=function(_,path)
        local now=clock()
        if last and now-last<SPACING then return end
        last=now
        stop()
        local ok,why=pcall(M.file(path) and playFile or post,path)
        if ok then failed[path]=nil
        elseif not failed[path] then
            failed[path]=true
            if report then pcall(report,'CHOICE_SOUND_FAILED',path..': '..tostring(why)) end
        end
    end}
end

return M
