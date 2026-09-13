#pragma language glsl3
// COMMON
// STYLE
#ifdef VERTEX
uniform Image u_state;
uniform float u_texSize;
#ifdef PARTICLE_DEPTH_STATE
uniform Image u_depthState; // r = z, g = z velocity
#endif
#ifdef PARTICLE_DEPTH
uniform float u_depthTilt;  // screen y per unit of z: the orbit seen slightly from above
#endif
attribute vec4 ParticleSpawn;
attribute vec4 ParticleStyle;
attribute float ParticleIndex;
vec4 position(mat4 transform,vec4 vertex) {
    vec2 uv=(vec2(mod(ParticleIndex,u_texSize),floor(ParticleIndex/u_texSize))+0.5)/u_texSize;
    vec4 state=Texel(u_state,uv);
    vec3 clock=particleClock(ParticleSpawn,ParticleIndex);
    vec2 p=state.xy;
#ifdef PARTICLE_DEPTH_STATE
    particleZ=Texel(u_depthState,uv).r;
#endif
#ifdef PARTICLE_DEPTH_CODE
    particleZ=depthCode(ParticleSpawn.z,clock.x);
#endif
#ifdef PARTICLE_DEPTH
    p.y+=particleZ*u_depthTilt;
#endif
    return styleVertex(transform,vertex,p,state.zw,ParticleStyle,clock,ParticleSpawn.y,ParticleSpawn.z);
}
#endif
