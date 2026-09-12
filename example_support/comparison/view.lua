local V={}
V.__index=V
function V.new()
  return setmetatable({title=love.graphics.newFont(27),number=love.graphics.newFont(34),label=love.graphics.newFont(13),small=love.graphics.newFont(11)},V)
end
local function time(ms) return ('%.3f ms'):format(ms) end
local function fps(value) return value and ('%.0f FPS'):format(value) or 'not measured' end
function V.particleViewport(_,name,width,height)
  width,height=width or love.graphics.getWidth(),height or love.graphics.getHeight()
  local span=(width-76)/2
  local top=147
  local bottom=height-94
  local size=math.min(span-24,math.max(100,bottom-top-62))
  local x=name=='native' and 28 or width/2+10
  return x+(span-size)/2,top,size
end
function V:mapPointer(x,y,width,height)
  for _,name in ipairs{'native','gpu'} do
    local left,top,size=self:particleViewport(name,width,height)
    if x>=left and x<=left+size and y>=top and y<=top+size then
      return (x-left)*512/size,(y-top)*512/size,true
    end
  end
  return nil,nil,false
end
function V:draw(model)
  local g=love.graphics
  local pair=model.particleCollision
  local width,height=g.getDimensions()
  g.push('all');g.setShader();g.setColor(1,1,1,1)
  g.clear(0.033,0.047,0.068)
  g.setFont(self.title);g.setColor(0.9,0.94,0.97)
  g.print(pair and 'Particle contacts' or model.mouseCollision and 'Mouse collision' or 'LÖVE / GPU',28,24)
  g.setFont(self.small);g.setColor(0.52,0.67,0.78)
  local detail=pair and ('%s each · %d contact iteration%s'):format(model.capacity,model.iterations,model.iterations==1 and '' or 's')
    or ('%s each · %d px · %g s · %s'):format(model.capacity,model.size,model.lifetime,model.gpuMode)
  g.print(detail,28,61)
  local live=model.fps>0 and ('%.0f'):format(model.fps) or '…'
  g.setFont(self.number);g.setColor(0.63,0.94,0.86);g.printf(live,width-187,23,155,'right')
  g.setFont(self.small);g.setColor(0.48,0.69,0.70);g.printf(model.view=='both' and 'WINDOW FPS' or 'ISOLATED FPS',width-212,61,180,'right')
  local top,bottom=90,height-94
  local panelWidth=(width-76)/2
  local panelHeight=bottom-top
  local function panel(name,x,span)
    local active=model:active(name)
    local blue=name=='native' and {0.55,0.72,0.94} or {0.43,0.87,0.74}
    g.setColor(0.05,0.074,0.104);g.rectangle('fill',x,top,span,panelHeight,8,8)
    g.setColor(unpack(blue));g.setFont(self.label)
    local backend=model.backend=='gpu' and ('GPU  /  '..model.gpuMode) or 'gpuparticles  /  native fallback'
    local heading=name=='native' and 'LÖVE  /  ParticleSystem' or backend
    if pair then
      local emitter=name=='native' and model.native or model.gpu
      heading=emitter:getBackend()=='gpu' and ('GPU stateful  ·  contacts '..(name=='native' and 'OFF' or 'ON')) or 'Native fallback · contacts unavailable'
    end
    g.print(heading,x+15,top+13)
    g.setFont(self.small);g.setColor(0.44,0.58,0.69)
    local count=name=='native' and model.liveNative or model.liveGPU
    local note=active and '' or '  ·  inactive'
    if model.mouseCollision then note=note..((name=='gpu' or pair) and model.backend=='gpu' and '  ·  collides with circle' or '  ·  passes through circle') end
    g.print(('%d particles%s'):format(count,note),x+15,top+35)
    g.setColor(1,1,1,active and 1 or 0.30)
    local imageX,imageY,size=self:particleViewport(name,width,height)
    g.draw(model.targets[name],imageX,imageY,0,size/512,size/512)
    if model.mouseCollision and model.pointer.inside then
      local p=model.pointer
      g.setScissor(imageX,imageY,size,size)
      g.setColor(0.98,0.69,0.39,name=='gpu' and 0.12 or 0.035)
      g.circle('fill',imageX+p.x*size/512,imageY+p.y*size/512,p.radius*size/512)
      g.setColor(0.98,0.69,0.39,name=='gpu' and 0.95 or 0.35);g.setLineWidth(1.5)
      g.circle('line',imageX+p.x*size/512,imageY+p.y*size/512,p.radius*size/512)
      g.setScissor()
    end
    g.setFont(self.small);g.setColor(0.49,0.62,0.73)
    local y=bottom-41
    g.print('UPDATE',x+15,y);g.print('DRAW SUBMIT',x+span/2,y)
    g.setFont(self.label);g.setColor(unpack(blue))
    g.print(active and time(model.cost[name].update) or '—',x+15,y+15)
    g.print(active and time(model.cost[name].draw) or '—',x+span/2,y+15)
  end
  panel('native',28,panelWidth);panel('gpu',width/2+10,panelWidth)
  g.setFont(self.label);g.setColor(0.69,0.79,0.86)
  local native=fps(model.results.native);local device=fps(model.results.gpu)
  local summary='LÖVE '..native..'     ·     '..(model.backend=='gpu' and 'GPU ' or 'Fallback ')..device
  if pair then
    summary='Contacts off '..native..'     ·     on '..device
    if model.results.native and model.results.gpu then summary=summary..('     ·     %.2fx frame time'):format(model.results.native/model.results.gpu) end
  end
  if model.benchmark then
    local label=pair and ('GPU with particle contact '..(model.view=='native' and 'OFF' or 'ON')) or model.view
    summary=('Benchmarking %s alone… %0.1f / 3.0 s'):format(label,model.benchmark.elapsed)
  end
  if model.mouseCollision then summary=('Circle %d px     ·     GPU collides     ·     LÖVE passes through'):format(model.pointer.radius) end
  g.print(summary,28,height-72)
  g.setFont(self.small);g.setColor(0.52,0.67,0.77)
  local controls='1 Left   2 Right   3 Both   B Benchmark   Up/Down Count   [ ] Size   M Mode   C Circle   S Contacts'
  if pair then controls=controls..'   I Iterations' end
  controls=controls..'   Space '..(model.paused and 'Resume' or 'Pause')..'   R Reset   Esc'
  g.print(controls,28,height-38)
  g.pop()
end
function V:release() self.title:release();self.number:release();self.label:release();self.small:release() end
return V
