-- Render geometry and collision data come from these same rounded rectangles.
local T = {}
T.__index = T
T.width, T.height, T.poolY = 1280, 800, 694
local function rectangleDistance(rock, x, y)
  local dx, dy = x-rock.x, y-rock.y
  local ca, sa = math.cos(rock.angle), math.sin(rock.angle)
  local px, py = dx*ca+dy*sa, -dx*sa+dy*ca
  local qx = math.abs(px)-(rock.w/2-rock.radius)
  local qy = math.abs(py)-(rock.h/2-rock.radius)
  return math.sqrt(math.max(qx,0)^2+math.max(qy,0)^2)+math.min(math.max(qx,qy),0)-rock.radius
end
function T.new()
  local self = setmetatable({rocks={
    {x=551-35*math.cos(0.22),y=360-35*math.sin(0.22),w=312,h=76,radius=23,angle=0.22},
    {x=804+83*math.cos(-0.4),y=533+83*math.sin(-0.4),w=420,h=100,radius=32,angle=-0.4},
    {x=480,y=697,w=242,h=126,radius=34,angle=-0.12},
    {x=1021,y=730,w=274,h=176,radius=39,angle=0.12},
  }}, T)
  local data = love.image.newImageData(640,400,'rgba32f')
  data:mapPixel(function(x,y)
    return self:distance((x+0.5)*2,(y+0.5)*2),0,0,1
  end)
  self.field = love.graphics.newImage(data)
  self.field:setFilter('linear','linear')
  self.field:setWrap('clamp','clamp')
  data:release()
  return self
end
function T:distance(x,y)
  return math.min(self.poolY-y,self:rockDistance(x,y))
end
function T:rockDistance(x,y)
  local d = 1e6
  for _,rock in ipairs(self.rocks) do d=math.min(d,rectangleDistance(rock,x,y)) end
  return d
end
function T:surface(index)
  local rock=self.rocks[index]
  local nx,ny=math.sin(rock.angle),-math.cos(rock.angle)
  return rock.x+nx*rock.h/2,rock.y+ny*rock.h/2,nx,ny
end
function T.drawRock(_,rock)
  local g=love.graphics
  g.push();g.translate(rock.x,rock.y);g.rotate(rock.angle)
  g.rectangle('fill',-rock.w/2,-rock.h/2,rock.w,rock.h,rock.radius,rock.radius)
  g.pop()
end
function T:release() self.field:release() end
return T
