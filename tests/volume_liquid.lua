local gpu=require('gpuparticles')
local H=require('tests.volume_helpers')
local M={}

local function blob(px,py)
  return px>=4 and px<=8 and py>=4 and py<=8 and 0.7 or 0,0,0,0
end

local function momentum(material)
  local state=material.state:newImageData()
  local velocity=material.velocity:newImageData()
  local x,y=0,0
  for py=0,state:getHeight()-1 do for px=0,state:getWidth()-1 do
    local mass=state:getPixel(px,py)
    local vx,vy=velocity:getPixel(px,py)
    x,y=x+mass*vx,y+mass*vy
  end end
  state:release();velocity:release()
  return x,y
end

local function divergenceEnergy(material)
  local state=material.state:newImageData()
  local velocity=material.velocity:newImageData()
  local width,height=state:getDimensions()
  local function sample(px,py,component)
    if px<0 or py<0 or px>=width or py>=height or state:getPixel(px,py)<=0.0001 then return 0 end
    local vx,vy=velocity:getPixel(px,py)
    return component==1 and vx or vy
  end
  local energy=0
  for py=0,height-1 do for px=0,width-1 do if state:getPixel(px,py)>0.0001 then
    local divergence=(sample(px+1,py,1)-sample(px-1,py,1))/(2*material.world.cell[1])
      +(sample(px,py+1,2)-sample(px,py-1,2))/(2*material.world.cell[2])
    energy=energy+divergence*divergence
  end end end
  state:release();velocity:release()
  return energy
end

function M.run()
  -- The compatibility name and the explicit settling behavior run the original solver.
  local old=assert(gpu.newVolumeWorld{width=16,height=16,cellSize=1,transportSteps=2})
  local named=assert(gpu.newVolumeWorld{width=16,height=16,cellSize=1,transportSteps=2})
  local water=old:addMaterial{name='water',model='water',cooling=0}
  local settling=named:addMaterial{name='mud',model='liquid',behavior='settling',cooling=0}
  H.seed(water.state,blob);H.seed(settling.state,blob)
  old:update(old.fixedStep);named:update(named.fixedStep)
  local a,b=old:readback(water),named:readback(settling)
  for y=0,15 do for x=0,15 do H.near(a:getPixel(x,y),b:getPixel(x,y),1e-7,'settling compatibility') end end
  a:release();b:release()
  assert(not water.velocity and not settling.velocity,'settling liquids must not allocate inertial state')
  old:release();named:release()

  -- A force changes persistent velocity: mass continues in the same direction on later steps.
  local world=assert(gpu.newVolumeWorld{width=32,height=16,cellSize=1,transportSteps=3,liquidPressureIterations=6})
  local liquid=world:addMaterial{name='river',model='liquid',behavior='fluid',gravity=0,pressure=0,
    viscosity=0,velocityDamping=0,surfaceTension=0,solidFriction=0,maxSpeed=500,
    volumeRelaxation=0,sleepSpeed=0,cooling=0}
  assert(liquid.velocity and liquid.velocityNext and liquid.pressureField,'inertial liquid state was not allocated')
  H.seed(liquid.state,blob)
  local before=H.sum(liquid)
  world:addWaterForce(6.5,6.5,6,90,0):update(world.fixedStep)
  local kicked=H.sum(liquid)
  local kickedMomentum=momentum(liquid)
  world:update(world.fixedStep)
  local coasted=H.sum(liquid)
  local coastedMomentum=momentum(liquid)
  H.near(kicked.mass,before.mass,1e-4,'inertial force mass conservation')
  H.near(coasted.mass,before.mass,1e-4,'inertial coast mass conservation')
  assert(kicked.x>before.x+0.05,'liquid impulse must move mass')
  assert(coasted.x>kicked.x+0.05,'liquid momentum must survive the impulse step')
  H.near(coastedMomentum,kickedMomentum,0.05,'liquid momentum transfer conservation')
  assert(world.waterForce[4]==0,'liquid impulse must be consumed once')
  liquid:set{viscosity=1.5,velocityDamping=0.4,pressure=0.9,surfaceTension=12,gravity=1200,
    solidFriction=0.3,maxSpeed=800,volumeRelaxation=9,sleepSpeed=1.5}
  assert(not pcall(liquid.set,liquid,{spread=0.2}),'inertial liquid must reject settling controls')
  local velocity=liquid.velocity;world:reset()
  local vd=velocity:newImageData();local vx,vy=vd:getPixel(6,6);vd:release()
  H.near(vx,0,1e-7,'reset liquid velocity x');H.near(vy,0,1e-7,'reset liquid velocity y')
  world:release();assert(not pcall(velocity.getWidth,velocity),'release must free liquid velocity')

  -- The free-surface pressure solve reduces divergence in occupied cells.
  local pressureWorld=assert(gpu.newVolumeWorld{width=16,height=16,cellSize=1,transportSteps=1,liquidPressureIterations=30})
  local projected=pressureWorld:addMaterial{name='projected',model='liquid',behavior='water',gravity=0,
    viscosity=0,velocityDamping=0,surfaceTension=0,solidFriction=0,maxSpeed=500,
    volumeRelaxation=0,sleepSpeed=0,cooling=0}
  H.seed(projected.state,function(px,py) return px>=3 and px<=12 and py>=3 and py<=12 and 1 or 0,0,0,0 end)
  H.seed(projected.velocity,function(px,py)
    if px<3 or px>12 or py<3 or py>12 then return 0,0,0,0 end
    return px<8 and -20 or 20,py<8 and -20 or 20,0,0
  end)
  local divergenceBefore=divergenceEnergy(projected)
  pressureWorld:update(pressureWorld.fixedStep)
  local divergenceAfter=divergenceEnergy(projected)
  assert(divergenceAfter<divergenceBefore*0.8,'liquid pressure projection must reduce divergence')
  pressureWorld:release()

  -- Occupancy relaxation packs partial mass into the lower cell even after motion stops.
  local relaxedWorld=assert(gpu.newVolumeWorld{width=8,height=8,cellSize=1,transportSteps=1,liquidPressureIterations=1})
  local staticWorld=assert(gpu.newVolumeWorld{width=8,height=8,cellSize=1,transportSteps=1,liquidPressureIterations=1})
  local relaxed=relaxedWorld:addMaterial{name='relaxed',model='liquid',behavior='water',gravity=0,pressure=0,
    viscosity=0,velocityDamping=0,surfaceTension=0,volumeRelaxation=100,sleepSpeed=0,cooling=0}
  local static=staticWorld:addMaterial{name='static',model='liquid',behavior='water',gravity=0,pressure=0,
    viscosity=0,velocityDamping=0,surfaceTension=0,volumeRelaxation=0,sleepSpeed=0,cooling=0}
  local function partial(px,py)
    if px==3 and py==2 then return 0.8,0,0,0 end
    if px==3 and py==3 then return 0.1,0,0,0 end
    return 0,0,0,0
  end
  H.seed(relaxed.state,partial);H.seed(static.state,partial)
  relaxedWorld:update(relaxedWorld.fixedStep);staticWorld:update(staticWorld.fixedStep)
  local relaxedData,staticData=relaxedWorld:readback(relaxed),staticWorld:readback(static)
  local lowerRelaxed=relaxedData:getPixel(3,3);local lowerStatic=staticData:getPixel(3,3)
  relaxedData:release();staticData:release()
  assert(lowerRelaxed>lowerStatic+0.2,'liquid volume relaxation must fill lower cells')
  H.near(H.sum(relaxed).mass,H.sum(static).mass,1e-5,'liquid volume relaxation conservation')
  relaxedWorld:release();staticWorld:release()

  local sleepWorld=assert(gpu.newVolumeWorld{width=8,height=8,cellSize=1,transportSteps=1,liquidPressureIterations=1,
    distance=function(_,y) return 7-y end})
  local sleepy=sleepWorld:addMaterial{name='sleepy',model='liquid',behavior='water',gravity=0,pressure=0,
    viscosity=0,velocityDamping=0,surfaceTension=0,volumeRelaxation=0,sleepSpeed=2,cooling=0}
  H.seed(sleepy.state,function(px,py) return px==3 and py==6 and 1 or 0,0,0,0 end)
  H.seed(sleepy.velocity,function(px,py) return px==3 and py==6 and 1 or 0,0,0,0 end)
  sleepWorld:update(sleepWorld.fixedStep)
  local sleepingMomentum=momentum(sleepy)
  H.near(sleepingMomentum,0,1e-6,'supported liquid sleep threshold')
  sleepWorld:release()

  -- A live stream must build a filled, level pool instead of circulating partial cells forever.
  local fillWorld=assert(gpu.newVolumeWorld{width=12,height=12,cellSize=1,transportSteps=3,liquidPressureIterations=10,
    distance=function(x,y) return math.min(x-1,11-x,11-y) end})
  local filling=fillWorld:addMaterial{name='filling',model='liquid',behavior='water',cooling=0}
  fillWorld:newSource{material=filling,position={6.5,2.5},rate=4}
  for _=1,480 do fillWorld:update(1/120) end
  local fillData=fillWorld:readback(filling)
  local bottomMass,bottomCells=0,0
  for x=1,10 do
    local m=fillData:getPixel(x,10)
    bottomMass=bottomMass+m
    if m>0.7 then bottomCells=bottomCells+1 end
  end
  fillData:release()
  print(('Liquid sustained fill bottom mass %.3f across %d cells'):format(bottomMass,bottomCells))
  assert(bottomMass>7 and bottomCells>=8,'live liquid stream must fill the supported basin')
  fillWorld:release()

  local presets={water={},oil={},slime={},lava={}}
  for behavior in pairs(presets) do
    local w=assert(gpu.newVolumeWorld{width=8,height=8,liquidPressureIterations=1})
    local m=w:addMaterial{name=behavior,model='liquid',behavior=behavior}
    presets[behavior]={m.viscosity,m.velocityDamping,m.maxSpeed,m.volumeRelaxation,m.solidFriction}
    w:release()
  end
  assert(presets.water[1]<presets.oil[1] and presets.oil[1]<presets.slime[1] and presets.slime[1]<presets.lava[1],
    'liquid presets must progress from water to lava viscosity')
  assert(presets.water[3]>presets.slime[3],'water must retain faster motion than slime')
  assert(presets.water[4]>presets.oil[4] and presets.oil[4]>presets.slime[4] and presets.slime[4]>presets.lava[4],
    'liquid presets must progress from fast water settling to slow lava settling')
  assert(presets.water[5]<presets.oil[5] and presets.oil[5]<presets.slime[5] and presets.slime[5]<presets.lava[5],
    'liquid presets must progress from water to lava surface friction')
  local invalid=assert(gpu.newVolumeWorld{width=8,height=8})
  assert(not pcall(invalid.addMaterial,invalid,{name='bad',model='liquid',behavior='mist'}),'unknown liquid behavior must fail')
  assert(not pcall(invalid.addMaterial,invalid,{name='bad',model='water',behavior='water'}),'legacy water must reject behavior')
  assert(not pcall(invalid.addMaterial,invalid,{name='bad',model='liquid',behavior='water',spread=0.2}),
    'inertial liquid must reject settling controls at construction')
  invalid:release()
  print('Liquid settling compatibility / momentum / pressure / volume relaxation / sleep / presets / lifecycle PASS')
end
return M
