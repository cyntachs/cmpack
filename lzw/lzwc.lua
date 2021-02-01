local lzw = {}

local function hex(num)
  local hxt = {'1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
  hxt[0] = '0'
  local hex = ''
  local q = num
  repeat
    local i,f = math.modf(q/16)
    hex = hxt[16 * f] .. hex
    q = i
  until q < 16
  hex = hxt[q] .. hex
  return hex
end
local function num(hex)
  return tonumber(hex,16)
end

function lzw.decompress(dta)
  local dct = {}
  local dtl = 0
  local hl = 1
  for i = 1, 255 do
    dct[hex(i)] = string.char(i)
    dtl = i
  end
  local hxs = ''
  local rwp = 1
  for i = 1, 32 do
    local ht = hex(string.byte(dta:sub(rwp,rwp)))
    hxs = hxs .. ht
    rwp = rwp + 1
  end
  local pos = 1
  local prv = ''
  local ob = ''
  local dec = ''
  while pos <= #hxs do
    local kys = num(hxs:sub(pos,pos))
    if (not kys) or kys == 0 then break end
    if pos + (kys+1) > #hxs then
      local new = ''
      for i = 1, kys+1 do
        if rwp > #dta then break end
        new = new .. hex(string.byte(dta:sub(rwp,rwp)))
        rwp = rwp + 1
      end
      hxs = hxs .. new
    end
    local ky = hxs:sub(pos+1,(pos+1)+kys-1)
    if (#ky) ~= kys then break end
    pos = pos + kys + 1
    local str = dct[ky]
    if (not str) then
      str = prv .. prv:sub(1,1)
    end
    ob = ob .. str
    if prv ~= '' then
      local nwe = prv .. str:sub(1,1)
      dtl = dtl + 1
      dct[hex(dtl)] = nwe
    end
    prv = str
  end
  return ob
end

return lzw