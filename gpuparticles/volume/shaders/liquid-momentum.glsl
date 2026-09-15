uniform Image u_stateAfter;
uniform Image u_velocity;
uniform Image u_flux;
uniform float u_sleepSpeed;
vec4 flow(vec2 p) { return at(u_flux,p); }
vec2 velocityAt(vec2 p) { return at(u_velocity,p).xy; }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (solid(p)) return vec4(0.0);
  vec4 outgoing=flow(p);
  float remaining=max(0.0,at(state,p).r-dot(outgoing,vec4(1.0)));
  vec2 momentum=remaining*velocityAt(p);
  vec2 left=p+vec2(-1,0),right=p+vec2(1,0),up=p+vec2(0,-1),down=p+vec2(0,1);
  momentum+=flow(left).y*velocityAt(left)+flow(right).x*velocityAt(right)
    +flow(up).z*velocityAt(up)+flow(down).w*velocityAt(down);
  float mass=at(u_stateAfter,p).r;
  vec2 v=mass>0.0001 ? momentum/mass : vec2(0.0);
  bool supported=solid(p+vec2(0,1)) || at(u_stateAfter,p+vec2(0,1)).r>0.8;
  if (supported && length(v)<u_sleepSpeed) v=vec2(0.0);
  return vec4(v,0.0,0.0);
}
