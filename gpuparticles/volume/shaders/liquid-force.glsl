uniform Image u_state;
uniform float u_dt;
uniform float u_gravity;
uniform float u_viscosity;
uniform float u_damping;
uniform float u_surfaceTension;
uniform float u_solidFriction;
uniform float u_maxSpeed;
uniform vec2 u_waterForceVector;
bool liquidAt(vec2 p) { return inside(p) && !solid(p) && at(u_state,p).r>0.0001; }
vec2 liquidVelocity(Image velocity,vec2 p,vec2 fallback) {
  return liquidAt(p) ? at(velocity,p).xy : fallback;
}
vec4 effect(vec4 color,Image velocity,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  float density=at(u_state,p).r;
  if (solid(p) || density<=0.0001) return vec4(0.0);
  vec2 v=at(velocity,p).xy;
  vec2 average=(liquidVelocity(velocity,p+vec2(1,0),v)+liquidVelocity(velocity,p-vec2(1,0),v)
    +liquidVelocity(velocity,p+vec2(0,1),v)+liquidVelocity(velocity,p-vec2(0,1),v))*0.25;
  v=mix(v,average,1.0-exp(-u_viscosity*u_dt));
  v.y+=u_gravity*u_dt;
  vec2 densityGradient=vec2(at(u_state,p+vec2(1,0)).r-at(u_state,p-vec2(1,0)).r,
    at(u_state,p+vec2(0,1)).r-at(u_state,p-vec2(0,1)).r);
  v+=densityGradient*u_surfaceTension*u_dt;
  vec2 pushDelta=(p+0.5)*u_cell-u_push.xy;
  float pushDistance=length(pushDelta);
  if (u_push.w>0.0 && pushDistance<u_push.z && pushDistance>0.0001) {
    float falloff=pow(1.0-pushDistance/u_push.z,2.0);
    v+=pushDelta/pushDistance*u_push.w*120.0*u_dt*falloff;
  }
  vec2 forceDelta=(p+0.5)*u_cell-u_waterForce.xy;
  float forceDistance=length(forceDelta);
  if (u_waterForce.w>0.5 && forceDistance<u_waterForce.z) {
    v+=u_waterForceVector*pow(1.0-forceDistance/u_waterForce.z,2.0);
  }
  v*=exp(-u_damping*u_dt);
  bool side=solid(p+vec2(1,0)) || solid(p-vec2(1,0));
  bool floorOrCeiling=solid(p+vec2(0,1)) || solid(p-vec2(0,1));
  if (solid(p+vec2(1,0))) v.x=min(v.x,0.0);
  if (solid(p-vec2(1,0))) v.x=max(v.x,0.0);
  if (solid(p+vec2(0,1))) v.y=min(v.y,0.0);
  if (solid(p-vec2(0,1))) v.y=max(v.y,0.0);
  float friction=exp(-u_solidFriction*u_dt);
  if (side) v.y*=friction;
  if (floorOrCeiling) v.x*=friction;
  float speed=length(v);
  if (speed>u_maxSpeed) v*=u_maxSpeed/speed;
  return vec4(v,0.0,0.0);
}
