//
//  Matrix.h
//  Maths
//
//  Created by Richard Henry on 21/11/2019.
//  Copyright © 2019 Dogstar Industries Ltd. All rights reserved.
//

#import <simd/simd.h>

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz);
matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis);
matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ);
