#pragma language glsl3
uniform float u_time;
uniform vec2 u_texel;

#ifdef VERTEX
vec4 position(mat4 transform_projection,vec4 vertex_position) {
  return transform_projection*vertex_position;
}
#endif

#ifdef PIXEL
float noise(vec2 p) {
  return fract(sin(dot(floor(p),vec2(127.1,311.7)))*43758.5453);
}

vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
  vec2 warped=tc+vec2(sin(tc.y*32.0+u_time*2.0),cos(tc.x*27.0-u_time*1.7))*0.004;
  vec4 base=Texel(tex,warped);
  float nearby=0.0;
  for (int x=-1;x<=1;x++) for (int y=-1;y<=1;y++)
    nearby=max(nearby,Texel(tex,warped+vec2(x,y)*u_texel*2.0).a);
  float outline=max(nearby-base.a,0.0);
  float dissolve=smoothstep(0.30,0.38,noise(sc*0.18+u_time*4.0));
  vec3 peach=vec3(1.0,0.714,0.651);
  vec3 teal=vec3(0.608,0.808,0.757);
  vec3 blue=vec3(0.404,0.635,0.773);
  float ramp=0.5+0.5*sin(u_time+base.r*4.0+tc.y*7.0);
  vec3 palette=mix(mix(blue,teal,ramp),peach,base.g*0.45);
  float glow=nearby*0.35;
  return vec4(palette*(base.a*dissolve+glow)+peach*outline,base.a*dissolve+outline+glow*0.5)*color;
}
#endif
