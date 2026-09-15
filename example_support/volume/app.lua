local gpu=require((...):gsub('example_support%.volume%.app$','gpuparticles'))
local prefix=(...):gsub('example_support%.volume%.app$','')
local palette=require(prefix..'example_support.palette')
local GifCapture=require(prefix..'example_support.gif_capture')
local A={}
local presets={
  {id='water',title='Water',kind='liquid',behavior='water',color={0.18,0.50,0.74,0.9}},
  {id='settling',title='Settling mud',kind='liquid',behavior='settling',color={0.38,0.27,0.17,0.92}},
  {id='oil',title='Oil',kind='liquid',behavior='oil',color={0.48,0.36,0.10,0.9}},
  {id='slime',title='Slime',kind='liquid',behavior='slime',color={0.20,0.58,0.28,0.92}},
  {id='smoke',title='Smoke',kind='gas'},
  {id='steam',title='Steam',kind='steam'},
}
local W,H=960,480
function A.install()
  local world,source,terrainShader,font,title
  local index,frames,radius,wind=1,0,35,20
  local smoke,capture,requested,captured,smooth=false,false,false,false,false
  local circle,inflow=true,true
  local mx,my,previousX,previousY=0,0,0,0
  local function viewport()
    local width,height=love.graphics.getDimensions()
    local scale=math.max(0.1,math.min((width-48)/W,(height-120)/H))
    return scale,(width-W*scale)/2,68
  end
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
    if value=='--smooth' then smooth=true end
    for i,preset in ipairs(presets) do if value=='--preset='..preset.id then index=i end end
  end
  local gif=GifCapture.new('volume-'..presets[index].id..(smooth and '-smooth' or '-pixel'))
  local function load()
    if world then world:release() end
    local preset=presets[index]
    local reason
    world,reason=gpu.newVolumeWorld{width=W,height=H,cellSize=6,renderStyle=smooth and 'smooth' or 'pixel',
      liquidPressureIterations=10,
      distance=function(x,y)
        local floor=H-12-y
        local ledge=math.max(math.abs(x-475)-145,math.abs(y-300)-9)
        if preset.kind=='gas' then ledge=math.max(math.abs(x-540)-90,math.abs(y-215)-9) end
        return math.min(floor,ledge)
      end}
    if not world then print(reason);return end
    local water
    if preset.kind=='liquid' or preset.kind=='steam' then
      water=world:addMaterial{name=preset.kind=='steam' and 'water' or preset.id,model='liquid',
        behavior=preset.kind=='steam' and 'water' or preset.behavior,cooling=0.03,
        color=preset.color or {palette.blue[1],palette.blue[2],palette.blue[3],0.9}}
    end
    if preset.kind=='gas' or preset.kind=='steam' then
      local gas=world:addMaterial{name=preset.id,model='gas',buoyancy=120,dissipation=0.18,cooling=0.06,
        color=preset.kind=='gas' and {palette.teal[1],palette.teal[2],palette.teal[3],0.82}
          or {palette.beige[1],palette.beige[2],palette.beige[3],0.88},
        force={code='return swirl * vec2(sin(position.y*0.035+time),cos(position.x*0.023+time*0.7)) * min(density,1.0);',uniforms={swirl=24}}}
      if preset.kind=='gas' then source=world:newSource{material=gas,position={420,415},radius=18,rate=2400,temperature=2.8}
      else
        world:addReaction{from=water,to=gas,temperatureAbove=1,rate=0.7}
        source=world:newSource{material=water,position={470,100},radius=12,rate=2000,temperature=2}
      end
    else source=world:newSource{material=water,position={450,70},radius=16,rate=5500} end
    world:setWind(wind,0);inflow=true
    if smoke then world:warm(3) end
  end
  function love.load()
    font=love.graphics.newFont(14);title=love.graphics.newFont(30)
    terrainShader=love.graphics.newShader([[#pragma language glsl3
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
  float d=Texel(tex,tc).r;
  return d<0.0 ? vec4(0.404,0.635,0.773,1.0) : vec4(0.0);
}]])
    load()
  end
  function love.update(dt)
    frames=frames+1
    if not world then if smoke then love.event.quit(1) end;return end
    local preset=presets[index]
    local scale,left,top=viewport()
    previousX,previousY=mx,my
    mx,my=love.mouse.getPosition();mx,my=(mx-left)/scale,(my-top)/scale
    if smoke then mx,my=510,240 end
    local inside=mx>=0 and mx<W and my>=0 and my<H
    if circle and inside then world:setCircleCollider(mx,my,radius) else world:setCircleCollider() end
    if inside and not smoke and not world.paused then
      if love.mouse.isDown(2) then world:paintTerrain(mx,my,radius,not love.keyboard.isDown('lshift','rshift')) end
      if love.mouse.isDown(1) then
        if preset.kind=='steam' then world:addHeat(mx,my,radius*2,math.min(dt,0.05)*6)
        elseif preset.kind=='gas' then world:addForce(mx,my,radius*2,(mx-previousX)*4,(my-previousY)*4)
        else world:addWaterForce(mx,my,radius*2,(mx-previousX)*8,(my-previousY)*8) end
      end
    end
    world:update(smoke and 1/60 or dt)
    if smoke and frames>=90 and (not capture or captured) and (not gif or gif.done) then print('Volume standalone render PASS');love.event.quit() end
  end
  function love.draw()
    local g=love.graphics
    local preset=presets[index]
    local displayName=preset.title
    g.clear(palette.ink);g.setFont(title);g.setColor(palette.beige);g.print(displayName,24,18)
    g.setFont(font)
    if not world then g.setColor(palette.teal);g.print('GPU volume canvases unavailable',25,58);return end
    local scale,left,top=viewport()
    g.setColor(palette.teal)
    g.printf(('%s · %d × %d · %d FPS'):format(world.renderStyle,world.columns,world.rows,love.timer.getFPS()),480,28,g.getWidth()-504,'right')
    g.push('all');g.translate(left,top);g.scale(scale)
    g.setScissor(left,top,W*scale,H*scale)
    g.setColor(palette.deep);g.rectangle('fill',0,0,W,H)
    world:draw()
    g.setShader(terrainShader);g.setColor(1,1,1,1);g.draw(world.terrain,0,0,0,world.cell[1],world.cell[2]);g.setShader()
    if world.circle[4]==1 then g.setColor(palette.peach);g.circle('line',mx,my,radius) end
    g.pop();g.setFont(font);g.setColor(palette.blue)
    local action=preset.kind=='steam' and '   LMB Heat' or '   LMB Stir'
    g.print(('1 Water   2 Settling   3 Oil   4 Slime   5 Smoke   6 Steam   F Style   V Inflow %s   C Circle   Wheel Size%s   RMB Terrain   Space Pause   R Reset   Esc'):format(
      inflow and 'on' or 'off',action),24,top+H*scale+16)
    if gif then gif:draw(frames) end
    if capture and frames>=60 and not requested then
      requested=true
      g.captureScreenshot(function(data)
        local file='volume-'..preset.id..'-'..world.renderStyle..'.png'
        data:encode('png',file);data:release();print('VOLUME_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit() end
    for i=1,#presets do if key==tostring(i) then index=i;load() end end
    if not world then return end
    if key=='f' then smooth=not smooth;world:setRenderStyle(smooth and 'smooth' or 'pixel') end
    if key=='v' then inflow=not inflow;if inflow then source:start() else source:stop() end end
    if key=='space' then if world.paused then world:start() else world:pause() end end
    if key=='r' then world:reset():resetTerrain() end
    if key=='c' then circle=not circle end
    if key=='left' or key=='right' then wind=math.max(-100,math.min(100,wind+(key=='left' and -10 or 10)));world:setWind(wind,0) end
  end
  function love.wheelmoved(_,y) radius=math.max(8,math.min(100,radius+y*4)) end
  function love.quit()
    if world then world:release() end
    for _,resource in ipairs{font,title,terrainShader} do resource:release() end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return A
