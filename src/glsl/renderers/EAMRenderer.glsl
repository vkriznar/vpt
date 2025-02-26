// #package glsl/shaders

// #include ../mixins/unproject.glsl
// #include ../mixins/intersectCube.glsl

// #section EAMGenerate/vertex

#version 300 es
precision mediump float;

uniform mat4 uMvpInverseMatrix;

layout(location = 0) in vec2 aPosition;
out vec3 vRayFrom;
out vec3 vRayTo;

@unproject

void main() {
    unproject(aPosition, uMvpInverseMatrix, vRayFrom, vRayTo);
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMGenerate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler3D uVolume;
uniform mediump sampler2D uTransferFunction;
uniform float uStepSize;
uniform float uOffset;
uniform float uAlphaCorrection;
uniform float uType;

in vec3 vRayFrom;
in vec3 vRayTo;
out vec4 oColor;

@intersectCube
@rand

void main() {
    vec3 rayDirection = vRayTo - vRayFrom;
    vec2 tbounds = max(intersectCube(vRayFrom, rayDirection), 0.0);
    if (tbounds.x >= tbounds.y) {
        oColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec3 from = mix(vRayFrom, vRayTo, tbounds.x);
        vec3 to = mix(vRayFrom, vRayTo, tbounds.y);
        float rayStepLength = distance(from, to) * uStepSize;

        float t = 0.0;
        // Sample offset
        if (uType == 1.0) { t = uStepSize * uOffset; }

        vec3 pos;
        float val;
        vec4 colorSample;
        vec4 accumulator = vec4(0.0);

        if (uType < 1.0) {
            vec2 randPosition = vRayFrom.xy * uOffset;
            vec2 r = rand(randPosition);

            for(int i = 1; i <= int(1.0 / uStepSize); i++) {
                if (accumulator.a > 0.99) { break; }

                pos = mix(from, to, t);
                val = texture(uVolume, pos).r;
                colorSample = texture(uTransferFunction, vec2(val, 0.5));
                colorSample.a *= rayStepLength * uAlphaCorrection;
                colorSample.rgb *= colorSample.a;
                accumulator += (1.0 - accumulator.a) * colorSample;

                t = uStepSize * float(i) + (r.x - 0.5) * uStepSize;
                r = rand(r);
            }
        } else {
            while (t < 1.0 && accumulator.a < 0.99) {
                pos = mix(from, to, t);
                val = texture(uVolume, pos).r;
                colorSample = texture(uTransferFunction, vec2(val, 0.5));
                colorSample.a *= rayStepLength * uAlphaCorrection;
                colorSample.rgb *= colorSample.a;
                accumulator += (1.0 - accumulator.a) * colorSample;

                t += uStepSize;
            }
        }

        if (accumulator.a > 1.0) {
            accumulator.rgb /= accumulator.a;
        }

        oColor = vec4(accumulator.rgb, 1.0);
    }
}

// #section EAMIntegrate/vertex

#version 300 es
precision mediump float;

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = (aPosition + 1.0) * 0.5;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMIntegrate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;
uniform mediump sampler2D uFrame;

in vec2 vPosition;
out vec4 oColor;

void main() {
    vec4 acc = texture(uAccumulator, vPosition);
    vec4 frame = texture(uFrame, vPosition);
    oColor = max(frame, acc);
}

// #section EAMRender/vertex

#version 300 es
precision mediump float;

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = (aPosition + 1.0) * 0.5;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMRender/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;

in vec2 vPosition;
out vec4 oColor;

void main() {
    oColor = texture(uAccumulator, vPosition);
}

// #section EAMReset/vertex

#version 300 es
precision mediump float;

layout(location = 0) in vec2 aPosition;

void main() {
    gl_Position = vec4(aPosition, 0.0, 1.0);
}

// #section EAMReset/fragment

#version 300 es
precision mediump float;

out vec4 oColor;

void main() {
    oColor = vec4(0.0, 0.0, 0.0, 1.0);
}
