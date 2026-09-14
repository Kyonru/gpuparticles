local prefix=(...):gsub('shaders$','')
local directory=prefix:gsub('%.','/') .. 'shaders/'
local timeline=require(prefix..'timeline')
local M={}
-- Shared immutable shader variants, reference counted; no application globals.
local cache={}
-- `depth` selects an optional z variant: {} for simulated z, {code=...} for a formula.
-- Emitters without it keep exactly the ids, and therefore the shaders, they had before.
local singleEntry='vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {\n    vec4 unused=vec4(0.0);\n    return stepParticle(tc,sc,unused);\n}'
local depthEntry='void effect() {\n    vec4 depth=Texel(u_depthState,VaryingTexCoord.xy);\n    love_Canvases[0]=stepParticle(VaryingTexCoord.xy,love_PixelCoord.xy,depth);\n    love_Canvases[1]=depth;\n}'
function M.acquire(kind, fragment, key, depth)
  local suffix=depth and (depth.code and ('|depth:code:'..depth.code) or '|depth:state') or ''
  local id=kind .. ':' .. (key or '') .. suffix
  local entry=cache[id]
  if not entry then
    local source=assert(love.filesystem.read(directory..kind..'.glsl'))
    if depth then
      local defines='#define PARTICLE_DEPTH\n'..(depth.code and '#define PARTICLE_DEPTH_CODE\n' or '#define PARTICLE_DEPTH_STATE\n')
      source=source:gsub('#pragma language glsl3\n',function(pragma) return pragma..defines end,1)
    end
    -- LOVE picks one render target or several from the effect signature it finds, so only
    -- one entry point may be in the source: a simulated-z step also writes the z texture.
    source=source:gsub('// ENTRY',function() return (depth and not depth.code) and depthEntry or singleEntry end)
    source=source:gsub('// COMMON',function() return assert(love.filesystem.read(directory..'common.glsl')) end)
    source=source:gsub('// STYLE',function()
      local style=assert(love.filesystem.read(directory..'style.glsl'))
      if depth and depth.code then
        style='#ifdef VERTEX\nfloat depthCode(float seed,float age) {\n'..depth.code..'\n}\n#endif\n'..style
      end
      return style
    end)
    source=source:gsub('// COLLISION',function() return assert(love.filesystem.read(directory..'collision.glsl')) end)
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
  M.send(shader,'u_stretch',c.stretch or 0)
end
-- Draw-time depth settings for z variants. Always sent in full: emitters share variants,
-- so a cut left over from one draw would otherwise apply to the next.
function M.depth(e,shader,options)
  local d=e.config.depth
  if not d then return end
  options=options or {}
  M.send(shader,'u_depthTilt',d.tilt)
  M.send(shader,'u_depthCut',options.cut=='behind' and 1 or options.cut=='front' and 2 or 0)
  M.send(shader,'u_depthRange',options.range or 1)
  M.send(shader,'u_depthSize',options.size or 0)
  M.send(shader,'u_depthDim',options.dim or 0)
  if e.depthA then M.send(shader,'u_depthState',e.depthA) end
end
return M
