//
//  Renderer.m
//  MetalWerk
//
//  Created by Richard Henry on 19/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>

#import "Renderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"

static const NSUInteger kUniformBufferMax = 3;

@implementation Renderer {
    
    dispatch_semaphore_t        frameBufferSemaphore;
    
    id <MTLDevice>              device;
    id <MTLCommandQueue>        commandQueue;
    
    id <MTLBuffer>              dynamicUniformBuffer[kUniformBufferMax];
    id <MTLRenderPipelineState> pipelineState;
    id <MTLDepthStencilState>   depthState;
    id <MTLTexture>             colourMap;
    
    MTLVertexDescriptor         *vertexDescriptor;
    uint8_t                     uniformBufferIndex;
    matrix_float4x4             projectionMatrix;
    float                       rotation;
    MTKMesh                     *mesh;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    
    if((self = [super init])) {
        
        device = view.device;
        frameBufferSemaphore = dispatch_semaphore_create(kUniformBufferMax);
        [self loadMetalWithView:view];
        [self loadAssets];
    }
    
    return self;
}

- (void)loadMetalWithView:(nonnull MTKView *)view {
    
    // Load Metal state objects and initalize renderer dependent view properties
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    view.sampleCount = 1;
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = view.sampleCount;
    
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    
    // Do summat
    id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
    pipelineStateDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    pipelineStateDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
    
    // Do summat
    vertexDescriptor = [MTLVertexDescriptor new];
    
    vertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[VertexAttributePosition].offset = 0;
    vertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;
    
    vertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
    vertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;
    
    vertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
    vertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
    vertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    
    vertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 8;
    vertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
    vertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    
    // Do summat
    NSError *error = NULL;
    if (!(pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error]))
        NSLog(@"Failed to created pipeline state, error %@", error);
    
    // Do summat
    MTLDepthStencilDescriptor *depthStateDesc = [MTLDepthStencilDescriptor new];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    depthState = [device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    for (unsigned i = 0; i < kUniformBufferMax; i++) {
        dynamicUniformBuffer[i] = [device newBufferWithLength:sizeof(Uniforms) options:MTLResourceStorageModeShared];
        dynamicUniformBuffer[i].label = [NSString stringWithFormat:@"UniformBuffer %d", i];
    }
    
    commandQueue = [device newCommandQueue];
}

- (void)loadAssets {
    
    // Load assets into metal objects
    
    NSError *error;
    
    MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice: device];
    MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){4, 4, 4} segments:(vector_uint3){2, 2, 2} geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:metalAllocator];
    
    MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor);
    mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;
    
    mdlMesh.vertexDescriptor = mdlVertexDescriptor;
    
    mesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:device error:&error];
    
    if (!mesh || error) NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    
    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSDictionary *textureLoaderOptions = @{
        MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
        MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
    };
    
    colourMap = [textureLoader newTextureWithName:@"ColorMap" scaleFactor:1.0 bundle:nil options:textureLoaderOptions error:&error];
    
    if (!colourMap || error) NSLog(@"Error creating texture %@", error.localizedDescription);
}

- (void)updateGameState {
    
    // Update any game state before encoding renderint commands to our drawable
    Uniforms *uniforms = (Uniforms *)dynamicUniformBuffer[uniformBufferIndex].contents;
    
    uniforms->projectionMatrix = projectionMatrix;
    
    vector_float3 rotationAxis = {1, 1, 0};
    matrix_float4x4 modelMatrix = matrix4x4_rotation(rotation, rotationAxis);
    matrix_float4x4 viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0);
    
    uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
    
    rotation += .01;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    
    // Per frame updates here
    dispatch_semaphore_wait(frameBufferSemaphore, DISPATCH_TIME_FOREVER);
    
    uniformBufferIndex = (uniformBufferIndex + 1) % kUniformBufferMax;
    
    id <MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    __block dispatch_semaphore_t block_sema = frameBufferSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) { dispatch_semaphore_signal(block_sema); }];
    
    [self updateGameState];
    
    /// Delay getting the currentRenderPassDescriptor until absolutely needed. This avoids
    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if (renderPassDescriptor) {
        
        /// Final pass rendering code here
        
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        [renderEncoder pushDebugGroup:@"DrawBox"];
        
        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderEncoder setCullMode:MTLCullModeBack];
        [renderEncoder setRenderPipelineState:pipelineState];
        [renderEncoder setDepthStencilState:depthState];
        
        [renderEncoder setVertexBuffer:dynamicUniformBuffer[uniformBufferIndex] offset:0 atIndex:BufferIndexUniforms];
        //[renderEncoder setFragmentBuffer:dynamicUniformBuffer[uniformBufferIndex] offset:0 atIndex:BufferIndexUniforms];
        
        for (unsigned bufferIndex = 0; bufferIndex < mesh.vertexBuffers.count; bufferIndex++) {
            
            MTKMeshBuffer *vertexBuffer = mesh.vertexBuffers[bufferIndex];
            
            if ((NSNull *)vertexBuffer != [NSNull null]) [renderEncoder setVertexBuffer:vertexBuffer.buffer offset:vertexBuffer.offset atIndex:bufferIndex];
        }
        
        [renderEncoder setFragmentTexture:colourMap atIndex:TextureIndexColor];
        
        for (MTKSubmesh *submesh in mesh.submeshes)
            [renderEncoder drawIndexedPrimitives:submesh.primitiveType indexCount:submesh.indexCount indexType:submesh.indexType indexBuffer:submesh.indexBuffer.buffer indexBufferOffset:submesh.indexBuffer.offset];
        
        [renderEncoder popDebugGroup];
        
        [renderEncoder endEncoding];
        
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    /// Respond to drawable size or orientation changes here
    
    float aspect = size.width / (float)size.height;
    projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

#pragma mark Matrix Math Utilities

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz)
{
    return (matrix_float4x4) {{
        { 1,   0,  0,  0 },
        { 0,   1,  0,  0 },
        { 0,   0,  1,  0 },
        { tx, ty, tz,  1 }
    }};
}

static matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis) {
    
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;
    
    return (matrix_float4x4) {{
        { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
        { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
        {                   0,                   0,                   0, 1}
    }};
}

matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ) {
    
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    
    return (matrix_float4x4) {{
        { xs,   0,          0,  0 },
        {  0,  ys,          0,  0 },
        {  0,   0,         zs, -1 },
        {  0,   0, nearZ * zs,  0 }
    }};
}

@end
