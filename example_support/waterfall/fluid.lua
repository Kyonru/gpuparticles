-- A side-view, conservative cellular water model. One unit is one full grid cell.
-- This owns water volume independently of the decorative particle emitters.
local directory=(...):gsub('fluid$',''):gsub('%.','/')
local F={}
F.__index=F
F.step=1/120
function F.new(options)
  options=options or {}
  local g=love.graphics
  local supported=g.getSupported()
  if not supported.glsl3 or not supported.pixelshaderhighp or not g.getCanvasFormats().rgba32f then
    return nil,'Water volume requires GLSL 3 and rgba32f canvases'
  end
  local self=setmetatable({owned={},inflow=true,time=0,circle={0,0,0,0},
    transportSteps=math.max(1,math.min(4,math.floor(options.transportSteps or 1)))},F)
  local function own(resource) self.owned[#self.owned+1]=resource;return resource end
  g.push('all')
  local ok,reason=xpcall(function()
    self.width,self.height=options.width or 1280,options.height or 800
    self.columns=math.ceil(self.width/(options.cellSize or 8))
    self.rows=math.ceil(self.height/(options.cellSize or 8))
    self.cell={self.width/self.columns,self.height/self.rows}
    self.grid={self.columns,self.rows}
    local function canvas()
      local c=own(g.newCanvas(self.columns,self.rows,{format='rgba32f',dpiscale=1,msaa=0}))
      c:setFilter('nearest','nearest');c:setWrap('clamp','clamp')
      g.setCanvas(c);g.clear(0,0,0,0)
      return c
    end
    g.origin();g.setScissor();g.setShader();g.setColor(1,1,1,1);g.setColorMask(true,true,true,true)
    self.state,self.next,self.flux=canvas(),canvas(),canvas()
    local data=own(love.image.newImageData(self.columns,self.rows,'rgba32f'))
    data:mapPixel(function(x,y)
      local distance=options.distance and options.distance((x+0.5)*self.cell[1],(y+0.5)*self.cell[2]) or 1e6
      return distance,0,0,1
    end)
    self.terrain=own(g.newImage(data));self.terrain:setFilter('nearest','nearest')
    local common=assert(love.filesystem.read(directory..'shaders/volume-common.glsl'))
    for _,name in ipairs{'flux','transport','draw'} do
      local code=assert(love.filesystem.read(directory..'shaders/volume-'..name..'.glsl'))
      local shader=own(g.newShader('#pragma language glsl3\n'..common..code))
      self[name..'Shader']=shader
      shader:send('u_grid',self.grid);shader:send('u_cell',self.cell);shader:send('u_terrain',self.terrain)
    end
    local source=options.source or {x=580,y=96,width=56,rate=12000}
    local left=math.max(0,math.floor((source.x-source.width/2)/self.cell[1]))
    local right=math.min(self.columns-1,math.floor((source.x+source.width/2)/self.cell[1]))
    local row=math.max(0,math.min(self.rows-1,math.floor(source.y/self.cell[2])))
    self.transportShader:send('u_source',{left,row,right,row})
    self.sourceRate=(source.rate or 0)/(self.cell[1]*self.cell[2]*math.max(1,right-left+1))
  end,debug.traceback)
  g.pop()
  if not ok then self:release();return nil,tostring(reason) end
  return self
end
function F:update(dt,mouse)
  assert(not self.released,'water volume is released')
  -- Call on a fixed clock. Clamping avoids an unstable, arbitrarily large transport step.
  dt=math.min(math.max(dt,0),self.step)
  if dt==0 then return end
  self.time=self.time+dt
  local c=self.circle
  if mouse then c[1],c[2],c[3],c[4]=mouse.x,mouse.y,mouse.radius,mouse.enabled and mouse.inside and 1 or 0
  else c[4]=0 end
  local g=love.graphics
  g.push('all');g.origin();g.setScissor();g.setColor(1,1,1,1);g.setColorMask(true,true,true,true)
  g.setStencilTest();g.setDepthMode();g.setMeshCullMode('none');g.setWireframe(false)
  g.setBlendMode('replace','premultiplied')
  local flux,transport=self.fluxShader,self.transportShader
  flux:send('u_circle',c);flux:send('u_step',dt/self.step)
  transport:send('u_circle',c);transport:send('u_flux',self.flux)
  transport:send('u_add',self.inflow and self.sourceRate*dt/self.transportSteps or 0)
  -- More relaxations speed redistribution, without multiplying the incoming volume.
  for _=1,self.transportSteps do
    g.setCanvas(self.flux);g.setShader(flux);g.draw(self.state)
    g.setCanvas(self.next);g.setShader(transport);g.draw(self.state)
    self.state,self.next=self.next,self.state
  end
  g.pop()
end
function F:draw(debug)
  local g,s=love.graphics,self.drawShader
  g.push('all');g.setBlendMode('alpha');g.setColor(1,1,1,1)
  s:send('u_circle',self.circle);s:send('u_time',self.time)
  s:send('u_debug',not not debug)
  g.setShader(s);g.draw(self.state,0,0,0,self.cell[1],self.cell[2]);g.pop()
end
function F:release()
  if self.released then return end
  for _,resource in ipairs(self.owned) do resource:release() end
  self.released=true
end
return F
