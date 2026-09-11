local Sprites=require('editor_support.sprites')
local Assets=require('editor_support.assets')
local D=require('editor_support.document')
local J=require('editor_support.json')
local Storage=require('editor_support.storage')
local Runtime=require('editor_support.runtime')
local T={}
local function render(effect)
  local g=love.graphics;local target=g.newCanvas(96,96,{dpiscale=1})
  g.push('all');g.setCanvas(target);g.origin();g.setScissor();g.clear(0,0,0,0);g.setColor(1,1,1,1)
  effect:draw(-432,-272);g.pop()
  local data=target:newImageData();target:release();return data
end
function T.run()
  for _,entry in ipairs(Sprites.entries) do
    local sprite=Sprites.make(entry.id);Assets.validate(sprite)
    assert(Sprites.identify(sprite)==entry.id and sprite.filter=='nearest','built-in sheets must identify themselves and use nearest filtering')
    local w,h=Assets.dimensions(Assets.bytes(sprite))
    assert(w/sprite.columns==h/sprite.rows and sprite.frames==entry.frames,'built-in sheet frames must be square and fully configured')
    local doc=D.new();local l=doc.layers[1];local c=l.emitter;l.sprite=sprite;l.bursts={{time=0,count=1}}
    c.max=1;c.rate=0;c.lifetime={4,4};c.position={480,320};c.speed={0,0};c.gravity={0,0};c.sizes={64};c.sizeVariation=0
    c.colors={{1,1,1,1}};c.blendMode='alpha';c.emissionArea.distribution='none'
    local decoded=Storage.decode(J.encode(doc));assert(decoded.layers[1].sprite.png==sprite.png,'built-in sheets must persist as embedded images')
    local source=Storage.exportSource(decoded)
    assert(not source:find('require%(["\']editor_support'),'built-in sheet exports must not depend on editor files')
    local original=Runtime.new(decoded);local exported=assert(loadstring(source))().new()
    assert(original.emitters[1]:getMode()=='analytic','choosing a built-in sprite must preserve analytic mode')
    local previous
    for frame=1,entry.frames do
      local time=(frame-0.5)/entry.frames*4;original:seek(time);exported:seek(time)
      local a,b=render(original),render(exported);local pixels=a:getString()
      assert(pixels==b:getString(),'built-in sprite frames must match in preview and export')
      assert(pixels~=previous,'built-in sprite frames must animate');previous=pixels
      local visible=0
      for y=0,95 do for x=0,95 do local _,_,_,alpha=a:getPixel(x,y);if alpha>0.1 then visible=visible+1 end end end
      assert(visible>10,'every built-in sprite frame must render visible pixels')
      a:release();b:release()
    end
    original:release();exported:release()
    sprite.frames=1;assert(Sprites.make(entry.id).frames==entry.frames,'editing a chosen sheet must not alter the built-in default')
  end
  assert(not pcall(Sprites.make,'missing'),'unknown built-in sprite IDs must be rejected')
  print('Editor built-in sheets / every frame rendered / mode / persistence / export parity / independent defaults PASS')
end
return T
