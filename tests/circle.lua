local gpu=require('gpuparticles')
local M={}
local function near(a,b) assert(math.abs(a-b)<0.001,('collider expected %.6f, got %.6f'):format(b,a)) end
local function state(e)
  assert(love.graphics.getCanvas()~=e.stateA,'unbind state before readback')
  local data=e.stateA:newImageData()
  local x,y,vx,vy=data:getPixel(0,0);data:release();return x,y,vx,vy
end
function M.run()
  local e=gpu.newEmitter{max=1,lifetime=10,position={80,99},speed=math.sqrt(10100),direction=math.atan2(10,100),
    circleCollider={x=100,y=100,radius=10,particleRadius=2,bounce=0.5,friction=0.25}}
  assert(e:getMode()=='stateful' and e:getBackend()=='gpu','circle requires automatic stateful selection')
  e:emit(1);e:update(0.1)
  local x,y,vx,vy=state(e);near(x,88);near(y,100);near(vx,-50);near(vy,7.5)
  local canvas,mesh,shader=e.stateA,e.instances,e.simShader
  assert(canvas and mesh and shader)
  e:setCircleCollider(110,100,22)
  assert(e.stateA==canvas and e.instances==mesh and e.simShader==shader,'moving circle must preserve GPU resources')
  e:emit(1);e:update(0.1)
  x,y,vx,vy=state(e);near(x,86);near(y,100);near(vx,-50);near(vy,7.5)
  e:setCircleCollider();e:emit(1);e:update(0.1)
  x,y,vx,vy=state(e);near(x,90);near(y,100);near(vx,100);near(vy,10)
  assert(not pcall(e.setCircleCollider,e,0,0,-1),'negative radius must be rejected')
  e:setCircleCollider(100,100,10)
  for i=1,1000 do e:setCircleCollider(i,100,10) end
  collectgarbage('collect');collectgarbage('stop')
  local memory=collectgarbage('count')
  for i=1,10000 do e:setCircleCollider(i,100,10) end
  local allocated=collectgarbage('count')-memory
  collectgarbage('restart');assert(allocated<0.01,'moving circle must not allocate per update')
  e:release()
  print('Circle auto mode / numeric projection / bounce / friction / live movement / disabled control / allocation PASS')

  e=gpu.newEmitter{max=1,lifetime=10,position={100,100},circleCollider={x=100,y=100,radius=10,particleRadius=2}}
  e:emit(1);e:update(0.1)
  x,y,vx,vy=state(e);near(x,100);near(y,88);near(vx,0);near(vy,0)
  local other=gpu.newEmitter{max=1,mode='stateful',position={100,100},lifetime=10}
  assert(other.simShader==e.simShader,'circle movement must use the shared simulation shader')
  other:emit(1);other:update(0.1)
  x,y=state(other);near(x,100);near(y,100);other:release();e:release()
  e=gpu.newEmitter{max=1,lifetime=10,position={2,0},speed=10,direction=math.pi/2,
    collision={type='plane',y=0.5,bounce=0.5},circleCollider={x=100,y=100,radius=10}}
  e:emit(1);e:update(0.1)
  x,y,vx,vy=state(e);near(x,2);near(y,0.5);near(vx,0);near(vy,-5);e:release()
  local ok,message=pcall(gpu.newEmitter,{mode='analytic',circleCollider={radius=10}})
  assert(not ok and message:find('requires stateful'))
  e=gpu.newEmitter{max=1}
  assert(not pcall(e.setCircleCollider,e,0,0,10),'analytic setters must refuse collision without silent promotion');e:release()
  print('Circle exact-center normal / shader sharing / uniform isolation / environment coexistence / analytic rejection PASS')

  e=gpu.newEmitter{max=1,lifetime=10,position={80,100},speed=100,direction=0,
    boxCollider={x=100,y=100,width=20,height=20,particleRadius=2,bounce=0.5,friction=0.25}}
  assert(e:getMode()=='stateful','box requires automatic stateful selection')
  e:emit(1);e:update(0.1);x,y,vx,vy=state(e);near(x,88);near(y,100);near(vx,-50);near(vy,0)
  canvas,mesh,shader=e.stateA,e.instances,e.simShader;e:setBoxCollider(110,100,30,18)
  assert(e.stateA==canvas and e.instances==mesh and e.simShader==shader,'moving box must preserve GPU resources')
  e:setBoxCollider();assert(not e.config.boxCollider.enabled);e:release()

  e=gpu.newEmitter{max=1,lifetime=10,position={80,100},speed=100,direction=0,
    capsuleCollider={x1=100,y1=90,x2=100,y2=110,radius=10,particleRadius=2,bounce=0.5,friction=0.25}}
  assert(e:getMode()=='stateful','capsule requires automatic stateful selection')
  e:emit(1);e:update(0.1);x,y,vx,vy=state(e);near(x,88);near(y,100);near(vx,-50);near(vy,0)
  canvas,mesh,shader=e.stateA,e.instances,e.simShader;e:setCapsuleCollider(105,90,105,110,12)
  assert(e.stateA==canvas and e.instances==mesh and e.simShader==shader,'moving capsule must preserve GPU resources')
  e:setCapsuleCollider();assert(not e.config.capsuleCollider.enabled);e:release()
  assert(not pcall(gpu.newEmitter,{mode='analytic',boxCollider={width=10,height=10}}))
  assert(not pcall(gpu.newEmitter,{mode='analytic',capsuleCollider={radius=10}}))
  print('Box and capsule auto mode / numeric projection / response / live movement / analytic rejection PASS')
end
return M
