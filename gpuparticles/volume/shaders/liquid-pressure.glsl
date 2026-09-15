uniform Image u_state;
uniform Image u_divergence;
bool occupied(vec2 p) { return inside(p) && !solid(p) && at(u_state,p).r>0.0001; }
float pressureAt(Image field,vec2 p,float center) {
  if (solid(p)) return center;
  return occupied(p) ? at(field,p).r : 0.0;
}
vec4 effect(vec4 color,Image field,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (!occupied(p)) return vec4(0.0);
  float c=at(field,p).r;vec2 inv=1.0/(u_cell*u_cell);
  float sum=(pressureAt(field,p+vec2(1,0),c)+pressureAt(field,p-vec2(1,0),c))*inv.x
    +(pressureAt(field,p+vec2(0,1),c)+pressureAt(field,p-vec2(0,1),c))*inv.y;
  return vec4((sum-at(u_divergence,p).r)/(2.0*(inv.x+inv.y)),0.0,0.0,0.0);
}
