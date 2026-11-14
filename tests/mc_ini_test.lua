package.path='Scripts/vendor/?.lua;'..package.path
local Ini=require('mc_ini')

-- Parsing: global lines, headers, entries, comments, malformed lines and byte ranges.
local text='top=1\n; note\n[A]\n key = value ; comment\nbare\n\n[B]\r\nx=\r\n# c\r\n[A]\ny=2'
local doc=Ini.parse(text)
assert(doc.newline=='\r\n' and #doc.lines==11,'lines and newline')
assert(#doc.sections==4 and doc.sections[1].name=='' and doc.sections[1].header==nil,'global section first')
assert(doc.sections[1].entries[1].key=='top' and doc.sections[1].entries[1].value=='1','global entries')
local a=doc.sections[2]
assert(a.name=='A' and a.header==3 and a.last==6 and a.finish==doc.lines[7].start,'section bounds')
local entry=a.entries[1]
assert(entry.key=='key' and entry.value=='value' and entry.raw==' value ; comment','value without comment')
assert(text:sub(entry.valueFirst,entry.valueLast)=='value','value byte range')
assert(#doc.malformed==1 and doc.malformed[1]==5,'malformed lines')
local x=doc.sections[3].entries[1]
assert(x.key=='x' and x.value=='' and x.valueLast==x.valueFirst-1,'empty value')
assert(#Ini.sections(doc,'A')==2 and #Ini.entries(doc,'A')==2 and Ini.entries(doc,'A','y')[1].value=='2','repeated sections')
assert(#Ini.parse('').lines==0 and Ini.parse('').sections[1].last==0,'empty text')
assert(#Ini.parse('a=1\n').lines==1,'a final line ending adds no line')

-- Setting: in place, keeping spacing and comments and every other byte.
assert(Ini.set(text,'A','key','new')==text:gsub(' value ; comment',' new ; comment'),'replace keeps comment')
assert(Ini.set(text,'B','x','5')=='top=1\n; note\n[A]\n key = value ; comment\nbare\n\n[B]\r\nx=5\r\n# c\r\n[A]\ny=2','empty value')
assert(Ini.set(text,'A','y','3'):sub(-4)=='\ny=3','first match in any section of the name')
-- Added keys go after the first section's last non-blank line.
assert(Ini.set('[A]\na=1\n\n[B]\n','A','b','2')=='[A]\na=1\nb=2\n\n[B]\n','added after the last line')
assert(Ini.set('[A]\r\na=1','A','b','2')=='[A]\r\na=1\r\nb=2\r\n','line ending added first, style kept')
assert(Ini.set('x=1\n[A]\n','','y','2')=='x=1\ny=2\n[A]\n','global section')
assert(Ini.set('[A]\n','A','b','2')=='[A]\nb=2\n','after the header')
-- A missing section is appended after a blank line.
assert(Ini.set('','M','k',1)=='[M]\nk=1\n','empty text')
assert(Ini.set('[A]\na=1','M','k',1)=='[A]\na=1\n\n[M]\nk=1\n','separated')
assert(Ini.set('[A]\na=1\n\n','M','k',1)=='[A]\na=1\n\n[M]\nk=1\n','existing blank line kept')
assert(not pcall(Ini.set,'','M','k','a;b') and not pcall(Ini.set,'','M','k=','1'),'unsafe text refused')
-- A leading UTF-8 BOM hides no header; offsets and edits keep its bytes.
local bom='\239\187\191'
doc=Ini.parse(bom..'[A]\nk=1\n')
assert(#doc.sections[1].entries==0 and doc.sections[2].name=='A' and doc.sections[2].entries[1].key=='k','BOM before a header')
assert(doc.lines[1].text=='[A]' and doc.lines[1].start==1 and doc.text:sub(1,3)==bom,'the BOM stays in the text')
doc=Ini.parse(bom..'k = 12 ; note\n')
local e=doc.sections[1].entries[1]
assert(e.key=='k' and e.value=='12' and doc.text:sub(e.valueFirst,e.valueLast)=='12','BOM before a key keeps offsets')
assert(Ini.set(bom..'[A]\nk=1\n','A','k',2)==bom..'[A]\nk=2\n','set splices BOM text in place')
assert(Ini.set(bom..'k=1','','k',3)==bom..'k=3','set on a BOM first line')
assert(Ini.set(bom..'[A]\nk=1\n','A','j',5)==bom..'[A]\nk=1\nj=5\n','added key under a BOM header')
assert(#Ini.parse('x'..bom..'[A]\n').sections==1,'only a leading BOM is skipped')
print('PASS mc_ini')
