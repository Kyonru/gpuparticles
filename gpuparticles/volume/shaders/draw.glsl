uniform bool u_gas;
uniform bool u_smooth;
uniform bool u_debug;
uniform vec4 u_color;
uniform Image u_flux;
vec4 displaySample(Image state,vec2 p) {
  if (!u_smooth) return at(state,floor(p+0.5));
  vec2 base=floor(p),f=fract(p);vec4 value=vec4(0.0);float weights=0.0;
  for (int y=0;y<2;y++) for (int x=0;x<2;x++) {
    vec2 q=base+vec2(x,y);
    if (!solid(q)) { float w=(x==0 ? 1.0-f.x : f.x)*(y==0 ? 1.0-f.y : f.y);value+=at(state,q)*w;weights+=w; }
  }
  return value/max(weights,0.000001);
}
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid),world=tc*u_grid*u_cell;
  vec4 s=displaySample(state,tc*u_grid-0.5);
  if (u_debug) return solid(p) ? vec4(0.85,0.3,0.2,0.6) : vec4(0.1,0.6,0.65,0.1+min(s.r,1.0)*0.4);
  if (solid(p) || s.r<0.0001) return vec4(0.0);
  vec4 appearance=u_color;
  if (u_gas) appearance.a*=1.0-exp(-s.r*2.5);
  else {
    float above=at(state,p-vec2(0,1)).r;
    float edge=fract(tc.y*u_grid.y)-(above<0.008 ? 1.0-clamp(s.r,0.0,1.0) : 0.0);
    float foam=(1.0-smoothstep(0.0,0.22,edge))*step(above,0.008);
    float motion=clamp(dot(at(u_flux,p),vec4(1.0))*1.4,0.0,1.0);
    float streak=0.5+0.5*sin(world.x*0.7+sin(world.y*0.06-u_time*8.0));
    appearance.rgb*=0.5+0.5*motion;appearance.rgb+=vec3(0.12,0.20,0.19)*streak*motion;
    appearance.rgb=mix(appearance.rgb,mix(u_color.rgb,vec3(1.0),0.55),foam*0.75);
    appearance.a*=u_smooth ? smoothstep(0.008,0.12,s.r) : smoothstep(-0.09,0.09,edge)*min(1.0,s.r*10.0);
  }
  appearance=customShade(appearance,s.r,s.b/max(s.r,0.000001),world,u_time);
  appearance.a*=u_circle.w>0.5 ? smoothstep(-0.5,1.0,length(world-u_circle.xy)-u_circle.z) : 1.0;
  return appearance;
}
