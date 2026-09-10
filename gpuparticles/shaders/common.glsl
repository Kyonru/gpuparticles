uniform float u_time;
uniform float u_emissionTime;
uniform Image u_timeline;
uniform int u_timelineCount;
float wallBirth(float birth) {
    int lo=0,hi=u_timelineCount-1;
    while (lo<hi) {
        int mid=(lo+hi+1)/2;
        float at=Texel(u_timeline,vec2((float(mid)+0.5)/float(u_timelineCount),0.5)).x;
        if (at<birth) lo=mid; else hi=mid-1;
    }
    vec2 segment=Texel(u_timeline,vec2((float(lo)+0.5)/float(u_timelineCount),0.5)).xy;
    return birth+segment.y-segment.x;
}
uniform vec2 u_origin;
uniform float u_rate;
uniform float u_epoch;
uniform float u_count;
uniform vec4 u_acceleration;
uniform vec2 u_damping;
uniform vec2 u_radial;
uniform vec2 u_tangential;
float randomTerm(float seed, float salt) { return fract(sin(seed*127.1+salt*311.7)*43758.5453); }
vec3 particleClock(vec4 spawn,float index) {
    float burstEnd=-1.0;
    if (spawn.w<0.0 && u_time-spawn.x>=spawn.y && u_rate>0.0) {
        burstEnd=spawn.x+spawn.y;
        spawn.x=u_epoch+(index+1.0)/u_rate;
        spawn.w=u_count/u_rate;
    }
    float birth = spawn.x;
    float eligible = u_emissionTime;
    if (spawn.w > 0.0 && eligible >= birth)
        birth += floor((eligible-birth)/spawn.w)*spawn.w;
    bool born=spawn.w<=0.0 || birth<=eligible;
    if (spawn.w>0.0) birth=wallBirth(birth);
    float age = u_time-birth;
    float alive = float(age >= 0.0 && age < spawn.y && born && birth>=burstEnd);
    return vec3(max(age,0.0), alive, birth);
}
vec2 particleOrigin(vec4 spawn,vec4 style) {
    return spawn.w<0.0 && u_time-spawn.x<spawn.y ? style.zw : u_origin;
}
vec2 accelerationFor(float seed, vec2 initialVelocity) {
    vec2 a = mix(u_acceleration.xy,u_acceleration.zw,vec2(randomTerm(seed,1.0),randomTerm(seed,2.0)));
    vec2 radial = length(initialVelocity)>0.00001 ? normalize(initialVelocity) : vec2(cos(seed*6.2831853),sin(seed*6.2831853));
    return a + radial*mix(u_radial.x,u_radial.y,randomTerm(seed,3.0))
      + vec2(-radial.y,radial.x)*mix(u_tangential.x,u_tangential.y,randomTerm(seed,4.0));
}
vec2 baseDisplacement(vec2 velocity, vec2 acceleration, float damping, float age) {
    if (damping < 0.0001) return velocity*age+0.5*acceleration*age*age;
    float decay = (1.0-exp(-damping*age))/damping;
    return velocity*decay+acceleration*(age-decay)/damping;
}
