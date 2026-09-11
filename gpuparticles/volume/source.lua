local U=require((...):gsub('source$','util'))
local S={};S.__index=S
function S.new(w,options)
  options=options or {};U.alive(w)
  U.keys(options,'material position radius shape width height rate temperature','source')
  local material=options.material
  assert(material and material.world==w and not material.released,'volume source needs a material from this world')
  assert(#w.sources<64,'volume source limit is 64')
  local self=setmetatable({world=w,material=material,active=true,released=false,
    position=U.vector(options.position,{0,0},'position',2),
    radius=U.number(options.radius,0,'source radius',0),
    shape=U.choice(options.shape,'circle','source shape',{circle=true,rectangle=true}),
    width=U.number(options.width,0,'source width',0),height=U.number(options.height,0,'source height',0),
    rate=U.number(options.rate,0,'source rate',0),temperature=U.number(options.temperature,material.model=='gas' and 1 or 0,'temperature',0,1000),
    bounds={0,0,0,0},brush={0,0,0,0}},S)
  self:geometry();w.sources[#w.sources+1]=self;return self
end
function S:geometry()
  local w,p,b=self.world,self.position,self.bounds
  local rx=self.shape=='circle' and self.radius or self.width/2
  local ry=self.shape=='circle' and self.radius or self.height/2
  b[1]=math.max(0,math.floor((p[1]-rx)/w.cell[1]));b[2]=math.max(0,math.floor((p[2]-ry)/w.cell[2]))
  b[3]=math.min(w.columns-1,math.floor((p[1]+rx)/w.cell[1]));b[4]=math.min(w.rows-1,math.floor((p[2]+ry)/w.cell[2]))
  local count=0
  if self.shape=='circle' and self.radius>0 then
    for y=b[2],b[4] do for x=b[1],b[3] do
      if ((x+0.5)*w.cell[1]-p[1])^2+((y+0.5)*w.cell[2]-p[2])^2<=self.radius^2 then count=count+1 end
    end end
  else count=math.max(0,b[3]-b[1]+1)*math.max(0,b[4]-b[2]+1) end
  self.count=count
  self.brush[1],self.brush[2],self.brush[3],self.brush[4]=p[1],p[2],self.radius,self.shape=='circle' and self.radius>0 and 1 or 0
end
function S:setPosition(x,y)
  U.alive(self);x=U.number(x,nil,'x');y=U.number(y,nil,'y')
  if self.position[1]~=x or self.position[2]~=y then self.position[1],self.position[2]=x,y;self:geometry() end
  return self
end
function S:setRadius(radius)
  U.alive(self);assert(self.shape=='circle','setRadius requires a circle source')
  self.radius=U.number(radius,nil,'radius',0);self:geometry();return self
end
function S:setSize(width,height)
  U.alive(self);assert(self.shape=='rectangle','setSize requires a rectangle source')
  width=U.number(width,nil,'width',0);height=U.number(height,nil,'height',0)
  self.width,self.height=width,height;self:geometry();return self
end
function S:setRate(rate) U.alive(self);self.rate=U.number(rate,nil,'rate',0);return self end
S.setEmissionRate=S.setRate
function S:setTemperature(t) U.alive(self);self.temperature=U.number(t,nil,'temperature',0,1000);return self end
function S:start() U.alive(self);self.active=true;return self end
function S:stop() U.alive(self);self.active=false;return self end
function S:isActive() return not self.released and self.active end
function S:emit(amount)
  U.alive(self);amount=U.number(amount,nil,'amount',0)
  U.guard(function() self.world:_injectSource(self,amount,true) end);return self
end
function S:release()
  if self.released then return end
  self.released=true;self.active=false
  for i,s in ipairs(self.world.sources) do if s==self then table.remove(self.world.sources,i);break end end
end
return S
