// #package js/main

// #include ../WebGL.js
// #include AbstractRenderer.js

class EAMRenderer extends AbstractRenderer {

constructor(gl, volume, environmentTexture, options) {
    super(gl, volume, environmentTexture, options);

    Object.assign(this, {
        _stepSize        : 0.05,
        _alphaCorrection : 3,
        _type            : 2
    }, options);

    this._programs = WebGL.buildPrograms(this._gl, {
        generate  : SHADERS.EAMGenerate,
        integrate : SHADERS.EAMIntegrate,
        render    : SHADERS.EAMRender,
        reset     : SHADERS.EAMReset
    }, MIXINS);
}

destroy() {
    const gl = this._gl;
    Object.keys(this._programs).forEach(programName => {
        gl.deleteProgram(this._programs[programName].program);
    });

    super.destroy();
}

_resetFrame() {
    const gl = this._gl;

    const program = this._programs.reset;
    gl.useProgram(program.program);

    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
}

_generateFrame() {
    const gl = this._gl;

    const program = this._programs.generate;
    gl.useProgram(program.program);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_3D, this._volume.getTexture());
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this._transferFunction);

    gl.uniform1i(program.uniforms.uVolume, 0);
    gl.uniform1i(program.uniforms.uTransferFunction, 1);
    gl.uniform1f(program.uniforms.uStepSize, this._stepSize);
    gl.uniform1f(program.uniforms.uAlphaCorrection, this._alphaCorrection);
    gl.uniform1f(program.uniforms.uOffset, Math.random());
    gl.uniform1f(program.uniforms.uType, this._type);
    gl.uniformMatrix4fv(program.uniforms.uMvpInverseMatrix, false, this._mvpInverseMatrix.m);

    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
}

_integrateFrame() {
    const gl = this._gl;

    const program = this._programs.integrate;
    gl.useProgram(program.program);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this._accumulationBuffer.getAttachments().color[0]);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this._frameBuffer.getAttachments().color[0]);

    gl.uniform1i(program.uniforms.uAccumulator, 0);
    gl.uniform1i(program.uniforms.uFrame, 1);

    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
}

_renderFrame() {
    const gl = this._gl;

    const program = this._programs.render;
    gl.useProgram(program.program);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this._accumulationBuffer.getAttachments().color[0]);

    gl.uniform1i(program.uniforms.uAccumulator, 0);

    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
}

_getFrameBufferSpec() {
    const gl = this._gl;
    return [{
        width          : this._bufferSize,
        height         : this._bufferSize,
        min            : gl.NEAREST,
        mag            : gl.NEAREST,
        format         : gl.RGBA,
        internalFormat : gl.RGBA,
        type           : gl.UNSIGNED_BYTE
    }];
}

_getAccumulationBufferSpec() {
    const gl = this._gl;
    return [{
        width          : this._bufferSize,
        height         : this._bufferSize,
        min            : gl.NEAREST,
        mag            : gl.NEAREST,
        format         : gl.RGBA,
        internalFormat : gl.RGBA,
        type           : gl.UNSIGNED_BYTE
    }];
}

}
