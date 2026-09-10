-- Run the production vertex physics, replacing only its raster placement and
-- fragment presentation so the position and velocity can be read numerically.
local shaders=require('gpuparticles.shaders')
local forces=require('gpuparticles.forces')
local M={}
local style=[[
varying vec4 inspectedState;
#ifdef VERTEX
attribute float ParticleIndex;
vec4 styleVertex(mat4 transform,vec4 vertex,vec2 p,vec2 velocity,vec4 style,vec3 clock,float life,float seed) {
    inspectedState=vec4(p,velocity);
    return transform*vec4(vertex.xy+vec2(ParticleIndex+0.5,0.5),0.0,1.0);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image image,vec2 tc,vec2 sc) { return inspectedState; }
#endif
]]
function M.read(e)
  local kind=e:getMode()=='analytic' and 'analytic' or 'render'
  local source=assert(love.filesystem.read('gpuparticles/shaders/'..kind..'.glsl'))
  source=source:gsub('attribute float ParticleIndex;','')
  source=source:gsub('// COMMON',function() return assert(love.filesystem.read('gpuparticles/shaders/common.glsl')) end)
  source=source:gsub('// STYLE',function() return style end)
  source=source:gsub('// FORCES',function() return e.compiledForces.source end)
  local shader=love.graphics.newShader(source)
  local target=love.graphics.newCanvas(e.config.max,1,{format='rgba32f',dpiscale=1,msaa=0})
  local g=love.graphics
  g.push('all');g.origin();g.setScissor();g.setColor(1,1,1,1)
  g.setCanvas(target);g.setBlendMode('replace','premultiplied');g.setShader(shader)
  shaders.common(e,shader);forces.send(e.compiledForces,shader)
  if kind=='render' then shader:send('u_state',e.stateA);shader:send('u_texSize',e.texSize) end
  g.drawInstanced(e.quad,e.config.max);g.pop()
  local data=target:newImageData();target:release();shader:release()
  return data
end
return M
