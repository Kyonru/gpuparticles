local prefix=(...):gsub('shaders$','')
local directory=prefix:gsub('%.','/') .. 'shaders/'
local timeline=require(prefix..'timeline')
local M={}
-- Shared immutable shader variants, reference counted; no application globals.
local cache={}
function M.acquire(kind, fragment, key)
  local id=kind .. ':' .. (key or '')
  local entry=cache[id]
  if not entry then
    local source=assert(love.filesystem.read(directory..kind..'.glsl'))
    source=source:gsub('// COMMON',function() return assert(love.filesystem.read(directory..'common.glsl')) end)
    source=source:gsub('// STYLE',function() return assert(love.filesystem.read(directory..'style.glsl')) end)
    source=source:gsub('// FORCES',function() return fragment or 'vec2 forceDisplacement(float seed,float age) { return vec2(0.0); }' end)
    entry={shader=love.graphics.newShader(source),refs=0}
    cache[id]=entry
  end
  entry.refs=entry.refs+1
  return entry.shader,id
end
function M.release(id)
  if not id then return end
  local entry=cache[id]
  entry.refs=entry.refs-1
  if entry.refs==0 then entry.shader:release();cache[id]=nil end
end
function M.send(shader,name,value)
  if shader:hasUniform(name) then shader:send(name,value) end
end
function M.common(e,shader)
  local c=e.config
  M.send(shader,'u_time',e.time)
  timeline.send(e,shader)
  M.send(shader,'u_origin',c.position)
  M.send(shader,'u_rate',c.rate)
  M.send(shader,'u_epoch',e.epoch)
  M.send(shader,'u_count',c.max)
  M.send(shader,'u_sizeVariation',c.sizeVariation)
  M.send(shader,'u_acceleration',c.acceleration)
  M.send(shader,'u_damping',c.damping)
  M.send(shader,'u_radial',c.radialAcceleration)
  M.send(shader,'u_tangential',c.tangentialAcceleration)
  M.send(shader,'u_offset',c.offset)
  M.send(shader,'u_relativeRotation',c.relativeRotation or false)
end
return M
