-- PNGs are embedded as data, never paths or executable project content.
local A={maxBytes=1048576,maxDimension=1024}
local function integer(bytes,at)
  local a,b,c,d=bytes:byte(at,at+3)
  assert(d,'Truncated PNG header.')
  return ((a*256+b)*256+c)*256+d
end
function A.dimensions(bytes)
  assert(type(bytes)=='string' and #bytes<=A.maxBytes,'Use a PNG no larger than 1 MB.')
  assert(bytes:sub(1,8)=='\137PNG\r\n\26\n' and bytes:sub(13,16)=='IHDR' and integer(bytes,9)==13,'Invalid PNG header.')
  local w,h=integer(bytes,17),integer(bytes,21)
  assert(w>=1 and h>=1 and w<=A.maxDimension and h<=A.maxDimension,'Use a PNG at most 1024 × 1024 pixels.')
  return w,h
end
function A.bytes(sprite)
  assert(type(sprite.png)=='string' and #sprite.png<=1398104 and #sprite.png%4==0 and not sprite.png:find('[^A-Za-z0-9+/=]'),'Invalid embedded PNG data.')
  local bytes=love.data.decode('string','base64',sprite.png)
  A.dimensions(bytes);return bytes
end
function A.image(sprite)
  local bytes=A.bytes(sprite)
  local file=love.filesystem.newFileData(bytes,'particle.png')
  local ok,data=pcall(love.image.newImageData,file);file:release();assert(ok,data)
  local good,image=pcall(love.graphics.newImage,data);data:release();assert(good,image)
  image:setFilter(sprite.filter,sprite.filter);return image
end
function A.import(bytes,name)
  A.dimensions(bytes)
  local sprite={name=name,png=love.data.encode('string','base64',bytes),columns=1,rows=1,frames=1,filter='nearest'}
  local image=A.image(sprite);image:release() -- Decode before changing a valid project.
  return sprite
end
function A.validate(sprite)
  assert(type(sprite)=='table','Missing texture settings.')
  for k in pairs(sprite) do assert(({name=true,png=true,columns=true,rows=true,frames=true,filter=true})[k],'Unknown texture setting: '..tostring(k)) end
  assert(type(sprite.name)=='string' and #sprite.name<=120 and not sprite.name:find('[%z\1-\31]'),'Invalid texture name.')
  assert(require('utf8').len(sprite.name),'Texture name must be valid UTF-8.')
  assert(sprite.filter=='nearest' or sprite.filter=='linear','Texture filter must be nearest or linear.')
  for _,k in ipairs{'columns','rows','frames'} do
    local v=sprite[k];assert(type(v)=='number' and v%1==0 and v>=1 and v<=256,'Sheet dimensions and frames must be integers from 1 to 256.')
  end
  assert(sprite.frames<=sprite.columns*sprite.rows,'Frame count exceeds the sprite sheet.')
  if sprite.png~='' then
    local w,h=A.dimensions(A.bytes(sprite))
    assert(w%sprite.columns==0 and h%sprite.rows==0,'Sheet columns and rows must divide the image dimensions.')
  else assert(sprite.columns==1 and sprite.rows==1 and sprite.frames==1,'Import a PNG before configuring a sprite sheet.') end
end
return A
