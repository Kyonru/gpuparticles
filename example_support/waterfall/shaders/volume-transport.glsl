uniform Image u_flux;
uniform vec4 u_source;
uniform float u_add;
vec4 flow(vec2 p) { return inside(p) ? Texel(u_flux,uv(p)) : vec4(0.0); }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  vec4 old=Texel(state,uv(p)),outgoing=flow(p);
  float incoming=flow(p+vec2(-1,0)).y+flow(p+vec2(1,0)).x
    +flow(p+vec2(0,-1)).z+flow(p+vec2(0,1)).w;
  float m=max(0.0,old.r-dot(outgoing,vec4(1.0)))+incoming;
  bool source=p.x>=u_source.x && p.x<=u_source.z && p.y==u_source.y;
  float added=source && !solid(p) ? min(u_add,max(0.0,1.0-m)) : 0.0;
  // r = conserved mass, g = cumulative admitted source, b = flow, a = cumulative overflow.
  return vec4(m+added,old.g+added,dot(outgoing,vec4(1.0)),old.a+(p.y<0.5 ? outgoing.w : 0.0));
}
