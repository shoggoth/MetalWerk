//
//  Shaders.metal
//  MetalWerk
//
//  Created by Richard Henry on 19/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

#import "ShaderTypes.h" // Shared Metal/Swift/Obj-C types

#include <metal_stdlib> // Metal kernel and shader functions

using namespace metal;

typedef struct {
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut meshVertexShader(Vertex in [[stage_in]], constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {
    
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 meshFragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d<half> colorMap [[texture(TextureIndexColor)]]) {
    
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);
    
    colorSample.r = half(uniforms.time);
    
    return float4(colorSample);
}
