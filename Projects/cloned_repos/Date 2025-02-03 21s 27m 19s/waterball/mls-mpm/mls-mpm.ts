import clearGrid from './clearGrid.wgsl'
import spawnParticles from './spawnParticles.wgsl'
import p2g_1 from './p2g_1.wgsl'
import p2g_2 from './p2g_2.wgsl'
import updateGrid from './updateGrid.wgsl'
import g2p from './g2p.wgsl'
import copyPosition from './copyPosition.wgsl'

import { numParticlesMax, renderUniformsViews } from '../common'

export const mlsmpmParticleStructSize = 80

export class MLSMPMSimulator {
    max_x_grids = 80;
    max_y_grids = 80;
    max_z_grids = 80;
    cellStructSize = 16;
    realBoxSizeBuffer: GPUBuffer
    initBoxSizeBuffer: GPUBuffer
    numParticlesBuffer: GPUBuffer
    densityBuffer: GPUBuffer
    mouseInfoUniformBuffer: GPUBuffer
    sphereRadiusBuffer: GPUBuffer
    numParticles = 0
    gridCount = 0

    clearGridPipeline: GPUComputePipeline
    spawnParticlesPipeline: GPUComputePipeline
    p2g1Pipeline: GPUComputePipeline
    p2g2Pipeline: GPUComputePipeline
    updateGridPipeline: GPUComputePipeline
    g2pPipeline: GPUComputePipeline
    copyPositionPipeline: GPUComputePipeline

    clearGridBindGroup: GPUBindGroup
    spawnParticlesBindGroup: GPUBindGroup
    p2g1BindGroup: GPUBindGroup
    p2g2BindGroup: GPUBindGroup
    updateGridBindGroup: GPUBindGroup
    g2pBindGroup: GPUBindGroup
    copyPositionBindGroup: GPUBindGroup

    particleBuffer: GPUBuffer

    device: GPUDevice

    renderDiameter: number

    frameCount: number

    spawned: boolean

    mouseInfoValues: ArrayBuffer

    restDensity: number

    constructor (particleBuffer: GPUBuffer, posvelBuffer: GPUBuffer, renderDiameter: number, device: GPUDevice, 
        renderUniformBuffer: GPUBuffer, depthMapTextureView: GPUTextureView, canvas: HTMLCanvasElement) 
    {
        this.device = device
        this.renderDiameter = renderDiameter
        this.frameCount = 0
        this.spawned = false
        this.numParticles = 0
        const clearGridModule = device.createShaderModule({ code: clearGrid });
        const spawnParticlesModule = device.createShaderModule({ code: spawnParticles });
        const p2g1Module = device.createShaderModule({ code: p2g_1 });
        const p2g2Module = device.createShaderModule({ code: p2g_2 });
        const updateGridModule = device.createShaderModule({ code: updateGrid });
        const g2pModule = device.createShaderModule({ code: g2p });
        const copyPositionModule = device.createShaderModule({ code: copyPosition });

        this.restDensity = 4.

        const constants = {
            stiffness: 3., 
            restDensity: this.restDensity, 
            dynamic_viscosity: 0.1, 
            dt: 0.20, 
            fixed_point_multiplier: 1e7, 
        }

        this.clearGridPipeline = device.createComputePipeline({
            label: "clear grid pipeline", 
            layout: 'auto', 
            compute: {
                module: clearGridModule, 
            }
        })
        this.spawnParticlesPipeline = device.createComputePipeline({
            label: "spawn particles pipeline", 
            layout: 'auto', 
            compute: {
                module: spawnParticlesModule, 
            }
        })
        this.p2g1Pipeline = device.createComputePipeline({
            label: "p2g 1 pipeline", 
            layout: 'auto', 
            compute: {
                module: p2g1Module, 
                constants: {
                    'fixed_point_multiplier': constants.fixed_point_multiplier
                }, 
            }
        })
        this.p2g2Pipeline = device.createComputePipeline({
            label: "p2g 2 pipeline", 
            layout: 'auto', 
            compute: {
                module: p2g2Module, 
                constants: {
                    'fixed_point_multiplier': constants.fixed_point_multiplier, 
                    'stiffness': constants.stiffness, 
                    'rest_density': constants.restDensity, 
                    'dynamic_viscosity': constants.dynamic_viscosity, 
                    'dt': constants.dt, 
                }, 
            }
        })
        this.updateGridPipeline = device.createComputePipeline({
            label: "update grid pipeline", 
            layout: 'auto', 
            compute: {
                module: updateGridModule, 
                constants: {
                    'fixed_point_multiplier': constants.fixed_point_multiplier, 
                    'dt': constants.dt, 
                }, 
            }
        });
        this.g2pPipeline = device.createComputePipeline({
            label: "g2p pipeline", 
            layout: 'auto', 
            compute: {
                module: g2pModule, 
                constants: {
                    'fixed_point_multiplier': constants.fixed_point_multiplier, 
                    'dt': constants.dt, 
                }, 
            }
        });
        this.copyPositionPipeline = device.createComputePipeline({
            label: "copy position pipeline", 
            layout: 'auto', 
            compute: {
                module: copyPositionModule, 
            }
        });

        const maxGridCount = this.max_x_grids * this.max_y_grids * this.max_z_grids;
        const realBoxSizeValues = new ArrayBuffer(12);
        const initBoxSizeValues = new ArrayBuffer(12);
        const numParticlesValues = new ArrayBuffer(4);
        this.mouseInfoValues = new ArrayBuffer(32);

        const cellBuffer = device.createBuffer({ 
            label: 'cells buffer', 
            size: this.cellStructSize * maxGridCount,  
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        })
        this.densityBuffer = device.createBuffer({
            label: 'density buffer', 
            size: 4 * numParticlesMax, 
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        })
        this.realBoxSizeBuffer = device.createBuffer({
            label: 'real box size buffer', 
            size: realBoxSizeValues.byteLength, 
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        })
        this.initBoxSizeBuffer = device.createBuffer({
            label: 'init box size buffer', 
            size: initBoxSizeValues.byteLength, 
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        })
        this.numParticlesBuffer = device.createBuffer({
            label: 'number of particles buffer', 
            size: numParticlesValues.byteLength, 
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        }) 
        this.mouseInfoUniformBuffer = device.createBuffer({
            label: 'mouse info buffer', 
            size: this.mouseInfoValues.byteLength, 
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        })
        this.sphereRadiusBuffer = device.createBuffer({
            label: 'sphere radius buffer', 
            size: 4, // single f32
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        })

        // TODO : これを一か所にまとめる
        const mouseInfoViews = {
            screenSize: new Float32Array(this.mouseInfoValues, 0, 2),
            mouseCoord: new Float32Array(this.mouseInfoValues, 8, 2),
            mouseVel: new Float32Array(this.mouseInfoValues, 16, 2),
            mouseRadius: new Float32Array(this.mouseInfoValues, 24, 1),
        };
        mouseInfoViews.screenSize.set([canvas.width, canvas.height]);
        this.device.queue.writeBuffer(this.mouseInfoUniformBuffer, 0, this.mouseInfoValues);

        // BindGroup
        this.clearGridBindGroup = device.createBindGroup({
            layout: this.clearGridPipeline.getBindGroupLayout(0), 
            entries: [
              { binding: 0, resource: { buffer: cellBuffer }}, 
            ],  
        })
        this.spawnParticlesBindGroup = device.createBindGroup({
            layout: this.spawnParticlesPipeline.getBindGroupLayout(0), 
            entries: [
              { binding: 0, resource: { buffer: particleBuffer }}, 
              { binding: 1, resource: { buffer: this.initBoxSizeBuffer }}, 
              { binding: 2, resource: { buffer: this.numParticlesBuffer }}
            ],  
        })
        this.p2g1BindGroup = device.createBindGroup({
            layout: this.p2g1Pipeline.getBindGroupLayout(0), 
            entries: [
                { binding: 0, resource: { buffer: particleBuffer }}, 
                { binding: 1, resource: { buffer: cellBuffer }}, 
                { binding: 2, resource: { buffer: this.initBoxSizeBuffer }}, 
                { binding: 3, resource: { buffer: this.numParticlesBuffer }}, 
            ],  
        })
        this.p2g2BindGroup = device.createBindGroup({
            layout: this.p2g2Pipeline.getBindGroupLayout(0), 
            entries: [
                { binding: 0, resource: { buffer: particleBuffer }}, 
                { binding: 1, resource: { buffer: cellBuffer }}, 
                { binding: 2, resource: { buffer: this.initBoxSizeBuffer }}, 
                { binding: 3, resource: { buffer: this.numParticlesBuffer }}, 
                { binding: 4, resource: { buffer: this.densityBuffer }}
            ]
        })
        this.updateGridBindGroup = device.createBindGroup({
            layout: this.updateGridPipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: { buffer: cellBuffer }},
                { binding: 1, resource: { buffer: this.realBoxSizeBuffer }},
                { binding: 2, resource: { buffer: this.initBoxSizeBuffer }},
                { binding: 3, resource: { buffer: renderUniformBuffer }}, 
                { binding: 4, resource: depthMapTextureView }, 
                { binding: 5, resource: { buffer: this.mouseInfoUniformBuffer }}, 
            ],
        })
        this.g2pBindGroup = device.createBindGroup({
            layout: this.g2pPipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: { buffer: particleBuffer }},
                { binding: 1, resource: { buffer: cellBuffer }},
                { binding: 2, resource: { buffer: this.realBoxSizeBuffer }},
                { binding: 3, resource: { buffer: this.initBoxSizeBuffer }},
                { binding: 4, resource: { buffer: this.numParticlesBuffer }}, 
                { binding: 5, resource: { buffer: this.sphereRadiusBuffer }}, 
            ],
        })
        this.copyPositionBindGroup = device.createBindGroup({
            layout: this.copyPositionPipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: { buffer: particleBuffer }}, 
                { binding: 1, resource: { buffer: posvelBuffer }}, 
                { binding: 2, resource: { buffer: this.numParticlesBuffer }}, 
                { binding: 3, resource: { buffer: this.densityBuffer }}, 
            ]
        })

        this.particleBuffer = particleBuffer
    }

    initDambreak(initBoxSize: number[], numParticles: number) {
        let particlesBuf = new ArrayBuffer(mlsmpmParticleStructSize * numParticlesMax);
        const spacing = 0.55;

        this.numParticles = 0;
        
        for (let j = 3; j < initBoxSize[1] * 0.80 && this.numParticles < numParticles; j += spacing) {
            for (let i = 3; i < initBoxSize[0] - 4 && this.numParticles < numParticles; i += spacing) {
                for (let k = 3; k < initBoxSize[2] / 2 && this.numParticles < numParticles; k += spacing) {
                    const offset = mlsmpmParticleStructSize * this.numParticles;
                    const particleViews = {
                        position: new Float32Array(particlesBuf, offset + 0, 3),
                        v: new Float32Array(particlesBuf, offset + 16, 3),
                        C: new Float32Array(particlesBuf, offset + 32, 12),
                    };
                    const jitter = 2.0 * Math.random();
                    particleViews.position.set([i + jitter, j + jitter, k + jitter]);
                    this.numParticles++;
                }
            }
        }
        
        let particles = new ArrayBuffer(mlsmpmParticleStructSize * this.numParticles);
        const oldView = new Uint8Array(particlesBuf);
        const newView = new Uint8Array(particles);
        newView.set(oldView.subarray(0, newView.length));
        
        return particles;
    }

    reset(initBoxSize: number[], sphereRadius: number) {
        renderUniformsViews.sphere_size.set([this.renderDiameter])
        const maxGridCount = this.max_x_grids * this.max_y_grids * this.max_z_grids;
        this.gridCount = Math.ceil(initBoxSize[0]) * Math.ceil(initBoxSize[1]) * Math.ceil(initBoxSize[2]);
        if (this.gridCount > maxGridCount) {
            throw new Error("gridCount should be equal to or less than maxGridCount")
        }
        const initBoxSizeValues = new ArrayBuffer(12)
        const initBoxSizeViews = new Float32Array(initBoxSizeValues)
        initBoxSizeViews.set(initBoxSize);    
        const sphereRadiusValues = new ArrayBuffer(4)
        const sphereRadiusViews = new Float32Array(sphereRadiusValues)
        sphereRadiusViews.set([sphereRadius])
        this.device.queue.writeBuffer(this.initBoxSizeBuffer, 0, initBoxSizeValues)
        this.device.queue.writeBuffer(this.sphereRadiusBuffer, 0, sphereRadiusValues)
        this.frameCount = 0;
        this.changeBoxSize(initBoxSize)
        this.changeNumParticles(0)
    }

    execute(commandEncoder: GPUCommandEncoder, mouseCoord: number[], mouseVel: number[], targetNumParticles: number, mouseRadius: number) {
        const computePass = commandEncoder.beginComputePass();

        const canvasInfoViews = {
            screenSize: new Float32Array(this.mouseInfoValues, 0, 2),
            mouseCoord: new Float32Array(this.mouseInfoValues, 8, 2),
            mouseVel: new Float32Array(this.mouseInfoValues, 16, 2),
            mouseRadius : new Float32Array(this.mouseInfoValues, 24, 2),
        };
        canvasInfoViews.mouseCoord.set([mouseCoord[0], mouseCoord[1]])
        canvasInfoViews.mouseVel.set([mouseVel[0], mouseVel[1]])
        canvasInfoViews.mouseRadius.set([mouseRadius])
        this.device.queue.writeBuffer(this.mouseInfoUniformBuffer, 0, this.mouseInfoValues);

        if (this.frameCount % 2 == 0 && this.numParticles < targetNumParticles) { // TODO : dt に依存しないようにする
            console.log("spawn");
            computePass.setBindGroup(0, this.spawnParticlesBindGroup)
            computePass.setPipeline(this.spawnParticlesPipeline)
            computePass.dispatchWorkgroups(1)
            this.changeNumParticles(this.numParticles + 100)
        }

        for (let i = 0; i < 2; i++) { 
            computePass.setBindGroup(0, this.clearGridBindGroup);
            computePass.setPipeline(this.clearGridPipeline);
            computePass.dispatchWorkgroups(Math.ceil(this.gridCount / 64)) 
            computePass.setBindGroup(0, this.p2g1BindGroup)
            computePass.setPipeline(this.p2g1Pipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.numParticles / 64))
            computePass.setBindGroup(0, this.p2g2BindGroup)
            computePass.setPipeline(this.p2g2Pipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.numParticles / 64)) 
            computePass.setBindGroup(0, this.updateGridBindGroup)
            computePass.setPipeline(this.updateGridPipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.gridCount / 64)) 
            computePass.setBindGroup(0, this.g2pBindGroup)
            computePass.setPipeline(this.g2pPipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.numParticles / 64)) 
            computePass.setBindGroup(0, this.copyPositionBindGroup)
            computePass.setPipeline(this.copyPositionPipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.numParticles / 64))  
            computePass.setBindGroup(0, this.copyPositionBindGroup)
            computePass.setPipeline(this.copyPositionPipeline)
            computePass.dispatchWorkgroups(Math.ceil(this.numParticles / 64))  
        }
        computePass.end()

        // console.log("current particles: ", this.numParticles)
        this.frameCount++;
    }

    changeBoxSize(realBoxSize: number[]) {
        const realBoxSizeValues = new ArrayBuffer(12);
        const realBoxSizeViews = new Float32Array(realBoxSizeValues);
        realBoxSizeViews.set(realBoxSize)
        this.device.queue.writeBuffer(this.realBoxSizeBuffer, 0, realBoxSizeViews)
    }

    changeNumParticles(numParticles: number) {
        const numParticlesValues = new ArrayBuffer(4);
        const numParticlesViews = new Int32Array(numParticlesValues)
        numParticlesViews.set([numParticles])
        this.device.queue.writeBuffer(this.numParticlesBuffer, 0, numParticlesViews)
        this.numParticles = numParticles
    }
}