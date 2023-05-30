// Copyright 2023 Michael Fabian Dirks <info@xaymar.com>
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// -------------------------------------------------------------------------------- //
// Parts of this code are taken or adapted from AcerolaFX (https://github.com/GarrettGunnell/AcerolaFX)
// -------------------------------------------------------------------------------- //
// MIT License
// 
// Copyright (c) 2022 Garrett Gunnell
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// -------------------------------------------------------------------------------- //

// An attempt at simulate human vision. Human vision has the following properties:
// - Rods/Cones are very sensitive to light and have a (logarithmic?) response curve.
// - Rods/Cones can be tune their sensitivity individually to some degree. ("ISO" but for each rod/cone)
// - Rods/Cones can be oversaturated, in which case the lens will shrink. ("Aperture")
// - Rods/Cones operate individually, and not as a large group like a camera sensor.
// 
// So in order to simulate human vision, I need to have the following:
// - A global auto exposure to simulate Aperture changes.
// - A local limited auto exposure to simulate Rods/Cones increasing or decreasing their sensitivity.
//
// TL;DR This is hard, no wonder Unreal Engine 5 was the first one to really do it.
// AcerolaFX only does the Global Exposure part, not the Local Exposure part.

#include "ReShade.fxh"
#include "Xmr_Common.fxh"

// Enable high quality processing which doubles the resource usage.
#ifndef XAYMAR_AUTOEXPOSURE_HIGHQUALITY
    #define XAYMAR_AUTOEXPOSURE_HIGHQUALITY 0
#endif

#if XAYMAR_AUTOEXPOSURE_HIGHQUALITY
    #define XAYMAR_AUTOEXPOSURE_FORMAT R32F
    #define XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS 128
#else
    #define XAYMAR_AUTOEXPOSURE_FORMAT R16F
    #define XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS 64
#endif

uniform uint Debug<
    ui_category = "Debug";
    ui_label = "Debug";
    ui_type = "combo";
    ui_items = "None\0"
        "Histogram\0"
        "Local Exposure\0";
> = 0;

uniform float _MinEV100<
    ui_category = "Global Exposure";
    ui_label = "Minimum EV100";
    ui_type = "slider";
    ui_min = -10.f;
    ui_max = 20.f;
    ui_step = 0.01f;
> = -10.;

uniform float _MaxEV100<
    ui_category = "Global Exposure";
    ui_label = "Maximum EV100";
    ui_type = "slider";
    ui_min = -10.f;
    ui_max = 5.f;
    ui_step = 0.01f;
> = 5.;

#define _DiffEV100 (_MaxEV100 - _MinEV100)

/*uniform float _Aperture<
    ui_category = "Exposure";
    ui_label = "Aperture (f-Stops)";
    ui_type = "slider";
    ui_min = 1.;
    ui_max = 10000.;
    ui_step = 0.001;
> = 1.;

uniform float _ShutterTime<
    ui_category = "Exposure";
    ui_label = "Shutter Time (seconds)";
    ui_type = "slider";
    ui_min = 0.;
    ui_max = 10.;
    ui_step = 0.001;
> = 0.01667;

uniform float _SensorSensitivity<
    ui_category = "Exposure";
    ui_label = "Sensor Sensitivity (ISO)";
    ui_type = "slider";
    ui_min = 50.;
    ui_max = 10000.;
    ui_step = 50.;
> = 100.;*/

// -------------------------------------------------------------------------------- //
// Downsampling

#if BUFFER_HEIGHT >= 2048
    #define XAYMAR_AUTOEXPOSURE_QUARTER 1
#elif BUFFER_HEIGHT >= 1024
    #if XAYMAR_AUTOEXPOSURE_HIGHQUALITY
        #define XAYMAR_AUTOEXPOSURE_HALF 1
    #else
        #define XAYMAR_AUTOEXPOSURE_QUARTER 1
    #endif
#else
    #define XAYMAR_AUTOEXPOSURE_HALF 1
#endif

#if defined(XAYMAR_AUTOEXPOSURE_QUARTER)
    #define XAYMAR_AUTOEXPOSURE_WIDTH (BUFFER_WIDTH / 4)
    #define XAYMAR_AUTOEXPOSURE_HEIGHT (BUFFER_HEIGHT / 4)
#elif defined(XAYMAR_AUTOEXPOSURE_HALF)
    #define XAYMAR_AUTOEXPOSURE_WIDTH (BUFFER_WIDTH / 2)
    #define XAYMAR_AUTOEXPOSURE_HEIGHT (BUFFER_HEIGHT / 2)
#endif

texture2D DownsampleTex <
    pooled = true;
> {
    Width = XAYMAR_AUTOEXPOSURE_WIDTH;
    Height = XAYMAR_AUTOEXPOSURE_HEIGHT;
    Format = XAYMAR_AUTOEXPOSURE_FORMAT;
};
sampler2D Downsample {
    Texture = DownsampleTex;
    MagFilter = LINEAR; MinFilter = LINEAR; MipFilter = LINEAR;
    MinLOD = 0.0f; MaxLOD = 0.0f;
    AddressU = CLAMP; AddressV = CLAMP; AddressW = CLAMP;
};

float Xaymar_Downsample(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET {
    #if defined(XAYMAR_AUTOEXPOSURE_QUARTER)
    //  | 0| 1| 2| 3|
    //--+--+--+--+--+
    // 0| A| A| B| B|
    //--+--X--+--X--+
    // 1| A| A| B| B|
    //--+--+--+--+--+
    // 2| C| C| D| D|
    //--+--X--+--X--+
    // 3| C| C| D| D|
    //--+--+--+--+--+

    float2 coord = float2(1, -1) / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float tl = Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord + coord.yy).rgb);
    float tr = Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord + coord.xy).rgb);
    float bl = Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord + coord.yx).rgb);
    float br = Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord + coord.xx).rgb);
    float color = (tl + tr + bl + br) * 0.25;
    return Xaymar::Color::ComputeEV100FromLuminance(color);

    #elif defined(XAYMAR_AUTOEXPOSURE_HALF)
    // X = Sample Location
    //  | 0| 1|
    //--+--+--+
    // 0|  |  |
    //--+--X--+
    // 1|  |  |
    //--+--+--+
    float3 color = Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord).rgb);
    return Xaymar::Color::ComputeEV100FromLuminance(color);
    #else
    return Xaymar::Color::Luminance(tex2D(Xaymar::BackBuffer, texcoord));
    #endif
}

// -------------------------------------------------------------------------------- //
// Histogram

uniform float _MinLogLuminance <
    ui_category = "Histogram";
    ui_min = -20.0f; ui_max = 20.0f;
    ui_label = "Min Log Luminance";
    ui_type = "drag";
    ui_tooltip = "Adjust the minimum log luminance allowed.";
> = -5.0f;

uniform float _MaxLogLuminance <
    ui_category = "Histogram";
    ui_min = -20.0f; ui_max = 20.0f;
    ui_label = "Max Log Luminance";
    ui_type = "drag";
    ui_tooltip = "Adjust the maximum log luminance allowed.";
> = -1.5f;

uniform float _Tau <
    ui_category = "Advanced Settings";
    ui_category_closed = true;
    ui_min = 0.01f; ui_max = 10.0f;
    ui_label = "Tau";
    ui_type = "drag";
    ui_tooltip = "Adjust rate at which auto exposure adjusts.";
> = 5.0f;

uniform float _S1 <
    ui_category = "Advanced Settings";
    ui_category_closed = true;
    ui_min = 0.01f; ui_max = 200.0f;
    ui_label = "Sensitivity Constant 1";
    ui_type = "drag";
    ui_tooltip = "Adjust sensor sensitivity ratio 1.";
> = 100.0f;

uniform float _S2 <
    ui_category = "Advanced Settings";
    ui_category_closed = true;
    ui_min = 0.01f; ui_max = 200.0f;
    ui_label = "Sensitivity Constant 2";
    ui_type = "drag";
    ui_tooltip = "Adjust sensor sensitivity ratio 2.";
> = 100.0f;

uniform float _K <
    ui_category = "Advanced Settings";
    ui_category_closed = true;
    ui_min = 1.0f; ui_max = 100.0f;
    ui_label = "Calibration Constant";
    ui_type = "drag";
    ui_tooltip = "Adjust reflected-light meter calibration constant.";
> = 12.5f;

uniform float _q <
    ui_category = "Advanced Settings";
    ui_category_closed = true;
    ui_min = 0.01f; ui_max = 10.0f;
    ui_label = "Lens Attenuation";
    ui_type = "drag";
    ui_tooltip = "Adjust lens and vignetting attenuation.";
> = 0.65f;

uniform float _DeltaTime < source = "frametime"; >;


#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_X XAYMAR_DIVIDE_ROUND_UP(XAYMAR_AUTOEXPOSURE_WIDTH, 16)
#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_Y XAYMAR_DIVIDE_ROUND_UP(XAYMAR_AUTOEXPOSURE_HEIGHT, 16)
#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILES (XAYMAR_AUTOEXPOSURE_HISTOGRAM_X * XAYMAR_AUTOEXPOSURE_HISTOGRAM_Y)
#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILE_STRIDE 16
#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_LOG_RANGE (_MinEV100 - _MaxEV100)
#define XAYMAR_AUTOEXPOSURE_HISTOGRAM_LOG_RANGE_RCP 1.0f / XAYMAR_AUTOEXPOSURE_HISTOGRAM_LOG_RANGE

// Tile Storage
texture2D HistogramTileTex { Width = XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILES; Height = XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS; Format = XAYMAR_AUTOEXPOSURE_FORMAT; };
storage2D HistogramTileBuffer { Texture = HistogramTileTex; };
sampler2D HistogramTile { Texture = HistogramTileTex; };

// Histogram Storage
texture2D HistogramTex { Width = XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS; Height = 1; Format = XAYMAR_AUTOEXPOSURE_FORMAT; };
storage2D HistogramBuffer { Texture = HistogramTex; };
sampler2D Histogram { Texture = HistogramTex; };

// Histogram Average
texture2D HistogramAverageTex { Width = 1; Height = 1; Format = RG32F; };
storage2D HistogramAverageBuffer { Texture = HistogramAverageTex; };
sampler2D HistogramAverage { Texture = HistogramAverageTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT; };

float ValueToBin(float v) {
    return saturate((v - _MinEV100) * (1 / _DiffEV100)) * float(XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS);
}

groupshared uint HistogramShared[XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS];
void Xaymar_HistogramGenerateTiles(uint groupIndex : SV_GROUPINDEX, uint3 threadId : SV_DISPATCHTHREADID, uint3 groupThreadId : SV_GROUPTHREADID) {
    HistogramShared[groupIndex] = 0;

    barrier();

    if ((threadId.x < XAYMAR_AUTOEXPOSURE_WIDTH) && (threadId.y < XAYMAR_AUTOEXPOSURE_HEIGHT)) {
        float l = tex2Dfetch(Downsample, threadId.xy).r;
        float ev = Xaymar::Color::ComputeEV100FromLuminance(l);
        uint bin = (uint)ValueToBin(ev);
        atomicAdd(HistogramShared[bin], 1);
    }

    barrier();

    uint dispatchIndex = threadId.x / 16 + (threadId.y / 16) * XAYMAR_AUTOEXPOSURE_HISTOGRAM_X;
    uint threadIndex = groupThreadId.x + groupThreadId.y * 16;
    tex2Dstore(HistogramTileBuffer, uint2(dispatchIndex, threadIndex), HistogramShared[groupIndex]);
}

groupshared uint HistogramMergedBin;
void Xaymar_HistogramMergeTiles(uint groupIndex : SV_GROUPINDEX, uint3 threadId : SV_DISPATCHTHREADID, uint3 groupThreadId : SV_GROUPTHREADID) {
    float2 coord = float2(threadId.x * XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILE_STRIDE, threadId.y) + 0.5;

    if (all(groupThreadId.xy == 0)) {
        HistogramMergedBin = 0;
    }

    barrier();
    
    uint histValues = 0;
    [unroll]
    for (int i = 0; i < XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILE_STRIDE; ++i) {
        histValues += tex2Dfetch(HistogramTile, coord + float2(i, 0)).r;
    }
    atomicAdd(HistogramMergedBin, histValues);

    barrier();

    if (all(groupThreadId.xy == 0)) {
        tex2Dstore(HistogramBuffer, uint2(threadId.y, 0), HistogramMergedBin);
    }
}

groupshared float HistogramAvgShared[256];
void Xaymar_HistogramAverage(uint3 threadId : SV_DISPATCHTHREADID) {
    float countForThisBin = (float)tex2Dfetch(Histogram, threadId.xy).r;

    HistogramAvgShared[threadId.x] = countForThisBin * (float)threadId.x;

    barrier();

    [unroll]
    for (uint histogramSampleIndex = (256 >> 1); histogramSampleIndex > 0; histogramSampleIndex >>= 1) {
        if (threadId.x < histogramSampleIndex) {
            HistogramAvgShared[threadId.x] += HistogramAvgShared[threadId.x + histogramSampleIndex];
        }

        barrier();
    }

    if (threadId.x == 0) {
        float weightedLogAverage = (HistogramAvgShared[0] / max((float)(XAYMAR_AUTOEXPOSURE_WIDTH * XAYMAR_AUTOEXPOSURE_HEIGHT) - countForThisBin, 1.0f)) - 1.0f;
        float weightedAverageLuminance = exp2(((weightedLogAverage / 254.0f) * XAYMAR_AUTOEXPOSURE_HISTOGRAM_LOG_RANGE) + _MinLogLuminance);
        float luminanceLastFrame = tex2Dfetch(HistogramAverage, uint2(0, 0)).r;
        float adaptedLuminance = luminanceLastFrame + (weightedAverageLuminance - luminanceLastFrame) * (1 - exp(-_DeltaTime * _Tau));
        tex2Dstore(HistogramAverageBuffer, uint2(0, 0), adaptedLuminance);
    }
}

// -------------------------------------------------------------------------------- //
// Global + Local Exposure

float4 Xaymar_AutoExposure(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float4 color = tex2D(Xaymar::BackBuffer, texcoord);
    float lclLum = tex2D(Downsample, texcoord).r;
    float avgLum = tex2Dfetch(HistogramAverage, 0).r;
    float diff = lclLum - avgLum;
    
    /*color.rgb = Xaymar::ColorConversion::RGB_to_XYZ(color.rgb, RGB_YUV_2020);
    float luminanceScale = (78.0f / (_q * _S1)) * (_S2 / _K) * avgLum;
    color.r /= luminanceScale;
    color.rgb = Xaymar::ColorConversion::XYZ_to_RGB(color.rgb, YUV_RGB_2020);*/

    //color.rgb = Xaymar::Color::ComputeEV100FromLuminance(Xaymar::Color::Luminance(color));

    if (Debug >= 1) {
        float2 wh = float2(BUFFER_WIDTH / 2 - 64, 192);
        float2 xy = BUFFER_SCREEN_SIZE - float2(64, 64) - wh;
        float thickness = 5.;
        float2 xyt = xy - thickness;
        float2 wht = wh + (thickness * 2.);
        if (Xaymar::Shapes::Rectangle(pos.xy, xyt, wht, thickness)) {
            color.rgb = lerp(float3(0., .25, 1.), float3(1., .25, 0.), (pos.x - xyt.x) / wht.x);
        } else if (Xaymar::Shapes::Rectangle(pos.xy, xy, wh)) {
            color.rgb = lerp(color.rgb, float3(0.1, 0.1, 0.1), 0.9);

            float barW = wh.x / XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS;            
            float x = floor(((pos.x - xy.x) / wh.x) * XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS);
            if (x < XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS) {
                float y = tex2D(Histogram, float2(x / XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS, 0)).r;
                if (Xaymar::Shapes::Rectangle(pos.xy, xy + float2(x * barW, wh.y - y) + float2(2, 0) * BUFFER_PIXEL_SIZE, float2(barW, y) - float2(4, 0) * BUFFER_PIXEL_SIZE)) {
                    color.rgb = float3(x / XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS, y, x / XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS + y);
                }
            }

            //if (Xaymar::Shapes::Rectangle(pos.xy, xy + float2(wh.x * LumaToBin(avgLum) / 255., 0.), float2(1., wh.y))) {
                //color.rgb = float3(1., 0., 0.);
            //}
        }
    }

    return color;
}

technique Xaymar_AutoExposure <
    ui_label = "[Xaymar] Auto Exposure";
> {
    #ifndef XAYMAR_AUTOEXPOSURE_NONE
    pass {
        VertexShader = PostProcessVS;
        PixelShader = Xaymar_Downsample;
        RenderTarget = DownsampleTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
    }
    #endif

    pass {
        ComputeShader = Xaymar_HistogramGenerateTiles<16, 16>;
        DispatchSizeX = XAYMAR_AUTOEXPOSURE_HISTOGRAM_X;
        DispatchSizeY = XAYMAR_AUTOEXPOSURE_HISTOGRAM_Y;
    }

    pass {
        ComputeShader = Xaymar_HistogramMergeTiles<XAYMAR_DIVIDE_ROUND_UP(XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILES, XAYMAR_AUTOEXPOSURE_HISTOGRAM_TILE_STRIDE), 1>;
        DispatchSizeX = 1;
        DispatchSizeY = XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS;
    }

    pass {
        ComputeShader = Xaymar_HistogramAverage<XAYMAR_AUTOEXPOSURE_HISTOGRAM_BUCKETS, 1>;
        DispatchSizeX = 1;
        DispatchSizeY = 1;
    }

    pass {
        VertexShader = PostProcessVS;
        PixelShader = Xaymar_AutoExposure;
        RenderTarget = Xaymar::BackBufferTargetTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
    }
    FlipBackBufferPass
}
