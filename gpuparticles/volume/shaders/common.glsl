uniform vec2 u_grid;
uniform vec2 u_cell;
uniform Image u_terrain;
uniform vec4 u_circle;
uniform float u_time;
bool inside(vec2 p) { return all(greaterThanEqual(p,vec2(0.0))) && all(lessThan(p,u_grid)); }
vec2 uv(vec2 p) { return (p+0.5)/u_grid; }
float circleDistance(vec2 p) {
  return u_circle.w>0.5 ? length((p+0.5)*u_cell-u_circle.xy)-u_circle.z : 1.0e6;
}
float obstacleDistance(vec2 p) { return min(Texel(u_terrain,uv(p)).r,circleDistance(p)); }
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
