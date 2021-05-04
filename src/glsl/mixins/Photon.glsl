// #package glsl/mixins

// #section Photon

struct Photon {
    vec3 position;
    vec3 direction;
    float transmittance;
    vec3 currentRadiance;
    vec3 radiance;
    uint bounces;
    uint samples;
};
