// #package glsl/shaders

// #include ../mixins/Photon.glsl
// #include ../mixins/rand.glsl
// #include ../mixins/unprojectRand.glsl
// #include ../mixins/intersectCube.glsl

// #section EAMMCGenerate/vertex

void main() {}

// #section EAMMCGenerate/fragment

void main() {}

// #section EAMMCIntegrate/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;

out vec2 vPosition;

void main() {
    vPosition = aPosition;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMMCIntegrate/fragment

#version 300 es
precision mediump float;

#define M_INVPI 0.31830988618
#define M_2PI 6.28318530718
#define EPS 1e-5

@Photon

uniform mediump sampler2D uPosition;
uniform mediump sampler2D uDirection;
uniform mediump sampler2D uTransmittance;
uniform mediump sampler2D uRadiance;

uniform mediump sampler3D uVolume;
uniform mediump sampler2D uTransferFunction;
uniform mediump sampler2D uEnvironment;

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

uniform float uAbsorptionCoefficient;
uniform float uEmissionCoefficient;
uniform float uMajorant;
uniform uint uMaxBounces;
uniform uint uSteps;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

@rand
@unprojectRand
@intersectCube

void resetPhoton(inout vec2 randState, inout Photon photon) {
    vec3 from, to;
    unprojectRand(randState, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    photon.bounces = 0u;
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
}

vec4 sampleEnvironmentMap(vec3 d) {
    vec2 texCoord = vec2(atan(d.x, -d.z), asin(-d.y) * 2.0) * M_INVPI * 0.5 + 0.5;
    return texture(uEnvironment, texCoord);
}

vec4 sampleVolumeColor(vec3 position) {
    vec2 volumeSample = texture(uVolume, position).rg;
    vec4 transferSample = texture(uTransferFunction, volumeSample);
    return transferSample;
}

vec3 randomDirection(vec2 U) {
    float phi = U.x * M_2PI;
    float z = U.y * 2.0 - 1.0;
    float k = sqrt(1.0 - z * z);
    return vec3(k * cos(phi), k * sin(phi), z);
}

void main() {
    // Create a Photon object with position, direction, transmittance, radience, bounces and samples
    Photon photon; 
    // Create 2d vector mapped position from vPosition (what is vPosisition - produces by GPU?) - YES
    vec2 mappedPosition = vPosition * 0.5 + 0.5;
    // What does texture do? uPosition?
    photon.position = texture(uPosition, mappedPosition).xyz;
    // xyz attribute takes care of direction of photon bounce, based on position, w?
    vec4 directionAndBounces = texture(uDirection, mappedPosition);
    photon.direction = directionAndBounces.xyz;
    photon.bounces = uint(directionAndBounces.w + 0.5);
    // Set photon's trasmitance to mapped position
    photon.transmittance = texture(uTransmittance, mappedPosition).rgb;
    vec4 radianceAndSamples = texture(uRadiance, mappedPosition);
    // Set photon's radiance based on uRadiance and position, w?
    photon.radiance = radianceAndSamples.rgb;
    photon.samples = uint(radianceAndSamples.w + 0.5);

    // Create new random seed in the form of vec2 r, what is r.x what is r.y? Does that just mean we
    // generate two seperate random floats from [0, 1)?
    vec2 r = rand(vPosition * uRandSeed);
    for (uint i = 0u; i < uSteps; i++) {
        r = rand(r);
        // TODO: Calculate step size based on exponential distance travelled and uMajorant, what is uMajorant?
        // Is uMajorant like a normalizing factor?
        float t = -log(r.x) / uMajorant;
        photon.position += t * photon.direction;

        vec4 volumeSample = sampleVolumeColor(photon.position);
        float muAbsorption = volumeSample.a * uAbsorptionCoefficient;
        float muEmission = volumeSample.a * uEmissionCoefficient;
        float muNull = uMajorant - muAbsorption - muEmission;
        float muMajorant = muAbsorption + muEmission + abs(muNull);
        float PNull = abs(muNull) / muMajorant;
        // TODO: PAbsorption based on a value of volume and absorption coefficient we then normalize it?
        float PAbsorption = muAbsorption / muMajorant;
        float PEmission = muEmission / muMajorant;

        if (any(greaterThan(photon.position, vec3(1))) || any(lessThan(photon.position, vec3(0)))) {
            // out of bounds
            vec3 radiance = vec3(0);
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            // What does resetting a photon do if we're out of bounce
            resetPhoton(r, photon);
        } else if (photon.bounces >= uMaxBounces) {
            // max bounces achieved -> only estimate transmittance
            // What is weightAS?
            float weightAS = (muAbsorption + muEmission) / uMajorant;
            photon.transmittance *= 1.0 - weightAS;
        } else if (r.y < PAbsorption) {
            // absorption - What is weightA? How much of our photon gets absorbed?
            float weightA = muAbsorption / (uMajorant * PAbsorption);
            photon.transmittance *= 1.0 - weightA;
        } else if (r.y < PAbsorption + PEmission) {
            // emission - I intend to do emission based on muAbsorption, if volume has absorped some
            // than it is more likely to emmit a photon. In slides funamentals page 7 there is 
            // modeling the emission as abs_coeff * emitted_radiance, what is emmited radience?
            // Here we generate a new Proton most likely, which means we now have two photons,
            // what do we need to call for the integrate part to be done on the new photon? Also
            // how much transmittance does the new photon have, same as volume had muAbsorption?
            vec3 radiance = photon.transmittance * volumeSample.rgb;
            radiance += photon.radiance
        } else {
            // null collision - what is null collision, photon just passing through? Or is it
            // photon colliding with fictitious medium?
            // What is weightN?
            float weightN = muNull / (uMajorant * PNull);
            // Why do we lower transmittance
            photon.transmittance *= weightN;
        }
    }

    // What are these oValues? original photon values?
    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    oRadiance = vec4(photon.radiance, float(photon.samples));
}

// #section EAMMCRender/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = (aPosition + 1.0) * 0.5;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMMCRender/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uColor;

in vec2 vPosition;
out vec4 oColor;

void main() {
    oColor = vec4(texture(uColor, vPosition).rgb, 1);
}

// #section EAMMCReset/vertex

#version 300 es

layout (location = 0) in vec2 aPosition;

out vec2 vPosition;

void main() {
    vPosition = aPosition;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMMCReset/fragment

#version 300 es
precision mediump float;

@Photon

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

@rand
@unprojectRand
@intersectCube

void main() {
    Photon photon;
    vec3 from, to;
    vec2 randState = rand(vPosition * uRandSeed);
    // TODO: What does unprojectRand do?
    unprojectRand(randState, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
    photon.radiance = vec3(1);
    photon.bounces = 0u;
    photon.samples = 0u;
    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    oRadiance = vec4(photon.radiance, float(photon.samples));
}
