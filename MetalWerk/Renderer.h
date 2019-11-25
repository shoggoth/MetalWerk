//
//  Renderer.h
//  MetalWerk
//
//  Created by Richard Henry on 19/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

#import <MetalKit/MetalKit.h>

@protocol MetalRenderer <NSObject, MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end

@interface Renderer : NSObject <MetalRenderer>

@end

