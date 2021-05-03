// #package js/main

// #include ../AbstractDialog.js
// #include ../../TransferFunctionWidget.js

// #include ../../../uispecs/renderers/EAMMCRendererDialog.json

class EAMMCRendererDialog extends AbstractDialog {

    constructor(renderer, options) {
        super(UISPECS.EAMMCRendererDialog, options);
    
        this._renderer = renderer;
    
        this._handleChange = this._handleChange.bind(this);
        this._handleTFChange = this._handleTFChange.bind(this);
    
        this._binds.extinction.addEventListener('input', this._handleChange);
        this._binds.albedo.addEventListener('change', this._handleChange);
        this._binds.ratio.addEventListener('change', this._handleChange);
        this._binds.bounces.addEventListener('input', this._handleChange);
        this._binds.steps.addEventListener('input', this._handleChange);
    
        this._tfwidget = new TransferFunctionWidget();
        this._binds.tfcontainer.add(this._tfwidget);
        this._tfwidget.addEventListener('change', this._handleTFChange);
    }
    
    destroy() {
        this._tfwidget.destroy();
        super.destroy();
    }
    
    _handleChange() {
        const extinction = this._binds.extinction.getValue();
        const albedo     = this._binds.albedo.getValue();
        const ratio      = this._binds.ratio.getValue();
        const bounces    = this._binds.bounces.getValue();
        const steps      = this._binds.steps.getValue();
    
        this._renderer.absorptionCoefficient = extinction * (1 - albedo);
        this._renderer.emissionCoefficient = extinction * albedo;
        this._renderer.majorant = extinction * ratio;
        this._renderer.maxBounces = bounces;
        this._renderer.steps = steps;
    
        this._renderer.reset();
    }
    
    _handleTFChange() {
        this._renderer.setTransferFunction(this._tfwidget.getTransferFunction());
        this._renderer.reset();
    }
    
    }
    