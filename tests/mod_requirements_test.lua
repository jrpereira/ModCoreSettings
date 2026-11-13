package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local R=require('mod_requirements')

local function same(a,b) return table.concat(a or {},'.')==table.concat(b or {},'.') end
assert(same(R.parts('1.6.0'),{1,6,0}) and same(R.parts(' v1.2.2-dev '),{1,2,2}) and same(R.parts('1.0.7.1'),{1,0,7,1}))
assert(same(R.parts('1.6.?',true),{1,6,0}) and R.parts('1.6.?')==nil,'only a requirement takes ?')
assert(R.parts('')==nil and R.parts('x')==nil and R.parts('1..2')==nil and R.parts(nil)==nil)
assert(R.compare({1,6},{1,6,0})==0 and R.compare({1,5,9},{1,6})==-1 and R.compare({2},{1,9,9})==1)
assert(R.published('1.6.?+')=='1.6.0+')
print('PASS versions parse and compare part by part')

local loaded={ModCoreSettings={name='ModCore Settings',version='1.6.2'},
    ModCoreTemplates={name='ModCore Templates',version='1.6.4'},
    DawnwalkerModMenu={name='DawnwalkerModMenu',version='1.0.7.1'},
    Native={name='Native'},Exact={name='Exact',version='2.0.0'}}
local function installed(id) return loaded[id] end
local report=R.evaluate({{id='UE4SS'},{id='ModCoreSettings',version='1.6.?+'},
    {id='DawnwalkerModMenu',version='1.0.7.1+'}},installed)
assert(report.met and #report.items==3,'every requirement met')
assert(R.describe(report)==' √    DawnwalkerModMenu 1.0.7.1+: 1.0.7.1\n √    ModCore Settings 1.6.0+: 1.6.2\n'
    ..' √    UE4SS: loaded',R.describe(report))
local failing=R.evaluate({{id='ModCoreTemplates',version='1.7.?+'},{id='UE4SSLuaEventBridge',version='1.2.?+'},
    {id='Native',version='1.0+'},{id='Exact',version='2.0'},{id='Exact',version='1.9'},{id='Native'},
    {id='ModCoreSettings',version='one+'}},installed)
assert(not failing.met)
assert(R.describe(failing)=='⚠  Exact 1.9: 2.0.0 (too new)\n'
    ..'⚠  ModCore Settings one+: 1.6.2 (unreadable requirement)\n'
    ..'⚠  ModCore Templates 1.7.0+: 1.6.4 (too old)\n'
    ..'⚠  Native 1.0+: loaded (version unknown)\n'
    ..'⚠  UE4SSLuaEventBridge 1.2.0+: not loaded\n'
    ..' √    Exact 2.0: 2.0.0\n'
    ..' √    Native: loaded',R.describe(failing))
assert(R.evaluate({},installed)==nil and R.evaluate(nil,installed)==nil,'no dependencies, no report')
print('PASS requirements report each dependency, its version and the mismatch, unmet first, by name')
