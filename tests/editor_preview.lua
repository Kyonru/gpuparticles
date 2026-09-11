local App=require('editor_support.app')
local View=require('editor_support.view')
local D=require('editor_support.document')
local Runtime=require('editor_support.runtime')
local T={}
local function near(a,b) assert(math.abs(a-b)<0.01,('preview expected %.4f, got %.4f'):format(b,a)) end
local function document(x,y,pixel)
  local doc=D.new();local layer=doc.layers[1];local c=layer.emitter
  layer.sprite=require('tests.editor_appearance').sprite();layer.bursts={{time=0,count=1}}
  c.max=1;c.rate=0;c.lifetime={10,10};c.speed={0,0};c.gravity={0,0};c.position={x,y};c.sizes={24};c.sizeVariation=0
  c.colors={{1,0,1,1}};c.blendMode='alpha';c.emissionArea.distribution='none';layer.appearance.pixelSize=pixel
  local hidden=D.layer('Gizmo');hidden.enabled=false;hidden.emitter.max=1;hidden.emitter.rate=0
  doc.layers[2]=hidden;return doc
end
local function draw(app,w,h)
  local g=love.graphics;local target=g.newCanvas(w,h,{dpiscale=1})
  g.push('all');g.setCanvas(target);g.origin();g.setScissor();app:draw();g.pop()
  local data=target:newImageData();target:release();return data
end
function T.run()
  local g=love.graphics;local previousW,previousH=g.getDimensions()
  for _,size in ipairs{{1120,760},{1440,900},{1920,900}} do
    local w,h=unpack(size);love.window.setMode(w,h,{vsync=0})
    local layout=View.layout(w,h);local area=View.previewRect(layout)
    local app=App.new();app.model.playing=false;app.model.grid=false
    for _,pixel in ipairs{1,4} do
      for _,point in ipairs{{area.x+area.w/2,area.y+10},{area.x+10,area.y+area.h/2}} do
        local wx,wy,inside=View.world(layout,point[1],point[2]);assert(inside,'the entire preview must accept pointer input')
        assert(app.model:replace(document(wx,wy,pixel)));app.model:update(0.01)
        local data=draw(app,w,h);local r,green,b=data:getPixel(math.floor(point[1]),math.floor(point[2]))
        assert(r>0.8 and green<0.1 and b>0.8,'particles must render through the full preview, including above the old top edge')
        local _,_,_,alpha=data:getPixel(0,0);near(alpha,1);data:release()
        local appearance=app.model.runtime.appearances[1]
        if appearance then
          local canvas=appearance.canvas;data=draw(app,w,h);data:release()
          assert(canvas==appearance.canvas,'a stable preview must reuse its appearance canvas')
        end
      end
    end
    local wx,wy,inside=View.world(layout,area.x+10,area.y+10);assert(inside)
    app.model:select(1);app:mousepressed(area.x+10,area.y+10,1);app:mousereleased(area.x+10,area.y+10,1)
    near(app.model:layer().emitter.position[1],wx);near(app.model:layer().emitter.position[2],wy)
    local _,_,header=View.world(layout,area.x+10,area.y-10);assert(not header,'preview header must remain outside the interaction area')
    app:release()
  end
  love.window.setMode(previousW,previousH,{vsync=0})
  local doc=document(480,320,4);doc.layers[1].appearance.dissolve=0.4
  local effect=Runtime.new(doc);effect:seek(0.2)
  local function render(bounds)
    local target=g.newCanvas(1100,800,{dpiscale=1})
    g.push('all');g.setCanvas(target);g.origin();g.setScissor();g.clear(0,0,0,0);g.setColor(1,1,1,1);g.translate(64,64)
    effect:draw(0,0,bounds);g.pop();local data=target:newImageData();target:release();return data
  end
  local a=render();local b=render({x=-64,y=-64,w=1088,h=768})
  for y=370,398 do for x=530,558 do local ar,ag,ab,aa=a:getPixel(x,y);local br,bg,bb,ba=b:getPixel(x,y);near(ar,br);near(ag,bg);near(ab,bb);near(aa,ba) end end
  a:release();b:release();effect:release()
  print('Editor full preview / top-edge particles / resize / extended pointer mapping / canvas reuse / stable shader coordinates PASS')
end
return T
