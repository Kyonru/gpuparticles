uniform float u_time;
uniform bool u_debug;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid),world=tc*u_grid*u_cell;
  vec4 water=Texel(state,uv(p));
  if (u_debug) return solid(p) ? vec4(0.85,0.3,0.2,0.6) : vec4(0.1,0.6,0.65,0.1+min(water.r,1.0)*0.4);
  if (water.r<0.008 || solid(p)) return vec4(0.0);
  float above=p.y>0.5 ? Texel(state,uv(p-vec2(0,1))).r : 0.0;
  float fill=clamp(water.r,0.0,1.0);
  float surface=above<0.008 ? 1.0-fill : 0.0;
  float edge=fract(tc.y*u_grid.y)-surface;
  float coverage=smoothstep(-0.09,0.09,edge);
  float foam=(1.0-smoothstep(0.0,0.22,edge))*step(above,0.008);
  float motion=clamp(water.b*1.4,0.0,1.0);
  float streak=0.5+0.5*sin(world.x*0.7+sin(world.y*0.06-u_time*8.0));
  vec3 deep=vec3(0.065,0.30,0.34),shallow=vec3(0.34,0.68,0.70);
  vec3 rgb=mix(deep,shallow,0.25+motion*0.5);
  rgb+=vec3(0.12,0.20,0.19)*streak*motion;
  rgb=mix(rgb,vec3(0.65,0.88,0.85),foam*0.75);
  float circleMask=u_circle.w>0.5 ? smoothstep(-0.5,1.0,length(world-u_circle.xy)-u_circle.z) : 1.0;
  return vec4(rgb,coverage*circleMask*min(1.0,water.r*10.0)*0.88);
}
