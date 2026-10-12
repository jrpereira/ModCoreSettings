package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local C=require('module_categories')
local G=require('browser_groups')
local J=require('mcs_module_json')
local T=require('mcs_taxonomy').loadLua('data/module_categories.lua')
local function entry(categories,tags,preferred)
 return T:entry({categories=categories,tags=tags or {},preferred=preferred,
 reason=categories[1]=='other' and 'insufficient_evidence' or nil})
end
assert(#T:categories({'items','gear','models'})==2,'parents do not consume extra slots')
assert(#T:parents({'gear','items'})==1,'two content selections grant content once')
assert(#T:parents({'gear','models'})==2)
assert(not pcall(T.categories,T,{'visuals'}) and not pcall(T.categories,T,{'vehicles'}),'no aliases')
assert(not pcall(T.categories,T,{'combat','gear','features','tools'}),'four category branches are rejected')
assert(#T:categories({'bodies','faces','textures','hair','eyes','social'})==6,
 'multiple leaf categories across three branches are allowed')
assert(not pcall(T.categories,T,{'gear','gear'}))
assert(not pcall(T.tags,T,{'unstable'}))
local index={schema_version=2,taxonomy_version=T.data.version,modules={
 A=entry({'gear','models'},{'fix'},'Custom'),B=entry({'interface'},{},'Custom')}}
local files={index=J.encode(index),config='[Modules]\nSortBy=1\nPreferredCategoryMinimum=0\n'}
local errors=0
local reader=C.reader('index','config',function(path) return files[path] end,{taxonomy=T,report=function() errors=errors+1 end})
local function providers()
 return {{id='A',name='A',mcFolder='A'},{id='A.child',name='Child',mcBrowserLevel=4,mcFolder='A'},
 {id='B',name='B',mcFolder='B'},{id='U',name='U',mcFolder='Unregistered'}}
end
local options=reader();local list=providers();G.arrange(list,nil,nil,options)
local headings,seen,instances={},{},{}
for _,p in ipairs(list) do
 if p.mcBrowserHeading then headings[#headings+1]=p.mcBrowserKind
 else seen[p.id]=(seen[p.id] or 0)+1;instances[p.id]=instances[p.id] or p;assert(instances[p.id]==p) end
end
assert(table.concat(headings,'|')=='Content|Presentation|Unclassified')
assert(seen.A==2 and seen['A.child']==2 and seen.B==1,'one placement per parent, same provider and settings')
assert(list.mcModuleCount==3,'placements and child pages do not inflate module count')
-- In the Categories view every group is a two-column grid of cells.
for _,p in ipairs(list) do
 if p.mcBrowserHeading then assert(p.mcBrowserColumns==2,'two columns: '..p.name)
 elseif not p.mcBrowserMore then assert(p.mcBrowserLine=='cell','a cell: '..p.id) end
end
local first=#list;G.arrange(list,nil,nil,options);assert(#list==first,'rebuild does not multiply placements')
-- Modules per row sets every group's columns; an unknown value keeps the default.
for _,case in ipairs({{'1',1},{'3',3},{'4',2},{'0',2}}) do
 files.config='[Modules]\nSortBy=1\nModulesPerRow='..case[1]..'\n'
 local chosen=reader();list=providers();G.arrange(list,nil,nil,chosen)
 for _,p in ipairs(list) do
  if p.mcBrowserHeading then assert(p.mcBrowserColumns==case[2],'ModulesPerRow='..case[1]..': '..p.name) end
 end
end
files.config='[Modules]\nSortBy=1\nPreferredCategoryMinimum=0\n'
-- In a single category, a mod spanning several top categories is listed only under its first.
files.config='[Modules]\nSortBy=1\nPreferredCategoryMinimum=0\nSingleCategory=1\n'
local single=reader();assert(single.singleCategory)
list=providers();G.arrange(list,nil,nil,single)
local once,singleHeadings={},{}
for _,p in ipairs(list) do
 if p.mcBrowserHeading then singleHeadings[#singleHeadings+1]=p.mcBrowserKind else once[p.id]=(once[p.id] or 0)+1 end
end
assert(once.A==1 and once['A.child']==1 and once.B==1,'one placement each')
assert(table.concat(singleHeadings,'|')=='Content|Presentation|Unclassified','a tie (gear, models) goes to the first declared: A under Content')
-- The top category holding most of a mod's categories wins over the first declared.
files.index=J.encode({schema_version=2,taxonomy_version=T.data.version,modules={
 A=entry({'gear','models','textures'},{}),B=entry({'interface'},{})}})
list=providers();G.arrange(list,nil,nil,reader())
local most={}
for _,p in ipairs(list) do if p.mcBrowserHeading then most[#most+1]=p.mcBrowserKind end end
assert(table.concat(most,'|')=='Presentation|Unclassified','models and textures outweigh gear: A and B under Presentation')
files.index=J.encode(index)
files.config='[Modules]\nSortBy=1\nPreferredCategoryMinimum=0\n'
assert(reader().singleCategory==nil,'off by default')
files.config='[Modules]\nSortBy=1\nPreferredCategoryMinimum=2\n'
list=providers();G.arrange(list,nil,nil,reader())
-- Top categories come first, then collections.
assert(list[1].mcBrowserKind=='Unclassified' and list[2].id=='U'
 and list[3].name=='Custom' and list[3].mcBrowserKind=='Collection'
 and list[4].id=='A' and list[5].id=='A.child' and list[6].id=='B')
local one={{id='A',name='A',mcFolder='A'},{id='A.child',name='Child',mcBrowserLevel=4,mcFolder='A'}}
G.arrange(one,nil,nil,reader());assert(one[1].mcBrowserKind=='Content','children do not meet the preferred-group threshold')
files.config='[Modules]\nSortBy=0\n'
list=providers();G.arrange(list,nil,nil,reader());assert(#list==5 and list[1].mcBrowserBare and list.mcModuleCount==3)
-- Recently added: newest first, in sections by age; baseline and unrecorded mods are Earlier.
local now=10*86400
files.config='[Modules]\nSortBy=2\n'
files.seen=J.encode({schema=2,folders={A={added=now-40*86400,updated=now-3600},B={added=now-3*86400},
 Unregistered={added=now-1,baseline=true}}})
local recentReader=C.reader('index','config',function(path) return files[path] end,{taxonomy=T,seenPath='seen'})
local recentOptions=recentReader();recentOptions.now=now
assert(recentOptions.groupModules==false and recentOptions.recent.A.updated==now-3600)
list=providers();G.arrange(list,nil,nil,recentOptions)
local arranged={}
for _,p in ipairs(list) do arranged[#arranged+1]=p.mcBrowserHeading and p.name or p.id end
assert(table.concat(arranged,',')=='Last 24 hours,A,A.child,Last 7 days,B,Earlier,U',table.concat(arranged,','))
assert(list[1].mcBrowserKind=='Added','a section names when its mods were added')
-- Inside a section mods stay newest first, whatever their load order.
files.seen=J.encode({schema=2,folders={A={added=now-7200},B={added=now-60}}})
local newest=recentReader();newest.now=now
list=providers();G.arrange(list,nil,nil,newest)
arranged={}
for _,p in ipairs(list) do arranged[#arranged+1]=p.mcBrowserHeading and p.name or p.id end
assert(table.concat(arranged,','):find('^Last 24 hours,B,A,'),table.concat(arranged,','))
files.seen=nil
assert(next(recentReader().recent)==nil,'without a record every mod is Earlier')
files.config='[Modules]\nSortBy=1\n'
assert(reader().recent==nil and reader().groupModules==true and reader().arrangement==1,'the record is read only for Recently added')
files.config='[Modules]\nSortBy=3\n'
assert(reader().loadOrder and reader().groupModules==false and reader().arrangement==3,'load order')
files.index='{invalid';local retained=reader();assert(retained.categoryRegister.A.categories[1]=='gear' and errors==1)
reader();assert(errors==1)
files.index=nil;assert(reader().categoryRegister.A)
files.index=J.encode({schema_version=2,taxonomy_version=T.data.version,modules={B=entry({'transport'})}})
assert(reader().categoryRegister.A==nil and reader().categoryRegister.B.parents[1]=='content')
assert(T:matches(index.modules.A,{values={'gear','models'},mode='all'},false))
assert(T:matches(index.modules.A,{values={'presentation'},mode='any'},false))
assert(not T:matches(index.modules.A,{values={'gear','sounds'},mode='all'},false))
assert(T:matches(index.modules.A,{values={'fix'},mode='all'},true))
assert(not T:matches(index.modules.A,{values={'adult'},mode='any'},true))
print('PASS canonical taxonomy, multi-parent placements, distinct counts, file handoff, preferred groups and independent filters')
