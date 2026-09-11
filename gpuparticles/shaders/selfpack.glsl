#pragma language glsl3
// COMMON
uniform Image u_state;
uniform Image u_spawn;
uniform float u_texSize;
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
    float index=floor(sc.y)*u_texSize+floor(sc.x);
    if (index>=u_count) return vec4(0.0);
    vec3 clock=particleClock(Texel(u_spawn,tc),index);
    return vec4(Texel(u_state,tc).xy,clock.y,0.0);
}
