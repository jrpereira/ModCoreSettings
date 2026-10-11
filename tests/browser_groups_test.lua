package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Groups=require('browser_groups')
local Tax=require('mcs_taxonomy').loadLua('data/module_categories.lua')

local function ids(list)
    local out={}
    for n,provider in ipairs(list) do out[n]=provider.id end
    return table.concat(out,',')
end
local function expect(list,wanted,message)
    assert(ids(list)==wanted,(message or 'order')..': '..ids(list)..' ~= '..wanted)
end

-- Without a taxonomy, mods sharing a mod.json group form a collection and mods sharing an
-- author an author group; groups of one join the plain list. Groups follow the load order
-- of their first mod. A child page follows its parent; mods without settings fold into a
-- final entry. Every mod follows the same rules: there is no ModCore group of its own.
local providers={
    {id='Other',name='Other',author='Solo'},
    {id='ModCoreControls',name='Controls',mcListGroup='ModCore'},
    {id='Bob.one',name='Bob One',author='Bob'},
    {id='ModCoreSettings',name='Settings',mcListGroup='ModCore'},
    {id='Bob.two',name='Bob Two',author=' Bob '},
    {id='Declared',name='Declared',author='Ann',mcListGroup='alpha'},
    {id='Declared.child',name='Child',mcBrowserLevel=4},
    {id='Quiet',name='Quiet',mcListGroup='alpha',noSettings=true},
    {id='Detected',name='Folder',detectedKind='ue4ss',noSettings=true,author='Unknown'},
}
Groups.arrange(providers)
local listed='ModCore.browser.group.list:ModCore,ModCoreControls,ModCoreSettings,'
    ..'ModCore.browser.group.list:Bob,Bob.one,Bob.two,'
    ..'ModCore.browser.group.list:alpha,Declared,Declared.child,Quiet,ModCore.browser.group.list:alpha.more,'
    ..'ModCore.browser.group.various,Other,Detected,ModCore.browser.group.various.more'
expect(providers,listed)
local byId={};for _,provider in ipairs(providers) do byId[provider.id]=provider end
local modcore=byId['ModCore.browser.group.list:ModCore']
assert(modcore.name=='ModCore' and modcore.mcBrowserKind=='Collection' and modcore.mcBrowserIcon=='⁂'
    and modcore.mcBrowserHeading and modcore.noSettings,'a shared mod.json group is a collection')
assert(byId['ModCore.browser.group.list:Bob'].mcBrowserKind=='Author','a shared author is an author group')
assert(byId.ModCoreControls.mcBrowserLine=='cell' and byId['Bob.one'].mcBrowserLine=='cell'
    and byId['Declared.child'].mcBrowserLine=='cell' and modcore.mcBrowserColumns==2
    and byId['ModCore.browser.group.list:Bob'].mcBrowserColumns==2,'every group is a two-column grid')
local function foldOf(list,id)
    for index,provider in ipairs(list) do if provider.id==id then return list.mcFoldedAt[index] end end
end
assert(foldOf(providers,'Quiet')=='list:alpha' and foldOf(providers,'Detected')=='various'
    and not foldOf(providers,'Declared'),'mods without settings fold')
local more=byId['ModCore.browser.group.list:alpha.more']
assert(more.mcBrowserMore=='list:alpha' and more.name=='and 1 more with no settings' and not more.noSettings
    and more.mcBrowserLine=='cell','the folded entry closes its group, filling a grid place like a mod')
assert(byId['ModCore.browser.group.various'].name=='Various Authors' and providers.mcModuleCount==8)
Groups.arrange(providers)
expect(providers,listed,'arranging again is stable')
local single={{id='Other',name='Other'}}
Groups.arrange(single)
expect(single,'ModCore.browser.group.various,Other')
local flat={{id='A',name='A',author='X'},{id='B',name='B',author='X'}}
Groups.arrange(flat,nil,nil,{groupModules=false})
expect(flat,'A,B','without grouping the list is plain')
assert(flat[1].mcBrowserLine=='row' and flat[2].mcBrowserLine=='row','an ungrouped list is one mod per line')
-- Ungrouped, mods sort by name, ignoring case, whatever order DMM found them in; a
-- page listed under another stays with it.
local unsorted={{id='z',name='zeta'},{id='b',name='Beta'},{id='b.child',name='Aardvark',mcBrowserLevel=4},
    {id='a',name='alpha'},{id='q',name='Quiet',noSettings=true},{id='c',name='Gamma',path='/Mods/2_G/mod_settings.ini'}}
Groups.arrange(unsorted,nil,nil,{groupModules=false})
expect(unsorted,'a,b,b.child,c,z,q,ModCore.browser.group.plain.more','ungrouped mods sort by name')
-- Load order: by folder name, as UE4SS starts them; pages without a folder first.
local folders={{id='p',name='Page'},{id='m9',name='Alpha',mcFolder='9_Alpha'},{id='m1',name='Zed',mcFolder='1_Zed'}}
Groups.arrange(folders,nil,nil,{groupModules=false,loadOrder=true})
expect(folders,'p,m1,m9','load order follows the folders')
assert(folders[1].mcLoadIndex==nil and folders[2].mcLoadIndex==1 and folders[3].mcLoadIndex==2,
    'mods are numbered in load order; a page without a folder is not loaded, so not numbered')
local quiet={{id='q',name='Quiet',mcFolder='1_Q',noSettings=true},{id='s',name='Set',mcFolder='2_S'}}
Groups.arrange(quiet,nil,nil,{groupModules=false,loadOrder=true})
expect(quiet,'s,q,ModCore.browser.group.plain.more','in load order mods without settings still fold')
assert(quiet[1].mcLoadIndex==2 and quiet[2].mcLoadIndex==1,'each keeps its load-order number, so shown numbers skip')
Groups.arrange(quiet,nil,nil,{groupModules=false})
assert(quiet[1].mcLoadIndex==nil,'numbers belong to load order only')
print('PASS mods group by collection or author, with no ModCore special case')

-- A mod folder's mod.json gives its preferred group, settings, identity and dependencies.
local manifests={['Mods/Grouped/mod.json']='{"id":"G","name":"Grouped Mod","author":"Ann","version":"2.0",'
        ..'"preferred":"ModCore","icon":"⟴","dependencies":[{"id":"ModCoreSettings","name":"MCS","version":"9"},'
        ..'{"id":"Other"}]}',
    ['Mods/Quiet/mod.json']='{"id":"Q","settings": false}',
    ['Mods/Escaped/mod.json']='{"dependencies":[{"id":"X"}],"name":"The \\"Quoted\\" Mod \\u2014 Two"}'}
local function openManifest(path)
    local content=manifests[path]
    return content and {read=function() return content end,close=function() end} or nil
end
local folderManifest=Groups.folderManifest('Mods/',openManifest)
local grouped=folderManifest('Grouped')
assert(grouped.preferred=='ModCore' and grouped.settings==nil and grouped.name=='Grouped Mod' and grouped.version=='2.0'
    and grouped.icon=='⟴' and grouped.requires.ModCoreSettings and grouped.requires.Other
    and folderManifest('Quiet').settings==false and folderManifest('Quiet').preferred==nil
    and next(folderManifest('Missing'))==nil and not pcall(folderManifest,'../x'))
assert(folderManifest('Escaped').name=='The "Quoted" Mod \u{2014} Two' and folderManifest('Escaped').requires.X,
    'mod.json is decoded as JSON: escapes and key order do not matter')
local folders={
    {id='detected:grouped',name='Grouped',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='detected:quiet',name='Quiet',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='MCT.module.Grouped',name='Grouped',author='ModCoreTemplates',mcContribution='MCT',
        mcFolder='Grouped',mcModuleEntry=true,choices={{id='x'}}},
    {id='MCT.extra',name='Extra',author='ModCoreTemplates',mcContribution='MCT',mcFolder='Quiet',choices={{id='y'}}},
}
Groups.arrange(folders,nil,nil,{folderManifest=folderManifest,
    folderVersion=function(folder) return folder=='Quiet' and '1.0.12' or nil end})
byId={};for _,provider in ipairs(folders) do byId[provider.id]=provider end
assert(byId['detected:grouped'].name=='Grouped Mod' and byId['detected:grouped'].author=='Ann'
    and byId['detected:grouped'].version=='2.0' and byId['detected:grouped'].mcBrowserIcon=='⟴',
    'a detected mod takes its folder identity')
assert(byId['detected:quiet'].mcNoSettingsDeclared and byId['detected:quiet'].version=='1.0.12'
    and byId['detected:quiet'].description=='Quiet has no settings to change.')
assert(byId['MCT.module.Grouped'].name=='Grouped Mod' and byId['MCT.module.Grouped'].version=='2.0',
    'a contributed page standing in for a mod takes its folder identity')
assert(byId['MCT.extra'].name=='Extra' and byId['MCT.extra'].author=='ModCoreTemplates',
    'a page that does not stand in for a mod keeps its own')
print('PASS mod.json gives each folder its group, identity and dependencies')

-- MCS's own page carries the index tabs: Errors and Developer Tools. Tool pages stay among the
-- providers so links open them, but are not listed while the tabs reach them.
local host='[Mod]\nId=ModCoreSettings\n\n[Setting.MCS_Page]\nId=MCS_Page\nType=picker\n'
local reads=0
local function read(path) reads=reads+1;assert(path=='/mods/1_ModCore_Settings/mod_settings.ini');return host end
local parsed
local function parse(manifest) parsed=manifest;return {{id='MCS_Page'},{id='row'}} end
local dependants={['Mods/2_Controls/mod.json']='{"name":"ModCore Controls","dependencies":[{"id":"ModCoreSettings"}]}',
    ['Mods/9_Fangdango/mod.json']='{"name":"Quickslot Fangdango","dependencies":[{"id":"ModCoreSettings"}]}',
    ['Mods/7_Unrelated/mod.json']='{"name":"Unrelated"}'}
local folderFields=Groups.folderManifest('Mods/',function(path)
    local content=dependants[path]
    return content and {read=function() return content end,close=function() end} or nil
end)
local indexed={
    {id='ModCoreSettings',name='Settings',path='/mods/1_ModCore_Settings/mod_settings.ini',version='1.0.2'},
    {id='ModCoreControls',name='ModCore Controls',path='/mods/2_Controls/mod_settings.ini',version='v1.0.3'},
    {id='detected:fangdango',name='9_Fangdango',detectedKind='ue4ss',noSettings=true},
    {id='Unrelated',name='Unrelated',path='/mods/7_Unrelated/mod_settings.ini'},
    {id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'},
}
Groups.arrange(indexed,parse,nil,{folderManifest=folderFields,read=read,pageVersions={}})
local mcs=indexed[1].id=='ModCoreSettings' and indexed[1]
for _,provider in ipairs(indexed) do if provider.id=='ModCoreSettings' then mcs=provider end end
assert(mcs.mcManifest==parsed and mcs.settingsCount==2 and mcs.choicesLoaded and not mcs.deferred
    and mcs.mcBaseManifest==host and mcs.mcManifest:sub(1,#host-1)==host:sub(1,-2),'the host page gains the tabs')
local function at(text) return assert(parsed:find(text,1,true),text) end
assert(not parsed:find('Installed',1,true) and not parsed:find('ModCore Controls',1,true),
    'there is no Installed tab')
assert(at('[Category.Errors]\nVisibleWhen=MCS_Page\nVisibleValues=4\nmcHeading=0\n') and at('mcText=errors'),
    'the Errors tab shows the errors text source')
assert(at('[Category.Developer Tools]\nVisibleWhen=MCS_Page\nVisibleValues=5\n')<at('Label=Sounds Explorer')
    and at('mcLinkPage=ModCoreDevTools.sounds'),'Developer Tools lists the tool pages')
local tool
for _,provider in ipairs(indexed) do if provider.id=='ModCoreDevTools.sounds' then tool=provider end end
assert(tool.mcBrowserHidden and indexed[#indexed]==tool,'tool pages stay listed last, hidden')
Groups.arrange(indexed,parse,nil,{folderManifest=folderFields,read=read})
assert(reads==1 and select(2,mcs.mcManifest:gsub('%[Category%.Errors%]',''))==1,
    'the base manifest is read once and the tabs are never appended twice')
local failures={}
local broken={{id='ModCoreSettings',name='Settings',path='/x'},{id='T',name='Tool',mcBrowserGroup='tool'}}
Groups.arrange(broken,function() error('bad manifest') end,function(event) failures[#failures+1]=event end,
    {read=function() return host end})
assert(failures[1]=='BROWSER_INDEX_FAILED' and not broken[#broken].mcBrowserHidden,
    'without the tabs a tool page is listed so it stays reachable')
print('PASS MCS\'s own page carries the Errors and Developer Tools tabs')

-- With the taxonomy, a mod is listed under each top category its categories belong to,
-- in load order (folder name order, keeping 0_ ... 9_ in sequence). Collections follow
-- the top categories, in the load order of their first mod; a preferred category is
-- declared first.
local register={
    Gear=Tax:entry({categories={'gear'},tags={}}),
    Audio=Tax:entry({categories={'sounds'},tags={}}),
    Both=Tax:entry({categories={'gear','interface'},tags={}}),
    Core1=Tax:entry({categories={'frameworks'},tags={},preferred='ModCore'}),
    Core2=Tax:entry({categories={'tools'},tags={},preferred='ModCore'}),
    Ann=Tax:entry({categories={'tools'},tags={},preferred='Ann'}),
    Ann2=Tax:entry({categories={'tools'},tags={},preferred='Ann'}),
    Lone=Tax:entry({categories={'tools'},tags={},preferred='Lonely'}),
    Prefers=Tax:entry({categories={'sounds'},tags={},preferred='frameworks'}),
}
local function mod(id,settings) return {id=id,name=id,mcFolder=id,noSettings=not settings} end
local taxed={mod('Both',true),mod('Audio',true),mod('Gear',true),mod('Core1',true),mod('Ann',true),
    mod('Core2',true),mod('Ann2',true),mod('Lone',true),mod('Prefers',true)}
for _,provider in ipairs(taxed) do provider.choices={{id='x'}} end
local authors={Ann='Ann',Ann2='Ann'}
Groups.arrange(taxed,nil,nil,{taxonomy=Tax,categoryRegister=register,preferredMinimum=2,
    folderManifest=function(folder) return {author=authors[folder]} end})
expect(taxed,'ModCore.browser.group.section:content,Both,Gear,'
    ..'ModCore.browser.group.section:presentation,Audio,Both,Prefers,'
    ..'ModCore.browser.group.section:auxiliary,Lone,Prefers,'
    ..'ModCore.browser.group.preferred:Ann,Ann,Ann2,'
    ..'ModCore.browser.group.preferred:ModCore,Core1,Core2','top categories, then collections')
byId={};for _,provider in ipairs(taxed) do byId[provider.id]=provider end
local content=byId['ModCore.browser.group.section:content']
assert(content.mcBrowserKind=='Content' and content.mcBrowserIcon=='◆'
    and content.name==Tax.definitions.items.description,'a section heading names its top-level branches present')
local presentation=byId['ModCore.browser.group.section:presentation']
assert(presentation.name==Tax.definitions.interface.description..' and '..Tax.definitions.media.description,
    'titles join the categories present in taxonomy order')
assert(byId['ModCore.browser.group.preferred:ModCore'].mcBrowserKind=='Collection'
    and byId['ModCore.browser.group.preferred:Ann'].mcBrowserKind=='Author'
    and byId['ModCore.browser.group.preferred:Ann'].mcBrowserIcon=='⁂','collections and author groups')
assert(taxed.mcModuleCount==9,'module totals count distinct folders')
-- DMM lists pages by name; a collection keeps its mods' load order (0_ ... 9_).
local numbered={mod('Controls',true),mod('Fangdango',true),mod('Settings',true)}
numbered[1].mcFolder,numbered[2].mcFolder,numbered[3].mcFolder='2_MC_Controls','9_MC_Fangdango','1_MC_Settings'
for _,provider in ipairs(numbered) do provider.choices={{id='x'}} end
local collected={}
for _,provider in ipairs(numbered) do
    collected[provider.mcFolder]=Tax:entry({categories={'frameworks'},tags={},preferred='ModCore'})
end
Groups.arrange(numbered,nil,nil,{taxonomy=Tax,categoryRegister=collected,preferredMinimum=2})
expect(numbered,'ModCore.browser.group.preferred:ModCore,Settings,Controls,Fangdango',
    'a collection lists its mods in load order')
assert(byId.Gear.mcBrowserLabel==nil,'mod rows show their name without an icon')
print('PASS top categories walk categories in order, then collections; a preferred category counts first')

-- DMM shows each row of its mod list and links its navigation itself.
local function widget()
    local w={visibility=0}
    function w:SetVisibility(v) self.visibility=v end
    function w:SetNavigationRuleExplicit(rule,target) self['rule'..rule]=target end
    function w:SetNavigationRuleBase(rule) self['rule'..rule]='base' end
    function w:SetRenderOpacity(v) self.opacity=v end
    function w:SetBackgroundColor(color) self.background=color.A end
    return w
end
local function browserPages(withHint)
    local pages={}
    pages.build=function(_,items)
        local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end},opened={},
            filterLabel=widget(),hint=withHint and widget() or nil}
        for index in ipairs(items) do page.allRows[index]={providerIndex=index,wrapper=widget(),widget=widget()} end
        function page:tickFilter() return true end
        function page:setFilter(compatibleOnly)
            self.compatibleOnly=compatibleOnly
            self.rows={}
            for _,row in ipairs(self.allRows) do
                local visible=not compatibleOnly or not items[row.providerIndex].noSettings
                row.wrapper:SetVisibility(visible and 0 or 1)
                if visible then self.rows[#self.rows+1]=row end
            end
        end
        function page:showDetail(index) self.opened[#self.opened+1]=items[self.rows[index].providerIndex].id end
        function page:refreshHint() self.hintCount=#self.rows end
        function page:highlight(index)
            for _,row in ipairs(self.allRows) do row.widget:SetBackgroundColor({A=self.rows[index]==row and 1 or 0}) end
        end
        function page:describe(index) self.describedBy=index end
        page:setFilter(false)
        return page
    end
    return pages
end
-- Mods without settings stay folded until the group's last entry is selected.
local folding=browserPages()
assert(Groups.install(folding) and not Groups.install(folding))
local browsingItems={{id='A',name='A',author='X',choices={{id='a'}}},{id='B',name='B',author='X',noSettings=true},
    {id='C',name='C',author='X',noSettings=true}}
local browsing=folding.build({},browsingItems,nil,{})
local function shown(page)
    local out={}
    for _,row in ipairs(page.rows) do out[#out+1]=row end
    return #out
end
assert(shown(browsing)==3 and browsing.allRows[3].wrapper.visibility==1 and browsing.allRows[4].wrapper.visibility==1
    and browsing.allRows[5].wrapper.visibility==0,'a heading, the mod with settings and the folded entry')
assert(browsing.allRows[1].widget.rule3==browsing.allRows[2].widget,'navigation links the shown rows')
browsing:showDetail(3)
assert(#browsing.opened==0 and shown(browsing)==4 and browsing.allRows[3].wrapper.visibility==0
    and browsing.allRows[5].wrapper.visibility==1,'selecting the folded entry lists the mods and opens nothing')
browsing:showDetail(2)
assert(browsing.opened[1]=='A','other entries open their page')
browsing:setFilter(true)
assert(shown(browsing)==4 and not browsing.compatibleOnly,'there is no compatible-only filter: every module stays listed')
assert(browsing:tickFilter()==false,'the filter button does nothing')
-- Mods without settings are dimmed and named without DMM's notice; hovering only
-- brightens them. The hint counts module folders, not menu entries.
browsing:setFilter(false)
local function rowOf(page,id)
    for index,row in ipairs(page.rows) do
        if browsingItems[row.providerIndex].id==id then return row,index end
    end
end
assert(browsing.hintCount==3,'three mod folders under one heading')
-- With DMM's page api the hint is the count alone, without DMM's input help.
local hinted=browserPages(true)
Groups.install(hinted)
local hintTexts={}
local hintApi={setText=function(target,text) hintTexts[target]=text end,
    t=function(copy,values) return (copy:gsub('{([%w_]+)}',function(key) return tostring(values[key]) end)) end}
local hintPage=hinted.build({},{{id='A',name='A',author='X',choices={{id='a'}}},{id='B',name='B',author='X',choices={{id='b'}}}},nil,hintApi)
hintPage:refreshHint()
assert(hintTexts[hintPage.hint]=='2 mods' and hintPage.hintCount==nil,'the hint is the count alone')
local quietPage=hinted.build({},{{id='A',name='A',author='X',choices={{id='a'}}},{id='B',name='B',author='X',noSettings=true},
    {id='C',name='C',author='X',noSettings=true}},nil,hintApi)
quietPage:refreshHint()
assert(hintTexts[quietPage.hint]=='3 mods (2 with no settings)',hintTexts[quietPage.hint])
-- Links to ModCore's own pages sit right of the title and open their page when clicked.
do
    local function node(name)
        local n={name=name,children={}}
        function n:GetParent() return self.parent end
        local function slot()
            local sl={}
            function sl:SetPadding(p) sl.padding=p end
            function sl:SetHorizontalAlignment(h) sl.horizontal=h end
            function sl:SetVerticalAlignment(v) sl.vertical=v end
            return sl
        end
        function n:AddChild(child) child.parent=self;self.children[#self.children+1]=child;child.Slot=slot();return child.Slot end
        function n:SetContent(child) self.children={};return self:AddChild(child) end
        return n
    end
    local pressedNow,hoveredNow={},{}
    local linkApi={setText=function() end,t=hintApi.t,construct=function(class) return node(class) end,
        button=function(_,text)
            local b=node('button');b.text=text
            local l=node('label');b:AddChild(l)
            function b:IsHovered() return hoveredNow[self.text]==true end
            function b:IsPressed() return pressedNow[self.text]==true end
            return b,l
        end}
    local title=node('filterButton')
    local header=node('header');header:AddChild(title)
    local items={{id='ModCoreControls',name='ModCore Controls',author='X',choices={{id='c'}}},
        {id='Other',name='Other',author='Y',choices={{id='o'}}}}
    -- The page DMM builds carries its title box before the wrapper runs.
    local base=browserPages(true)
    local baseBuild=base.build
    base.build=function(...)
        local made=baseBuild(...)
        made.filterButton=title
        return made
    end
    Groups.install(base)
    local pageWithTitle=base.build({},items,nil,linkApi)
    local overlay=header.children[1]
    assert(overlay and overlay.name=='/Script/UMG.Overlay' and overlay.children[1]==title,'the title stays, left')
    local line=overlay.children[2]
    assert(line.Slot.horizontal==3 and #line.children==1 and line.children[1].text=='controls',
        'one link per listed ModCore page, right of the title')
    local function released(widget,previous,pointer)
        local pressed=widget:IsPressed()
        return previous and not pressed,pressed,pointer
    end
    assert(pageWithTitle:tickFilter(released)==false)
    pressedNow.controls=true;assert(pageWithTitle:tickFilter(released)==false)
    pressedNow.controls=false;assert(pageWithTitle:tickFilter(released)==true,'a click is handled')
    assert(pageWithTitle.opened[1]=='ModCoreControls','the link opens its page')
end
local rowA,indexA=rowOf(browsing,'A')
local rowB,indexB=rowOf(browsing,'B')
assert(rowB.widget.opacity==0.5 and rowA.widget.opacity==nil,'a mod without settings is dimmed')
assert(browsingItems[rowB.providerIndex].mcBrowserLabel=='B','no "No settings available" notice')
browsing:highlight(indexB)
assert(rowB.widget.opacity==0.75 and rowB.widget.background==0,'hovering brightens it without the highlight pattern')
browsing.selected=indexB;browsing:highlight(indexB)
assert(rowB.widget.opacity==0.7,'a keyboard-selected mod without settings')
browsing.selected=nil;browsing:highlight(indexA)
assert(rowA.widget.background==1 and rowB.widget.opacity==0.5,'a mod with settings keeps the full highlight')
browsing:describe(indexB)
assert(rowB.widget.opacity==0.7 and browsing.describedBy==indexB,'the mod described stays selected')
browsing:describe(nil)
-- The folded entry is quiet too: dimmed, brighter on hover, never highlighted.
local foldingPage=browserPages()
Groups.install(foldingPage)
local foldItems={{id='P',name='P',author='Y',choices={{id='p'}}},{id='Q',name='Q',author='Y',noSettings=true}}
local foldPage=foldingPage.build({},foldItems,nil,{})
local moreRow,moreIndex
for index,row in ipairs(foldPage.rows) do
    if foldItems[row.providerIndex].mcBrowserMore then moreRow,moreIndex=row,index end
end
assert(moreRow and moreRow.widget.opacity==0.5,'the folded entry is dimmed')
foldPage.selected=moreIndex;foldPage:highlight(moreIndex)
assert(moreRow.widget.opacity==0.75 and moreRow.widget.background==0,'hovering the folded entry only brightens it')
-- The index page is titled Modules and lists MCS's modules: active module folders,
-- MCS's own page and tool pages. Disabled folders and packages are dropped.
local modulePages=browserPages()
assert(Groups.install(modulePages,nil,nil,nil,nil,function()
    return {categoryRegister={Active=Tax:entry({categories={'tools'},tags={}})}}
end))
local moduleItems={{id='Active',name='Active',mcFolder='Active',choices={{id='a'}}},
    {id='Off',name='Off',mcFolder='Off',choices={{id='o'}}},
    {id='Package',name='Package',noSettings=true,detectedKind='pak'},
    {id='ModCoreSettings',name='Settings',path='/Mods/1_ModCore_Settings/mod_settings.ini',choices={{id='s'}}},
    {id='Tool',name='Tool',mcBrowserGroup='tool',choices={{id='t'}}}}
local titled=modulePages.build({},moduleItems,nil,{setText=function(widget,text) widget.text=text end})
local listedIds={}
for _,provider in ipairs(moduleItems) do listedIds[provider.id]=true end
assert(listedIds.Active and listedIds.ModCoreSettings and listedIds.Tool and not listedIds.Off
    and not listedIds.Package,'only active modules, MCS and tools are listed')
assert(titled.filterLabel.text=='Modules','the filter label is the page title')
local unchanged={{id='Off',name='Off',mcFolder='Off',choices={{id='o'}}}}
Groups.modules(unchanged,nil);Groups.modules(unchanged,{})
assert(#unchanged==1,'without a register the list is left as DMM built it')
-- A mod without settings in two groups unfolds only where its group's entry is chosen.
local twicePages=browserPages()
Groups.install(twicePages,nil,nil,nil,nil,function()
    return {taxonomy=Tax,categoryRegister={Twice=Tax:entry({categories={'gear','layout'},tags={}}),
        Kit=Tax:entry({categories={'gear'},tags={}}),Hud=Tax:entry({categories={'layout'},tags={}})}}
end)
local twiceItems={{id='Kit',name='Kit',mcFolder='Kit',choices={{id='k'}}},
    {id='Hud',name='Hud',mcFolder='Hud',choices={{id='h'}}},
    {id='Twice',name='Twice',mcFolder='Twice',noSettings=true}}
local twice=twicePages.build({},twiceItems,nil,{})
local placements,mores={},{}
for _,row in ipairs(twice.allRows) do
    local provider=twiceItems[row.providerIndex]
    if provider.id=='Twice' then placements[#placements+1]=row end
    if provider.mcBrowserMore then mores[#mores+1]=row end
end
assert(#placements==2 and #mores==2,'listed and folded in both groups')
local first
for index,row in ipairs(twice.rows) do if row==mores[1] then first=index end end
twice:showDetail(first)
assert(placements[1].wrapper.visibility==0 and placements[2].wrapper.visibility==1,
    'only the chosen group shows its folded mod')
print('PASS the folded entry lists mods without settings and opens nothing')

-- Taxonomy filtering combines independent category and tag sets.
local filterPages={build=function(_,items)
    local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end}}
    for index in ipairs(items) do page.allRows[index]={providerIndex=index,wrapper=widget(),widget=widget()} end
    function page:setFilter(only) self.compatibleOnly=only;self.rows=self.allRows end
    function page:refreshHint() end
    return page
end}
local multi={id='Multi',name='Multi',mcFolder='Multi',choices={{id='same-setting'}}}
local solo={id='Single',name='Single',mcFolder='Single',choices={{id='s'}}}
local entries={Multi=Tax:entry({categories={'gear','models'},tags={'fix'},icon='♞'}),
    Single=Tax:entry({categories={'sounds'},tags={}})}
Groups.install(filterPages,nil,nil,nil,nil,function()
    return {taxonomy=Tax,categoryRegister=entries,preferredMinimum=0}
end)
local placements={multi,solo}
local filtered=filterPages.build({},placements,nil,{})
assert(#filtered.rows==5 and filtered.mcModuleCount==2 and multi.mcBrowserLabel==nil)
filtered:setTagFilter({'fix'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({'sounds'},'any');assert(#filtered.rows==0 and filtered.empty.visibility==0)
filtered:setTagFilter({},'any');assert(#filtered.rows==2)
filtered:setCategoryFilter({'gear','models'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({},'any');filtered:setFilter(false);assert(#filtered.rows==5)
assert(not pcall(filtered.setCategoryFilter,filtered,{'vehicles'},'any'))
print('PASS taxonomy row filtering combines independent category/tag sets')

-- Through DMM's real parser the host page's tabs parse and open without a config file.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP index tabs parse: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
assert(require('navigation').install(Choices))
local Presentation=require('presentation')
-- MCS's page is contributed menu data, compiled as menu_pages compiles it.
local Contributions=require('menu_contributions')
local mcsMenu=require('mcs_page')
Contributions.validate('ModCoreSettings',{pages={{id='ModCoreSettings',name='ModCore Settings',
    attach='1_ModCore_Settings',configDirectory='/x',menu=mcsMenu}}})
local base=require('menu_data').manifest(mcsMenu)
assert(base:find('[Category.Listing]\nVisibleWhen=MCS_Page\nVisibleValues=0\n\n',1,true)
    and base:find('Id=SortBy\nLabel=Sort by\nGroup=Listing',1,true),'the Modules tab lists its settings under Listing')
local hostPage={{id='ModCoreSettings',name='Settings',path='/x/mod_settings.ini',mcManifest=base},
    {id='ModCoreControls',name='Controls',path='/m/2_Controls/mod_settings.ini'},
    {id='Tool',name='Sounds Explorer',mcBrowserGroup='tool'}}
Groups.arrange(hostPage,function(manifest) return Presentation.parse(manifest,Choices.parse(manifest)) end,nil,
    {read=function() error('a contributed page is never read from disk') end,folderManifest=folderFields})
local page
for _,provider in ipairs(hostPage) do if provider.id=='ModCoreSettings' then page=provider end end
local items={};for _,item in ipairs(page.choices) do items[item.id]=item end
assert(items.MCS_Page and #items.MCS_Page.values==3 and items.MCS_Page.labels[2]=='Errors'
    and items.MCS_Index_Errors.mcText=='errors' and items.MCS_Index_1.mcLinkPage
    and items.SortBy.file=='config.ini' and items.SortBy.section=='Modules',
    'the tabs parse through DMM beside the page\'s own settings')
print('PASS the index tabs parse through DMM')
