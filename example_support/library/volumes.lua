local prefix=(...):gsub('example_support%.library%.volumes$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')

local V={}
local Scene={};Scene.__index=Scene

local function distanceFor(kind,width,height,x,y)
  local floor=height-22-y
  if kind=='water' then
    local left=math.max(math.abs(x-width*0.28)-width*0.18,math.abs(y-height*0.68)-10)
    local right=math.max(math.abs(x-width*0.72)-width*0.18,math.abs(y-height*0.68)-10)
    return math.min(floor,left,right)
  elseif kind=='terrain' then
    local shelf=math.max(math.abs(x-width*0.55)-width*0.2,math.abs(y-height*0.64)-9)
    return math.min(floor,shelf)
  end
  return floor
end

function V.new(kind,width,height,automated)
  local self=setmetatable({kind=kind,width=width,height=height,time=0,automated=automated,
    pointer={x=width*0.5,y=height*0.45,previousX=width*0.5,previousY=height*0.45,inside=true}},Scene)
  local world,reason=gpu.newVolumeWorld{
    width=width,height=height,cellSize=7,renderStyle=kind=='smoke' and 'smooth' or 'pixel',
    pressureIterations=18,liquidPressureIterations=10,
    distance=function(x,y) return distanceFor(kind,width,height,x,y) end,
  }
  self.world,self.error=world,reason
  if not world then return self end

  if kind=='water' or kind=='terrain' or kind=='colliders' then
    local material={name='water',model=kind=='water' and 'liquid' or 'water',
      color={palette.blue[1],palette.blue[2],palette.blue[3],0.9}}
    if kind=='water' then material.behavior='water' else material.flowSpeed=1;material.spread=0.5 end
    self.material=world:addMaterial(material)
    self.source=world:newSource{material=self.material,shape='rectangle',position={width*0.5,28},
      width=kind=='colliders' and 150 or 38,height=2,rate=7500}
    if kind=='colliders' then
      self.colliders={
        circle={x=width*0.27,y=height*0.43,radius=32},
        box={x=width*0.51,y=height*0.52,width=78,height=48},
        capsule={x1=width*0.70,y1=height*0.42,x2=width*0.84,y2=height*0.55,radius=20},
      }
    end
  elseif kind=='smoke' then
    self.material=world:addMaterial{name='smoke',model='gas',buoyancy=80,dissipation=0.12,cooling=0.12,
      color={palette.teal[1],palette.teal[2],palette.teal[3],0.75},
      force={code='return vec2(sin(position.y*0.035+time)*curl,cos(position.x*0.024-time)*curl*0.5);',uniforms={curl=22}}}
    self.source=world:newSource{material=self.material,position={width*0.46,height-46},radius=17,rate=2300,temperature=2.8}
    world:setWind(25,-3)
  elseif kind=='steam' then
    self.water=world:addMaterial{name='water',model='liquid',behavior='water',cooling=0.03,
      color={palette.blue[1],palette.blue[2],palette.blue[3],0.9}}
    self.material=world:addMaterial{name='steam',model='gas',buoyancy=150,dissipation=0.08,cooling=0.06,
      color={palette.beige[1],palette.beige[2],palette.beige[3],0.94}}
    self.source=world:newSource{material=self.water,position={width*0.5,70},radius=13,rate=3300,temperature=0.15}
    world:addReaction{from=self.water,to=self.material,temperatureAbove=0.45,rate=4}
    world:setWind(32,-4)
  else error('unknown volume library recipe: '..tostring(kind)) end

  self.terrainShader=love.graphics.newShader([[#pragma language glsl3
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
  float d=Texel(tex,tc).r;
  return d<0.0 ? color : vec4(0.0);
}]])
  world:warm(kind=='smoke' and 1.8 or 1.2)
  return self
end

function Scene:setPointer(x,y,inside)
  local p=self.pointer
  p.previousX,p.previousY=p.x,p.y;p.x,p.y,p.inside=x,y,inside
end

function Scene:update(dt)
  if not self.world then return end
  self.time=self.time+dt
  local p=self.pointer
  if self.automated then
    local travel=self.kind=='water' and self.width*0.09 or self.width*0.25
    local centerY=self.kind=='water' and self.height*0.60 or self.height*0.46
    self:setPointer(self.width*0.5+math.sin(self.time*0.9)*travel,
      centerY+math.cos(self.time*1.2)*35,true)
    p=self.pointer
  end
  if self.kind=='water' then
    if p.inside then
      self.world:setCirclePush(p.x,p.y,68,1.15)
      local vx,vy=(p.x-p.previousX)/math.max(dt,1/240),(p.y-p.previousY)/math.max(dt,1/240)
      self.world:addWaterForce(p.x,p.y,76,vx*0.32,vy*0.32)
    else self.world:setCirclePush() end
  elseif self.kind=='smoke' then
    self.world:setCircleCollider(p.x,p.y,28)
    local vx,vy=(p.x-p.previousX)/math.max(dt,1/240),(p.y-p.previousY)/math.max(dt,1/240)
    self.world:addForce(p.x,p.y,70,vx*0.14,vy*0.14)
  elseif self.kind=='terrain' then
    if self.automated and math.floor(self.time*8)%3==0 then
      self.world:paintTerrain(p.x,p.y,22,math.floor(self.time*1.2)%2==0)
    elseif love.mouse.isDown(1) then self.world:paintTerrain(p.x,p.y,22,true)
    elseif love.mouse.isDown(2) then self.world:paintTerrain(p.x,p.y,22,false) end
  elseif self.kind=='steam' then
    self.world:addHeat(self.width*0.5,self.height-100,65,dt*12,self.water)
  elseif self.kind=='colliders' then
    local motion=math.sin(self.time*1.15)*34
    local c,b,k=self.colliders.circle,self.colliders.box,self.colliders.capsule
    c.x,c.y,c.radius=self.width*0.27,self.height*0.43+motion,32
    b.x,b.y,b.width,b.height=self.width*0.51,self.height*0.52-motion*0.55,78,48
    k.x1,k.y1=self.width*0.70,self.height*0.42-motion*0.35
    k.x2,k.y2,k.radius=self.width*0.84,self.height*0.55+motion*0.35,20
    self.world:setCircleCollider(c.x,c.y,c.radius)
    self.world:setBoxCollider(b.x,b.y,b.width,b.height)
    self.world:setCapsuleCollider(k.x1,k.y1,k.x2,k.y2,k.radius)
  end
  self.world:update(dt)
end

function Scene:draw(x,y)
  local g=love.graphics
  if not self.world then g.setColor(palette.peach);g.print(self.error or 'Volume unavailable',x+24,y+24);return end
  g.push('all');g.translate(x,y);g.setColor(palette.deep);g.rectangle('fill',0,0,self.width,self.height)
  self.world:draw()
  g.setShader(self.terrainShader);g.setColor(palette.blue[1],palette.blue[2],palette.blue[3],0.4)
  g.draw(self.world.terrain,0,0,0,self.world.cell[1],self.world.cell[2]);g.setShader()
  if self.kind=='water' then
    g.setColor(palette.waterLight);g.circle('line',self.pointer.x,self.pointer.y,68)
    g.setColor(palette.water[1],palette.water[2],palette.water[3],0.7);g.circle('line',self.pointer.x,self.pointer.y,42)
  elseif self.kind=='smoke' then
    g.setColor(palette.peach);g.circle('line',self.pointer.x,self.pointer.y,28)
  elseif self.kind=='colliders' then
    local c,b,k=self.colliders.circle,self.colliders.box,self.colliders.capsule
    g.setColor(palette.peach);g.setLineWidth(2);g.circle('line',c.x,c.y,c.radius)
    g.rectangle('line',b.x-b.width/2,b.y-b.height/2,b.width,b.height,5,5)
    local dx,dy=k.x2-k.x1,k.y2-k.y1;local length=math.sqrt(dx*dx+dy*dy)
    local nx,ny=-dy/length*k.radius,dx/length*k.radius
    g.line(k.x1+nx,k.y1+ny,k.x2+nx,k.y2+ny);g.line(k.x1-nx,k.y1-ny,k.x2-nx,k.y2-ny)
    g.circle('line',k.x1,k.y1,k.radius);g.circle('line',k.x2,k.y2,k.radius)
    g.setColor(palette.waterLight)
    g.printf('CIRCLE',c.x-55,c.y-c.radius-24,110,'center')
    g.printf('BOX',b.x-55,b.y-b.height/2-24,110,'center')
    g.printf('CAPSULE',(k.x1+k.x2)/2-60,math.min(k.y1,k.y2)-k.radius-24,120,'center')
  elseif self.kind=='steam' then
    g.setColor(palette.blue);g.printf('COOL WATER',self.width*0.5-90,112,180,'center')
    g.setColor(palette.peach[1],palette.peach[2],palette.peach[3],0.18);g.circle('fill',self.width*0.5,self.height-100,65)
    g.setColor(palette.peach);g.circle('line',self.width*0.5,self.height-100,65)
    g.printf('HEAT: WATER TO STEAM',self.width*0.5-120,self.height-104,240,'center')
    g.line(self.width*0.5+52,self.height-142,self.width*0.68,self.height*0.48)
    g.printf('STEAM RISES',self.width*0.68-70,self.height*0.44,140,'center')
  end
  g.pop()
end

function Scene:mousepressed(x,y,button)
  if not self.world then return end
  if self.kind=='terrain' then self.world:paintTerrain(x,y,22,button~=2)
  elseif button==1 and self.kind=='steam' then self.world:addHeat(x,y,55,2.5,self.water) end
end
function Scene:mousereleased() return self end
function Scene:emit() if self.source then self.source:emit(800) end end
function Scene:action() self:emit() end
function Scene:controls()
  if self.kind=='steam' then return 'Click to add heat · blue falls, beige steam rises' end
  if self.kind=='water' then return 'Move mouse to push and stir · no solid mask or deleted density' end
  if self.kind=='colliders' then return 'Circle · box · capsule exclude and redirect the volume' end
  return nil
end
function Scene:release()
  if self.world then self.world:release() end
  if self.terrainShader then self.terrainShader:release() end
end

return V
