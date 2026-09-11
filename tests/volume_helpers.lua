local H={}
function H.near(actual,expected,tolerance,label)
  assert(math.abs(actual-expected)<tolerance,('%s expected %.8f, got %.8f'):format(label or 'volume',expected,actual))
end
function H.sum(material)
  local w=material.world;local d=w:readback(material)
  local s={mass=0,added=0,heat=0,lost=0,x=0,y=0}
  for y=0,w.rows-1 do for x=0,w.columns-1 do
    local r,g,b,a=d:getPixel(x,y)
    assert(r==r and r>=-1e-7 and r<1e8 and b==b and b>=-1e-7,'volume density and heat must stay finite and nonnegative')
    s.mass=s.mass+r;s.added=s.added+g;s.heat=s.heat+b;s.lost=s.lost+a
    s.x=s.x+(x+0.5)*w.cell[1]*r;s.y=s.y+(y+0.5)*w.cell[2]*r
  end end
  if s.mass>0 then s.x,s.y=s.x/s.mass,s.y/s.mass end
  d:release();return s
end
function H.seed(canvas,fn)
  local g=love.graphics;local width,height=canvas:getDimensions()
  local data=love.image.newImageData(width,height,'rgba32f');data:mapPixel(fn)
  local image=g.newImage(data)
  g.push('all');g.origin();g.setScissor();g.setShader();g.setColor(1,1,1,1)
  g.setCanvas(canvas);g.setBlendMode('replace','premultiplied');g.draw(image);g.pop()
  image:release();data:release()
end
function H.picture(world)
  local g=love.graphics;local c=g.newCanvas(world.width,world.height,{format='rgba32f',dpiscale=1,msaa=0})
  g.push('all');g.setCanvas(c);g.origin();g.setScissor();g.clear(0,0,0,0);world:draw();g.pop()
  local d=c:newImageData();c:release();return d
end
return H
