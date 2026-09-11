uniform Image u_divergence;
float pressureAt(Image field,vec2 p,float center) { return gasSolid(p) ? center : at(field,p).r; }
vec4 effect(vec4 color,Image field,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (gasSolid(p)) return vec4(0.0);
  float c=at(field,p).r;vec2 inv=1.0/(u_cell*u_cell);
  float sum=(pressureAt(field,p+vec2(1,0),c)+pressureAt(field,p-vec2(1,0),c))*inv.x
    +(pressureAt(field,p+vec2(0,1),c)+pressureAt(field,p-vec2(0,1),c))*inv.y;
  return vec4((sum-at(u_divergence,p).r)/(2.0*(inv.x+inv.y)),0.0,0.0,0.0);
}
