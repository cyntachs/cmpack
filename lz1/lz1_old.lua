local lz1 = {}

-- Keysize,chunk size,chunk position

getmetatable('').__index = function(str,i) return string.sub(str,i,i) end -- index strings
getmetatable('').__call = string.sub -- substring

local function tohex(num)
  local hextable = {'1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'}; hextable[0] = '0'
  local hex = ''
  local q = num
  repeat
    local i,f = math.modf(q/16)
    hex = hextable[16 * f] .. hex
    q = i
  until q < 16
  hex = hextable[q] .. hex
  return hex
end

function lz1.compress(data,print)
  print = print or (function() end)
  -- Variables
  local dictionary = {}
  local dictionaryl = 1
  local dictionaryi = 1
  local dictionary_header = ''
  -- init dictionary
  for i = 1, 255 do
    dictionary_header = dictionary_header .. string.char(i)
    dictionary[string.char(i)] = tohex(1)(2,2) .. tohex(i)
    dictionaryi = i
  end
  -- encode
  local pos = 1
  local dsize = 4194304 -- dictionary limit
  local encoded = ''
  local temp_enc = ''
  while pos <= #data do
    local lm = dictionaryl
    local chunk = ''
    repeat
      chunk = data(pos,pos+lm-1)
      if dictionary[chunk] then
        local olap = tonumber(dictionary[chunk][1],16) + tonumber(dictionary[chunk](2),16)
        if olap < (pos+#dictionary_header) then
          break
        end
      end
      lm = lm - 1
    until lm == -1
    if lm == -1 then error('no match') end
    -- encode
    if ((pos/(#data*2))*100)%5 <= 0.002 then
      print( math.floor((pos/(#data*2))*100) )
    end
    --
    local key = dictionary[chunk]
    local keysize = tohex(#key)(2,2)
    if keysize == '0' then error('keysize error') end
    temp_enc = temp_enc .. keysize .. key
    pos = pos + (lm)
    -- add new entries to dictionary
    local newd = chunk..data[pos]
    if (not dictionary[newd]) and (dictionaryi <= dsize) and (#newd <= 15) then
      dictionaryi = dictionaryi + 1
      dictionary[newd] = tohex(#newd)(2,2) .. tohex((pos + #dictionary_header) - (lm))
      if #newd > dictionaryl then dictionaryl = #newd end
    end
    -- in-situ coversion
    if (#temp_enc % 2) == 0 then
      temp_enc = '-' .. temp_enc
      local tmp = ''
      for i = 1, (#temp_enc/2) do
        tmp = tmp .. string.char(tonumber(temp_enc(i*2,(i*2)+1),16))
      end
      encoded = encoded .. tmp
      temp_enc = ''
    end
  end
  -- convert whats left
  local retval = ''
  if temp_enc ~= '' then
    repeat
      temp_enc = temp_enc .. '0'
    until (#temp_enc%2) == 0
    temp_enc = '-' .. temp_enc
    for i = 1, (#temp_enc/2) do
      retval = retval .. string.char(tonumber(temp_enc(i*2,(i*2)+1),16))
    end
    retval = encoded .. retval
  else
    retval = encoded
  end
  print(100)
  return retval
end

function lz1.decompress(rawdata,print)
  print = print or (function() end)
  local rawpos = 1
  local mstring = ''
  for i = 1, 32 do
    mstring = mstring .. tohex(string.byte(rawdata[rawpos]))
    rawpos = rawpos + 1
  end
  
  -- setup dictionary
  local init_dict = ''
  for i = 1, 255 do
    init_dict = init_dict .. string.char(i)
  end
  mstring = init_dict .. mstring
  
  -- decode
  local pos = #init_dict + 1
  local temp = init_dict
  while pos < #mstring do
    -- get key size
    local keysize = tonumber(mstring[pos],16)
    if (not keysize) or keysize == 0 then break end
    -- get key
    local key = mstring(pos+1,(pos+1)+keysize-1)
    if (#mstring(pos+1,(pos+1)+keysize-1)) ~= keysize then break end
    -- break key
    local word_len = tonumber(key[1],16)
    local pointer = tonumber(key(2),16)
    --
    if ((pos/(#rawdata*2))*100)%5 <= 0.002 then
      print( math.floor((pos/(#rawdata*2))*100) )
    end
    -- decode
    temp = temp .. temp(pointer,pointer+word_len-1)
    pos = pos + keysize + 1
    -- in-situ conversion
    if (pos >= #mstring-16) and (rawpos <= #rawdata)then
      for i = 1, 32 do
        if rawpos > #rawdata then break end
        mstring = mstring .. tohex(string.byte(rawdata[rawpos]))
        rawpos = rawpos + 1
      end
    end
  end
  return temp(256)
end

--------------------
return lz1