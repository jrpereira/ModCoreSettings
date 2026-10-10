package.path='Scripts/?.lua;'..package.path
local P=require('mcs_module_patterns')
local function scan(text)
    return P.scan('/renamed',{'Scripts/main.lua','Scripts/dmm_api.lua','backup/copy.lua'},function(path)
        assert(path=='/renamed/Scripts/main.lua','excluded source was read');return text
    end)
end
local result=scan('object.AutoExposureBias=2; NightVision()')
assert(result.category=='other' and result.classified and #result.categories==2
    and result.categories[1]=='effects' and result.categories[2]=='filters' and #result.evidence==2)
result=scan('ApplyDamage(); PotionEffect()')
assert(result.classified and #result.categories==2 and result.categories[1]=='combat' and result.categories[2]=='consumables','features can occupy two categories')
result=scan('local ApplyDamageHelper=1; local MaxWalkSpeedy=2')
assert(not result.classified and result.reason=='no_pattern','substrings do not match')
result=scan('ConsumeItem(); ConsumeItem(); PotionEffect()')
assert(result.category=='consumables' and result.classified and #result.evidence==1)
result=P.scan('/renamed',{'mod.dll'},function() error('binary should not be read') end)
assert(result.reason=='no_source' and not result.classified)
local snapshot={__absolute_path='/mods',Renamed={__files={{__name='enabled.txt'}},Scripts={__files={{__name='main.lua'}}}}}
local live=P.live(snapshot,'/mods',function() return 'EquipItem()' end)
local offline=P.scan('/mods/Renamed',{'Scripts/main.lua'},function() return 'EquipItem()' end)
assert(live.Renamed.category==offline.category and live.Renamed.purpose==offline.purpose
    and live.Renamed.evidence[1].rule==offline.evidence[1].rule,'snapshot and offline scanners use identical rules')
assert(not scan('CreateWidget(); AddToViewport(); RegisterConsoleCommandHandler()').classified,'setup UI and private helpers do not establish categories')
assert(scan('SkillTimeCost=0').categories[1]=='skills')
assert(scan('ApplyDamage(); PotionEffect(); AutoExposureBias=1; LanguagePack()').reason=='ambiguous')
print('PASS multi-category heuristics, learning/action boundaries, setup UI exclusions and binary abstention')
