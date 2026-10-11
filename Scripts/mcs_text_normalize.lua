-- Unicode normalisation of folder names (NFC, case folding, alphanumerics only): the
-- key both the boot index and the offline folder map use.
local D=require('mcs_unicode_data')
local M={unicodeVersion=D.version}
local function decompose(cp,out)
    if cp>=0xAC00 and cp<=0xD7A3 then
        local s=cp-0xAC00
        out[#out+1]=0x1100+s//588;out[#out+1]=0x1161+(s%588)//28
        if s%28~=0 then out[#out+1]=0x11A7+s%28 end
    elseif D.decomposition[cp] then
        for _,part in ipairs(D.decomposition[cp]) do decompose(part,out) end
    else out[#out+1]=cp end
end
local function compose(a,b)
    if a>=0x1100 and a<=0x1112 and b>=0x1161 and b<=0x1175 then
        return 0xAC00+(a-0x1100)*588+(b-0x1161)*28
    elseif a>=0xAC00 and a<=0xD7A3 and (a-0xAC00)%28==0 and b>=0x11A8 and b<=0x11C2 then
        return a+b-0x11A7
    end
    return D.composition[a] and D.composition[a][b]
end
local function nfc(value)
    local parts={}
    for _,cp in utf8.codes(value) do decompose(cp,parts) end
    for i=2,#parts do
        local j=i;local cc=D.combining[parts[j]] or 0
        while cc~=0 and j>1 and (D.combining[parts[j-1]] or 0)>cc do
            parts[j],parts[j-1]=parts[j-1],parts[j];j=j-1
        end
    end
    local out,starter,last={},nil,0
    for _,cp in ipairs(parts) do
        local cc=D.combining[cp] or 0
        local combined=starter and compose(out[starter],cp)
        if combined and (last<cc or last==0) then out[starter]=combined
        else
            out[#out+1]=cp
            if cc==0 then starter=#out end
            last=cc
        end
    end
    return out
end
function M.normalize(value)
    assert(type(value)=='string' and utf8.len(value),'invalid UTF-8')
    local out,pending={},false
    for _,cp in ipairs(nfc(value)) do
        for _,folded in ipairs(D.folding[cp] or {cp}) do
            if D.spaces[folded] then pending=#out>0
            else
                if pending then out[#out+1]=' ';pending=false end
                out[#out+1]=utf8.char(folded)
            end
        end
    end
    return table.concat(out)
end
local function alnum(cp)
    local lo,hi=1,#D.alnum
    while lo<=hi do
        local mid=(lo+hi)//2;local range=D.alnum[mid]
        if cp<range[1] then hi=mid-1 elseif cp>range[2] then lo=mid+1 else return true end
    end
    return false
end
M.isAlnum=alnum
function M.anchor(value)
    local out={}
    for _,cp in utf8.codes(M.normalize(value)) do if alnum(cp) then out[#out+1]=utf8.char(cp) end end
    return table.concat(out)
end
return M
