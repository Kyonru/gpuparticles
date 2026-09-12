local gpu=require('gpuparticles')
local H=require('tests.volume_helpers')
local M={}
function M.run()
  local w=assert(gpu.newVolumeWorld{width=32,height=32,cellSize=1,transportSteps=1})
  local m=w:addMaterial{name='water',model='water',flowSpeed=0,cooling=0}
  local a=w:newSource{material=m,position={8,8},shape='rectangle',width=3,height=3,rate=8}
  local b=w:newSource{material=m,position={22,8},radius=3,rate=4}
  w:warm(0.5);local s=H.sum(m)
  H.near(s.mass,6,1e-5,'multiple source rates');H.near(s.mass,s.added,1e-5,'water source budget')
  a:stop();b:stop();w:warm(0.5);H.near(H.sum(m).mass,6,1e-5,'stopped sources retain water')
  b:setPosition(12,15):setRadius(2):setRate(10):setTemperature(3):start();w:warm(0.2)
  H.near(H.sum(m).heat,6,1e-4,'source heat content')
  b:stop();w:pause();local time=w.time;w:update(1);assert(w.time==time)
  w:start();w:update(w.fixedStep/2);assert(w.time==time);w:update(w.fixedStep/2)
  H.near(w.time,time+w.fixedStep,1e-8,'fixed step accumulation')
  w:update(1);assert(w.droppedTime>0.9,'world update must bound catch-up')
  assert(w:getBackend()=='gpu' and gpu.getCapabilities().volume)
  assert(not pcall(w.addMaterial,w,{name='water',model='gas'}),'duplicate names must be rejected')
  assert(not pcall(w.addMaterial,w,{name='sand',model='sand'}),'unsupported models must be rejected')
  assert(not pcall(w.addMaterial,w,{name='oil',model='water'}),'multiple liquid models must be rejected')
  assert(not pcall(w.update,w,-1) and not pcall(a.setRate,a,0/0),'invalid API numbers must be rejected')
  local world2=assert(gpu.newVolumeWorld{width=8,height=8})
  assert(not pcall(world2.newSource,world2,{material=m}),'cross-world source references must be rejected')
  local gas=world2:addMaterial{name='smoke',model='gas',buoyancy=0,dissipation=0,cooling=0}
  local probe=world2:newSource{material=gas,position={4,4},rate=0}
  world2:setBoxCollider(4,4,4,4);probe:emit(8);assert(H.sum(gas).mass==0,'box must reject volume injection')
  world2:setBoxCollider();world2:setCapsuleCollider(2,4,6,4,2);probe:emit(8)
  assert(H.sum(gas).mass==0,'capsule must reject volume injection')
  world2:setCapsuleCollider();probe:emit(8);assert(H.sum(gas).mass>0,'disabled dynamic colliders must admit volume injection')
  world2:release()
  local pushWorld=assert(gpu.newVolumeWorld{width=15,height=15,cellSize=1,transportSteps=1})
  local controlWorld=assert(gpu.newVolumeWorld{width=15,height=15,cellSize=1,transportSteps=1})
  local pushed=pushWorld:addMaterial{name='pushed water',model='water',flowSpeed=1,spread=0.5,cooling=0}
  local control=controlWorld:addMaterial{name='control water',model='water',flowSpeed=1,spread=0.5,cooling=0}
  H.seed(pushed.state,function() return 0.5,0,0,0 end);H.seed(control.state,function() return 0.5,0,0,0 end)
  pushWorld:setCirclePush(7.5,7.5,5,1.4):update(pushWorld.fixedStep)
  controlWorld:update(controlWorld.fixedStep)
  local pushedSum=H.sum(pushed);H.near(pushedSum.mass,112.5,1e-4,'soft water push conserves mass')
  local pushedData=pushWorld:readback(pushed);local controlData=controlWorld:readback(control)
  local difference,minInside=0,1e6
  for py=0,14 do for px=0,14 do
    local density=pushedData:getPixel(px,py);difference=difference+math.abs(density-0.5)
    difference=difference-math.abs(controlData:getPixel(px,py)-0.5)
    if (px+0.5-7.5)^2+(py+0.5-7.5)^2<16 then minInside=math.min(minInside,density) end
  end end
  pushedData:release();controlData:release()
  assert(difference>0.1 and minInside>0.01,'soft water push must move density without carving a masked hole')
  pushWorld:setCirclePush();assert(pushWorld.push[4]==0)
  assert(not pcall(pushWorld.setCirclePush,pushWorld,1,1,2,-1),'negative water push must be rejected')
  pushWorld:reset();controlWorld:reset()
  local function forceSeed(px,py) return px>=5 and px<=9 and py>=5 and py<=9 and 0.5 or 0,0,0,0 end
  H.seed(pushed.state,forceSeed);H.seed(control.state,forceSeed)
  pushWorld:addWaterForce(7.5,7.5,5,120,0):update(pushWorld.fixedStep)
  controlWorld:update(controlWorld.fixedStep)
  local forceResult,forceControl=H.sum(pushed),H.sum(control)
  H.near(forceResult.mass,forceControl.mass,1e-5,'directional water force conserves mass')
  assert(forceResult.x>forceControl.x+0.05,'directional water force must move density along its vector')
  assert(pushWorld.waterForce[4]==0,'directional water force must be consumed after one simulation step')
  pushWorld:release();controlWorld:release()
  w:reset();assert(H.sum(m).mass==0 and w.time==0,'reset must empty the world')
  m:set{flowSpeed=1};a:setPosition(8,12):emit(8)
  local initial=H.sum(m).mass
  w:paintTerrain(8,12,5,true);w:warm(1)
  H.near(H.sum(m).mass,initial,1e-4,'painted terrain must displace water without deleting it')
  local data=w:readback(m);local inside=0
  for y=7,16 do for x=3,12 do if (x+0.5-8)^2+(y+0.5-12)^2<25 then inside=inside+data:getPixel(x,y) end end end
  data:release();assert(inside<1e-5,'painted solids must evacuate existing water')
  w:paintTerrain(8,12,5,false);data=w.terrain:newImageData();assert(data:getPixel(8,12)>0);data:release()
  w:resetTerrain()
  local state=m.state;w:release();w:release()
  assert(not pcall(state.getWidth,state) and a.released and b.released and m.released,'world release must release owned handles')
  assert(not pcall(a.start,a),'released source must reject mutation')
  print('Volume sources / dynamic colliders / runtime controls / fixed clock / validation / terrain editing / release PASS')
end
return M
