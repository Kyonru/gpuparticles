local gpu=require('gpuparticles')
local T={}
local function near(a,b,label,tolerance)
  assert(math.abs(a-b)<(tolerance or 0.0001),('%s: expected %.6f, got %.6f'):format(label or 'self collision',b,a))
end
local function state(e,index)
  local data=e.stateA:newImageData();local x,y,vx,vy=data:getPixel(index%e.texSize,math.floor(index/e.texSize));data:release()
  assert(x==x and y==y and vx==vx and vy==vy,'self collision state must remain finite');return x,y,vx,vy
end
function T.run()
  local e=gpu.newEmitter{max=2,lifetime=10,position={-0.75,0},speed=1,selfCollision={radius=1,bounce=1,strength=1}}
  assert(e:getBackend()=='gpu' and e:getMode()=='stateful','self collision must use GPU stateful mode')
  e:emit(1);e:setPosition(0.75,0);e:setDirection(math.pi);e:emit(1);e:update(0.1)
  local x,y,vx,vy=state(e,0);near(x,-1,'pair separation');near(y,0);near(vx,-1,'pair bounce');near(vy,0)
  x,y,vx,vy=state(e,1);near(x,1,'pair separation');near(y,0);near(vx,1,'pair bounce');near(vy,0)
  local same=gpu.newEmitter{max=3,mode='stateful'}
  assert(same.simShader==e.simShader and not same.selfPacked,'disabled self collision must keep the original simulation shader and resource count')
  local g,draw,calls=love.graphics,love.graphics.draw,0
  g.draw=function(...) calls=calls+1;return draw(...) end
  same:update(1/60);g.draw=draw;assert(calls==1,'disabled self collision must cost exactly one simulation pass')
  calls=0;g.draw=function(...) calls=calls+1;return draw(...) end
  e:update(1/60);g.draw=draw;assert(calls==3,'one self collision iteration must add two GPU passes')
  local packed=e.selfPacked;local filter=packed:getFilter();assert(filter=='nearest','self collision state filtering must be nearest')
  local other=gpu.newEmitter{max=16,selfCollision=true}
  assert(other.selfResolve==e.selfResolve and other.selfPack==e.selfPack,'self collision shaders must be cached across capacities')
  assert(not pcall(e.setBufferSize,e,24001) and e:getBufferSize()==2,'resize must enforce the self collision cap before mutation')
  e:release();same:release();other:emit(1);other:update(1/60);other:release()
  assert(not pcall(packed.getWidth,packed),'self collision texture must be released')
  print('Self collision numeric pair separation / bounce / auto mode / disabled cost / shader cache / resize cap / release PASS')

  e=gpu.newEmitter{max=3,lifetime=0.2,selfCollision={radius=1,strength=1}}
  e:emit(1);e:update(0.1);x,y=state(e,0);near(x,0,'inactive neighbor exclusion');near(y,0)
  e:update(0.15);e:emit(1);e:update(0.01);x,y=state(e,1);near(x,0,'expired neighbor exclusion');near(y,0)
  local mask=e.selfPacked:newImageData();near(select(3,mask:getPixel(0,0)),0);near(select(3,mask:getPixel(1,0)),1)
  near(select(3,mask:getPixel(1,1)),0,'padding exclusion');mask:release();e:release()
  e=gpu.newEmitter{max=2,lifetime=10,selfCollision={radius=1,strength=1}}
  e:emit(2);e:update(1/60)
  local ax,ay=state(e,0);local bx,by=state(e,1)
  near(ax+bx,0,'coincident symmetry');near(ay+by,0);near(math.sqrt((ax-bx)^2+(ay-by)^2),2,'coincident separation')
  e:release()
  e=gpu.newEmitter{max=2,lifetime=10,position={-0.5,0},selfCollision={radius=1,strength=0.5,iterations=2}}
  e:emit(1);e:setPosition(0.5,0);e:emit(1);e:update(1/60)
  ax=state(e,0);bx=state(e,1);near(bx-ax,1.75,'iteration convergence');e:release()
  e=gpu.newEmitter{max=16,lifetime=10,gravity={0,200},selfCollision={radius=1,iterations=4},collision={type='plane',y=0,radius=1,bounce=0}}
  e:emit(16)
  local target=g.newCanvas(32,32);local shader=g.newShader('vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){return c;}')
  g.push('all');g.setCanvas(target);g.setShader(shader);g.setBlendMode('add','premultiplied');g.setScissor(3,4,10,11);g.translate(5,6)
  for _=1,30 do e:update(1/120) end
  assert(g.getCanvas()==target and g.getShader()==shader,'self collision must restore caller render targets and shaders')
  local blend,alpha=g.getBlendMode();assert(blend=='add' and alpha=='premultiplied')
  local sx,sy,sw,sh=g.getScissor();assert(sx==3 and sy==4 and sw==10 and sh==11)
  local tx,ty=g.transformPoint(0,0);near(tx,5);near(ty,6);g.pop()
  for i=0,15 do x,y,vx,vy=state(e,i);assert(y<=-0.9999,'self collision must reapply environment projection');assert(math.abs(x)+math.abs(y)+math.abs(vx)+math.abs(vy)<1000,'dense cluster must stay bounded') end
  e:reset();e:emit(16);e:update(1/120);assert(e.selfPacked);e:release();target:release();shader:release()
  print('Self collision alive mask / padding / exact overlap / iterations / dense cluster / environment / graphics restoration / reset PASS')
  for _,c in ipairs{{max=24001,selfCollision=true},{mode='analytic',selfCollision=true},{selfCollision={iterations=5}},
    {selfCollision={radius=0}},{selfCollision={bounce=2}},{selfCollision={strength=-1}},{selfCollision={iterations=1.5}}} do
    assert(not pcall(gpu.newEmitter,c),'invalid self collision settings must be rejected')
  end
  for _,option in ipairs{false,{enabled=false}} do
    e=gpu.newEmitter{max=24001,selfCollision=option};assert(e:getMode()=='analytic');e:release()
  end
  local capabilities=gpu.getCapabilities
  gpu.getCapabilities=function() local c=capabilities();c.stateful=false;return c end
  e=gpu.newEmitter{max=16,selfCollision=true};gpu.getCapabilities=capabilities
  assert(e:getBackend()=='native' and e:getMode()=='stateful' and not e.selfPacked)
  e:emit(4);e:update(1/60);e:draw();assert(e:getCount()==4);e:release()
  print('Self collision validation / opt-out analytic selection / native fallback PASS')
end
function T.install()
  function love.load() local ok,err=xpcall(T.run,debug.traceback);if not ok then print(err) end;love.event.quit(ok and 0 or 1) end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return T
