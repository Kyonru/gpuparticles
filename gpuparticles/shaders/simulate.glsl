#pragma language glsl3
// COMMON
// FORCES
uniform Image u_state;
uniform Image u_spawn;
uniform Image u_motion;
uniform Image u_style;
uniform float u_dt;
uniform vec2 u_carry; // velocity moving particles are carried by on top of their own
uniform float u_texSize;
uniform Image u_flow;
uniform bool u_hasFlow;
uniform vec4 u_flowRegion;
uniform vec2 u_flowEncoding;
uniform float u_flowStrength;
uniform Image u_attractors;
uniform int u_attractorCount;
#ifdef PARTICLE_DEPTH_STATE
// Optional simulated z, in its own ping-pong pair: r = z, g = z velocity.
uniform Image u_depthState;
uniform float u_depthAxis;     // world x of the vertical axis particles orbit
uniform vec2 u_depthOrbit;     // orbit rate range, radians per second
uniform float u_depthGravity;  // constant z acceleration
uniform float u_depthEmission; // z spread at birth
uniform vec2 u_depthSpeed;     // extra z velocity range at birth
float depthOrbit(float seed) { return mix(u_depthOrbit.x,u_depthOrbit.y,randomTerm(seed,13.0)); }
// Born moving round the axis at the particle's own orbit rate, so the spring in
// stepParticle carries it in a circle rather than swinging it back and forth across.
vec4 depthBirth(float seed,float x) {
    return vec4((randomTerm(seed,11.0)*2.0-1.0)*u_depthEmission,
        (x-u_depthAxis)*depthOrbit(seed)+mix(u_depthSpeed.x,u_depthSpeed.y,randomTerm(seed,12.0)),0.0,0.0);
}
#endif
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
vec4 stepParticle(vec2 tc,vec2 sc,inout vec4 depth) {
    float index=floor(sc.y)*u_texSize+floor(sc.x);
    if (index>=u_count) return vec4(0.0);
    vec4 spawn=Texel(u_spawn,tc), motion=Texel(u_motion,tc), style=Texel(u_style,tc);
    vec3 clock=particleClock(spawn,index);
    vec4 state=Texel(u_state,tc);
    if (clock.y==0.0) return state;
    float stepTime=min(u_dt,clock.x);
    float seed=spawn.z;
    bool born=clock.z>u_time-u_dt;
    if (born) state=vec4(motion.xy+particleOrigin(spawn,style),motion.zw);
#ifdef PARTICLE_DEPTH_STATE
    if (born) depth=depthBirth(seed,state.x);
#endif
    vec2 radial=state.xy-u_origin;
    if (length(radial)<0.00001) radial=motion.zw;
    vec2 acceleration=accelerationFor(seed,radial);
    acceleration+=externalAcceleration(state.xy,state.zw,seed,clock.x);
    float damping=mix(u_damping.x,u_damping.y,randomTerm(seed,5.0));
#ifdef PARTICLE_DEPTH_STATE
    // A spring towards the axis in the x/z plane. Damping acts on z as it does on x and y.
    float orbit=depthOrbit(seed);
    float spring=orbit*orbit;
    acceleration.x-=(state.x-u_depthAxis)*spring;
    depth.g=(depth.g+(u_depthGravity-depth.r*spring)*stepTime)*exp(-damping*stepTime);
    depth.r+=depth.g*stepTime;
#endif
    vec2 velocity=(state.zw+acceleration*stepTime)*exp(-damping*stepTime);
    vec2 p=state.xy+velocity*stepTime;
    p+=forceDisplacement(seed,clock.x)-forceDisplacement(seed,max(clock.x-stepTime,0.0));
    // Carry: displaced along with a moving frame, such as a camera, without touching velocity,
    // so streaks keep their shape. It fades with the particle's own speed, so a particle a
    // collision has stopped stays where it landed.
    p+=u_carry*smoothstep(0.5,8.0,length(velocity))*stepTime;
    bool collisionHit=collide(p,velocity);
    if (collisionHit && u_collisionAction==3) p=vec2(1.0e20);
    if (collisionHit && u_collisionAction==4) {
        p=motion.xy+particleOrigin(spawn,style);
        velocity=motion.zw;
#ifdef PARTICLE_DEPTH_STATE
        depth=depthBirth(seed,p.x);
#endif
    }
    return vec4(p,velocity);
}
// ENTRY
