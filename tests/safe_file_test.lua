package.path='Scripts/vendor/?.lua;'..package.path
local Safe=require('safe_file')
local dir=os.getenv('TMPDIR') or '/tmp'
local path=dir..'/safe_file_test.txt'
local function clear() for _,suffix in ipairs({'','.new','.old'}) do os.remove(path..suffix) end end
local function exists(p) local f=io.open(p,'rb'); if f then f:close() end; return f~=nil end
clear()

assert(Safe.read(path)==nil,'a missing file reads as nil')
Safe.write(path,'one')
assert(Safe.read(path)=='one' and not exists(path..'.new') and not exists(path..'.old'),'a first write leaves no side files')
Safe.write(path,'two')
assert(Safe.read(path)=='two' and Safe.read(path..'.old')=='one' and not exists(path..'.new'),
    'a replacement keeps the previous file as .old')
Safe.put(path,'three')
assert(Safe.read(path)=='three','put writes in place')

-- A crash after the current file moved out publishes the complete replacement.
clear();Safe.put(path..'.old','previous');Safe.put(path..'.new','complete')
assert(Safe.read(path)=='complete' and not exists(path..'.new'),'an interrupted replacement is finished')
-- A crash before the current file moved out discards the unpublished replacement.
clear();Safe.put(path,'current');Safe.put(path..'.new','partial')
assert(Safe.read(path)=='current' and not exists(path..'.new'),'an unpublished replacement is discarded')
-- A removed file with only its backup stays removed.
clear();Safe.put(path..'.old','backup')
assert(Safe.read(path)==nil,'a backup alone is not restored')

clear()
Safe.put(path,string.rep('x',Safe.LIMIT))
assert(#Safe.read(path)==Safe.LIMIT,'the limit itself is readable')
Safe.put(path,string.rep('x',Safe.LIMIT+1))
assert(not pcall(Safe.read,path),'a file over 1 MiB raises')
assert(#Safe.read(path,Safe.LIMIT+1)==Safe.LIMIT+1,'a caller may raise the limit')
assert(not pcall(Safe.read,dir),'a folder raises rather than reading as missing')

local folder=dir..'/safe_file_test_dir/nested'
Safe.mkdir(folder);Safe.mkdir(folder)
Safe.put(folder..'/x','x');assert(Safe.read(folder..'/x')=='x','mkdir creates nested folders')
os.remove(folder..'/x');os.remove(folder);os.remove(dir..'/safe_file_test_dir')
clear()
print('PASS safe_file')
