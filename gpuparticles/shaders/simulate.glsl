#pragma language glsl3
// COMMON
// FORCES
uniform Image u_state;
uniform Image u_spawn;
uniform Image u_motion;
uniform Image u_style;
uniform float u_dt;
uniform float u_texSize;
uniform Image u_flow;
uniform bool u_hasFlow;
uniform vec4 u_flowRegion;
uniform vec2 u_flowEncoding;
uniform float u_flowStrength;
uniform Image u_attractors;
uniform int u_attractorCount;
// COLLISION
vec2 externalAcceleration(vec2 p,vec2 velocity,float seed,float age) {
    vec2 a=statefulAcceleration(p,velocity,seed,age);
    if (u_hasFlow) {
        vec2 uv=(p-u_flowRegion.xy)/u_flowRegion.zw;
        a+=(Texel(u_flow,uv).rg*u_flowEncoding.x+u_flowEncoding.y)*u_flowStrength;
    }
    for (int i=0;i<u_attractorCount;i++) {
        vec4 attractor=Texel(u_attractors,vec2((float(i)+0.5)/float(u_attractorCount),0.5));
        vec2 d=attractor.xy-p;
        float r2=max(dot(d,d),max(attractor.w*attractor.w,0.0001));
        a+=d*attractor.z/(r2*sqrt(r2));
    }
    return a;
}
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
    float index=floor(sc.y)*u_texSize+floor(sc.x);
    if (index>=u_count) return vec4(0.0);
    vec4 spawn=Texel(u_spawn,tc), motion=Texel(u_motion,tc), style=Texel(u_style,tc);
    vec3 clock=particleClock(spawn,index);
    vec4 state=Texel(u_state,tc);
    if (clock.y==0.0) return state;
    float stepTime=min(u_dt,clock.x);
    if (clock.z>u_time-u_dt) state=vec4(motion.xy+particleOrigin(spawn,style),motion.zw);
    float seed=spawn.z;
    vec2 radial=state.xy-u_origin;
    if (length(radial)<0.00001) radial=motion.zw;
    vec2 acceleration=accelerationFor(seed,radial);
    acceleration+=externalAcceleration(state.xy,state.zw,seed,clock.x);
    float damping=mix(u_damping.x,u_damping.y,randomTerm(seed,5.0));
    vec2 velocity=(state.zw+acceleration*stepTime)*exp(-damping*stepTime);
    vec2 p=state.xy+velocity*stepTime;
    p+=forceDisplacement(seed,clock.x)-forceDisplacement(seed,max(clock.x-stepTime,0.0));
    collide(p,velocity);
    return vec4(p,velocity);
}
