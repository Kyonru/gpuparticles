local prefix=(...):gsub('example_support%.sdf_groups%.app$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local GifCapture=require(prefix..'example_support.gif_capture')

local M={}

local function circleDistance(x,y,cx,cy,radius)
  local dx,dy=x-cx,y-cy
  return math.sqrt(dx*dx+dy*dy)-radius
end

local function roundedBoxDistance(x,y,cx,cy,width,height,radius)
  local qx=math.abs(x-cx)-(width*0.5-radius)
  local qy=math.abs(y-cy)-(height*0.5-radius)
  return math.sqrt(math.max(qx,0)^2+math.max(qy,0)^2)+math.min(math.max(qx,qy),0)-radius
end

local function makeSdf(width,height)
  local textureWidth,textureHeight=480,320
  local data=love.image.newImageData(textureWidth,textureHeight,'rgba32f')
  data:mapPixel(function(column,row)
    local x=(column+0.5)/textureWidth*width
    local y=(row+0.5)/textureHeight*height
    local floor=height-66-y
    local pillar=circleDistance(x,y,width*0.5,height-188,76)
    local shelf=roundedBoxDistance(x,y,170,height-174,220,54,18)
    return math.min(floor,pillar,shelf),0,0,1
  end)
  local image=love.graphics.newImage(data)
  data:release()
  image:setFilter('linear','linear')
  image:setWrap('clamp','clamp')
  return image
end

local function emitterConfig(width,height,sdf,color,seed)
  return {
    max=6000,rate=1300,lifetime={3.4,4.4},seed=seed,
    position={width*0.5,44},emissionArea={distribution='uniform',x=width*0.46,y=2},
    direction=math.pi/2,spread=0.08,speed={35,90},gravity={0,250},damping=0.08,
    sizes={3,5,2,0},sizeVariation=0.45,blendMode='alpha',
    colors={{color[1],color[2],color[3],0.9},{color[1],color[2],color[3],0.65},{color[1],color[2],color[3],0}},
    collision={type='sdf',texture=sdf,size={width,height},radius=2,bounce=0.38,friction=0.08},
  }
end

function M.install()
  local width,height,time,accumulator=960,640,0,0
  local sdf,worldParticles,playerParticles,enemyParticles
  local playerEnabled,enemyEnabled=true,true
  local smoke,frames=false,0
  for _,value in ipairs(arg or {}) do if value=='--smoke' then smoke=true end end
  local gif=GifCapture.new('sdf-collision-groups')

  local function release()
    for _,emitter in ipairs{worldParticles,playerParticles,enemyParticles} do
      if emitter then emitter:release() end
    end
    if sdf then sdf:release() end
  end

  local function enemyShapes()
    local boxX=265+math.sin(time*0.9)*90
    local boxY=330+math.sin(time*1.4)*24
    local cx=700+math.cos(time*0.7)*72
    local cy=350+math.sin(time*1.1)*55
    local angle=time*0.8
    local dx,dy=math.cos(angle)*58,math.sin(angle)*58
    return boxX,boxY,cx-dx,cy-dy,cx+dx,cy+dy
  end

  local function updateColliders()
    local mouseX,mouseY=love.mouse.getPosition()
    if smoke then
      mouseX=width*0.5+math.sin(time*0.9)*210
      mouseY=height*0.38+math.cos(time*1.2)*70
    end
    if playerEnabled then playerParticles:setCircleCollider(mouseX,mouseY,48)
    else playerParticles:setCircleCollider() end
    local boxX,boxY,x1,y1,x2,y2=enemyShapes()
    if enemyEnabled then
      enemyParticles:setBoxCollider(boxX,boxY,116,62)
      enemyParticles:setCapsuleCollider(x1,y1,x2,y2,25)
    else
      enemyParticles:setBoxCollider()
      enemyParticles:setCapsuleCollider()
    end
  end

  function love.load()
    width,height=love.graphics.getDimensions()
    sdf=makeSdf(width,height)
    local world=emitterConfig(width,height,sdf,palette.beige,101)
    local player=emitterConfig(width,height,sdf,palette.peach,202)
    player.circleCollider={radius=48,particleRadius=2,bounce=0.5,friction=0.08,enabled=false}
    local enemy=emitterConfig(width,height,sdf,palette.teal,303)
    enemy.boxCollider={width=116,height=62,particleRadius=2,bounce=0.5,friction=0.08,enabled=false}
    enemy.capsuleCollider={radius=25,particleRadius=2,bounce=0.5,friction=0.08,enabled=false}
    worldParticles=gpu.newEmitter(world)
    playerParticles=gpu.newEmitter(player)
    enemyParticles=gpu.newEmitter(enemy)
    assert(worldParticles:getMode()=='stateful' and playerParticles:getMode()=='stateful' and enemyParticles:getMode()=='stateful')
    for _,emitter in ipairs{worldParticles,playerParticles,enemyParticles} do emitter:warm(1.3) end
    updateColliders()
  end

  function love.update(dt)
    dt=smoke and 1/60 or math.min(dt,1/30)
    accumulator=math.min(accumulator+dt,1/30)
    local step=1/120
    while accumulator>=step do
      time=time+step
      updateColliders()
      worldParticles:update(step)
      playerParticles:update(step)
      enemyParticles:update(step)
      accumulator=accumulator-step
    end
    if smoke then
      frames=frames+1
      if frames>=100 and (not gif or gif.done) then print('SDF groups standalone render PASS');love.event.quit() end
    end
  end

  function love.draw()
    local g=love.graphics
    g.clear(palette.ink)
    g.setColor(palette.deep)
    g.rectangle('fill',0,height-66,width,66)
    g.circle('fill',width*0.5,height-188,76)
    g.rectangle('fill',60,height-201,220,54,18,18)
    g.setLineWidth(2)
    g.setColor(palette.blue)
    g.line(0,height-66,width,height-66)
    g.circle('line',width*0.5,height-188,76)
    g.rectangle('line',60,height-201,220,54,18,18)

    worldParticles:draw()
    playerParticles:draw()
    enemyParticles:draw()

    local mouseX,mouseY=love.mouse.getPosition()
    if smoke then
      mouseX=width*0.5+math.sin(time*0.9)*210
      mouseY=height*0.38+math.cos(time*1.2)*70
    end
    if playerEnabled then
      g.setColor(palette.peach);g.circle('line',mouseX,mouseY,48)
    end
    local boxX,boxY,x1,y1,x2,y2=enemyShapes()
    if enemyEnabled then
      g.setColor(palette.teal);g.rectangle('line',boxX-58,boxY-31,116,62,8,8)
      g.line(x1,y1,x2,y2);g.circle('line',x1,y1,25);g.circle('line',x2,y2,25)
    end

    g.setColor(palette.beige);g.print('SDF COLLISION GROUPS',24,22)
    g.setColor(palette.blue);g.print('Blue outlines: shared static SDF',24,44)
    g.setColor(palette.beige);g.print('Beige particles: static SDF only',24,66)
    g.setColor(palette.peach);g.print('Peach: player circle  [P to toggle]',24,88)
    g.setColor(palette.teal);g.print('Teal: enemy box + capsule  [E to toggle]',24,110)
    g.setColor(palette.blue);g.print('Move mouse to move the player collider   Space: burst   Esc: quit',24,height-28)
    if gif then gif:draw(frames) end
  end

  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='p' then playerEnabled=not playerEnabled
    elseif key=='e' then enemyEnabled=not enemyEnabled
    elseif key=='space' then
      for _,emitter in ipairs{worldParticles,playerParticles,enemyParticles} do emitter:emit(300) end
    end
  end

  function love.quit() release() end
  function love.errorhandler(message) print(message);return function() return 1 end end
end

return M
