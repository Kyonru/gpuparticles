local gpu=require('gpuparticles')
local M={}
local function memoryStable(fn,label)
  fn();fn();collectgarbage('collect');collectgarbage('stop')
  fn() -- materialize interpreter/C-call caches after the collection
  local before=collectgarbage('count')
  fn()
  local difference=collectgarbage('count')-before
  collectgarbage('restart')
  assert(difference<0.01,label..' allocated '..difference..' KiB')
end
function M.run()
  for _,mode in ipairs{'analytic','stateful'} do
    local e=gpu.newEmitter{max=16,mode=mode,rate=10,lifetime=5}
    local canvas=love.graphics.newCanvas(32,32)
    local callerShader=love.graphics.newShader('vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc) { return c*Texel(t,uv); }')
    local g=love.graphics
    g.push('all');g.setCanvas(canvas);g.setShader(callerShader);g.setColor(0.3,0.4,0.5,0.6)
    g.setBlendMode('alpha','premultiplied');g.setScissor(2,3,20,21);g.translate(8,9)
    e:emit(2);e:update(1/60);e:draw()
    assert(g.getCanvas()==canvas and g.getShader()==callerShader,'canvas and shader must be restored')
    local r,green,b,a=g.getColor();assert(r==0.3 or math.abs(r-0.3)<1e-6);assert(green>0.39 and b==0.5 and a>0.59)
    local blend,alpha=g.getBlendMode();assert(blend=='alpha' and alpha=='premultiplied')
    local x,y,w,h=g.getScissor();assert(x==2 and y==3 and w==20 and h==21)
    x,y=g.transformPoint(0,0);assert(x==8 and y==9)
    g.pop()
    local function frames()
      for _=1,100 do e:update(1/10000);e:draw() end
    end
    memoryStable(frames,mode..' update + draw')
    e:release();canvas:release();callerShader:release()
  end
  print('Graphics state restoration / allocation-free GPU update + draw PASS')
  local source=love.graphics.newCanvas(8,8,{format='rgba32f'})
  local treated=love.graphics.newCanvas(8,8,{format='rgba32f'})
  local post=love.graphics.newShader(assert(love.filesystem.read('example_support/library/showcase.glsl')))
  post:send('u_texel',{1/8,1/8});post:send('u_time',0.5)
  love.graphics.push('all');love.graphics.setCanvas(source);love.graphics.setBlendMode('replace','premultiplied')
  love.graphics.clear(0.8,0.2,0.4,0)
  love.graphics.setCanvas(treated);love.graphics.clear(0,0,0,0);love.graphics.setShader(post);love.graphics.draw(source)
  love.graphics.setCanvas();love.graphics.pop()
  local pixels=treated:newImageData();local r,g,b,a=pixels:getPixel(4,4);pixels:release()
  assert(r+g+b>0.1 and a>0.1,'post shader must derive coverage from additive RGB when alpha is empty')
  source:release();treated:release();post:release()
  print('Particle post shader additive RGB coverage PASS')
  local e=gpu.newEmitter{max=4,noFFI=true,attractors={}}
  assert(e:getMode()=='analytic','empty attractors must not promote to stateful')
  e:emit(2);e:draw();e:release()
  local ok,err=pcall(gpu.newEmitter,{collision={type='typo'}})
  assert(not ok and err:find('collision type'))
  print('No-FFI path / empty force set / validation PASS')
end
return M
