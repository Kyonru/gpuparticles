local prefix=(...):gsub('example_support%.colliders%.app$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local A={}
function A.install()
  local emitter,title,text
  local selected,time,accumulator,frames=3,0,0,0
  local mx,my=0,0
  local smoke,capture,requested,captured=false,false,false,false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
  end
  local function releaseEmitter() if emitter then emitter:release();emitter=nil end end
  local function loadEmitter()
    releaseEmitter()
    local width,height=love.graphics.getDimensions();mx,my=width/2,height*0.38
    emitter=gpu.newEmitter{
      max=20000,rate=5200,lifetime={2.5,4},seed=29,
      position={width/2,32},emissionArea={distribution='uniform',x=width*0.42,y=0},
      direction=math.pi/2,spread=0.08,speed={35,90},gravity={0,260},damping=0.04,sizes={4,6,3},
      colors={{palette.blue[1],palette.blue[2],palette.blue[3],0.2},
        {palette.teal[1],palette.teal[2],palette.teal[3],0.9},
        {palette.peach[1],palette.peach[2],palette.peach[3],0.7},
        {palette.beige[1],palette.beige[2],palette.beige[3],0}},
      collision={type='plane',y=height-66,radius=3,bounce=0.25,friction=0.04},
      circleCollider={radius=58,particleRadius=3,bounce=0.35,friction=0.05,enabled=false},
      boxCollider={width=170,height=90,particleRadius=3,bounce=0.35,friction=0.05,enabled=false},
      capsuleCollider={radius=30,particleRadius=3,bounce=0.35,friction=0.05,enabled=false},
    }
    assert(emitter:getMode()=='stateful','dynamic colliders must select stateful mode')
    emitter:warm(1.2)
  end
  local function moveCollider()
    emitter:setCircleCollider();emitter:setBoxCollider();emitter:setCapsuleCollider()
    if selected==1 then emitter:setCircleCollider(mx,my,58)
    elseif selected==2 then emitter:setBoxCollider(mx,my,170,90)
    else
      local angle=time*0.65;local dx,dy=math.cos(angle)*88,math.sin(angle)*88
      emitter:setCapsuleCollider(mx-dx,my-dy,mx+dx,my+dy,30)
    end
  end
  function love.load()
    title=love.graphics.newFont(30);text=love.graphics.newFont(13);loadEmitter()
  end
  function love.resize() loadEmitter() end
  function love.mousemoved(x,y) mx,my=x,y end
  function love.update(dt)
    dt=math.min(dt,0.1);time=time+(smoke and 1/60 or dt);frames=frames+1
    if smoke then
      local width,height=love.graphics.getDimensions()
      mx=width/2+math.sin(time*0.8)*180;my=height*0.38+math.cos(time*1.1)*55
    end
    moveCollider();accumulator=accumulator+dt
    local steps=0
    while accumulator>=1/120 and steps<8 do emitter:update(1/120);accumulator=accumulator-1/120;steps=steps+1 end
    if steps==8 then accumulator=0 end
    if smoke and frames>=100 and (not capture or captured) then print('Colliders standalone render PASS');love.event.quit() end
  end
  local function obstacle(g)
    g.setColor(palette.peach[1],palette.peach[2],palette.peach[3],0.14);g.setLineWidth(2)
    if selected==1 then
      g.circle('fill',mx,my,58);g.setColor(palette.peach);g.circle('line',mx,my,58)
    elseif selected==2 then
      g.rectangle('fill',mx-85,my-45,170,90);g.setColor(palette.peach);g.rectangle('line',mx-85,my-45,170,90)
    else
      local c=emitter.config.capsuleCollider;local dx,dy=c.x2-c.x1,c.y2-c.y1;local length=math.sqrt(dx*dx+dy*dy)
      local nx,ny=-dy/length*30,dx/length*30
      g.setLineWidth(60);g.line(c.x1,c.y1,c.x2,c.y2);g.circle('fill',c.x1,c.y1,30);g.circle('fill',c.x2,c.y2,30)
      g.setColor(palette.peach);g.setLineWidth(2)
      g.line(c.x1+nx,c.y1+ny,c.x2+nx,c.y2+ny);g.line(c.x1-nx,c.y1-ny,c.x2-nx,c.y2-ny)
      g.circle('line',c.x1,c.y1,30);g.circle('line',c.x2,c.y2,30)
    end
  end
  function love.draw()
    local g=love.graphics;local width,height=g.getDimensions()
    g.clear(palette.ink);emitter:draw();obstacle(g)
    g.setLineWidth(2);g.setColor(palette.teal);g.line(0,height-66,width,height-66)
    g.setFont(title);g.setColor(palette.beige);g.print('Moving colliders',28,23)
    g.setFont(text);g.setColor(palette.teal)
    local names={'circle','box','capsule'}
    local measured=love.timer.getFPS();local fps=measured>0 and (measured..' FPS') or 'FPS …'
    g.print(('%s  ·  stateful  ·  %s particles  ·  %s'):format(names[selected],emitter:getBufferSize(),fps),29,63)
    g.setColor(palette.blue);g.print('1 Circle   2 Box   3 Capsule   Move mouse   R Reset   Esc',29,height-33)
    if capture and frames>=70 and not requested then
      requested=true;g.captureScreenshot(function(data)
        local file='colliders.png';data:encode('png',file);data:release()
        print('COLLIDERS_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='r' then loadEmitter()
    else for i=1,3 do if key==tostring(i) then selected=i end end end
  end
  function love.quit()
    releaseEmitter();for _,resource in ipairs{title,text} do if resource then resource:release() end end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return A
