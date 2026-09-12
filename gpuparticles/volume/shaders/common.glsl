uniform vec2 u_grid;
uniform vec2 u_cell;
uniform Image u_terrain;
uniform vec4 u_circle;
uniform vec4 u_push; // xy center, z radius, w strength; never marks cells solid
uniform vec4 u_waterForce; // xy center, z radius, w enabled
uniform vec4 u_box;
uniform bool u_boxEnabled;
uniform vec4 u_capsule;
uniform float u_capsuleRadius;
uniform bool u_capsuleEnabled;
uniform float u_time;
bool inside(vec2 p) { return all(greaterThanEqual(p,vec2(0.0))) && all(lessThan(p,u_grid)); }
vec2 uv(vec2 p) { return (p+0.5)/u_grid; }
float circleDistance(vec2 p) {
  return u_circle.w>0.5 ? length((p+0.5)*u_cell-u_circle.xy)-u_circle.z : 1.0e6;
}
float boxDistance(vec2 p) {
  vec2 q=abs((p+0.5)*u_cell-u_box.xy)-u_box.zw;
  return u_boxEnabled ? length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0) : 1.0e6;
}
float capsuleDistance(vec2 p) {
  vec2 world=(p+0.5)*u_cell,a=u_capsule.xy,segment=u_capsule.zw-a;
  float length2=dot(segment,segment);
  float along=length2>0.00001 ? clamp(dot(world-a,segment)/length2,0.0,1.0) : 0.0;
  return u_capsuleEnabled ? length(world-(a+segment*along))-u_capsuleRadius : 1.0e6;
}
float dynamicDistance(vec2 p) { return min(circleDistance(p),min(boxDistance(p),capsuleDistance(p))); }
float obstacleDistance(vec2 p) { return min(Texel(u_terrain,uv(p)).r,dynamicDistance(p)); }
bool solid(vec2 p) { return !inside(p) || obstacleDistance(p)<0.0; }
bool gasSolid(vec2 p) { return solid(p); }
vec4 at(Image field,vec2 p) { return inside(p) ? Texel(field,uv(p)) : vec4(0.0); }
// Manual interpolation leaves all simulation textures nearest filtered. Solid samples
// contribute no density and cannot pull smoke through an obstacle.
vec4 sampleGas(Image field,vec2 p) {
  vec2 base=floor(p),f=fract(p);vec4 value=vec4(0.0);
  for (int y=0;y<2;y++) for (int x=0;x<2;x++) {
    vec2 q=base+vec2(x,y);
    if (inside(q) && !gasSolid(q)) value+=at(field,q)*(x==0 ? 1.0-f.x : f.x)*(y==0 ? 1.0-f.y : f.y);
  }
  return value;
}
// Limit the trace to one cell per tick and stop at solid samples along the segment.
vec2 traceGas(vec2 p,vec2 displacement) {
  displacement=clamp(displacement,vec2(-0.75),vec2(0.75));
  vec2 last=p;
  for (int i=1;i<=4;i++) {
    vec2 q=p-displacement*(float(i)/4.0);
    if (gasSolid(floor(q+0.5))) break;
    last=q;
  }
  return last;
}
