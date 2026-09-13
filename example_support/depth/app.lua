local prefix=(...):gsub('example_support%.depth%.app$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local GifCapture=require(prefix..'example_support.gif_capture')
local A={}
-- Two ways to give particles depth, each drawn in two passes around a solid shape:
--   left   simulated z: stateful sparks orbit an obelisk while an attractor lifts them
--   right  depth code: an analytic ring whose z is a formula, holding no extra state
function A.install()
  local sparks,ring,title,text
  local cut,cues,tint=true,true,false
  local time,frames,accumulator=0,0,0
  local layout
  local smoke,capture,requested,captured=false,false,false,false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
  end
  local gif=GifCapture.new('depth')
  local ringSpin,ringTilt=0.9,0.3
  local function releaseEmitters()
    if sparks then sparks:release();sparks=nil end
    if ring then ring:release();ring=nil end
  end
  local function loadEmitters()
    releaseEmitters()
    local width,height=love.graphics.getDimensions()
    layout={
      obelisk={x=width*0.32,base=height*0.74,width=64,height=250},
      planet={x=width*0.7,y=height*0.46,radius=72},
    }
    local o=layout.obelisk
    sparks=gpu.newEmitter{
      max=6000,rate=1500,lifetime={2.2,3},seed=41,
      position={o.x,o.base-6},emissionArea={distribution='uniform',x=o.width*1.3,y=4},
      direction=-math.pi/2,spread=0.25,speed={20,45},gravity={0,-36},sizes={3,6,2},sizeVariation=0.4,
      colors={{palette.peach[1],palette.peach[2],palette.peach[3],0},
        {palette.yellow[1],palette.yellow[2],palette.yellow[3],0.95},
        {palette.teal[1],palette.teal[2],palette.teal[3],0.8},
        {palette.blue[1],palette.blue[2],palette.blue[3],0}},
      attractors={{x=o.x,y=o.base-o.height-40,strength=900000,softening=90}},
      -- Simulated z: a spring round the obelisk's axis makes each spark circle it.
      depth={axis=o.x,orbit={2.2,3.4},tilt=0.28},
    }
    assert(sparks:getMode()=='stateful','simulated depth must select stateful mode')
    local p=layout.planet
    local radius=p.radius*1.8
    -- The ring's position and its depth come from the same angle, so z is exact.
    local angle=('seed*6.2831853+age*%.4f'):format(ringSpin)
    ring=gpu.newEmitter{
      max=9000,rate=3000,lifetime=3,seed=77,position={p.x,p.y},sizes={2,3,2},sizeVariation=0.3,
      colors={{palette.beige[1],palette.beige[2],palette.beige[3],0},
        {palette.beige[1],palette.beige[2],palette.beige[3],0.85},
        {palette.pink[1],palette.pink[2],palette.pink[3],0}},
      forces={gpu.forces.custom{name='ring',code=([[
        float theta=%s;
        float r=%.4f*(0.85+0.3*fract(seed*5.31));
        return vec2(cos(theta)*r,sin(theta)*r*%.4f);
      ]]):format(angle,radius,ringTilt)}},
      depth={code=('return sin(%s)*%.4f;'):format(angle,radius)},
    }
    assert(ring:getMode()=='analytic' and ring:getStateMemory()==0,'depth code must stay analytic')
    sparks:warm(1.5);ring:warm(3)
  end
  local function options(half,range)
    if not cut and not cues then return nil end
    return {cut=cut and half or nil,range=range,size=cues and 0.35 or 0,dim=cues and 0.6 or 0}
  end
  local function drawObelisk(g)
    local o=layout.obelisk;local half=o.width/2;local top=o.base-o.height
    if tint then
      g.setColor(palette.peach);g.setLineWidth(2)
      g.polygon('line',o.x-half,o.base,o.x+half,o.base,o.x+half*0.6,top+26,o.x,top,o.x-half*0.6,top+26)
      return
    end
    -- Lit and shaded faces, bright enough to read against the night, with a pale edge.
    g.setColor(palette.blue[1]*0.55,palette.blue[2]*0.55,palette.blue[3]*0.55)
    g.polygon('fill',o.x-half,o.base,o.x,o.base,o.x,top,o.x-half*0.6,top+26)
    g.setColor(palette.blue[1]*0.85,palette.blue[2]*0.85,palette.blue[3]*0.85)
    g.polygon('fill',o.x,o.base,o.x+half,o.base,o.x+half*0.6,top+26,o.x,top)
    g.setColor(palette.teal);g.setLineWidth(2)
    g.line(o.x,o.base,o.x,top)
    g.polygon('line',o.x-half,o.base,o.x+half,o.base,o.x+half*0.6,top+26,o.x,top,o.x-half*0.6,top+26)
  end
  local function drawPlanet(g)
    local p=layout.planet
    if tint then
      g.setColor(palette.peach);g.setLineWidth(2);g.circle('line',p.x,p.y,p.radius);return
    end
    g.setColor(palette.waterDeep);g.circle('fill',p.x,p.y,p.radius)
    g.setColor(palette.water);g.circle('fill',p.x-p.radius*0.18,p.y-p.radius*0.18,p.radius*0.78)
    g.setColor(palette.waterLight[1],palette.waterLight[2],palette.waterLight[3],0.35)
    g.circle('fill',p.x-p.radius*0.36,p.y-p.radius*0.4,p.radius*0.28)
  end
  -- Behind half, then the shape, then the front half. Without the cut the shape comes first
  -- and the whole emitter draws over it, which is how an emitter without depth looks.
  local function around(g,emitter,range,shape)
    if cut then
      if tint then g.setColor(1,0.25,0.25,1) end
      emitter:draw(0,0,options('behind',range))
      shape(g)
      g.setColor(1,1,1,1)
      emitter:draw(0,0,options('front',range))
    else
      shape(g)
      g.setColor(1,1,1,1)
      emitter:draw(0,0,options(nil,range))
    end
  end
  function love.load()
    title=love.graphics.newFont(30);text=love.graphics.newFont(13);loadEmitters()
  end
  function love.resize() loadEmitters() end
  function love.update(dt)
    dt=math.min(dt,0.1);time=time+(smoke and 1/60 or dt);frames=frames+1
    if smoke then
      tint=frames>=30 and frames<40
      cut=not (frames>=40 and frames<50)
      cues=not (frames>=50 and frames<60)
    end
    accumulator=accumulator+(smoke and 1/60 or dt)
    local steps=0
    while accumulator>=1/120 and steps<8 do sparks:update(1/120);accumulator=accumulator-1/120;steps=steps+1 end
    if steps==8 then accumulator=0 end
    ring:update(smoke and 1/60 or dt)
    if smoke and frames>=100 and (not capture or captured) and (not gif or gif.done) then
      print('Depth standalone render PASS');love.event.quit()
    end
  end
  function love.draw()
    local g=love.graphics;local width,height=g.getDimensions()
    g.clear(palette.ink[1]*0.55,palette.ink[2]*0.55,palette.ink[3]*0.55)
    g.setColor(palette.deep);g.rectangle('fill',0,layout.obelisk.base,width,height-layout.obelisk.base)
    around(g,sparks,40,drawObelisk)
    around(g,ring,layout.planet.radius*1.8,drawPlanet)
    g.setFont(title);g.setColor(palette.beige);g.print('Depth and occlusion',28,23)
    g.setFont(text);g.setColor(palette.teal)
    local measured=love.timer.getFPS();local fps=measured>0 and (measured..' FPS') or 'FPS …'
    g.print(('cut %s  ·  cues %s  ·  sparks: simulated z, %d KiB state  ·  ring: depth code, %d KiB state  ·  %s'):format(
      cut and 'on' or 'off',cues and 'on' or 'off',math.floor(sparks:getStateMemory()/1024),
      math.floor(ring:getStateMemory()/1024),fps),29,63)
    g.setColor(palette.blue);g.print('C Cut around shapes   V Depth cues   T Tint the behind half   R Reset   Esc',29,height-33)
    if gif then gif:draw(frames) end
    if capture and frames>=70 and not requested then
      requested=true;g.captureScreenshot(function(data)
        local file='depth.png';data:encode('png',file);data:release()
        print('DEPTH_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='r' then loadEmitters()
    elseif key=='c' then cut=not cut
    elseif key=='v' then cues=not cues
    elseif key=='t' then tint=not tint end
  end
  function love.quit()
    releaseEmitters();for _,resource in ipairs{title,text} do if resource then resource:release() end end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return A
