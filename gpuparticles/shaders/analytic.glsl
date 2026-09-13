#pragma language glsl3
// COMMON
// FORCES
// STYLE
#ifdef VERTEX
#ifdef PARTICLE_DEPTH
uniform float u_depthTilt;  // screen y per unit of z
#endif
attribute vec4 ParticleSpawn;
attribute float ParticleIndex;
attribute vec4 ParticleMotion;
attribute vec4 ParticleStyle;
vec4 position(mat4 transform, vec4 vertex) {
    vec3 clock=particleClock(ParticleSpawn,ParticleIndex);
    float age=clock.x, seed=ParticleSpawn.z;
    vec2 acceleration=accelerationFor(seed,ParticleMotion.zw);
    float damping=mix(u_damping.x,u_damping.y,randomTerm(seed,5.0));
    vec2 p=ParticleMotion.xy+particleOrigin(ParticleSpawn,ParticleStyle);
    vec2 displacement=baseDisplacement(ParticleMotion.zw,acceleration,damping,age);
    displacement+=forceDisplacement(seed,age);
    vec2 velocity=ParticleMotion.zw*exp(-damping*age);
    velocity+=acceleration*(damping<0.0001 ? age : (1.0-exp(-damping*age))/max(damping,0.0001));
#ifdef PARTICLE_DEPTH_CODE
    particleZ=depthCode(seed,age);
    displacement.y+=particleZ*u_depthTilt;
#endif
    return styleVertex(transform,vertex,p+displacement,velocity,ParticleStyle,clock,ParticleSpawn.y,seed);
}
#endif
