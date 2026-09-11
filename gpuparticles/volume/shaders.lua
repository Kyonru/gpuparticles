local directory=(...):gsub('shaders$',''):gsub('%.','/')..'shaders/'
local U=require((...):gsub('shaders$','util'))
local M={}
local cache={}
function M.hook(input,kind)
  input=input or {};assert(type(input)=='table','volume '..kind..' hook must be a table')
  U.keys(input,'code uniforms',kind..' hook')
  assert(input.code==nil or type(input.code)=='string','volume hook code must be GLSL')
  local uniforms,types,names={},{},{}
  for name,value in pairs(input.uniforms or {}) do
    assert(type(name)=='string' and name:match('^[a-zA-Z][a-zA-Z0-9_]*$') and not name:match('^u_'),'invalid volume uniform name')
    assert(not (' position velocity density temperature time color '):find(' '..name..' ',1,true),'volume uniform name conflicts with a hook argument')
    if type(value)=='table' then
      assert(#value>=2 and #value<=4,'volume uniform vectors need 2–4 components')
      uniforms[name]=U.vector(value,nil,name,#value);types[name]='vec'..#value
    else uniforms[name]=U.number(value,nil,name);types[name]='float' end
    names[#names+1]=name
  end
  table.sort(names)
  local source={}
  for _,name in ipairs(names) do source[#source+1]='uniform '..types[name]..' hook_'..name..';' end
  local code=input.code or (kind=='force' and 'return vec2(0.0);' or 'return color;')
  for _,name in ipairs(names) do code=code:gsub('%f[%w_]'..name..'%f[^%w_]', 'hook_'..name) end
  source[#source+1]=kind=='force' and
    'vec2 customForce(vec2 position,vec2 velocity,float density,float temperature,float time) {'..code..'}' or
    'vec4 customShade(vec4 color,float density,float temperature,vec2 position,float time) {'..code..'}'
  return {source=table.concat(source,'\n'),uniforms=uniforms,types=types}
end
function M.acquire(kind,hook)
  local key=kind..'\n'..(hook and hook.source or '')
  local entry=cache[key]
  if not entry then
    local common=assert(love.filesystem.read(directory..'common.glsl'))
    local source=assert(love.filesystem.read(directory..kind..'.glsl'))
    entry={shader=love.graphics.newShader('#pragma language glsl3\n'..common..'\n'..(hook and hook.source or '')..'\n'..source),refs=0}
    cache[key]=entry
  end
  entry.refs=entry.refs+1;return entry.shader,key
end
function M.release(key)
  local entry=cache[key];entry.refs=entry.refs-1
  if entry.refs==0 then entry.shader:release();cache[key]=nil end
end
function M.send(s,hook)
  for name,value in pairs(hook.uniforms) do U.send(s,'hook_'..name,value) end
end
function M.set(hook,name,value)
  local kind=hook.types[name];assert(kind,'unknown volume hook uniform '..tostring(name))
  hook.uniforms[name]=kind=='float' and U.number(value,nil,name) or U.vector(value,nil,name,tonumber(kind:sub(4)))
end
return M
