local directory=(...):gsub('plants$',''):gsub('%.','/')
local prefix=(...):gsub('example_support%.waterfall%.plants$','')
local palette=require(prefix..'example_support.palette')
local P={};P.__index=P
local format={{'VertexPosition','float',2},{'PlantRoot','float',2},{'PlantData','float',4},{'VertexColor','float',4}}
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
function P.new(definitions)
  assert(#definitions<=64,'Plant batch exceeds 64 ferns.')
  local self=setmetatable({plants={},bends={},wind=1,time=0},P)
  local vertices={}
  for i,d in ipairs(definitions) do
    local p={x=d[1],y=d[2],scale=d[3],angle=d[4],phase=i*2.399963,bx=0,by=0,vx=0,vy=0}
    self.plants[i]=p;self.bends[i]={0,0}
    local function vertex(x,y)
      vertices[#vertices+1]={x,y,p.x,p.y,p.scale,p.angle,p.phase,i-1,
        palette.teal[1],palette.teal[2],palette.teal[3],1}
    end
    local function triangle(ax,ay,bx,by,cx,cy) vertex(ax,ay);vertex(bx,by);vertex(cx,cy) end
    local stem={{0,0},{4,-22},{1,-54},{-9,-87}}
    for n=1,#stem-1 do
      local a,b=stem[n],stem[n+1];local dx,dy=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dy*dy)
      local nx,ny=-dy/len*0.7,dx/len*0.7
      triangle(a[1]+nx,a[2]+ny,a[1]-nx,a[2]-ny,b[1]+nx,b[2]+ny)
      triangle(a[1]-nx,a[2]-ny,b[1]-nx,b[2]-ny,b[1]+nx,b[2]+ny)
    end
    for n=1,8 do
      local y,extent=-n*10,(9-n)*2.5
      triangle(2,y,-extent,y-16,-extent*0.7,y-3)
      triangle(2,y,extent+4,y-13,extent*0.7+3,y-1)
    end
  end
  -- Uniform array size stays fixed; mesh attributes select each plant's entry.
  for i=#definitions+1,64 do self.bends[i]={0,0} end
  local ok,err=pcall(function()
    self.mesh=love.graphics.newMesh(format,vertices,'triangles','static')
    self.shader=love.graphics.newShader(assert(love.filesystem.read(directory..'shaders/plants.glsl')))
  end)
  if not ok then self:release();error(err) end
  return self
end
function P:point(index,x,y,time)
  local p=self.plants[index];local h=clamp(-y/96,0,1);local weight=h*h
  local wave=self.wind*(math.sin(time*1.7+p.phase)+0.35*math.sin(time*3.1+p.phase*1.7))*7*p.scale
  local ca,sa=math.cos(p.angle),math.sin(p.angle)
  return p.x+(ca*x-sa*y)*p.scale+(p.bx+wave)*weight,
    p.y+(sa*x+ca*y)*p.scale+p.by*weight
end
function P:update(dt,time,circle)
  self.time=time
  for i,p in ipairs(self.plants) do
    local tx,ty,best=0,0,0
    if circle and circle.enabled and circle.inside then
      for sample=1,3 do
        local y=-sample*28;local weight=(-y/96)^2
        local xw,yw=self:point(i,0,y,time)
        -- Rest pose plus wind, so contact does not chase its own spring motion.
        xw,yw=xw-p.bx*weight,yw-p.by*weight
        local dx,dy=xw-circle.x,yw-circle.y;local distance=math.sqrt(dx*dx+dy*dy)
        local overlap=circle.radius+8*p.scale-distance
        if overlap>0 then
          if distance<0.001 then dx,dy,distance=math.cos(p.phase),math.sin(p.phase),1 end
          local amount=overlap/weight
          if amount>best then tx,ty,best=dx/distance*amount,dy/distance*amount,amount end
        end
      end
    end
    local length=math.sqrt(tx*tx+ty*ty);local limit=55*p.scale
    if length>limit then tx,ty=tx/length*limit,ty/length*limit end
    -- Called on the scene's fixed 120 Hz clock. No particle or GPU state readback.
    p.vx=p.vx+((tx-p.bx)*100-p.vx*15)*dt
    p.vy=p.vy+((ty-p.by)*100-p.vy*15)*dt
    p.bx,p.by=p.bx+p.vx*dt,p.by+p.vy*dt
    self.bends[i][1],self.bends[i][2]=p.bx,p.by
  end
end
function P:draw(time)
  local g=love.graphics;g.push('all');g.setShader(self.shader);g.setColor(1,1,1,1)
  self.shader:send('u_time',time);self.shader:send('u_wind',self.wind);self.shader:send('u_bends',unpack(self.bends))
  g.draw(self.mesh);g.pop()
end
function P:release()
  if self.mesh then self.mesh:release();self.mesh=nil end
  if self.shader then self.shader:release();self.shader=nil end
end
return P
