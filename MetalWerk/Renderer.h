//
//  Renderer.h
//  MetalWerk
//
//  Created by Richard Henry on 19/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

@import MetalKit;

@protocol MetalRenderer <NSObject, MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end

#pragma mark - Renderer base

@interface Renderer : NSObject <MetalRenderer> {

    // Metal components
    id <MTLDevice>              device;
    id <MTLCommandQueue>        commandQueue;

    // Synchronisation
    dispatch_semaphore_t        frameBufferSemaphore;
    uint8_t                     bufferIndex, bufferCount;
}

@end

#pragma mark - Test Renderer

@interface TestRenderer : Renderer

@end
