local M = {}
local unpack = unpack or table.unpack
local function resample(stops, limit)
  if #stops <= limit then return stops end
  local out = {}
  for i = 1, limit do
    local t = (i-1)/(limit-1)*(#stops-1)
    local a, b, f = math.floor(t)+1, math.min(math.floor(t)+2,#stops), t%1
    if type(stops[1]) == 'table' then
      out[i] = {}
      for j = 1, 4 do out[i][j] = stops[a][j]*(1-f)+stops[b][j]*f end
    else out[i] = stops[a]*(1-f)+stops[b]*f end
  end
  return out
end
function M.configure(e)
  local p, c = e.native, e.config
  p:setEmissionRate(c.rate)
  p:setParticleLifetime(unpack(c.lifetime))
  p:setPosition(unpack(c.position))
  p:setSpeed(unpack(c.speed))
  p:setDirection(c.direction)
  p:setSpread(c.spread)
  p:setLinearAcceleration(unpack(c.acceleration))
  p:setLinearDamping(unpack(c.damping))
  p:setRadialAcceleration(unpack(c.radialAcceleration))
  p:setTangentialAcceleration(unpack(c.tangentialAcceleration))
  p:setSpin(unpack(c.spin))
  p:setSpinVariation(c.spinVariation)
  p:setRotation(unpack(c.rotation))
  p:setRelativeRotation(c.relativeRotation or false)
  p:setSizeVariation(c.sizeVariation)
  local sizes=resample(c.sizes,8)
  local scaled={}
  for i,size in ipairs(sizes) do scaled[i]=size/e.texture:getWidth() end
  p:setSizes(unpack(scaled))
  p:setColors(unpack(resample(c.colors, 8)))
  p:setEmitterLifetime(c.emitterLifetime)
  p:setOffset(e.texture:getWidth()/2+c.offset[1],e.texture:getHeight()/2+c.offset[2])
  p:setInsertMode(c.insertMode)
  local a = c.emissionArea
  p:setEmissionArea(a.distribution, a.x, a.y, a.angle or 0, a.directionRelative or false)
  p:setQuads(unpack(c.quads))
end
function M.new(e)
  e.native = love.graphics.newParticleSystem(e.texture, e.config.max)
  M.configure(e)
end
function M.update(e, dt) e.native:update(dt) end
function M.draw(e, x, y)
  love.graphics.push('all')
  love.graphics.setBlendMode(e.config.blendMode)
  love.graphics.draw(e.native, x or 0, y or 0)
  love.graphics.pop()
end
function M.release(e) e.native:release() end
return M
