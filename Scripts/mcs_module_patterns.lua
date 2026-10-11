-- Purpose clues, evaluated separately from catalog identity and manifest categories.
local Registry=require('mcs_mod_registry')
local Taxonomy=Registry.taxonomy
local M={version=1}
-- Exact domain clues provide tentative categories; setup UI and private helpers do not.
local rules={
    {id='action.damage',purpose='action',categories={'combat'},terms={'ApplyDamage','AttackDamage','ParryWindow','AbilityCooldown','StaminaCost'}},
    {id='progression.skills',purpose='progression',categories={'skills'},terms={'SkillTimeCost','PerkTimeCost','ExperienceMultiplier','PerkPointCost'}},
    {id='items.consumables',purpose='items',categories={'consumables'},terms={'ConsumeItem','PotionEffect','FoodEffect'}},
    {id='gear.equipment',purpose='gear',categories={'gear'},terms={'EquipItem','EquippedWeapon','WeaponDurability','ArmorRating','ArmourRating'}},
    {id='visuals.exposure',purpose='visuals',categories={'filters'},terms={'AutoExposureBias','PostProcessSettings','PostProcessVolume'}},
    {id='visuals.effects',purpose='visuals',categories={'effects'},terms={'NightVision','BloomIntensity','VignetteIntensity'}},
    {id='movement.walk',purpose='movement',categories={'movement'},terms={'Player.Input.Walk','Debug_GE_ForceWalk','MaxWalkSpeed'}},
    {id='movement.travel',purpose='movement',categories={'movement'},terms={'FastTravel','TeleportTo','TravelRestriction'}},
    {id='interface.hud',purpose='interface',categories={'features','layout'},terms={'AttackDirectionIndicator','QuickslotWheel','HUDWarning','CompassMarker','player.quickslots','incoming attack direction'}},
    {id='economy.crafting',purpose='economy',categories={'economy'},terms={'CraftingCost','MerchantPriceMultiplier','InventoryCapacity'}},
    {id='survival.needs',purpose='survival',categories={'survival'},terms={'HungerRate','ThirstRate','FatigueRate'}},
    {id='behaviour.relationships',purpose='behaviour',categories={'social'},terms={'RelationshipGain','CompanionCommand','NPCWorkSchedule'}},
    {id='characters.identity',purpose='characters',categories={'bodies','faces'},terms={'NPCCharacterAppearance','PlayerBodyMesh'}},
    {id='world.locations',purpose='world',categories={'locations'},terms={'TerrainHeightmap','WorldLocationReplacement'}},
    {id='quests.story',purpose='world',categories={'quests'},terms={'QuestDialogueReplacement','QuestRewardOverride'}},
    {id='transport.mounts',purpose='characters',categories={'transport'},terms={'MountSaddleMesh','VehicleSpecification'}},
    {id='appearance.assets',purpose='appearance',categories={'models','textures','clothing'},terms={'TextureReplacement','CosmeticAnimation','ClothingMeshReplacement'}},
    {id='audio.sound',purpose='audio',categories={},termCategories={SoundBankReplacement='sounds',MusicTrackReplacement='music',VoicePackReplacement='voices'},terms={'SoundBankReplacement','MusicTrackReplacement','VoicePackReplacement'}},
    {id='camera.view',purpose='camera',categories={'camera'},terms={'CameraFieldOfView','PhotoModeCamera','FirstPersonCameraOffset'}},
    {id='performance.engine',purpose='performance',categories={'performance'},terms={'FrameRateLimitOverride','ShaderCacheOptimization'}},
    {id='translations.language',purpose='translations',categories={'translations'},terms={'LocalizationReplacement','LanguagePack'}}
}
M.rules=rules
local ignored={['dmm_api.lua']=true,['UE4SSDawnwalkerSettings.lua']=true,
    ['SettingsStore.lua']=true,['SettingsUpgrade.lua']=true}
local function contains(text,term)
    local start=1
    while true do
        local a,b=text:find(term,start,true);if not a then return false end
        -- Literal object paths are useful too; only identifier continuations are excluded.
        local left=a>1 and text:sub(a-1,a-1) or ''
        local right=text:sub(b+1,b+1)
        if not left:match('[%w_]') and not right:match('[%w_]') then return true end
        start=b+1
    end
end
function M.scan(folder,files,read)
    read=read or Registry.read
    local hits,foundCategories={},{};local sourceCount=0
    local ordered={};for _,entry in ipairs(files) do ordered[#ordered+1]=entry end
    table.sort(ordered,function(a,b)
        return (type(a)=='table' and a.relative_path or a)<(type(b)=='table' and b.relative_path or b)
    end)
    for _,entry in ipairs(ordered) do
        local path=type(entry)=='table' and entry.relative_path or entry
        -- A mod's own backup copies of its code are not evidence of what it does.
        if Registry.safePath(path) and not path:lower():find('backup',1,true)
            and not (type(entry)=='table' and entry.is_symlink) then
            local name=path:match('([^/\\]+)$')
            if path:lower():match('%.lua$') and not ignored[name] and not path:find('/vendor/',1,true) and not path:match('^Scripts/mcs_') then
                local text=assert(read(folder..'/'..path),'unreadable source: '..path)
                sourceCount=sourceCount+1
                -- Comments and strings may contain clues: report presence, never execution.
                for _,rule in ipairs(rules) do
                    local terms={}
                    for _,term in ipairs(rule.terms) do if contains(text,term) then terms[#terms+1]=term end end
                    if #terms>0 then
                        hits[#hits+1]={rule=rule.id,purpose=rule.purpose,file=path,terms=terms}
                        -- One vote per rule and category, regardless of repetitions/files.
                        for _,term in ipairs(terms) do
                            local category=rule.termCategories and rule.termCategories[term]
                            if category then foundCategories[category]=true end
                        end
                        for _,category in ipairs(rule.categories) do foundCategories[category]=true end
                    end
                end
            end
        end
    end
    local raw={};for id in pairs(foundCategories) do raw[#raw+1]=id end
    local categoriesOk,categories=pcall(Taxonomy.categories,Taxonomy,raw)
    if #raw==0 or not categoriesOk then categories={} end
    local reason=sourceCount==0 and 'no_source' or #categories==0 and (#raw==0 and 'no_pattern' or 'ambiguous') or 'pattern'
    local classified=#categories>0
    local purpose=classified and #categories==1 and categories[1] or nil
    return {category=purpose or 'other',categories=classified and categories or {'other'},purpose=purpose,reason=reason,
        classified=classified,source_files=sourceCount,evidence=hits,version=2}
end
return M
