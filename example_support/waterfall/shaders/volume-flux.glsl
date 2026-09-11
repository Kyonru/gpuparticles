uniform float u_step;
// Equilibrium mass in the LOWER cell of a vertical pair, with slight compression.
float lowerMass(float total) {
  const float compression=0.125;
  if (total<=1.0) return total;
  if (total<2.0+compression) return (1.0+total*compression)/(1.0+compression);
  return (total+compression)*0.5;
}
float mass(Image state,vec2 p) { return inside(p) ? Texel(state,uv(p)).r : 0.0; }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  float m=mass(state,p);
  vec4 f=vec4(0.0); // left, right, down, up; each edge has exactly one sender.
  vec2 neighbors[4];
  neighbors[0]=p+vec2(-1,0);neighbors[1]=p+vec2(1,0);
  neighbors[2]=p+vec2(0,1);neighbors[3]=p+vec2(0,-1);
  if (m<=0.0) return f;
  if (circleDistance(p)<0.0) {
    // Moving obstacles displace existing mass outward, even through their interior.
    // Free cells never send into a solid cell. Nothing is cleared when the circle moves.
    for (int i=0;i<4;i++) {
      if (!rock(neighbors[i])) f[i]=max(0.0,circleDistance(neighbors[i])-circleDistance(p));
    }
    float weights=dot(f,vec4(1.0));
    return weights>0.0 ? f*(0.5*m*u_step/weights) : vec4(0.0);
  }
  for (int i=0;i<4;i++) {
    vec2 n=neighbors[i];
    if (i==3 && p.y<0.5) { f[i]=max(0.0,m-1.0);continue; } // open top: explicit overflow
    if (solid(n)) continue;
    float other=mass(state,n);
    // Falling streams keep their width. Lateral equalization acts on supported water.
    float support=solid(p+vec2(0,1)) ? 1.0 : smoothstep(0.8,1.05,mass(state,p+vec2(0,1)));
    if (i<2) f[i]=max(0.0,(m-other)*(0.0005+support*0.4995));
    else if (i==2) f[i]=max(0.0,lowerMass(m+other)-other);
    else f[i]=max(0.0,m-lowerMass(m+other));
  }
  f*=u_step;
  float total=dot(f,vec4(1.0));
  // Retain half the cell's mass: full-cell transfers cause odd/even grid oscillation.
  return 0.5*f*min(1.0,m/max(total,0.0000001));
}
