#pragma language glsl3
// COMMON
// STYLE
#ifdef VERTEX
uniform Image u_state;
uniform float u_texSize;
attribute vec4 ParticleSpawn;
attribute vec4 ParticleStyle;
attribute float ParticleIndex;
vec4 position(mat4 transform,vec4 vertex) {
    vec2 uv=(vec2(mod(ParticleIndex,u_texSize),floor(ParticleIndex/u_texSize))+0.5)/u_texSize;
    vec4 state=Texel(u_state,uv);
    vec3 clock=particleClock(ParticleSpawn,ParticleIndex);
    return styleVertex(transform,vertex,state.xy,state.zw,ParticleStyle,clock,ParticleSpawn.y,ParticleSpawn.z);
}
#endif
