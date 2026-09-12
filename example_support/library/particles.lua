local prefix=(...):gsub('example_support%.library%.particles$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')

local P={}
local Scene={};Scene.__index=Scene

local function rgba(color,alpha) return {color[1],color[2],color[3],alpha} end

local function image(width,height,pixel,filter,format)
  local data=love.image.newImageData(width,height,format)
  data:mapPixel(pixel)
  local result=love.graphics.newImage(data)
  data:release();result:setFilter(filter or 'linear',filter or 'linear')
  return result
end

local function softDisc(size)
  return image(size,size,function(x,y)
    local dx,dy=(x+0.5)/size-0.5,(y+0.5)/size-0.5
    local alpha=math.max(0,1-math.sqrt(dx*dx+dy*dy)*2)
    return 1,1,1,alpha*alpha
  end)
end

local function pixelSheet()
  local frame,size=16,16
  local sheet=image(frame*4,size,function(x,y)
    local f=math.floor(x/frame);local px=x%frame
    local cx,cy=7.5,7.5;local dx,dy=math.abs(px-cx),math.abs(y-cy)
    local radii={2.2,3.5,5,3.2}
    local on=(dx+dy<radii[f+1]*1.45) or (math.max(dx,dy)<radii[f+1]*0.72)
    return 1,1,1,on and 1 or 0
  end,'nearest')
  local quads={}
  for i=0,3 do quads[#quads+1]=love.graphics.newQuad(i*frame,0,frame,frame,sheet:getDimensions()) end
  return sheet,quads
end

local function flowTexture()
  return image(96,64,function(x,y)
    local nx,ny=x/95*2-1,y/63*2-1
    local length=math.max(math.sqrt(nx*nx+ny*ny),0.12)
    return -ny/length*90,nx/length*90,0,1
  end,'linear','rgba32f')
end

local function base(width,height)
  return {
    max=7000,rate=1800,lifetime={1.5,3},seed=17,
    position={width*0.5,height*0.72},direction=-math.pi/2,spread=0.5,speed={35,120},
    sizes={3,9,0},sizeVariation=0.5,gravity={0,-18},damping=0.25,blendMode='add',
    colors={rgba(palette.beige,0.9),rgba(palette.peach,0.65),rgba(palette.blue,0)},
  }
end

local function add(self,config)
  local emitter=gpu.newEmitter(config)
  self.emitters[#self.emitters+1]=emitter
  return emitter
end

local function clone(source)
  local result={}
  for key,value in pairs(source) do
    if type(value)=='table' then result[key]=clone(value) else result[key]=value end
  end
  return result
end

local builders={}

function builders.fire(self,w,h)
  local fire=base(w,h);fire.max=12000;fire.rate=4200;fire.lifetime={0.7,1.8};fire.speed={35,105}
  fire.spread=0.75;fire.sizes={3,14,4,0};fire.gravity={0,-60};fire.damping=0.5
  fire.colors={rgba(palette.beige,1),rgba(palette.peach,0.9),rgba(palette.teal,0.36),rgba(palette.blue,0)}
  fire.forces={gpu.forces.turbulence{amplitude={22,7},frequency={5,3}}};add(self,fire)
  local embers=base(w,h);embers.max=5000;embers.rate=650;embers.lifetime={1.4,3.5};embers.speed={70,180}
  embers.spread=1.1;embers.gravity={0,45};embers.sizes={2,3,0};embers.colors={rgba(palette.beige,1),rgba(palette.peach,0.8),rgba(palette.peach,0)};add(self,embers)
end

function builders.explosions(self,w,h)
  local flash=base(w,h);flash.rate=0;flash.max=3000;flash.position={w*0.5,h*0.48};flash.spread=math.pi*2
  flash.direction=0;flash.speed={80,280};flash.gravity={0,90};flash.damping=1.1;flash.lifetime={0.45,1.1}
  flash.sizes={2,9,0};flash.colors={rgba(palette.beige,1),rgba(palette.peach,0.9),rgba(palette.blue,0)}
  self.primary=add(self,flash);self.burstEvery=1.15;self.primary:emit(900)
  local trail=clone(flash);trail.seed=29;trail.max=1800;trail.speed={30,140};trail.lifetime={1.2,2.1};trail.damping=0.25
  trail.colors={rgba(palette.teal,0.9),rgba(palette.blue,0.7),rgba(palette.blue,0)};self.secondary=add(self,trail);self.secondary:emit(500)
end

function builders.weather(self,w,h)
  local rain=base(w,h);rain.position={w*0.5,10};rain.emissionArea={distribution='uniform',x=w*0.48,y=4}
  rain.max=10000;rain.rate=3800;rain.lifetime={1.2,2};rain.direction=math.pi/2+0.12;rain.spread=0.04;rain.speed={280,410}
  rain.gravity={40,260};rain.sizes={2,4,2};rain.colors={rgba(palette.blue,0.75),rgba(palette.teal,0.3),rgba(palette.blue,0)};add(self,rain)
  local snow=clone(rain);snow.seed=22;snow.max=5000;snow.rate=800;snow.speed={25,55};snow.gravity={0,18};snow.damping=0.25
  snow.lifetime={4,7};snow.sizes={3,7,3};snow.colors={rgba(palette.beige,0.8),rgba(palette.beige,0.55),rgba(palette.beige,0)}
  snow.forces={gpu.forces.turbulence{amplitude={28,5},frequency={1.8,1.2}}};add(self,snow)
end

function builders.ambient(self,w,h)
  local colors={palette.peach,palette.teal,palette.beige,palette.blue}
  for i,color in ipairs(colors) do
    local c=base(w,h);c.seed=30+i;c.max=2600;c.rate=260;c.lifetime={4,8};c.position={w*(0.15+i*0.18),h*0.55}
    c.emissionArea={distribution='uniform',x=w*0.12,y=h*0.34};c.direction=-math.pi/2;c.spread=math.pi*2;c.speed={2,18}
    c.gravity={i==1 and 5 or 0,i==2 and -8 or -2};c.damping=0.7;c.sizes=i==1 and {5,9,4} or {1,4,0}
    c.spin={-2,2};c.rotation={0,math.pi*2};c.colors={rgba(color,0),rgba(color,0.72),rgba(color,0)}
    c.forces={gpu.forces.turbulence{amplitude={12+i*3,8},frequency={1+i*0.2,1.5}}};add(self,c)
  end
end

function builders.magic(self,w,h)
  local center={w*0.5,h*0.5}
  local ring=base(w,h);ring.max=9000;ring.rate=2600;ring.lifetime={2.8,4.2};ring.position=center;ring.speed={0,0};ring.spread=math.pi*2
  ring.sizes={2,8,2,0};ring.colors={rgba(palette.teal,0),rgba(palette.teal,0.9),rgba(palette.blue,0.8),rgba(palette.peach,0)}
  ring.forces={gpu.forces.custom{name='orbit',uniforms={radius=125,speed=2.3},code=[[
    float phase=seed*6.2831853;float a=phase+age*speed;
    return radius*vec2(cos(a)-cos(phase),sin(a)-sin(phase));
  ]]}};add(self,ring)
  local energy=clone(ring);energy.seed=52;energy.max=5000;energy.rate=900;energy.lifetime={1.1,2.2};energy.sizes={10,3,0}
  energy.forces={gpu.forces.custom{name='spiral',uniforms={radius=180,speed=3.7,decay=0.75},code=[[
    float phase=seed*6.2831853;float r=radius*exp(-decay*age);float a=phase+age*speed;
    return r*vec2(cos(a),sin(a))-radius*vec2(cos(phase),sin(phase));
  ]]}};add(self,energy)
end

function builders.clouds(self,w,h)
  local cloud=base(w,h);cloud.max=9000;cloud.rate=1800;cloud.lifetime={4,7};cloud.position={w*0.35,h*0.7}
  cloud.emissionArea={distribution='ellipse',x=w*0.22,y=25};cloud.direction=-math.pi/2;cloud.spread=0.8;cloud.speed={8,35}
  cloud.gravity={10,-15};cloud.damping=0.5;cloud.sizes={18,48,75};cloud.blendMode='alpha';cloud.texture=softDisc(32);self.owned[#self.owned+1]=cloud.texture
  cloud.colors={rgba(palette.blue,0),rgba(palette.teal,0.18),rgba(palette.beige,0.22),rgba(palette.beige,0)}
  cloud.forces={gpu.forces.turbulence{amplitude={30,12},frequency={1.4,1.1}}};add(self,cloud)
  local steam=clone(cloud);steam.seed=66;steam.max=3500;steam.rate=520;steam.position={w*0.76,h*0.78};steam.emissionArea={distribution='uniform',x=18,y=4}
  steam.lifetime={2,4};steam.speed={20,55};steam.sizes={8,32,55};steam.colors={rgba(palette.beige,0.32),rgba(palette.teal,0.18),rgba(palette.blue,0)};add(self,steam)
end

function builders.sprays(self,w,h)
  local specs={{palette.peach,w*0.28,0.9,82},{palette.teal,w*0.5,0.35,38},{palette.beige,w*0.72,0.62,120}}
  for i,spec in ipairs(specs) do
    local c=base(w,h);c.seed=70+i;c.rate=0;c.max=2600;c.position={spec[2],h*0.72};c.direction=-math.pi/2;c.spread=spec[3]
    c.speed={spec[4]*0.5,spec[4]*1.8};c.gravity={0,260};c.damping=i==2 and 1.8 or 0.2;c.lifetime={0.7,1.8};c.sizes=i==2 and {8,13,5,0} or {3,7,0}
    c.colors={rgba(spec[1],0.95),rgba(spec[1],0.7),rgba(spec[1],0)};c.collision={type='plane',y=h*0.82,radius=2,bounce=i==3 and 0.55 or 0.1,friction=0.2}
    add(self,c):emit(700)
  end
  self.burstEvery=1.5
end

function builders.fields(self,w,h)
  local flow=flowTexture();self.owned[#self.owned+1]=flow
  local c=base(w,h);c.max=5000;c.rate=1100;c.lifetime={3,5};c.position={w*0.23,h*0.5};c.spread=math.pi*2;c.speed={15,45}
  c.flowField={texture=flow,size={w,h},strength=1};c.gravity={0,0};c.damping=0.15;c.colors={rgba(palette.blue,0.8),rgba(palette.teal,0.7),rgba(palette.blue,0)};add(self,c)
  local attract=base(w,h);attract.max=5000;attract.rate=1000;attract.lifetime={2.5,4};attract.position={w*0.78,h*0.5};attract.spread=math.pi*2
  attract.speed={80,150};attract.gravity={0,0};attract.damping=0.1;attract.attractors={{x=w*0.78,y=h*0.5,strength=900000,softening=55}}
  attract.colors={rgba(palette.peach,0.9),rgba(palette.beige,0.65),rgba(palette.peach,0)};add(self,attract)
end

function builders.pixel(self,w,h)
  local sheet,quads=pixelSheet();self.owned[#self.owned+1]=sheet
  for _,quad in ipairs(quads) do self.owned[#self.owned+1]=quad end
  local c=base(w,h);c.texture=sheet;c.quads=quads;c.max=10000;c.rate=2600;c.lifetime={1.2,2.6};c.position={w*0.5,h*0.76}
  c.spread=1.4;c.speed={45,170};c.gravity={0,90};c.damping=0.2;c.sizes={12,24,8,0};c.spin={-2,2}
  c.colors={rgba(palette.beige,1),rgba(palette.peach,1),rgba(palette.teal,0.8),rgba(palette.blue,0)};add(self,c)
end

function builders.shaders(self,w,h)
  local c=base(w,h);c.max=16000;c.rate=4500;c.lifetime={1.8,3.4};c.position={w*0.5,h*0.72};c.spread=0.8;c.speed={60,150}
  c.gravity={0,-25};c.sizes={3,13,4,0};c.colors={rgba(palette.beige,0.9),rgba(palette.peach,0.8),rgba(palette.teal,0)}
  c.forces={gpu.forces.curl{amplitude=36,frequency=0.8}};add(self,c)
  self.postCanvas=love.graphics.newCanvas(w,h,{dpiscale=1,msaa=0});self.postCanvas:setFilter('linear','linear')
  self.postShader=love.graphics.newShader(assert(love.filesystem.read(prefix..'example_support/library/showcase.glsl')))
  self.postShader:send('u_texel',{1/w,1/h})
end

function P.new(kind,width,height)
  local self=setmetatable({kind=kind,width=width,height=height,time=0,emitters={},owned={}},Scene)
  assert(builders[kind],'unknown particle library recipe: '..tostring(kind))(self,width,height)
  for _,emitter in ipairs(self.emitters) do emitter:warm(1.2) end
  return self
end

function Scene:update(dt)
  self.time=self.time+dt
  for _,emitter in ipairs(self.emitters) do emitter:update(dt) end
  if self.burstEvery and self.time>=(self.nextBurst or self.burstEvery) then
    self.nextBurst=self.time+self.burstEvery
    if self.kind=='explosions' then
      local x=self.width*(0.25+0.5*(0.5+0.5*math.sin(self.time*1.7)))
      local y=self.height*(0.3+0.14*math.sin(self.time*1.1))
      self.primary:setPosition(x,y);self.secondary:setPosition(x,y);self.primary:emit(900);self.secondary:emit(500)
    else for _,emitter in ipairs(self.emitters) do emitter:emit(700) end end
  end
end

function Scene:draw(x,y)
  local g=love.graphics
  if self.postCanvas then
    g.push('all');g.setCanvas(self.postCanvas);g.clear(0,0,0,0)
    for _,emitter in ipairs(self.emitters) do emitter:draw() end
    g.setCanvas();self.postShader:send('u_time',self.time);g.setShader(self.postShader)
    g.setColor(1,1,1,1);g.setBlendMode('alpha','premultiplied');g.draw(self.postCanvas,x,y);g.pop()
  else for _,emitter in ipairs(self.emitters) do emitter:draw(x,y) end end
end

function Scene:emit() for _,emitter in ipairs(self.emitters) do emitter:emit(math.min(700,emitter:getBufferSize())) end end
function Scene:mousepressed() self:emit() end
function Scene:mousereleased() return self end

function Scene:release()
  for _,emitter in ipairs(self.emitters) do emitter:release() end
  for _,resource in ipairs(self.owned) do resource:release() end
  if self.postCanvas then self.postCanvas:release() end
  if self.postShader then self.postShader:release() end
end

return P
