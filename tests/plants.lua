local Plants=require('example_support.waterfall.plants')
local T={}
local function near(a,b) assert(math.abs(a-b)<0.001,('plant expected %.6f, got %.6f'):format(b,a)) end
local function gpuPoints(plants,time)
  -- Run the production deformation shader, writing its world positions into a float target.
  local source=assert(love.filesystem.read('example_support/waterfall/shaders/plants.glsl'))
  source=source:gsub('#ifdef VERTEX','varying vec2 testPosition;\n#ifdef VERTEX',1)
  source=source:gsub('return transform%*vec4%(PlantRoot%+p,0%.0,1%.0%);',
    'testPosition=PlantRoot+p; return transform*vec4(PlantData.w+0.5,0.5,0.0,1.0);')
  source=source:gsub('return color;','return vec4(testPosition,0.0,1.0);')
  local shader=love.graphics.newShader(source);local p=plants.plants[1]
  local vertices={}
  for i=0,2 do vertices[#vertices+1]={0,-i*48,p.x,p.y,p.scale,p.angle,p.phase,i} end
  local mesh=love.graphics.newMesh({{'VertexPosition','float',2},{'PlantRoot','float',2},{'PlantData','float',4}},vertices,'points','static')
  local bends={};for i=1,64 do bends[i]={p.bx,p.by} end
  shader:send('u_time',time);shader:send('u_wind',plants.wind);shader:send('u_bends',unpack(bends))
  local g=love.graphics;local canvas=g.newCanvas(3,1,{format='rgba32f',dpiscale=1})
  g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.clear();g.setPointSize(1)
  g.setBlendMode('replace','premultiplied');g.setShader(shader);g.draw(mesh);g.pop()
  local data=canvas:newImageData();canvas:release();mesh:release();shader:release();return data
end
function T.run()
  local plants=Plants.new({{100,150,1,0}});local p=plants.plants[1]
  plants.wind=0
  local data=gpuPoints(plants,0);local x,y=data:getPixel(0,0);near(x,100);near(y,150)
  x,y=data:getPixel(2,0);near(x,100);near(y,54);data:release()
  plants.wind=1;data=gpuPoints(plants,1.2)
  x,y=data:getPixel(0,0);near(x,100);near(y,150)
  local wx,wy=plants:point(1,0,-96,1.2);x,y=data:getPixel(2,0);near(x,wx);near(y,wy)
  assert(math.abs(x-100)>0.2,'GPU wind must deform the fern tip');data:release()
  plants.wind=0
  local circle={x=90,y=90,radius=25,enabled=true,inside=true}
  for i=1,120 do plants:update(1/120,i/120,circle) end
  assert(p.bx>5,'circle contact must push the fern away')
  data=gpuPoints(plants,1);x,y=data:getPixel(0,0);near(x,100);near(y,150)
  x,y=data:getPixel(2,0);near(x,100+p.bx);near(y,54+p.by)
  assert(x>105,'GPU plants must render spring displacement');data:release()
  circle.enabled=false;local before=p.bx;plants:update(1/120,1,circle)
  assert(p.bx>before*0.8,'release must recover smoothly rather than snap')
  for i=1,720 do plants:update(1/120,1+i/120,circle) end
  near(p.bx,0);near(p.by,0);near(p.vx,0);near(p.vy,0)
  circle.enabled=true;circle.inside=false;plants:update(1/120,8,circle);near(p.bx,0)
  circle.inside=true;circle.x,circle.y=100,150;circle.radius=140
  for i=1,360 do plants:update(1/120,8+i/120,circle) end
  assert(p.bx==p.bx and p.by==p.by and math.abs(p.bx)<60 and math.abs(p.by)<60,'deep contact must remain bounded')
  local g=love.graphics;g.push('all');g.setBlendMode('add');g.setColor(0.2,0.3,0.4,0.5);plants:draw(11)
  assert(g.getShader()==nil and g.getBlendMode()=='add');local r,green,b,a=g.getColor();near(r,0.2);near(green,0.3);near(b,0.4);near(a,0.5);g.pop()
  plants:release();plants:release()
  print('Plant numeric GPU deformation / anchored roots / wind / circle / smooth recovery / bounds / state restoration PASS')
end
return T
