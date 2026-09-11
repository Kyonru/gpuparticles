local D=require('editor_support.document')
local Assets=require('editor_support.assets')
local Runtime=require('editor_support.runtime')
local Storage=require('editor_support.storage')
local Json=require('editor_support.json')
local T={}
local function near(a,b) assert(math.abs(a-b)<0.015,('appearance expected %.4f, got %.4f'):format(b,a)) end
function T.sprite(sheet)
  local data=love.image.newImageData(sheet and 16 or 8,8)
  data:mapPixel(function(x) return sheet and (x<8 and 1 or 0) or 1,sheet and 0 or 1,sheet and (x<8 and 0 or 1) or 1,1 end)
  local file=data:encode('png');local bytes=file:getString();file:release();data:release()
  local sprite=Assets.import(bytes,'test-sprite.png')
  if sheet then sprite.columns=2;sprite.frames=2 end
  return sprite,bytes
end
local function definition()
  local d=D.new();local l=d.layers[1];local c=l.emitter
  d.loop=false;l.sprite=T.sprite();l.bursts={{time=0,count=1}};c.max=1;c.rate=0;c.lifetime={2,2}
  c.position={480,320};c.speed={0,0};c.gravity={0,0};c.sizes={16};c.sizeVariation=0;c.colors={{0.3,0.6,0.9,1}}
  c.blendMode='alpha';c.emissionArea.distribution='none'
  return d,l
end
local function render(effect)
  local g=love.graphics;local canvas=g.newCanvas(960,640,{format='rgba32f',dpiscale=1})
  g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.setColor(1,1,1,1);g.clear(0,0,0,0);effect:draw();g.pop()
  local data=canvas:newImageData();canvas:release();return data
end
local function output(doc,time)
  D.validate(doc);local effect=Runtime.new(doc);effect:seek(time or 0.1)
  assert(effect.emitters[1]:getMode()=='analytic','appearance effects must stay analytic')
  local data=render(effect);effect:release();return data
end
local function total(data)
  local sum=0;for y=290,350 do for x=450,510 do local r,g,b=data:getPixel(x,y);sum=sum+r+g+b end end;return sum
end
function T.run()
  local doc,l=definition()
  local runtime=Runtime.new(doc);assert(next(runtime.appearances)==nil,'disabled effects must allocate no processing canvases');runtime:release()
  local baseline=output(doc);local r,g,b=baseline:getPixel(480,320);near(r,0.3);near(g,0.6);near(b,0.9)
  l.appearance.levels=2;l.appearance.tint={1,0.5,1}
  local data=output(doc);r,g,b=data:getPixel(480,320);near(r,0);near(g,0.5);near(b,1);data:release()
  l.appearance=D.layer().appearance;l.appearance.outline=3
  data=output(doc);local _,_,_,alpha=data:getPixel(470,320);assert(alpha>0.9,'outline must extend the layer silhouette');data:release()
  l.appearance=D.layer().appearance;l.appearance.glow=1;l.appearance.glowRadius=6
  data=output(doc);r,g,b=data:getPixel(470,320);assert(r+g+b>0.05,'glow must contribute outside the layer silhouette');data:release()
  l.appearance.dissolve=1;data=output(doc);assert(total(data)==0,'full dissolve must remove the layer and its halo');data:release()
  l.appearance=D.layer().appearance;l.appearance.distortion=10
  data=output(doc);local diff=0
  for y=290,350 do for x=450,510 do local a=baseline:getPixel(x,y);local v=data:getPixel(x,y);diff=diff+math.abs(a-v) end end
  assert(diff>10,'distortion must move rendered pixels');data:release();baseline:release()
  l.appearance=D.layer().appearance;l.appearance.pixelSize=4;l.emitter.position={481,321};l.emitter.rotation={0.6,0.6}
  data=output(doc)
  for y=296,344,4 do for x=456,504,4 do
    local rr,gg,bb,aa=data:getPixel(x,y)
    for dy=0,3 do for dx=0,3 do local cr,cg,cb,ca=data:getPixel(x+dx,y+dy);near(rr,cr);near(gg,cg);near(bb,cb);near(aa,ca) end end
  end end
  assert(total(data)>20,'pixel grid must retain visible output');data:release()
  l.emitter.position={480,320};l.emitter.rotation={0,0};l.emitter.colors={{0.3,0.6,0.9,0.5}}
  data=output(doc);local pr,pg,pb,pa=data:getPixel(480,320)
  near(pr,0.15);near(pg,0.3);near(pb,0.45);near(pa,0.5);data:release()
  print('Editor palette / tint / outline / glow / dissolve / distortion / integer pixel grid / analytic mode PASS')

  doc,l=definition();l.sprite=T.sprite(true);l.emitter.colors={{1,1,1,1}}
  data=output(doc,0.2);r,g,b=data:getPixel(480,320);near(r,1);near(g,0);near(b,0);data:release()
  data=output(doc,1.2);r,g,b=data:getPixel(480,320);near(r,0);near(g,0);near(b,1);data:release()
  assert(Json.encode(Storage.decode(Json.encode(doc)))==Json.encode(doc),'embedded PNG must survive project round trip')
  local copy=D.copy(doc);copy.layers[1].sprite.columns=3;assert(not pcall(D.validate,copy),'invalid sheet geometry must be rejected')
  copy=D.copy(doc);copy.layers[1].sprite.frames=3;assert(not pcall(D.validate,copy),'invalid sheet frame count must be rejected')
  copy=D.copy(doc);copy.layers[1].sprite.png='AAAA';assert(not pcall(D.validate,copy),'invalid embedded PNG must be rejected')
  local _,bytes=T.sprite();assert(not pcall(Assets.import,bytes:sub(1,30),'truncated.png'),'truncated PNG must be rejected before editing')
  assert(Json.decode(Json.encode(string.rep('abc',2000)))==string.rep('abc',2000),'JSON must support embedded image strings')
  copy=D.copy(doc);copy.layers[1].sprite=nil;copy.layers[1].appearance=nil;D.validate(copy)
  assert(copy.layers[1].appearance.pixelSize==1,'old projects must get neutral appearance defaults')
  print('Editor PNG decoding / sheet animation / embedded image round trip / validation / old project compatibility PASS')

  doc,l=definition();l.appearance.pixelSize=2;l.appearance.outline=2;l.appearance.glow=0.2
  local original=Runtime.new(doc);local exported=assert(loadstring(Storage.exportSource(doc)))().new()
  original:seek(0.4);exported:seek(0.4);local a,bdata=render(original),render(exported)
  for y=290,350 do for x=450,510 do local ar,ag,ab,aa=a:getPixel(x,y);local br,bg,bb,ba=bdata:getPixel(x,y);near(ar,br);near(ag,bg);near(ab,bb);near(aa,ba) end end
  a:release();bdata:release();exported:release()
  local gapi=love.graphics;local target=gapi.newCanvas(960,640)
  gapi.push('all');gapi.setCanvas(target);gapi.setScissor(3,5,800,600);gapi.setBlendMode('add');gapi.setColor(0.4,0.5,0.6,0.7)
  original:draw(5,7);assert(gapi.getCanvas()==target and gapi.getBlendMode()=='add' and gapi.getShader()==nil,'appearance must restore caller graphics state')
  local sx,sy=gapi.getScissor();assert(sx==3 and sy==5);local cr,cg,cb,ca=gapi.getColor();near(cr,0.4);near(cg,0.5);near(cb,0.6);near(ca,0.7)
  gapi.pop();target:release();original:release()
  print('Editor textured shader export parity / caller graphics state PASS')

  doc,l=definition();l.sprite=T.sprite(true);l.emitter.colors={{1,1,1,1}};l.appearance.pixelSize=2
  local gpu=require('gpuparticles');local capabilities=gpu.getCapabilities
  gpu.getCapabilities=function() local caps=capabilities();caps.analytic=false;caps.stateful=false;return caps end
  local ok,native=pcall(Runtime.new,doc)
  gpu.getCapabilities=capabilities;assert(ok,native)
  assert(native.emitters[1]:getBackend()=='native');native:seek(0.2);data=render(native)
  for _,x in ipairs{472,480,487} do local red,_,_,a2=data:getPixel(x,320);near(red,1);near(a2,1) end
  for _,x in ipairs{471,488} do local _,_,_,a2=data:getPixel(x,320);near(a2,0) end
  data:release();native:release()
  print('Editor native sprite-sheet size / centering / appearance PASS')
end
return T
