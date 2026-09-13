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
// Terrain distance in world pixels at a point between cell centres, bilinear over the
// four surrounding cells. The terrain canvas is nearest filtered, so this is manual.
float terrainDistanceAt(vec2 p) {
  vec2 base=floor(p),f=fract(p);float d=0.0;
  for (int y=0;y<2;y++) for (int x=0;x<2;x++) {
    vec2 q=clamp(base+vec2(x,y),vec2(0.0),u_grid-1.0);
    d+=Texel(u_terrain,uv(q)).r*(x==0 ? 1.0-f.x : f.x)*(y==0 ? 1.0-f.y : f.y);
  }
  return d;
}
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid),world=tc*u_grid*u_cell;
  vec4 s=displaySample(state,tc*u_grid-0.5);
  if (u_debug) return solid(p) ? vec4(0.85,0.3,0.2,0.6) : vec4(0.1,0.6,0.65,0.1+min(s.r,1.0)*0.4);
  // Smooth display cuts at the interpolated terrain surface rather than at whole cells,
  // and fades in over most of a cell, so a sloped wall reads as a line instead of a
  // staircase. Pixel display keeps the per-cell cut. Moving obstacles still fade below.
  float terrainFade=1.0;
  if (u_smooth) {
    float d=terrainDistanceAt(tc*u_grid-0.5);
    if (d<0.0 || dynamicDistance(p)<0.0 || s.r<0.0001) return vec4(0.0);
    terrainFade=smoothstep(0.0,max(u_cell.x,u_cell.y)*0.75,d);
  } else if (solid(p) || s.r<0.0001) return vec4(0.0);
  vec4 appearance=u_color;
  if (u_gas) appearance.a*=1.0-exp(-s.r*2.5);
  else {
    float above=at(state,p-vec2(0,1)).r;
    float surface=step(above,0.008);
    float edge=fract(tc.y*u_grid.y)-(1.0-clamp(s.r,0.0,1.0));
    float foam=(1.0-smoothstep(0.0,0.22,edge))*surface;
    float motion=clamp(dot(at(u_flux,p),vec4(1.0))*1.4,0.0,1.0);
    float streak=0.5+0.5*sin(world.x*0.7+sin(world.y*0.06-u_time*8.0));
    appearance.rgb*=0.72+0.28*motion*surface;
    appearance.rgb+=vec3(0.12,0.20,0.19)*streak*motion*surface;
    appearance.rgb=mix(appearance.rgb,mix(u_color.rgb,vec3(1.0),0.55),foam*0.75);
    float bodyAlpha=min(1.0,s.r*10.0);
    float surfaceAlpha=smoothstep(-0.09,0.09,edge)*bodyAlpha;
    appearance.a*=u_smooth ? smoothstep(0.008,0.12,s.r) : mix(bodyAlpha,surfaceAlpha,surface);
  }
  appearance=customShade(appearance,s.r,s.b/max(s.r,0.000001),world,u_time);
  appearance.a*=smoothstep(-0.5,1.0,dynamicDistance(p))*terrainFade;
  return appearance;
}
