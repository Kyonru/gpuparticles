uniform float u_amount;
uniform float u_gravity;
float mass(Image state,vec2 p) { return inside(p) ? at(state,p).r : 0.0; }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  float m=mass(state,p);
  vec4 f=vec4(0.0);
  if (m<=0.0 || solid(p)) return f;
  vec2 neighbors[4];
  neighbors[0]=p+vec2(-1,0);neighbors[1]=p+vec2(1,0);
  neighbors[2]=p+vec2(0,1);neighbors[3]=p+vec2(0,-1);
  int gravityDirection=u_gravity<0.0 ? 3 : 2;
  int oppositeDirection=gravityDirection==2 ? 3 : 2;
  vec2 gravityNeighbor=neighbors[gravityDirection];
  if (!solid(gravityNeighbor)) {
    float below=mass(state,gravityNeighbor);
    f[gravityDirection]=max(0.0,min(m+below,1.0)-below);
  }
  vec2 oppositeNeighbor=neighbors[oppositeDirection];
  if (!solid(oppositeNeighbor)) {
    float above=mass(state,oppositeNeighbor);
    f[oppositeDirection]=max(0.0,m-min(m+above,1.0));
  }
  bool supported=solid(gravityNeighbor) || mass(state,gravityNeighbor)>0.8;
  if (supported) {
    for (int i=0;i<2;i++) if (!solid(neighbors[i])) {
      f[i]=max(0.0,(m-mass(state,neighbors[i]))*0.5);
    }
  }
  f*=u_amount;
  float total=dot(f,vec4(1.0));
  return f*min(1.0,0.5*m/max(total,0.0000001));
}
