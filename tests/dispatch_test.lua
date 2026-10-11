package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Dirty labels are the work that keeps a page's updates scheduled.
local binds,refreshes,usable=0,0,1
local changing
local bound
package.loaded.dirty_labels={new=function() return {open=function() end,close=function() end,
    bind=function(_,rows) binds=binds+1;bound=rows end,
    refresh=function(self) refreshes=refreshes+1;self.changed=changing and 1 or 0;return usable end} end}
local queue,now={},0
local objects={}
local lifecycle
package.loaded.dmm_lifecycle={install=function(_,onChange)
 local scope={enabled=true,epoch=0}
 lifecycle={
  open=function(selection)
   scope.epoch=scope.epoch+1;scope.path='/Transient.CommonActivatableWidget_1'
   onChange(scope.path,scope.epoch,selection or {path='/Transient.scroll',address='scroll'})
  end,
  close=function() scope.epoch=scope.epoch+1;scope.path=nil;onChange(nil,scope.epoch) end,
 }
 function scope:matches(path,epoch) return self.path==path and self.epoch==epoch end
 function scope:ownerLive()
  if not self.path then return false end
  local h=objects[self.path]
  if not h or h.visible==false or h.active==false or h.enabled==false then lifecycle.close();return false end
  return true
 end
 function scope:invalidate() if self.path then lifecycle.close() end end
 return scope
end}
local calls,scans,finds=0,0,0
local function obj(name)
 local o={name=name}
 function o:IsValid() calls=calls+1;return true end
 function o:GetAddress() calls=calls+1;return self.name end
 function o:IsInViewport() calls=calls+1;return true end
 function o:IsActivated() calls=calls+1;return self.active~=false end
 function o:IsVisible() calls=calls+1;return self.visible~=false end
 function o:GetIsEnabled() calls=calls+1;return self.enabled~=false end
 objects['/Transient.'..name]=o;return o
end
local host=obj('CommonActivatableWidget_1')
local scroll=obj('scroll')
local function row(id,kind,provider,settingKind)
 return {kind=kind or 'picker',wrapper=obj('wrapper'..id),identityProviderId=provider or 'P',settingId=id,
  dmmSetting={id=id,kind=settingKind or kind or 'picker',values={0,1},labels={'A','B'}}}
end
local pageRows={row('A'),row('B')}
local treeScans=true
StaticFindObject=function(path) calls=calls+1;finds=finds+1;return objects[path] end
LoopAsync=function() error('permanent timer forbidden') end
ExecuteWithDelay=function(delay,fn) queue[#queue+1]={time=now+delay,fn=fn} end
ExecuteInGameThread=function(fn) fn() end
EGameThreadMethod={EngineTick=1};EngineTickAvailable=true
package.loaded.widget_discovery={valid=function(o) return o and o:IsValid() end,address=function(o) return o:GetAddress() end,
 activeTrees=function() scans=scans+1;return treeScans and {{scrolls={scroll},routes={}}} or {} end,
 routesFor=function() return {} end,
 rowsFromScroll=function(target) if target==scroll then return pageRows end end}
local marked={}
package.loaded.row_error={mark=function(r,message) marked[r]=message;return true end}
local diagnostics={}
assert(require('dmm_binding').install(function(event,detail) diagnostics[#diagnostics+1]=event..':'..tostring(detail) end))
local function untilTime(target)
 while true do
  table.sort(queue,function(a,b) return a.time<b.time end)
  if not queue[1] or queue[1].time>target then break end
  local task=table.remove(queue,1);now=task.time;task.fn()
 end
 now=target
end

assert(#queue==0 and calls==0)
untilTime(60000);assert(#queue==0 and calls==0)
print('PASS 60 seconds idle: zero queued timers, zero UObject calls, zero scans')

-- A page event binds the selected list once, then updates resolve only the host.
lifecycle.open();untilTime(now)
assert(binds==1 and #bound==2 and scans==0,'the selected ScrollBox binds without a tree scan')
local firstFinds=finds
untilTime(now+900)
-- The binding tick counts as the first quiet one: 9 more 50 ms apart, then 250 ms.
assert(binds==1 and scans==0 and finds-firstFinds==10,'quiet updates back off, resolve one host, never rescan')
changing=true;local busyFinds=finds
untilTime(now+1000)
assert(finds-busyFinds>=16,'a changing page is observed every 50 ms again')
changing=false
print('PASS page selection binds the exact list once; steady updates resolve only the host')

-- Same-stack DMM callbacks share one deferred discovery.
lifecycle.open();lifecycle.open();lifecycle.open();untilTime(now)
assert(binds==2,'a burst of page events binds once')
print('PASS same-stack page events coalesce')

-- A hidden or disabled host stops updates and timers.
for _,field in ipairs({'visible','enabled'}) do
 host[field]=false
 untilTime(now+100)
 local after=calls
 untilTime(now+60000)
 assert(calls==after and #queue==0,'hidden/disabled host kept timers alive')
 host[field]=true;lifecycle.open();untilTime(now)
end
print('PASS a hidden or disabled host stops updates before any control work')

-- Closing drains obsolete callbacks without native access.
lifecycle.close();local stopped=calls
untilTime(now+60000)
assert(calls==stopped and #queue==0)
print('PASS close: obsolete callbacks drain with zero UObject calls')

-- Without a selected list, one bounded tree traversal finds the page.
local scansBefore=scans
lifecycle.open({path='/Transient.missing',address='missing'});untilTime(now)
assert(scans==scansBefore+1 and binds>0)
print('PASS activation without a selected list falls back to one tree traversal')

-- Nothing left to keep up to date stops scheduling.
usable=0
local before=#queue
untilTime(now+100)
assert(#queue==0 and before>=0,'an idle page keeps no timer')
usable=1
print('PASS a page with nothing to update keeps no timer')

-- Row identities: inconsistent rows show an error, field-type rows belong to their editor.
marked={}
local typed=row('T','toggle','P','extension')
local foreign=row('F','picker','Other')
local twinA,twinB=row('D'),row('D')
local mismatch=row('M','toggle','P','picker')
local blank=row('N');blank.settingId=nil
pageRows={row('A'),typed,foreign,twinA,twinB,mismatch,blank,row('B')}
lifecycle.open();untilTime(now)
assert(not marked[pageRows[1]] and not marked[typed] and not marked[pageRows[8]])
assert(marked[foreign]=='Error: other page' and marked[twinA]=='Error: duplicate id' and marked[twinB]=='Error: duplicate id'
 and marked[mismatch]=='Error: type mismatch' and marked[blank]=='Error: no identity')
local names={}
for _,r in ipairs(bound) do names[#names+1]=r.settingId end
assert(table.concat(names,',')=='A,T,B','only consistent rows are bound')
local logged=false
for _,entry in ipairs(diagnostics) do if entry:find('ROW_ERROR:P row 3 F: Error: other page',1,true) then logged=true end end
assert(logged,'each row error is logged with its row')
print('PASS inconsistent rows show an error; consistent and field-type rows stay usable')

-- Revocation after dispatch but before game-thread execution prevents native access.
local jobs={}
ExecuteInGameThread=function(fn) jobs[#jobs+1]=fn end
lifecycle.close();untilTime(now+100)
lifecycle.open();untilTime(now);assert(#jobs==1)
lifecycle.close();local revoked=calls
jobs[1]();untilTime(now+60000)
assert(calls==revoked and #queue==0)
print('PASS revocation after dispatch but before game-thread execution prevents native access')

-- Dispatch and scheduling failures close the scope without retries.
ExecuteInGameThread=function() error('injected dispatch failure') end
lifecycle.open();untilTime(now+60000);assert(#queue==0)
ExecuteWithDelay=function() error('injected scheduling failure') end
lifecycle.open();untilTime(now)
assert(#queue==0)
print('PASS dispatch and scheduling failures stop updates without retries')
