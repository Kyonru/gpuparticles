#pragma language glsl3
uniform float u_time;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
    float depth=smoothstep(0.0,1.0,uv.y);
    vec3 water=mix(vec3(0.404,0.635,0.773),vec3(0.129,0.212,0.251),depth);
    float waves=sin(uv.x*93.0+sin(uv.y*42.0+u_time)*3.0-u_time*2.0)*sin(uv.y*80.0+u_time*2.3);
    float highlight=pow(max(0.0,waves),9.0)*(1.0-depth)*0.18;
    float reflection=exp(-pow((uv.x-0.64)*7.0,2.0))*(1.0-depth);
    water+=vec3(0.608,0.808,0.757)*reflection*0.35+vec3(1.0,0.922,0.827)*highlight*0.55;
    return vec4(water,1.0)*color;
}
