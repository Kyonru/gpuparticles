local gpu=require((...):gsub('example_support%.volume%.app$','gpuparticles'))
local A={}
local names={'water','smoke','steam'}
local W,H=960,480
function A.install()
  local world,source,terrainShader,font,title
  local index,frames,radius,wind=2,0,35,20
  local smoke,capture,requested,captured,smooth=false,false,false,false,false
  local circle,inflow=true,true
  local mx,my,previousX,previousY=0,0,0,0
  local function viewport()
    local width,height=love.graphics.getDimensions()
    local scale=math.max(0.1,math.min((width-48)/W,(height-190)/H))
    return scale,(width-W*scale)/2,120
  end
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
    if value=='--smooth' then smooth=true end
    for i,name in ipairs(names) do if value=='--preset='..name then index=i end end
  end
  local function load()
    if world then world:release() end
    local reason
    world,reason=gpu.newVolumeWorld{width=W,height=H,cellSize=6,renderStyle=smooth and 'smooth' or 'pixel',
      distance=function(x,y)
        local floor=H-12-y
        local ledge=math.max(math.abs(x-475)-145,math.abs(y-300)-9)
        if index==2 then ledge=math.max(math.abs(x-540)-90,math.abs(y-215)-9) end
        return math.min(floor,ledge)
      end}
    if not world then print(reason);return end
    local water
    if index~=2 then water=world:addMaterial{name='water',model='water',cooling=0.03} end
    if index~=1 then
      local gas=world:addMaterial{name=names[index],model='gas',buoyancy=120,dissipation=0.18,cooling=0.06,
        color=index==2 and {0.65,0.75,0.87,0.8} or {0.8,0.9,0.85,0.85},
        force={code='return swirl * vec2(sin(position.y*0.035+time),cos(position.x*0.023+time*0.7)) * min(density,1.0);',uniforms={swirl=24}}}
      if index==2 then source=world:newSource{material=gas,position={420,415},radius=18,rate=2400,temperature=2.8}
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
  return d<0.0 ? vec4(0.21,0.30,0.34,1.0) : vec4(0.0);
}]])
    load()
  end
  function love.update(dt)
    frames=frames+1
    if not world then if smoke then love.event.quit(1) end;return end
    local scale,left,top=viewport()
    previousX,previousY=mx,my
    mx,my=love.mouse.getPosition();mx,my=(mx-left)/scale,(my-top)/scale
    if smoke then mx,my=510,240 end
    local inside=mx>=0 and mx<W and my>=0 and my<H
    if circle and inside then world:setCircleCollider(mx,my,radius) else world:setCircleCollider() end
    if inside and not smoke and not world.paused then
      if love.mouse.isDown(2) then world:paintTerrain(mx,my,radius,not love.keyboard.isDown('lshift','rshift')) end
      if love.mouse.isDown(1) then
        if index==3 then world:addHeat(mx,my,radius*2,math.min(dt,0.05)*6)
        elseif world.gas then world:addForce(mx,my,radius*2,(mx-previousX)*4,(my-previousY)*4) end
      end
    end
    world:update(smoke and 1/60 or dt)
    if smoke and frames>=90 and (not capture or captured) then print('Volume standalone render PASS');love.event.quit() end
  end
  function love.draw()
    local g=love.graphics
    g.clear(0.025,0.043,0.059);g.setFont(title);g.setColor(0.85,0.92,0.92);g.print('Material volumes',24,20)
    g.setFont(font);g.setColor(0.51,0.70,0.73)
    g.print('1 Water    2 Smoke    3 Hot water / steam',25,65)
    if not world then g.print('This device cannot create the required GPU volume canvases.',25,110);return end
    local scale,left,top=viewport()
    g.setColor(0.75,0.85,0.83)
    g.printf(('%s · %s · %d FPS\n%d × %d cells · wind %d px/s'):format(names[index]:upper(),world.renderStyle,love.timer.getFPS(),world.columns,world.rows,wind),480,30,g.getWidth()-504,'right')
    g.push('all');g.translate(left,top);g.scale(scale)
    g.setScissor(left,top,W*scale,H*scale)
    g.setColor(0.018,0.03,0.041);g.rectangle('fill',0,0,W,H)
    g.setColor(0.10,0.16,0.20,0.35)
    for x=0,W,48 do g.line(x,0,x,H) end
    for y=0,H,48 do g.line(0,y,W,y) end
    world:draw()
    g.setShader(terrainShader);g.setColor(1,1,1,1);g.draw(world.terrain,0,0,0,world.cell[1],world.cell[2]);g.setShader()
    if world.circle[4]==1 then g.setColor(1,0.72,0.4,0.8);g.circle('line',mx,my,radius) end
    g.pop();g.setFont(font);g.setColor(0.65,0.78,0.80)
    local y=top+H*scale+15
    g.print('F Pixel / smooth    V Inflow '..(inflow and 'on' or 'off')..'    SPACE Pause    R Reset    C Circle    Wheel Radius    Left / Right Wind',24,y)
    g.setColor(0.43,0.61,0.65)
    g.print('Right drag: build terrain    Shift + right drag: erase    Left drag: '..(index==3 and 'heat water' or 'stir gas')..'    ESC Exit',24,y+24)
    if capture and frames>=60 and not requested then
      requested=true
      g.captureScreenshot(function(data)
        local file='volume-'..names[index]..'-'..world.renderStyle..'.png'
        data:encode('png',file);data:release();print('VOLUME_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit() end
    for i=1,3 do if key==tostring(i) then index=i;load() end end
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
