local gpu=require('gpuparticles')
local M={}
local function near(a,b) assert(math.abs(a-b)<1e-5,('expected %.9f, got %.9f'):format(b,a)) end
local function pixel(canvas,x,y)
  assert(love.graphics.getCanvas()~=canvas,'readback must happen after unbinding')
  local data=canvas:newImageData();local a,b,c,d=data:getPixel(x or 0,y or 0);data:release()
  return a,b,c,d
end
function M.run()
  local e=gpu.newEmitter{max=4,mode='stateful',lifetime=10,gravity={0,200},sizes={2}}
  e:emit(1)
  local a,b=e.stateA:getFilter();assert(a=='nearest' and b=='nearest','state filtering must be nearest')
  local before=e.stateA
  e:update(1/60)
  assert(e.stateA~=before,'state must ping-pong')
  local x,y,vx,vy=pixel(e.stateA)
  near(x,0);near(y,200/3600);near(vx,0);near(vy,200/60)
  e:release()
  print('Stateful numeric gravity / replace blending / nearest / ping-pong PASS')

  local data=love.image.newImageData(2,2,'rgba32f')
  data:mapPixel(function() return 120,-60,0,1 end)
  local flow=love.graphics.newImage(data);data:release()
  e=gpu.newEmitter{max=5,lifetime=10,flowField={texture=flow,size={64,64}},position={16,16},sizes={2},colors={{1,1,1,1}}}
  assert(e:getMode()=='stateful','auto must select stateful for a flow field')
  e:emit(5);e:update(0.1)
  x,y,vx,vy=pixel(e.stateA,1,1)
  near(x,17.2);near(y,15.4);near(vx,12);near(vy,-6)
  local target=love.graphics.newCanvas(64,64,{format='rgba32f'})
  love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0);e:draw();love.graphics.setCanvas()
  local r=pixel(target,17,15);assert(r>0,'vertex texture fetch must position visible particles')
  near(pixel(e.stateA,2,2),0)
  e:release();flow:release();target:release()
  print('Flow field / auto selection / vertex texture fetch / padding PASS')

  e=gpu.newEmitter{max=2,lifetime=10,position={2,0},direction=math.pi/2,speed=10,
    collision={type='plane',y=0.5,bounce=0.5}}
  assert(e:getMode()=='stateful');e:emit(1);e:update(0.1)
  x,y,vx,vy=pixel(e.stateA);near(x,2);near(y,0.5);near(vx,0);near(vy,-5)
  e:release()
  print('Collision projection / restitution PASS')

  e=gpu.newEmitter{max=1,lifetime=10,forces={gpu.forces.custom{name='wind',stateful=true,code='return vec2(power, 0.0);',uniforms={power=4}}}}
  assert(e:getMode()=='stateful');e:emit(1);e:update(0.5)
  x,y,vx,vy=pixel(e.stateA);near(x,1);near(y,0);near(vx,2);near(vy,0)
  e:release()
  print('Custom stateful force PASS')
  data=love.image.newImageData(4,1,'rgba32f');data:mapPixel(function() return 0.5,0,0,1 end)
  local heightfield=love.graphics.newImage(data);data:release()
  e=gpu.newEmitter{max=1,lifetime=10,direction=math.pi/2,speed=10,
    collision={type='heightfield',texture=heightfield,size={4,4},bounce=0.5}}
  e:emit(1);e:update(0.1);x,y,vx,vy=pixel(e.stateA);near(x,0);near(y,0.5);near(vx,0);near(vy,-5)
  e:release();heightfield:release()
  data=love.image.newImageData(4,4,'rgba32f');data:mapPixel(function(_,row) return 2-(row+0.5),0,0,1 end)
  local sdf=love.graphics.newImage(data);data:release();sdf:setFilter('linear','linear')
  e=gpu.newEmitter{max=1,lifetime=10,position={1.5,1.5},direction=math.pi/2,speed=10,
    collision={type='sdf',texture=sdf,size={4,4},bounce=0.5}}
  e:emit(1);e:update(0.1);x,y,vx,vy=pixel(e.stateA);near(x,1.5);near(y,2);near(vx,0);near(vy,-5)
  e:release();sdf:release()
  e=gpu.newEmitter{max=1,lifetime=10,attractors={{x=4,y=0,strength=16,softening=0}}}
  assert(e:getMode()=='stateful');e:emit(1);e:update(0.5)
  x,y,vx,vy=pixel(e.stateA);near(x,0.25);near(y,0);near(vx,0.5);near(vy,0)
  e:release()
  print('Numeric heightfield / SDF / attractor forces PASS')
end
return M
