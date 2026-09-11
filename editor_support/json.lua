-- Bounded data codec adapted from hybrid/src/level/json.lua; no Lua evaluation.
local utf8=require('utf8')
local J={}
local function quote(s)
  return '"'..s:gsub('[%z\1-\31\\"]',function(c)
    return ({['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'})[c] or string.format('\\u%04x',c:byte())
  end)..'"'
end
function J.encode(value)
  local seen={}
  local function encode(v,depth)
    assert(depth<=32,"Data nesting limit exceeded.")
    if type(v)=="string" then return quote(v)
    elseif type(v)=="boolean" then return tostring(v)
    elseif type(v)=="number" then assert(v==v and math.abs(v)<math.huge,"Non-finite number."); return string.format("%.17g",v)
    end
    assert(type(v)=="table" and not seen[v],"Invalid or cyclic data."); seen[v]=true
    local out={}; local n=#v
    if n>0 then
      local count=0; for k in pairs(v) do assert(type(k)=="number" and k%1==0 and k>=1 and k<=n,"Mixed array/object."); count=count+1 end
      assert(count==n,"Sparse array.")
      for i=1,n do out[i]=encode(v[i],depth+1) end
      seen[v]=nil; return "["..table.concat(out,",").."]"
    end
    local keys={}; for k in pairs(v) do assert(type(k)=="string","Invalid object key."); keys[#keys+1]=k end; table.sort(keys)
    for _,k in ipairs(keys) do out[#out+1]=quote(k)..":"..encode(v[k],depth+1) end
    seen[v]=nil; return "{"..table.concat(out,",").."}"
  end
  return encode(value,0)
end
function J.decode(text)
  assert(type(text)=="string" and #text<=8000000,"Data exceeds 8 MB.")
  local at,nodes=1,0
  local function ws() local _,last=text:find("^[ \r\n\t]*",at); at=(last or at-1)+1 end
  local function str()
    assert(text:sub(at,at)=='"',"Expected a quoted string."); at=at+1; local out={}; local length=0
    while at<=#text do
      local stop=text:find('["\\%z\1-\31]',at) or (#text+1)
      if stop>at then
        local chunk=text:sub(at,stop-1);length=length+#chunk
        assert(length<=1398104,"String too long.");out[#out+1]=chunk;at=stop
      end
      if at>#text then break end
      local c=text:sub(at,at);at=at+1
      if c=='"' then return table.concat(out) end
      if c=='\\' then
        local e=text:sub(at,at); at=at+1
        c=({['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'})[e]
        if e=='u' then
          local hex=text:sub(at,at+3); assert(hex:match('^%x%x%x%x$'),"Invalid Unicode escape.")
          local code=tonumber(hex,16);at=at+4
          if code>=0xD800 and code<=0xDBFF then
            assert(text:sub(at,at+1)=='\\u','Missing low surrogate.');local low=tonumber(text:sub(at+2,at+5),16)
            assert(low and low>=0xDC00 and low<=0xDFFF,'Invalid low surrogate.');at=at+6
            code=0x10000+(code-0xD800)*0x400+low-0xDC00
          else assert(code<0xDC00 or code>0xDFFF,'Unexpected low surrogate.') end
          c=utf8.char(code)
        end
        assert(c,"Invalid string escape.")
      else assert(c:byte()>=32,"Text cannot contain control characters.") end
      length=length+#c; assert(length<=1398104,"String too long."); out[#out+1]=c
    end
    error("Unterminated string.")
  end
  local parse
  parse=function(depth)
    assert(depth<=32,"Data nesting limit exceeded."); nodes=nodes+1; assert(nodes<=600000,"Too many data values.")
    ws(); local c=text:sub(at,at)
    if c=='"' then return str() end
    if c=='{' or c=='[' then
      local object=c=='{'; local close=object and '}' or ']'; local out={}; at=at+1; ws()
      if text:sub(at,at)==close then at=at+1; return out end
      while true do
        ws(); local key
        if object then key=str(); assert(out[key]==nil,"Duplicate object key."); ws(); assert(text:sub(at,at)==':',"Expected colon."); at=at+1
        else key=#out+1 end
        out[key]=parse(depth+1); ws(); local sep=text:sub(at,at); at=at+1
        if sep==close then return out end
        assert(sep==',',"Expected comma or closing delimiter.")
      end
    end
    for literal,value in pairs({["true"]=true,["false"]=false}) do
      if text:sub(at,at+#literal-1)==literal then at=at+#literal; return value end
    end
    local token=text:sub(at):match('^%-?%d+%.?%d*[eE]?[+-]?%d*')
    assert(token and #token>0,"Expected JSON data value (null is not used by this schema).")
    assert(not token:match('^%-?0%d') and not token:match('%.[eE]') and not token:match('%.$'),"Invalid JSON number.")
    local value=tonumber(token); assert(value and value==value and math.abs(value)<math.huge,"Invalid finite number.")
    at=at+#token; return value
  end
  local result=parse(0); ws(); assert(at>#text,"Trailing data after JSON payload."); return result
end
return J
