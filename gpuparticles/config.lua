local M = {selfCollisionLimit=24000}
function M.copy(value)
  if type(value) ~= 'table' then return value end
  local result = {}
  for k, v in pairs(value) do result[k] = M.copy(v) end
  return result
end
function M.number(value, label, minimum)
  if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then
    error('gpuparticles: ' .. label .. ' must be a finite number', 3)
  end
  if minimum and value < minimum then error('gpuparticles: ' .. label .. ' is out of range', 3) end
  return value
end
function M.range(value, default, label, minimum)
  value = value == nil and default or value
  if type(value) ~= 'table' then value = {value, value} end
  local a, b = M.number(value[1], label, minimum), M.number(value[2] or value[1], label, minimum)
  assert(b >= a, 'gpuparticles: ' .. label .. ' maximum must be >= minimum')
  return {a, b}
end
function M.circleCollider(c)
  assert(type(c)=='table','gpuparticles: circleCollider must be a table')
  c.x=M.number(c.x or 0,'circle center x')
  c.y=M.number(c.y or 0,'circle center y')
  c.radius=M.number(c.radius or 40,'circle radius',0.000001)
  c.particleRadius=M.number(c.particleRadius or 0,'circle particle radius',0)
  c.bounce=M.number(c.bounce or 0.5,'circle bounce',0)
  c.friction=M.number(c.friction or 0,'circle friction',0)
  assert(c.bounce<=1 and c.friction<=1,'gpuparticles: circle bounce and friction must be between 0 and 1')
  assert(c.enabled==nil or type(c.enabled)=='boolean','gpuparticles: circle enabled must be boolean')
  return c
end
function M.normalize(input)
  local c = M.copy(input or {})
  c.max = M.number(c.max or 1000, 'max', 1)
  assert(c.max % 1 == 0, 'gpuparticles: max must be an integer')
  c.mode = c.mode or 'auto'
  assert(c.mode == 'auto' or c.mode == 'analytic' or c.mode == 'stateful', 'gpuparticles: invalid mode')
  c.rate = M.number(c.rate or 0, 'rate', 0)
  c.lifetime = M.range(c.lifetime, {1,1}, 'lifetime', 0.0001)
  c.speed = M.range(c.speed, {0,0}, 'speed')
  c.position = c.position or {0,0}
  c.gravity = c.gravity or {0,0}
  c.acceleration = c.acceleration or {c.gravity[1], c.gravity[2], c.gravity[1], c.gravity[2]}
  c.damping = M.range(c.damping, 0, 'damping', 0)
  c.radialAcceleration = M.range(c.radialAcceleration, 0, 'radialAcceleration')
  c.tangentialAcceleration = M.range(c.tangentialAcceleration, 0, 'tangentialAcceleration')
  c.spin = M.range(c.spin, 0, 'spin')
  c.rotation = M.range(c.rotation, 0, 'rotation')
  c.direction, c.spread = c.direction or 0, c.spread or 0
  c.sizeVariation, c.spinVariation = c.sizeVariation or 0, c.spinVariation or 0
  c.sizes = c.sizes or {8, 0}
  c.colors = c.colors or {{1,1,1,1}, {1,1,1,0}}
  c.offset, c.quads = c.offset or {0,0}, c.quads or {}
  c.emissionArea = c.emissionArea or {distribution = 'none', x = 0, y = 0, angle = 0}
  c.seed = M.number(c.seed or 1, 'seed')
  c.blendMode, c.insertMode = c.blendMode or 'add', c.insertMode or 'top'
  c.emitterLifetime = c.emitterLifetime or -1
  c.forces = c.forces or {}
  assert(c.max<=16777216,'gpuparticles: max exceeds exact float particle indices')
  for _,field in ipairs{'position','gravity','offset'} do
    assert(type(c[field])=='table','gpuparticles: '..field..' must be a vector')
    M.number(c[field][1],field..' x');M.number(c[field][2],field..' y')
  end
  for _,field in ipairs{'direction','spread','emitterLifetime','sizeVariation','spinVariation'} do M.number(c[field],field) end
  assert(c.sizeVariation>=0 and c.sizeVariation<=1 and c.spinVariation>=0 and c.spinVariation<=1,'gpuparticles: variations must be between 0 and 1')
  assert(type(c.sizes)=='table' and #c.sizes>0,'gpuparticles: sizes require at least one stop')
  for _,size in ipairs(c.sizes) do M.number(size,'size',0) end
  assert(type(c.colors)=='table' and #c.colors>0,'gpuparticles: colors require at least one stop')
  for _,color in ipairs(c.colors) do
    assert(type(color)=='table' and #color>=3,'gpuparticles: colors must be RGB or RGBA tables')
    color[4]=color[4] or 1
    for i=1,4 do M.number(color[i],'color') end
  end
  assert(c.insertMode=='top' or c.insertMode=='bottom' or c.insertMode=='random','gpuparticles: invalid insertMode')
  assert(type(c.forces)=='table','gpuparticles: forces must be an array')
  if c.warmStep then M.number(c.warmStep,'warmStep',0.000001) end
  if c.flowField then
    local f=c.flowField
    local texture=type(f)=='table' and f.texture or f
    assert(texture and texture.typeOf and texture:typeOf('Texture'),'gpuparticles: flowField needs a texture')
    if type(f)=='table' and f.size then M.number(f.size[1],'flow width',0.000001);M.number(f.size[2],'flow height',0.000001) end
  end
  if c.collision then
    local collision=c.collision
    assert(type(collision)=='table' and (collision.type=='plane' or collision.type=='heightfield' or collision.type=='sdf'),'gpuparticles: collision type must be plane, heightfield or sdf')
    if collision.type~='plane' then
      assert(collision.texture and collision.texture.typeOf and collision.texture:typeOf('Texture'),'gpuparticles: collision needs a texture')
      assert(collision.size,'gpuparticles: texture collision needs its world size')
      M.number(collision.size[1],'collision width',0.000001);M.number(collision.size[2],'collision height',0.000001)
    end
  end
  if c.attractors then
    assert(type(c.attractors)=='table','gpuparticles: attractors must be an array')
    for _,a in ipairs(c.attractors) do
      M.number(a.x or (a.position or {})[1],'attractor x');M.number(a.y or (a.position or {})[2],'attractor y')
      M.number(a.strength or 1000,'attractor strength');M.number(a.softening or 10,'attractor softening',0)
    end
  end
  if c.circleCollider then M.circleCollider(c.circleCollider) end
  if c.selfCollision==true then c.selfCollision={} end
  if c.selfCollision then
    local s=c.selfCollision
    assert(type(s)=='table','gpuparticles: selfCollision must be a table or boolean')
    assert(s.enabled==nil or type(s.enabled)=='boolean','gpuparticles: selfCollision enabled must be boolean')
    if s.enabled==false then c.selfCollision=nil
    else
      assert(c.max<=M.selfCollisionLimit,'gpuparticles: selfCollision supports at most 24000 particle slots per emitter; reduce max or disable it')
      s.radius=M.number(s.radius or 3,'self collision radius',0.000001)
      s.bounce=M.number(s.bounce or 0.2,'self collision bounce',0)
      s.strength=M.number(s.strength or 0.8,'self collision separation',0)
      s.iterations=M.number(s.iterations or 1,'self collision iterations',1)
      assert(s.bounce<=1 and s.strength<=1,'gpuparticles: self collision bounce and separation must be between 0 and 1')
      assert(s.iterations%1==0 and s.iterations<=4,'gpuparticles: self collision iterations must be an integer from 1 to 4')
    end
  end
  return c
end
return M
