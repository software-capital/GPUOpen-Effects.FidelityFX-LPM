// AMD Cauldron code
// 
// Copyright(c) 2018 Advanced Micro Devices, Inc.All rights reserved.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#version 460
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable
#extension GL_ARB_gpu_shader_fp64 : enable

layout (location = 0) in vec2 inTexCoord;

layout (location = 0) out vec4 outColor;

layout (std140, binding = 0) uniform perBatch 
{
    bool u_shoulder;
    bool u_con;
    bool u_soft;
    bool u_con2;
    bool u_clip;
    bool u_scaleOnly;
    uint u_displayMode;
    uint pad;
    mat4 u_inputToOutputMatrix;
    ivec4 u_ctl[24 * 4];
} myPerScene;

layout(set=0, binding=1) uniform sampler2D sSampler;

//--------------------------------------------------------------------------------------
// Timothy Lottes LPM
//--------------------------------------------------------------------------------------

#define A_GPU 1
#define A_GLSL 1

#include "ffx_a.h"

AU4 LpmFilterCtl(AU1 i)
{
    return myPerScene.u_ctl[i];
}

#define LPM_NO_SETUP 1
#include "ffx_lpm.h"

#include "transferfunction.h"

void main() 
{
    vec4 color = texture(sSampler, inTexCoord.st);

    color = myPerScene.u_inputToOutputMatrix * color;

    // This code is there to make sure no negative values make it down to LPM. Make sure to never hit this case and convert content to correct colourspace
    color.r = max(0, color.r);
    color.g = max(0, color.g);
    color.b = max(0, color.b);
    //

    LpmFilter(color.r, color.g, color.b, myPerScene.u_shoulder, myPerScene.u_con, myPerScene.u_soft, myPerScene.u_con2, myPerScene.u_clip, myPerScene.u_scaleOnly);

    switch (myPerScene.u_displayMode)
    {
        case 1: 
            // FS2_DisplayNative
            // Apply gamma
            color.xyz = ApplyGamma(color.rgb);
            break;

        case 3:
            // HDR10_ST2084
            // Apply ST2084 curve
            color.xyz = ApplyPQ(color.xyz);
            break;
    }

    outColor = color;
}
