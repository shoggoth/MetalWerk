//
//  RootViewController.m
//  MetalWerk
//
//  Created by Richard Henry on 19/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

#import "RootViewController.h"
#import "Renderer.h"

@implementation RootViewController {
    
    IBOutlet UIView     *noMetalView;           // This view replaces the main view if Metal initialisation fails.
    
    MTKView             *view;
    id <MetalRenderer>  renderer;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

    view = (MTKView *)self.view;

    // Create Metal device and check that Metal is supported.
    view.device = MTLCreateSystemDefaultDevice();
    if (!view.device) { self.view = noMetalView; return; }

    // Setup renderer
    renderer = [[TestRenderer alloc] initWithMetalKitView:view];
    [renderer mtkView:view drawableSizeWillChange:view.bounds.size];
    view.delegate = renderer;
    
#ifdef DEBUG
    float viewContentsScale = view.layer.contentsScale;
    float screenContentsScale = [[UIScreen mainScreen] scale];
    
    NSAssert(viewContentsScale == screenContentsScale, @"View (%f) and screen (%f) scale mismatch", viewContentsScale, screenContentsScale);
#endif
}

- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }

@end
