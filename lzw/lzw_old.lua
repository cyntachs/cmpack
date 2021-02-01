local lzw = {}

local function hex(num)
  return string.format("%02x",num):upper()
end
local function num(hex)
  return tonumber(hex,16)
end
local function hexchar(hex)
  return string.char(num(hex))
end

function lzw.compress(data, print)
  print = print or (function () end)
  -- dictionary variables
  local dictionary = {}
  local dictionary_len = 0
  local max_dictionary_len = 0xFFFFFFFFFFFFFFF
  local high_len = 1
  -- initialize dictionary
  for i = 1, 255 do
    dictionary[string.char(i)] = hex(#(hex(i))):sub(2,2) .. hex(i) -- [key size][key]
    dictionary_len = i
  end
  -- encode
  local pos = 1
  local out_buffer = ''
  local encoded = ''
  while pos <= #data do
    local block = ''
    local blocklen = high_len
    -- find longest block in dictionary
    repeat
      block = data:sub(pos,pos+blocklen-1)
      if dictionary[block] then
        break
      end
      blocklen = blocklen - 1
    until blocklen == -1
    if blocklen == -1 then error('dictionary error') end
    -- convert
    if ((pos/(#data))*100)%5 <= 0.002 then -- progress
      print( math.floor((pos/(#data))*100) )
    end
    out_buffer = out_buffer .. dictionary[block]
    pos = pos + blocklen
    -- add new entries to dictionary
    local newentry = block..data:sub(pos,pos)
    if (not dictionary[newentry]) and (dictionary_len <= max_dictionary_len) then
      dictionary_len = dictionary_len + 1
      dictionary[newentry] = hex(#(hex(dictionary_len))):sub(2,2) .. hex(dictionary_len)
      if #newentry > high_len then high_len = #newentry end
    end
    -- hex to char conversion
    if (#out_buffer % 2) == 0 then
      out_buffer = '-'.. out_buffer
      local t = ''
      for i = 1, (#out_buffer/2) do
        t = t .. hexchar(out_buffer:sub(i*2,(i*2)+1))
      end
      encoded = encoded .. t
      out_buffer = ''
    end
  end
  -- hex to char conversion of whats left
  local retval = ''
  if out_buffer ~= '' then
    repeat
      out_buffer = out_buffer .. '0'
    until (#out_buffer%2) == 0
    out_buffer = '-'..out_buffer
    for i = 1, (#out_buffer/2) do
      retval = retval .. hexchar(out_buffer:sub(i*2,(i*2)+1))
    end
    retval = encoded .. retval
  else
    retval = encoded
  end
  return retval
end

function lzw.decompress(data, print)
  print = print or (function() end)
  -- dictionary variables
  local dictionary = {}
  local dictionary_len = 0
  local high_len = 1
  -- initialize dictionary
  for i = 1, 255 do
    dictionary[hex(i)] = string.char(i)
    dictionary_len = i
  end
  -- char to hex conversion of first 32 chars
  local hexstr = ''
  local rawpos = 1
  for i = 1, 32 do
    local ht = hex(string.byte(data:sub(rawpos,rawpos)))
    hexstr = hexstr .. ht
    rawpos = rawpos + 1
  end
  -- decode
  local pos = 1
  local previous = ''
  local out_buffer = ''
  local decoded = ''
  while pos <= #hexstr do
    -- get key size
    local keysize = num(hexstr:sub(pos,pos))
    if (not keysize) or keysize == 0 then break end
    -- convert more data if insuficient
    if pos + (keysize+1) > #hexstr then
      local new = ''
      for i = 1, keysize+1 do
        if rawpos > #data then break end
        new = new .. hex(string.byte(data:sub(rawpos,rawpos)))
        rawpos = rawpos + 1
      end
      hexstr = hexstr .. new
    end
    -- get key
    local key = hexstr:sub(pos+1,(pos+1)+keysize-1)
    if (#key) ~= keysize then break end
    pos = pos + keysize + 1
    -- translate from dictionary
    local str = dictionary[key]
    if (not str) then
      str = previous .. previous:sub(1,1)
    end
    out_buffer = out_buffer .. str
    if ((pos/(#data*2))*100)%5 <= 0.002 then
      print( math.floor((pos/(#data*2))*100) )
    end
    -- add to dictionary
    if previous ~= '' then
      local newentry = previous .. str:sub(1,1)
      dictionary_len = dictionary_len + 1
      dictionary[hex(dictionary_len)] = newentry
    end
    -- set previous
    previous = str
  end
  return out_buffer
end

function lzw.pcompress(data,csize,print)
  csize = csize or 4096
  local retval = ""
  for i = 1, #data, csize do
    local tmp = lzw.compress(data:sub(i,i + csize - 1),print)
    local th = "0000" local tsz = th:sub(1,4-#hex(#tmp)) .. hex(#tmp)
    local sz = ""
    for i=1,4,2 do sz = sz .. hexchar(tsz:sub(i,i+1)) end
    retval = retval .. sz .. tmp
  end
  return retval .. hexchar("00") .. hexchar("00")
end
function lzw.pdecompress(data,print)
  local retval = ""
  local pos = 1
  local size = 0
  local tmp = ""
  while pos < #data do
    size = tonumber(data:sub(pos,pos+1):gsub(".",function (c) return string.format("%02x",string.byte(c)) end),16)
    if size == 0 then break end
    pos = pos + 2
    tmp = data:sub(pos,pos+size-1)
    pos = pos + size
    retval = retval .. lzw.decompress(tmp,print)
  end
  return retval
end

return lzw