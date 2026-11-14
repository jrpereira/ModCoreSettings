package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local P=require('mcs_module_patterns')
local function scan(text)
    return P.scan('/renamed',{'Scripts/main.lua','Scripts/dmm_api.lua','backup/copy.lua'},function(path)
        assert(path=='/renamed/Scripts/main.lua','excluded source was read');return text
    end)
end
local result=scan('object.AutoExposureBias=2; NightVision()')
assert(result.reason=='pattern' and #result.categories==2
    and result.categories[1]=='effects' and result.categories[2]=='filters' and #result.evidence==2)
result=scan('ApplyDamage(); PotionEffect()')
assert(result.reason=='pattern' and #result.categories==2 and result.categories[1]=='combat' and result.categories[2]=='consumables','features can occupy two categories')
result=scan('local ApplyDamageHelper=1; local MaxWalkSpeedy=2')
assert(result.reason=='no_pattern' and result.categories[1]=='other','substrings do not match')
result=scan('ConsumeItem(); ConsumeItem(); PotionEffect()')
assert(result.reason=='pattern' and #result.categories==1 and result.categories[1]=='consumables' and #result.evidence==1)
result=P.scan('/renamed',{'mod.dll'},function() error('binary should not be read') end)
assert(result.reason=='no_source' and result.categories[1]=='other')
local snapshot={__absolute_path='/mods',Renamed={__files={{__name='enabled.txt'}},Scripts={__files={{__name='main.lua'}}}}}
-- Every active folder scanned, as the offline comparison does.
local Registry=require('mcs_mod_registry')
local live={}
for _,folder in ipairs(Registry.folders(snapshot,'/mods')) do
    live[folder.name]=P.scan(folder.path,folder.files,function() return 'EquipItem()' end)
end
local offline=P.scan('/mods/Renamed',{'Scripts/main.lua'},function() return 'EquipItem()' end)
assert(table.concat(live.Renamed.categories,',')==table.concat(offline.categories,',')
    and live.Renamed.evidence[1].rule==offline.evidence[1].rule,'snapshot and offline scanners use identical rules')
assert(scan('CreateWidget(); AddToViewport(); RegisterConsoleCommandHandler()').reason~='pattern','setup UI and private helpers do not establish categories')
assert(scan('SkillTimeCost=0').categories[1]=='skills')
assert(scan('ApplyDamage(); PotionEffect(); AutoExposureBias=1; LanguagePack()').reason=='ambiguous')
print('PASS multi-category heuristics, learning/action boundaries, setup UI exclusions and binary abstention')
