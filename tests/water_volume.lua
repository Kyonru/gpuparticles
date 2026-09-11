local Fluid=require('example_support.waterfall.fluid')
local M={}
local function near(actual,expected,tolerance,label)
  assert(math.abs(actual-expected)<tolerance,('%s: expected %.6f, got %.6f'):format(label,expected,actual))
end
local function snapshot(fluid)
  local data=fluid.state:newImageData()
  local result={mass=0,added=0,overflow=0,upper=0,lower=0}
  for y=0,fluid.rows-1 do for x=0,fluid.columns-1 do
    local m,added,flow,overflow=data:getPixel(x,y)
    assert(m==m and m>=0 and m<10000 and flow==flow,'water mass must remain finite and nonnegative')
    result.mass=result.mass+m;result.added=result.added+added;result.overflow=result.overflow+overflow
    local region=y<12 and 'upper' or 'lower';result[region]=result[region]+m
  end end
  data:release();return result
end
local function budget(fluid,initial)
  local s=snapshot(fluid)
  near(s.mass+s.overflow,(initial or 0)+s.added,0.012,'conserved water budget')
  return s
end
local function seed(fluid,fn)
  local g=love.graphics
  local data=love.image.newImageData(fluid.columns,fluid.rows,'rgba32f')
  data:mapPixel(function(x,y) return fn(x,y),0,0,0 end)
  local image=g.newImage(data)
  g.push('all');g.origin();g.setShader();g.setScissor();g.setCanvas(fluid.state)
  g.setColor(1,1,1,1);g.setBlendMode('replace','premultiplied');g.draw(image);g.pop()
  image:release();data:release()
end
local function steps(fluid,count,circle)
  for _=1,count do fluid:update(Fluid.step,circle) end
end
function M.run()
  local g=love.graphics
  local f=assert(Fluid.new{width=7,height=7,cellSize=1,source={x=3,y=0,width=0,rate=0},
    distance=function(x) return math.floor(x)==3 and 1 or -1 end})
  seed(f,function(x,y) return x==3 and y==2 and 0.5 or 0 end)
  for _,canvas in ipairs{f.state,f.next,f.flux} do
    local min,mag=canvas:getFilter();assert(min=='nearest' and mag=='nearest','water state filtering must be nearest')
  end
  local target=g.newCanvas(16,16)
  g.push('all');g.setCanvas(target);g.translate(9,11);g.setScissor(2,3,4,5)
  g.setBlendMode('add','alphamultiply');g.setColor(0.2,0.3,0.4,0.5)
  f:update(Fluid.step)
  assert(g.getCanvas()==target,'water pass must restore caller canvas')
  local mode,alpha=g.getBlendMode();assert(mode=='add' and alpha=='alphamultiply')
  local x,y=g.transformPoint(0,0);near(x,9,1e-6,'restored transform');near(y,11,1e-6,'restored transform')
  local sx,sy,sw,sh=g.getScissor();assert(sx==2 and sy==3 and sw==4 and sh==5)
  local r,green,b,a=g.getColor()
  near(r,0.2,1e-6,'restored color');near(green,0.3,1e-6,'restored color')
  near(b,0.4,1e-6,'restored color');near(a,0.5,1e-6,'restored color')
  f:draw();assert(g.getCanvas()==target);g.pop();target:release()
  local data=f.state:newImageData()
  near(data:getPixel(3,3),0.25,1e-6,'water gravity transfer');near(data:getPixel(3,2),0.25,1e-6,'water gravity departure')
  data:release();budget(f,0.5);f:release();f:release()
  assert(not pcall(f.state.getDimensions,f.state) and not pcall(f.terrain.getDimensions,f.terrain), 'water resources must be released')
  print('Water volume gravity / numeric mass / graphics restoration / filtering / release PASS')

  local function basin()
    return assert(Fluid.new{width=24,height=24,cellSize=1,source={x=12,y=2,width=2,rate=50},
      distance=function(px,py)
        local ix,iy=math.floor(px),math.floor(py)
        if ix<3 or ix>=21 or iy>=23 or (iy>=12 and iy<14 and (ix<10 or ix>14)) then return -1 end
        return 1
      end})
  end
  local open,blocked=basin(),basin()
  local circle={x=12.5,y=12.5,radius=3.2,enabled=true,inside=true}
  steps(open,240);steps(blocked,240,circle)
  local os,bs=budget(open),budget(blocked)
  near(os.added,100,0.001,'water source rate')
  assert(bs.added<=100.001 and bs.added>60,'blocked source must admit only available volume')
  assert(os.lower>45 and bs.lower<0.001 and bs.upper>60,'circle dam must retain upstream water and reduce downstream supply')
  blocked.inflow=false
  steps(blocked,360)
  local drained=budget(blocked)
  assert(drained.lower>bs.lower+40 and drained.upper<bs.upper-40,'removing the circle dam must drain the temporary pool')
  near(drained.added,bs.added,0.001,'inflow off must stop adding water')
  local spread=blocked.state:newImageData();local wet=0
  for ix=3,20 do if spread:getPixel(ix,22)>0.1 then wet=wet+1 end end
  spread:release();assert(wet>=16,'water must spread across the basin floor')
  steps(blocked,600)
  local persisted=budget(blocked)
  near(persisted.mass,drained.mass,0.01,'pool persists without inflow or particles')
  print('Water volume source / spontaneous circle dam / release / lateral spreading / persistent pool PASS')

  circle.x,circle.y,circle.radius=12,21,5
  local before=budget(blocked).mass
  steps(blocked,1,circle);budget(blocked)
  steps(blocked,120,circle)
  near(budget(blocked).mass,before,0.01,'moving circle must displace, never delete water')
  data=blocked.state:newImageData();local trapped=0
  for iy=0,23 do for ix=0,23 do
    if (ix+0.5-circle.x)^2+(iy+0.5-circle.y)^2<circle.radius^2 then trapped=trapped+data:getPixel(ix,iy) end
  end end
  data:release();assert(trapped<0.001,'displaced water must escape the circle interior')
  open:release();blocked:release()

  f=assert(Fluid.new{width=2,height=2,cellSize=1,source={x=0,y=0,width=0,rate=0}})
  seed(f,function() return 4 end);steps(f,60)
  assert(budget(f,16).overflow>5,'water above the open top must be accounted as overflow')
  f:release()
  print('Water volume moving collider / conservation / explicit top overflow PASS')
  require('tests.water_volume_scene').run()
end
function M.install()
  function love.load()
    local ok,err=xpcall(M.run,debug.traceback)
    love.graphics.setCanvas()
    if not ok then print(err) end
    love.event.quit(ok and 0 or 1)
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
