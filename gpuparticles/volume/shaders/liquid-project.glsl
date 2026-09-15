uniform Image u_state;
uniform Image u_pressure;
uniform float u_strength;
bool occupied(vec2 p) { return inside(p) && !solid(p) && at(u_state,p).r>0.0001; }
float pressureAt(vec2 p,float center) {
  if (solid(p)) return center;
  return occupied(p) ? at(u_pressure,p).r : 0.0;
}
vec4 effect(vec4 color,Image velocity,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (!occupied(p)) return vec4(0.0);
  float c=at(u_pressure,p).r;
  vec2 gradient=vec2(pressureAt(p+vec2(1,0),c)-pressureAt(p-vec2(1,0),c),
    pressureAt(p+vec2(0,1),c)-pressureAt(p-vec2(0,1),c))/(2.0*u_cell);
  vec2 v=at(velocity,p).xy-u_strength*gradient;
  if (solid(p+vec2(1,0))) v.x=min(v.x,0.0);
  if (solid(p-vec2(1,0))) v.x=max(v.x,0.0);
  if (solid(p+vec2(0,1))) v.y=min(v.y,0.0);
  if (solid(p-vec2(0,1))) v.y=max(v.y,0.0);
  return vec4(v,0.0,0.0);
}
