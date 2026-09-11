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
  local size=math.min(span-24,math.max(100,height-379))
  local x=name=='native' and 28 or width/2+10
  return x+(span-size)/2,177,size
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
  g.setFont(self.small);g.setColor(0.44,0.60,0.74)
  g.print(pair and 'GPU PARTICLES  /  PARTICLE COLLISION COMPARISON' or model.mouseCollision and 'GPU PARTICLES  /  MOUSE COLLISION DEMO' or 'GPU PARTICLES  /  MATCHED COMPARISON',28,22)
  g.setFont(self.title);g.setColor(0.9,0.94,0.97);g.print(pair and 'Particle contact. Off / on.' or 'The same falling-water preset.',26,40)
  g.setFont(self.label);g.setColor(0.58,0.69,0.79)
  g.print(('%s capacity each  ·  %d px  ·  %g s lifetime  ·  %s  ·  VSync off'):format(
    model.capacity,model.size,model.lifetime,pair and (model.iterations..' contact iteration(s)') or model.mouseCollision and 'GPU collision on' or 'collisions off'),28,79)
  local live=model.fps>0 and ('%.0f'):format(model.fps) or '…'
  g.setFont(self.number);g.setColor(0.63,0.94,0.86);g.printf(live,width-187,23,155,'right')
  g.setFont(self.small);g.setColor(0.48,0.69,0.70);g.printf(model.view=='both' and 'SHARED WINDOW FPS' or 'ISOLATED WINDOW FPS',width-212,65,180,'right')
  local top,bottom=120,height-143
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
      heading=emitter:getBackend()=='gpu' and ('GPU stateful  /  particle collisions '..(name=='native' and 'OFF' or 'ON')) or 'Native fallback / particle collisions unavailable'
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
    g.print('CPU UPDATE',x+15,y);g.print('CPU DRAW SUBMISSION',x+span/2,y)
    g.setFont(self.label);g.setColor(unpack(blue))
    g.print(active and time(model.cost[name].update) or '—',x+15,y+15)
    g.print(active and time(model.cost[name].draw) or '—',x+span/2,y+15)
  end
  panel('native',28,panelWidth);panel('gpu',width/2+10,panelWidth)
  g.setFont(self.label);g.setColor(0.69,0.79,0.86)
  local native=fps(model.results.native);local device=fps(model.results.gpu)
  local summary='Isolated results    LÖVE '..native..'     /     '..(model.backend=='gpu' and 'GPU ' or 'Fallback ')..device
  if pair then
    summary='Isolated window results    OFF '..native..'     /     ON '..device
    if model.results.native and model.results.gpu then summary=summary..('    ·    %.2fx frame time'):format(model.results.native/model.results.gpu) end
  end
  if model.benchmark then
    local label=pair and ('GPU with particle contact '..(model.view=='native' and 'OFF' or 'ON')) or model.view
    summary=('Benchmarking %s alone… %0.1f / 3.0 s'):format(label,model.benchmark.elapsed)
  end
  if model.mouseCollision then summary=('Mouse obstacle  /  %d px radius  /  %s'):format(model.pointer.radius,pair and 'Both GPU systems collide with the circle.' or 'GPU collides; native particles pass through.') end
  g.print(summary,28,height-121)
  g.setFont(self.small);g.setColor(0.46,0.61,0.72)
  g.print(pair and 'B isolates each system with one 1/120 s simulation step per frame. CPU timings exclude GPU completion.' or
    'Side-by-side FPS includes both systems. CPU submission time excludes GPU completion. B measures each system separately.',28,height-96)
  g.setFont(self.label);g.setColor(0.65,0.77,0.86)
  g.print('1 Left only   2 Right only   3 Both   B Benchmark   UP / DOWN Count   [ ] Size   S Particle collisions',28,height-66)
  g.setFont(self.small);g.setColor(0.43,0.57,0.69)
  g.print('I Contact iterations   M GPU mode   C Mouse collider   Wheel Radius   SPACE '..(model.paused and 'Resume' or 'Pause')..'   R Restart   ESC Exit',28,height-41)
  g.print(pair and 'Up to 10,000 particles. Preview limits catch-up to two steps/frame and slows under load. Dense piles can still overlap.' or model.mouseCollision and 'Hover either particle panel. B disables the obstacle for a matched benchmark.' or
    'Same texture and spawn settings; randomness is sampled independently. Press C to try a mouse obstacle.',28,height-22)
  g.pop()
end
function V:release() self.title:release();self.number:release();self.label:release();self.small:release() end
return V
