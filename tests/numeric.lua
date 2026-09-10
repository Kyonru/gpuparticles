local gpu=require('gpuparticles')
local inspect=require('tests.inspect')
local M={}
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 1e-4),('expected %.9f, got %.9f'):format(b,a)) end
function M.run()
  local e=gpu.newEmitter{max=1,lifetime=10,position={4,5},speed=20,direction=0,gravity={0,200}}
  e:emit(1);e:warm(0.5)
  local data=inspect.read(e)
  local x,y,vx,vy=data:getPixel(0,0)
  near(x,14);near(y,30);near(vx,20);near(vy,100)
  data:release();e:release()
  e=gpu.newEmitter{max=1,lifetime=10,speed=20,damping=0.4,gravity={0,200}}
  e:emit(1);e:warm(0.5);data=inspect.read(e)
  x,y,vx,vy=data:getPixel(0,0)
  local integral=(1-math.exp(-0.2))/0.4
  near(x,20*integral);near(y,200*(0.5-integral)/0.4)
  near(vx,20*math.exp(-0.2));near(vy,200*integral)
  data:release();e:release()
  print('Analytic production shader: position / velocity / damping / exact warmup PASS')

  e=gpu.newEmitter{max=9,mode='stateful',lifetime=10}
  for i=1,9 do e:setPosition(i*3,i*2):setSpeed(i):emit(1) end
  e:update(0.25);data=inspect.read(e)
  for i=1,9 do
    x,y,vx,vy=data:getPixel(i-1,0)
    near(x,i*3+i*0.25);near(y,i*2);near(vx,i);near(vy,0)
  end
  data:release();e:release()
  print('Numeric vertex fetch: nine distinct particles across texture rows PASS')

  for _,mode in ipairs{'analytic','stateful'} do
    e=gpu.newEmitter{max=2,mode=mode,rate=2,lifetime=0.25,position={0,0},speed=4}
    e:emit(2);e:update(0.3);assert(e:getCount()==0)
    e:update(0.3);assert(e:getCount()==1,'a burst must return its slot to implicit emission')
    data=inspect.read(e);x=data:getPixel(0,0);near(x,0.4)
    data:release();e:release()
  end
  print('Continuous emission recovers burst slots on the GPU PASS')

  local textureData=love.image.newImageData(1,1);textureData:setPixel(0,0,1,1,1,1)
  local texture=love.graphics.newImage(textureData);textureData:release()
  local colors={}
  for i=1,16 do colors[i]={i/16,0,0,1} end
  e=gpu.newEmitter{max=1,texture=texture,position={4,4},sizes={8},colors=colors,lifetime=15,blendMode='alpha'}
  e:emit(1);e:warm(8)
  local target=love.graphics.newCanvas(8,8,{format='rgba32f'})
  love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0);e:draw();love.graphics.pop()
  data=target:newImageData();near(data:getPixel(4,4),9/16)
  data:release();target:release();e:release();texture:release()
  print('Sixteenth-stop LUT interpolation numeric PASS')
end
return M
