#version 300 es

precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col;
uniform vec2 u_resolution; // Resolution of the screen
uniform float u_time;
vec4 FragColor;

uniform vec3 u_ellipsoidRadius;
uniform vec2 u_cloudStretch;
uniform float u_brightness;

#define AMBIENT .8 // ambient luminosity; default = 4
#define ANIM true
#define PI 3.1415927
#define MOD3 vec3(.1031,.11369,.13787)
vec3 L = normalize(vec3(-0.4, 0, 0.2)); // light source (og: vec3(-.4,0.,1.))

// --- noise functions from https://www.shadertoy.com/view/XslGRr
// Reference: inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
mat3 m = mat3( 0.00,  0.80,  0.60,
              -0.80,  0.36, -0.48,
              -0.60, -0.48,  0.64 );

float hash( float n )    // in [0,1]
{
    return fract(sin(n)*43758.5453);
}

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}


float fbm( vec3 p )    // in [0,1]
{
	if (ANIM) p += u_time/100.0;
	
    float f;
    f  = 0.5000*noise( p ); p = m*p*2.02;
    f += 0.2500*noise( p ); p = m*p*2.23;
    f += 0.1250*noise( p ); p = m*p*2.41;
    f += 0.0625*noise( p ); p = m*p*2.62;
	f += 0.03125*noise( p); 
    return f;
}

// Reference: https://www.shadertoy.com/view/XsfXW8

// --- view matrix when looking T from O with [-1,1]x[-1,1] screen at dist df
mat3 lookat(vec3 O, vec3 T, float d) {
	mat3 M;
	vec3 OT = normalize(T-O);
	M[0] = OT;
	M[2] = normalize(vec3(0.,0.,1.)-OT.z*OT)/d;
	M[1] = cross(M[2],OT);
	return M;
}

// --- ray -  ellipsoid intersection
bool intersect_ellipsoid(vec3 O, vec3 D, out vec3 P, out vec3 N, out float l) {
	vec3 OR = O/u_ellipsoidRadius, DR = D/u_ellipsoidRadius; // to space where ellipsoid is a sphere 
	float OD = dot(OR,DR), OO=dot(OR,OR), DD=dot(DR,DR);
	float d = OD*OD - (OO-1.)*DD;
	
	if (!((d >=0.)&&(OD<0.)&&(OO>1.))) return false;
	// ray intersects the ellipsoid (and not in our back)
	// note that t>0 <=> -OD>0 &  OD^2 > OD^ -(OO-1.)*DD -> |O|>1
		
	float t = (-OD-sqrt(d))/DD;
	// return intersection point, normal and thickness
	P = O+t*D;
	N=normalize(P/(u_ellipsoidRadius*u_ellipsoidRadius));
	l = 2.*sqrt(d)/DD;

	return true;
}

// --- Gardner textured ellipsoids

// 's' index corresponds to Garner faked silhouette
// 'i' index corresponds to interior term faked by mid-surface

float ks,ps, ki,pi;  // smoothness/thichness parameters
float l;
void draw_obj(vec3 O, mat3 M, vec2 pos, int mode) {
	vec3 D = normalize(M*vec3(1.,pos));		// ray
	
	vec3 P,N; 
	if (! intersect_ellipsoid(O,D, P,N,l)) return;
	
	vec3 Pm = P+.5*l*D,                		// .5: deepest point inside cloud. 
		 Nm = normalize(Pm/(u_ellipsoidRadius*u_ellipsoidRadius)),     
	     Nn = normalize(P/u_ellipsoidRadius);
	float nl = clamp( dot(N,L),0.,1.), 		// ratio of light-facing (for lighting)
		  nd = clamp(-dot(Nn,D),0.,1.); 	// ratio of camera-facing (for silhouette)


	float ns = fbm(P), ni = fbm(Pm+10.);
	float A, l0 = 3.;
	l = clamp(l-6.*ni,0.,1e10);
	float As = pow(ks*nd, ps), 			 	 // silhouette
		  Ai = 1.-pow(.7,pi*l);              // interior

	As =clamp(As-ns,0.,1.)*2.; // As = 2.*pow(As ,.6);
	if (mode==2) 
		A = 1.- (1.-As)*(1.-Ai);  			// mul Ti and Ts
	else
		A = (mode==0) ? Ai : As; 
	A = clamp(A,0.,1.); 
	nl = .8*( nl + ((mode==0) ? fbm(Pm-10.) : fbm(P+10.) ));

#if 0 // noise bump
	N = normalize(N -.1*(dFdx(A)*M[1]+dFdy(A)*M[2])*u_resolution.y); 
	nl = clamp( dot(N,L),0.,1.);
#endif
	vec4 col = vec4(mix(nl,1.,AMBIENT));
	FragColor = mix(FragColor,col,A);
}

void main() {
	float t = u_time/100.0;
    vec2 uv = 2.*(gl_FragCoord.xy / u_resolution.y-vec2(.85,.5));
	float z = .2;
	// ks: Makes it more ellipsoid like and less cloud like (higher = more ellipsoid like, default = 1.)
	// ps: Thickness (lower = thicker, default = 3)
	// pi: Brightness/shaper edges (higher = brighter/shaper edges, default = 5)

	ks = 1.; ps = 3.; ki = .9; pi = 5.;
	vec3 O = vec3(-15.*cos(z),10.*cos(z),1.*sin(z));	// camera
	float compas = t-.2*uv.x; 
	vec2 dir = vec2(cos(compas),sin(compas));

    FragColor = vec4(1.0, 1.0, 1.0, 0.0);
	mat3 M = lookat(O,vec3(0.),5.); 
	vec2 dx = vec2(0.5,0.);


	// Horizontal cloud formation
	if(u_cloudStretch.x == 1.0) {
		draw_obj(O,M, uv, 2);	
	} else {
		int prevMode = 0;
		float upperX = u_cloudStretch.x/2.0;
		float lowerX = -upperX;
		for(float i = lowerX; i < upperX; i++) {
			draw_obj(O, M, 1.5*(uv+vec2(i*0.6, 0.)), prevMode);
			if(prevMode == 0)
				prevMode = 1;
			else if (prevMode == 1)
				prevMode = 2;
			else
				prevMode = 0;
		} 
	}

	// Vertical cloud formation
	if(!(u_cloudStretch.y == 1.0)) {
		FragColor = vec4(1.0, 1.0, 1.0, 0.0);
		int prevMode = 0;
		float upperY = u_cloudStretch.y;
		float lowerY = -1.0;
		float maxHorizontal = 4.0;
		for(float y = lowerY; y < upperY; y++) {
			for(float x = -maxHorizontal/2.0; x < maxHorizontal/2.0; x++) {
				draw_obj(O, M, 1.5*(uv+vec2(x*0.5, -y*0.3)), prevMode);
				if(prevMode == 0)
					prevMode = 1;
				else if (prevMode == 1)
					prevMode = 2;
				else
					prevMode = 0;
			}
			maxHorizontal--;
		} 
	}
    out_Col = FragColor*FragColor.r; 
}
