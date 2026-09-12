-- Waterfall settings and compatibility accessors; simulation lives in the public library.
local prefix=(...):gsub('example_support%.waterfall%.fluid$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local F={};F.__index=F;F.step=1/120
function F.new(options)
  options=options or {}
  local world,reason=gpu.newVolumeWorld{width=options.width or 1280,height=options.height or 800,
    cellSize=options.cellSize or 8,transportSteps=options.transportSteps or 1,fixedStep=F.step,distance=options.distance}
  if not world then return nil,reason end
  local self=setmetatable({world=world,inflow=true,interaction=options.interaction or 'solid',
    pushStrength=options.pushStrength or 1.35},F)
  local ok,err=xpcall(function()
    self.material=world:addMaterial{name='water',model='water',cooling=0,
      color={palette.blue[1],palette.blue[2],palette.blue[3],0.9}}
    local source=options.source or {x=580,y=96,width=56,rate=12000}
    self.source=world:newSource{material=self.material,position={source.x,source.y},shape='rectangle',
      width=source.width,height=0,rate=source.rate or 0}
    self:_sync()
  end,debug.traceback)
  if not ok then world:release();return nil,err end
  return self
end
function F:_sync()
  local w,m=self.world,self.material
  self.state,self.next,self.flux=m.state,m.next,m.flux
  self.terrain,self.circle,self.push,self.time=w.terrain,w.circle,w.push,w.time
  self.columns,self.rows,self.transportSteps=w.columns,w.rows,w.transportSteps
end
function F:update(dt,mouse)
  if mouse and mouse.enabled and mouse.inside then
    if self.interaction=='push' then
      self.world:setCircleCollider();self.world:setCirclePush(mouse.x,mouse.y,mouse.radius,self.pushStrength)
      if self.lastMouseX then
        local vx=(mouse.x-self.lastMouseX)/math.max(dt,1/240)
        local vy=(mouse.y-self.lastMouseY)/math.max(dt,1/240)
        if math.abs(vx)+math.abs(vy)>0.01 then self.world:addWaterForce(mouse.x,mouse.y,mouse.radius*1.35,vx*0.28,vy*0.28) end
      end
      self.lastMouseX,self.lastMouseY=mouse.x,mouse.y
    else self.world:setCirclePush();self.world:setCircleCollider(mouse.x,mouse.y,mouse.radius) end
  else self.world:setCircleCollider();self.world:setCirclePush();self.lastMouseX,self.lastMouseY=nil,nil end
  if self.inflow then self.source:start() else self.source:stop() end
  self.world:update(math.min(dt,F.step));self:_sync()
end
function F:draw(debug) self.world:draw(0,0,debug) end
function F:release() self.world:release();self.released=true end
return F
