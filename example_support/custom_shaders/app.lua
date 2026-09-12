local prefix=(...):gsub('example_support%.custom_shaders%.app$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local GifCapture=require(prefix..'example_support.gif_capture')
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
  local gif=GifCapture.new('custom-shaders')
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
      colors={{palette.teal[1],palette.teal[2],palette.teal[3],0},
        {palette.teal[1],palette.teal[2],palette.teal[3],0.92},
        {palette.blue[1],palette.blue[2],palette.blue[3],0.76},
        {palette.peach[1],palette.peach[2],palette.peach[3],0}},
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
    if smoke and frames>=90 and (not capture or captured) and (not gif or gif.done) then
      print('Custom shaders standalone render PASS');love.event.quit()
    end
  end
  function love.draw()
    local g=love.graphics
    g.push('all');g.setCanvas(canvas);g.clear(0,0,0,0);emitter:draw();g.setCanvas()
    g.clear(palette.ink)
    local _,height=g.getDimensions()
    shader:send('u_time',elapsed);shader:send('u_glow',1)
    if shaderEnabled then g.setShader(shader) end
    g.setBlendMode('alpha','premultiplied');g.setColor(1,1,1,1);g.draw(canvas);g.setShader()
    g.setBlendMode('alpha','alphamultiply')
    g.setFont(title);g.setColor(palette.beige);g.print('Custom shaders',28,23)
    g.setFont(text);g.setColor(palette.teal)
    local measured=love.timer.getFPS()
    local fps=measured>0 and (measured..' FPS') or 'FPS …'
    g.print(('analytic GLSL movement  ·  fragment shader %s  ·  %s particles  ·  %s'):format(
      shaderEnabled and 'on' or 'off',emitter:getBufferSize(),fps),29,63)
    g.setColor(palette.blue)
    g.print('G Shader   Space Burst   R Reset   Esc',29,height-33)
    g.pop()
    if gif then gif:draw(frames) end
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
