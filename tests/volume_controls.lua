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
  world2:release()
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
  print('Volume sources / runtime controls / fixed clock / validation / terrain editing / release PASS')
end
return M
