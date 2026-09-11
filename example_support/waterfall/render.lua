local directory=(...):gsub('render$',''):gsub('%.','/')
local R={}
R.__index=R
local W,H=1280,800
local Plants=require((...):gsub('render$','plants'))
local function ribbon(points)
  local vertices={}
  for i=1,#points-1 do
    local a,b=points[i],points[i+1]
    for j=0,11 do
      local t=j/12
      local x,y,w=a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t
      local v=((i-1)+t)/(#points-1)
      vertices[#vertices+1]={x-w/2,y,0,v}
      vertices[#vertices+1]={x+w/2,y,1,v}
    end
  end
  local last=points[#points]
  vertices[#vertices+1]={last[1]-last[3]/2,last[2],0,1}
  vertices[#vertices+1]={last[1]+last[3]/2,last[2],1,1}
  return love.graphics.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2}},vertices,'strip','static')
end
function R.new(terrain)
  local self=setmetatable({terrain=terrain,owned={},ribbons={},circle={0,0,0,0}},R)
  local g=love.graphics
  local function own(resource) self.owned[#self.owned+1]=resource;return resource end
  local function shader(name)
    local source=assert(love.filesystem.read(directory..'shaders/'..name..'.glsl'))
    return own(g.newShader(source))
  end
  local function canvas(draw)
    local c=own(g.newCanvas(W,H,{dpiscale=1,msaa=0}))
    g.push('all');g.setCanvas(c);g.origin();g.setScissor();g.setShader();g.setColor(1,1,1,1)
    g.setBlendMode('alpha');g.clear(0,0,0,0);draw();g.pop()
    return c
  end
  self.curtain=shader('curtain');self.pool=shader('pool');self.rock=shader('rock')
  self.curtain:send('u_distance',terrain.field);self.curtain:send('u_worldSize',{W,H})
  self.rock:send('u_distance',terrain.field);self.rock:send('u_worldSize',{W,H});self.rock:send('u_canvasSize',{W,H})
  self.background=canvas(function()
    for y=0,H-1,2 do
      local t=y/H
      g.setColor(0.065-0.033*t,0.16-0.067*t,0.19-0.060*t)
      g.rectangle('fill',0,y,W,2)
    end
    g.setColor(0.29,0.49,0.43,0.04);g.polygon('fill',660,0,742,0,944,H,306,H)
    g.setColor(0.32,0.5,0.44,0.04);g.polygon('fill',780,0,812,0,1050,H,454,H)
    -- Distant trunks and canyon silhouettes are scenery, separate from the four collidable foreground rocks.
    for i=0,34 do
      local x=i*43+math.sin(i*4)*20
      local top=62+math.sin(i*2.9)*30
      g.setColor(0.11,0.22,0.23,0.38);g.rectangle('fill',x,top,3,520)
      g.setColor(0.09,0.19,0.20,0.32)
      for k=0,5 do g.polygon('fill',x+1,top+k*32,x-24+k*2,top+80+k*32,x+25-k*2,top+80+k*32) end
    end
    g.setColor(0.066,0.125,0.155)
    g.polygon('fill',0,0,388,0,443,94,417,198,462,283,419,442,392,551,417,692,351,800,0,800)
    g.setColor(0.047,0.107,0.139)
    g.polygon('fill',1280,0,1076,0,1040,134,1075,253,1010,363,1042,442,948,551,941,800,1280,800)
    g.setColor(0.027,0.072,0.093)
    g.polygon('fill',0,0,271,0,311,155,282,305,331,473,281,622,321,800,0,800)
    g.polygon('fill',1280,0,1160,0,1108,282,1146,444,1103,583,1139,800,1280,800)
    for i=0,35 do
      local y=i*25
      g.setColor(0.18,0.25,0.23,0.12);g.setLineWidth(1)
      g.line(20,y,136,y-15,262,y-6,316,y-26)
      g.setColor(0.19,0.29,0.25,0.10);g.line(1103,y+33,1180,y+10,1278,y+22)
    end
    -- The source shelf meets the first water ribbon.
    g.setColor(0.07,0.145,0.16);g.polygon('fill',364,71,570,67,618,92,571,114,437,123,392,151)
    g.setColor(0.18,0.32,0.25);g.line(369,70,568,66,596,83)
  end)
  self.rock:send('u_overlay',false)
  self.rocks=canvas(function()
    g.setShader(self.rock);g.setColor(1,1,1,1)
    for _,rock in ipairs(terrain.rocks) do terrain:drawRock(rock) end
    g.setShader()
    for _,rock in ipairs(terrain.rocks) do
      g.push();g.translate(rock.x,rock.y);g.rotate(rock.angle)
      g.setColor(0.21,0.34,0.26,0.7);g.setLineWidth(3)
      g.line(-rock.w/2+rock.radius,-rock.h/2+2,rock.w/2-rock.radius,-rock.h/2+2)
      g.setColor(0.02,0.05,0.07,0.42);g.setLineWidth(2)
      for i=1,5 do
        local x=-rock.w/2+i*rock.w/6
        g.line(x,-rock.h/2+13,x+7,0,x-1,rock.h/2-8)
      end
      g.pop()
    end
  end)
  local back,front={},{}
  for i=1,12 do back[#back+1]={325+i*18,97+math.sin(i)*20,0.5+i%3*0.2,-0.5+i%4*0.24} end
  for i=1,8 do front[#front+1]={435+i*9,311+i*2,0.35+i%3*0.15,-0.7+i*0.12} end
  for i=1,10 do front[#front+1]={861+i*7,445-i*2,0.4+i%3*0.18,-0.4+i*0.12} end
  for i=1,8 do front[#front+1]={425+i*12,635-i*1.4,0.55,-0.7+i*0.17} end
  for i=1,13 do front[#front+1]={20+i*24,779+math.sin(i)*13,0.6+i%4*0.2,-0.6+i%5*0.2} end
  self.backPlants=own(Plants.new(back));self.frontPlants=own(Plants.new(front))
  self.foregroundCanvas=canvas(function()
    g.setColor(0.018,0.055,0.064);g.polygon('fill',0,740,93,693,193,742,319,725,411,800,0,800)
  end)
  self.overlay=canvas(function()
    self.rock:send('u_overlay',true);g.setShader(self.rock);g.rectangle('fill',0,0,W,H);g.setShader()
  end)
  self.rock:send('u_overlay',false)
  local paths={
    {{580,92,65},{577,191,65},{582,280,79},{594,363,105}},
    {{591,323,22},{637,336,22},{677,355,24}},
    {{680,360,31},{710,416,40},{736,477,62},{750,530,75}},
    {{752,496,27},{701,518,32},{670,548,33}},
    {{675,547,43},{653,591,50},{630,645,68},{616,701,99}},
  }
  for _,points in ipairs(paths) do self.ribbons[#self.ribbons+1]=own(ribbon(points)) end
  self.poolMesh=own(g.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2}},
    {{0,terrain.poolY,0,0},{W,terrain.poolY,1,0},{W,H,1,1},{0,H,0,1}},'fan','static'))
  self.title=own(g.newFont(36));self.text=own(g.newFont(13));self.small=own(g.newFont(11))
  return self
end
function R:base(time,waterVolume)
  local g=love.graphics
  g.setColor(1,1,1,1);g.draw(self.background)
  self.backPlants:draw(time)
  if not waterVolume then self.pool:send('u_time',time);g.setShader(self.pool);g.draw(self.poolMesh);g.setShader() end
end
function R:water(time,mouse)
  local g=love.graphics
  local c=self.circle
  c[1],c[2],c[3],c[4]=mouse.x,mouse.y,mouse.radius,mouse.enabled and mouse.inside and 1 or 0
  self.curtain:send('u_circle',c)
  self.curtain:send('u_time',time);g.setShader(self.curtain);g.setColor(1,1,1,1)
  for _,mesh in ipairs(self.ribbons) do g.draw(mesh) end
  g.setShader()
end
function R:mouseObstacle(mouse)
  if not mouse.enabled or not mouse.inside then return end
  local g=love.graphics
  g.setColor(0.99,0.73,0.43,0.10);g.circle('fill',mouse.x,mouse.y,mouse.radius)
  g.setColor(0.99,0.73,0.43,0.9);g.setLineWidth(1.5);g.circle('line',mouse.x,mouse.y,mouse.radius)
  g.setFont(self.small);g.print(('%d px'):format(mouse.radius),mouse.x+mouse.radius+7,mouse.y-6)
end
function R:environment() love.graphics.setColor(1,1,1,1);love.graphics.draw(self.rocks) end
function R:updatePlants(dt,time,mouse)
  self.backPlants:update(dt,time,mouse);self.frontPlants:update(dt,time,mouse)
end
function R:foreground(time)
  love.graphics.setColor(1,1,1,1);love.graphics.draw(self.foregroundCanvas);self.frontPlants:draw(time)
end
function R:debug()
  love.graphics.setColor(1,1,1,1);love.graphics.draw(self.overlay)
end
function R:hud(scene)
  local g=love.graphics
  g.setFont(self.small);g.setColor(0.47,0.72,0.66);g.print('PARTICLE STUDIES  /  01',48,41)
  g.setFont(self.title);g.setColor(0.85,0.92,0.85);g.print('Basalt Falls',45,59)
  g.setFont(self.text);g.setColor(0.53,0.68,0.67);g.print('Water, stone, and a little GPU weather.',48,107)
  g.setFont(self.small);g.setColor(0.58,0.79,0.74)
  local backend=scene.drops:getBackend()
  local contacts=backend~='gpu' and 'UNAVAILABLE' or scene.selfCollision and 'ON' or 'OFF'
  local diagnostic=scene.fluid and ('WATER VOLUME  /  %d × %d GRID\nINFLOW  /  %s\nPARTICLE LAYERS  /  SUSPENDED\nFIXED STEP  /  120 Hz · %d FPS'):format(
    scene.fluid.columns,scene.fluid.rows,scene.inflow and 'ON' or 'OFF',love.timer.getFPS())
    or ('DROPLETS  /  %s\nSELF COLLISION  /  %s · %d SLOTS\nSPRAY + MIST  /  ANALYTIC\nFIXED STEP  /  120 Hz · %d FPS'):format(
      backend=='gpu' and 'GPU COLLISION' or 'NATIVE FALLBACK',contacts,scene.drops.config.max,love.timer.getFPS())
  g.printf(diagnostic,912,45,320,'right')
  local legend=scene.fluid and ('1 Water %s    D Collision map %s    ·    Close a gap with the circle; move it away to drain.'):format(
    scene.layers.curtain and 'on' or 'off',scene.layers.field and 'on' or 'off')
    or ('1 Curtain %s    2 Droplets %s    3 Spray + mist %s    D Collision map %s'):format(
      scene.layers.curtain and 'on' or 'off',scene.layers.drops and 'on' or 'off',scene.layers.mist and 'on' or 'off',scene.layers.field and 'on' or 'off')
  g.setColor(0.02,0.06,0.08,0.8);g.rectangle('fill',35,692,1210,88,6,6)
  g.setFont(self.text);g.setColor(0.68,0.83,0.79);g.print(legend,49,702)
  local status=scene.fluid and 'F Water volume on    V Inflow '..(scene.inflow and 'on' or 'off')..'    ·    R Empty and restart'
    or 'F Water volume '..(scene.volumeUnavailable and 'unavailable on this GPU' or 'off')
  g.print(status,49,722)
  g.print(scene.fluid and 'Water stays in the scene. It spreads, rises, and spills around obstacles.' or
    ('S Self collision %s  /  %d slots · %d droplets/s in both modes'):format(contacts:lower(),scene.drops.config.max,scene.drops.config.rate),49,742)
  g.setFont(self.small);g.setColor(0.43,0.61,0.60)
  g.print('C Mouse '..(scene.mouse.enabled and 'on' or 'off')..'    Wheel Radius    SPACE '..(scene.paused and 'Resume' or 'Pause')..'    R Restart    H Hide controls    ESC Exit',49,762)
  g.printf(scene.layers.field and 'CORAL = SOLID  /  TEAL = AIR' or ('W Wind '..(scene.wind and 'on' or 'off')..' · brush the ferns'),955,762,273,'right')
end
function R:release() for _,resource in ipairs(self.owned) do resource:release() end end
return R
