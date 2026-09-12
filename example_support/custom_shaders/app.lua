local prefix=(...):gsub('example_support%.custom_shaders%.app$','')
local gpu=require(prefix..'gpuparticles')
local A={}
function A.install()
  local emitter,canvas,shader,title,text
  local elapsed,frames=0,0
  local shaderEnabled=true
  local smoke,capture,requested,captured=false,false,false,false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
  end
  local function releaseScene()
    if emitter then emitter:release();emitter=nil end
    if canvas then canvas:release();canvas=nil end
  end
  local function loadScene()
    releaseScene()
    local width,height=love.graphics.getDimensions()
    canvas=love.graphics.newCanvas(width,height,{dpiscale=1,msaa=0})
    canvas:setFilter('linear','linear')
    emitter=gpu.newEmitter{
      max=50000,rate=11000,lifetime={2.4,4.2},seed=77,
      position={width/2,height-92},direction=-math.pi/2,spread=0.42,speed={105,205},
      gravity={0,-12},damping=0.16,sizes={2,7,3,0},blendMode='add',
      colors={{0.18,0.95,1,0},{0.2,0.9,1,0.9},{0.65,0.25,1,0.72},{1,0.2,0.55,0}},
      forces={gpu.forces.custom{
        name='helix',uniforms={amplitude=72,frequency=5.4,lift=16},
        code=[[
          float phase=seed*6.2831853;
          float envelope=1.0-exp(-age*2.0);
          return vec2(
            amplitude*(sin(age*frequency+phase)-sin(phase)),
            lift*(cos(age*frequency*0.47+phase)-cos(phase))
          )*envelope;
        ]],
      }},
    }
    assert(emitter:getMode()=='analytic','custom analytic GLSL must keep the analytic mode')
    emitter:warm(1.8)
    shader:send('u_texel',{1/width,1/height})
  end
  function love.load()
    title=love.graphics.newFont(30);text=love.graphics.newFont(13)
    shader=love.graphics.newShader(assert(love.filesystem.read(prefix..'example_support/custom_shaders/aura.glsl')))
    loadScene()
  end
  function love.resize() loadScene() end
  function love.update(dt)
    dt=math.min(dt,1/30);elapsed=elapsed+dt;frames=frames+1
    emitter:update(smoke and 1/60 or dt)
    if smoke and frames>=90 and (not capture or captured) then
      print('Custom shaders standalone render PASS');love.event.quit()
    end
  end
  function love.draw()
    local g=love.graphics
    g.push('all');g.setCanvas(canvas);g.clear(0,0,0,0);emitter:draw();g.setCanvas()
    g.clear(0.012,0.018,0.032)
    local width,height=g.getDimensions()
    g.setColor(0.12,0.34,0.43,0.18);g.setLineWidth(1)
    for y=104,height-70,48 do g.line(0,y,width,y) end
    shader:send('u_time',elapsed);shader:send('u_glow',1)
    if shaderEnabled then g.setShader(shader) end
    g.setBlendMode('alpha','premultiplied');g.setColor(1,1,1,1);g.draw(canvas);g.setShader()
    g.setBlendMode('alpha','alphamultiply')
    g.setFont(title);g.setColor(0.88,0.94,1,1);g.print('Custom shaders',28,23)
    g.setFont(text);g.setColor(0.42,0.77,0.84)
    local measured=love.timer.getFPS()
    local fps=measured>0 and (measured..' FPS') or 'FPS …'
    g.print(('analytic GLSL movement  ·  fragment shader %s  ·  %s particles  ·  %s'):format(
      shaderEnabled and 'on' or 'off',emitter:getBufferSize(),fps),29,63)
    g.setColor(0.48,0.66,0.74)
    g.print('G Shader   Space Burst   R Reset   Esc',29,height-33)
    g.pop()
    if capture and frames>=60 and not requested then
      requested=true
      g.captureScreenshot(function(data)
        local file='custom-shaders.png';data:encode('png',file);data:release()
        print('CUSTOM_SHADERS_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='g' then shaderEnabled=not shaderEnabled
    elseif key=='space' then emitter:emit(800)
    elseif key=='r' then loadScene() end
  end
  function love.quit()
    releaseScene()
    for _,resource in ipairs{shader,title,text} do if resource then resource:release() end end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return A
