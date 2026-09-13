local prefix=(...):gsub('analytic$','')
local records,curves,shaders=require(prefix..'records'),require(prefix..'curves'),require(prefix..'shaders')
local forces=require(prefix..'forces')
local timeline=require(prefix..'timeline')
local M={}
function M.new(e)
  records.new(e)
  e.quad=records.quad(e)
  curves.refresh(e)
  e.shader,e.shaderKey=shaders.acquire('analytic',e.compiledForces.source,e.compiledForces.key,
    e.config.depth and {code=e.config.depth.code} or nil)
end
function M.update(e,dt) timeline.advance(e,dt) end
function M.warm(e,seconds) timeline.advance(e,seconds) end
function M.emit(e,n) records.emit(e,n) end
M.count=records.count
M.refresh=records.refresh
function M.draw(e,x,y,options)
  local g=love.graphics
  g.push('all')
  g.setBlendMode(e.config.blendMode)
  g.setShader(e.shader)
  shaders.common(e,e.shader)
  curves.send(e,e.shader)
  forces.send(e.compiledForces,e.shader)
  shaders.depth(e,e.shader,options)
  g.drawInstanced(e.quad,e.config.max,x or 0,y or 0)
  g.pop()
end
M.release=require(prefix..'resources').release

return M
