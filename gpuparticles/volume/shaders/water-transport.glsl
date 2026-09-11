uniform Image u_flux;
uniform Image u_injection;
uniform float u_injectionScale;
uniform float u_decay;
uniform float u_cooling;
vec4 flow(vec2 p) { return at(u_flux,p); }
float temperature(Image state,vec2 p) { vec4 s=at(state,p);return s.r>0.0 ? s.b/s.r : 0.0; }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  vec4 old=at(state,p),outgoing=flow(p);
  vec4 incoming=vec4(flow(p+vec2(-1,0)).y,flow(p+vec2(1,0)).x,flow(p+vec2(0,-1)).z,flow(p+vec2(0,1)).w);
  float remaining=max(0.0,old.r-dot(outgoing,vec4(1.0)));
  float m=remaining+dot(incoming,vec4(1.0));
  float heat=remaining*temperature(state,p)+dot(incoming,vec4(
    temperature(state,p+vec2(-1,0)),temperature(state,p+vec2(1,0)),temperature(state,p+vec2(0,-1)),temperature(state,p+vec2(0,1))));
  vec4 injection=at(u_injection,p)*u_injectionScale;
  float added=!solid(p) ? min(injection.r,max(0.0,1.0-m)) : 0.0;
  float admittedHeat=injection.r>0.0 ? injection.b*added/injection.r : 0.0;
  // r=mass, g=cumulative admitted input, b=heat content, a=cumulative mass lost.
  return vec4(m*u_decay+added,old.g+added,heat*u_decay*u_cooling+admittedHeat,
    old.a+(p.y<0.5 ? outgoing.w : 0.0)+m*(1.0-u_decay));
}
