local gpu=require('gpuparticles')
local M={}
function M.run()
  local methods={'setColors','setSizes','setSizeVariation','setSpeed','setSpread','setDirection','setLinearAcceleration',
    'setRadialAcceleration','setTangentialAcceleration','setLinearDamping','setSpin','setSpinVariation','setRotation',
    'setRelativeRotation','setEmissionArea','setEmitterLifetime','setParticleLifetime','setOffset','setQuads','setInsertMode',
    'setCircleCollider','setBoxCollider','setCapsuleCollider','setBufferSize','emit','start','stop','pause','reset','getCount'}
  for _,mode in ipairs{'analytic','stateful'} do
    local e=gpu.newEmitter{max=8,mode=mode,rate=4,lifetime=1}
    for _,method in ipairs(methods) do assert(type(e[method])=='function','missing '..method) end
    assert(e:getCount()==0)
    e:update(0.5);assert(e:getCount()==2)
    e:pause();e:update(0.6);assert(e:getCount()==2,'paused particles must keep aging')
    e:start();e:update(0.2);assert(e:getCount()==1,'resume must not invent births during pause')
    e:update(0.1);assert(e:getCount()==2)
    e:stop();e:update(2);assert(e:getCount()==0)
    e:emit(8);assert(e:getCount()==0,'stopped emit is ignored like the native system')
    e:start();e:emit(3);assert(e:getCount()==3)
    e:reset();assert(e:getCount()==0)
    local colors,sizes={},{}
    for i=1,16 do colors[i]={i/16,1-i/16,0,1};sizes[i]=i end
    e:setColors(colors):setSizes(sizes)
    assert(e.colorCurve:getWidth()==16 and e.sizeCurve:getWidth()==16)
    e:setSpeed(1,2):setParticleLifetime(2,3):setSpread(1):setDirection(0.5)
    e:setLinearAcceleration(0,1,1,2):setLinearDamping(0.3):setRadialAcceleration(2):setTangentialAcceleration(3)
    e:setSizeVariation(0.2):setSpin(-1,1):setSpinVariation(0.4):setRotation(0,1):setRelativeRotation(true)
    e:setOffset(1,2):setEmissionArea('ellipse',4,8,0.1,true):setEmitterLifetime(0.5)
    local quad=love.graphics.newQuad(0,0,16,16,32,32)
    e:setQuads(quad)
    e:setInsertMode('bottom'):emit(2);assert(e.cursor==6)
    e:setBufferSize(16);assert(e:getCount()==0 and e:getBufferSize()==16)
    e:update(1);assert(not e:isActive(),'finite emitter must stop emitting')
    e:release();quad:release()
  end
  print('Lifecycle / pause history / setters / 16 stops / buffer reset PASS')
  local config={max=16,rate=0,lifetime={1,2},speed={1,30},spread=3,seed=17}
  local a,b=gpu.newEmitter(config),gpu.newEmitter(config)
  a:emit(7);b:emit(7)
  for i=1,16 do
    local av,bv={a.instances:getVertex(i)},{b.instances:getVertex(i)}
    for j=1,#av do assert(av[j]==bv[j],'seeded records must replay exactly') end
  end
  a:release();b:release()
  print('Deterministic randomness PASS')
end
return M
