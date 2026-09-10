#pragma language glsl3
uniform Image u_distance;
uniform vec2 u_worldSize;
uniform vec2 u_canvasSize;
uniform bool u_overlay;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
    vec2 world=screen/u_canvasSize*u_worldSize;
    float d=Texel(u_distance,world/u_worldSize).r;
    float grain=hash(floor(world*0.8));
    if (u_overlay) {
        vec3 tint=d<0.0 ? vec3(0.96,0.35,0.28) : vec3(0.15,0.8,0.72);
        float contour=1.0-smoothstep(0.0,1.0,abs(mod(abs(d)+8.0,16.0)-8.0));
        float boundary=1.0-smoothstep(0.0,2.0,abs(d));
        return vec4(tint,0.10+contour*0.28+boundary*0.55);
    }
    vec3 base=mix(vec3(0.055,0.11,0.14),vec3(0.16,0.24,0.25),grain*0.22);
    float seam=pow(0.5+0.5*sin(world.y*0.19+sin(world.x*0.027)*2.0),16.0);
    base+=vec3(0.018,0.027,0.025)*seam;
    float edge=exp(-abs(d)*0.17);
    base+=vec3(0.04,0.11,0.085)*edge;
    return vec4(base,1.0)*color;
}
