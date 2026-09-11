local gpu=require('gpuparticles')
local H=require('tests.volume_helpers')
local U=require('gpuparticles.volume.util')
local M={}
function M.run()
  local w=assert(gpu.newVolumeWorld{width=64,height=64,cellSize=2})
  local smoke=w:addMaterial{name='smoke',model='gas',buoyancy=0,dissipation=0.5,cooling=1}
  local source=w:newSource{material=smoke,position={32,48},radius=5,rate=200,temperature=2}
  source:emit(64);source:stop()
  H.near(H.sum(smoke).mass,16,1e-5,'gas source amount units')
  w:warm(1)
  local s=H.sum(smoke)
  H.near(s.mass,16*math.exp(-0.5),0.0003,'gas exponential dissipation')
  H.near(s.heat/s.mass,2*math.exp(-1),0.0003,'gas temperature cooling')
  H.near(s.mass+s.lost,s.added,0.001,'stationary gas decay budget')
  smoke:set{dissipation=0,cooling=0,buoyancy=100};w:reset();source:start();w:warm(1)
  s=H.sum(smoke);assert(s.y<46,'hot smoke buoyancy must lift the plume')
  print(('Gas buoyancy centroid y %.3f (source 48)'):format(s.y))
  smoke:set{buoyancy=0};w:reset();w:setWind(50,0);w:warm(1)
  assert(H.sum(smoke).x>34,'wind must advect smoke horizontally')
  w:release()

  w=assert(gpu.newVolumeWorld{width=64,height=64,cellSize=1,pressureIterations=40,
    distance=function(x) return math.floor(x)==32 and -1 or 1 end})
  smoke=w:addMaterial{name='smoke',model='gas',buoyancy=0,dissipation=0,cooling=0}
  w:newSource{material=smoke,position={25,32},radius=2,rate=50}
  w:setWind(90,0);w:warm(1)
  local d=w:readback(smoke);local behind=0
  for y=0,63 do for x=33,63 do behind=behind+d:getPixel(x,y) end end
  d:release();assert(behind<1e-7,'gas must not advect through a one-cell wall')
  w:setCircleCollider(25,32,5);w:update(1/120)
  d=w:readback(smoke);local density=d:getPixel(25,32);d:release()
  assert(density==0,'gas must exclude the circle collider')
  w:release()
  print('Gas density / temperature / buoyancy / wind / wall and circle collision PASS')

  w=assert(gpu.newVolumeWorld{width=32,height=32,cellSize=1,pressureIterations=60})
  w:addMaterial{name='smoke',model='gas'}
  H.seed(w.gas.state,function(x,y)
    local dx,dy=x-15.5,y-15.5;local f=math.exp(-(dx*dx+dy*dy)/30)
    return dx*f,dy*f,0,0
  end)
  local function divergence()
    U.guard(function() U.pass(w,w.shaders.divergence,w.gas.divergence,w.gas.state) end)
    local data=w.gas.divergence:newImageData();local sum=0
    for y=0,31 do for x=0,31 do local value=data:getPixel(x,y);sum=sum+value*value end end
    data:release();return sum
  end
  local before=divergence();U.guard(function() w:_project() end);local after=divergence()
  assert(after<before*0.4,'gas pressure projection must reduce divergence')
  print(('Gas pressure projection squared divergence %.5f -> %.5f PASS'):format(before,after))
  w:release()
end
return M
