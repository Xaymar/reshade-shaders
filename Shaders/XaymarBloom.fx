// Copyright 2017 - 2021 Michael Fabian Dirks <info@xaymar.com>
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

// Approximation of physical bloom.
// - Dual Filtering to quickly approximate blur.
// - YUV Luma based Bloom.

#include "ReShade.fxh"
#include "ReShadeUI.fxh"
#include "Math.fxh"
#include "Dither.fxh"
#include "ConvertRGBYUV.fxh"
#include "DualFiltering.fxh"

//----------------------------------------------------------------------------//
// Bloom

uniform float pStrength <
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;
uniform float pDechromaStrength <
	ui_type = "slider";
	ui_label = "De-Chroma Strength";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pThreshold <
	ui_type = "slider";
	ui_label = "Threshold";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.8;

#define DEBUG_BLUR2_COLOR 1
#define DEBUG_BLUR2_WEIGHT 2
#define DEBUG_BLUR4_COLOR 3
#define DEBUG_BLUR4_WEIGHT 4
#define DEBUG_BLUR8_COLOR 5
#define DEBUG_BLUR8_WEIGHT 6
uniform int pDebug <
	__UNIFORM_COMBO_INT1
	ui_items =
		"None=0\0"
		"Blur 2 Color=1\0"
		"Blur 2 Weight=2\0"
		"Blur 4 Color=3\0"
		"Blur 4 Weight=4\0"
		"Blur 8 Color=5\0"
		"Blur 8 Weight=6\0";
	ui_label = "Debug Output";
> = 0;


float realistic_brightness_curve(float v) {
	// Apply Threshold
	v = clamp(v - pThreshold, 0., 1.) / max(1. - pThreshold, .000001);

	// Create an inverse curve that is initially weak, but then picks up fast.
	v = v * v * v; // Add any number of * v here, it strengthens the curve.
/* Generate a weird sine approximation, not exactly what we want.
	float v0 = 1. - v;
	float v1 = 1. - (v0 * v0);
	float v2 = v1 * v1;
*/
	return v;
}

float4 Bloom(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float4 b1 = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));

	float4 b2 = Blur2(uv);
	float4 b4 = Blur4(uv);
	float4 b8 = Blur8(uv);

	float4 b2yuv = RGBAtoYUVAf(b2, RGB_YUV_709);
	float4 b4yuv = RGBAtoYUVAf(b4, RGB_YUV_709);
	float4 b8yuv = RGBAtoYUVAf(b8, RGB_YUV_709);

	float b2weight = realistic_brightness_curve(b2yuv.r);
	float b4weight = realistic_brightness_curve(b4yuv.r);
	float b8weight = realistic_brightness_curve(b8yuv.r);

	b2yuv.gb *= clamp(1. - b2weight * pDechromaStrength, 0., 1.);
	b2 = YUVAtoRGBAf(b2yuv, YUV_709_RGB);
	b2 *= b2weight * pStrength;
	if (pDebug == DEBUG_BLUR2_COLOR) {
		return b2;
	} else if (pDebug == DEBUG_BLUR2_WEIGHT) {
		return b2weight;
	}

	b4yuv.gb *= clamp(1. - b4weight * pDechromaStrength, 0., 1.);
	b4 = YUVAtoRGBAf(b4yuv, YUV_709_RGB);
	b4 *= b4weight * pStrength;
	if (pDebug == DEBUG_BLUR4_COLOR) {
		return b4;
	} else if (pDebug == DEBUG_BLUR4_WEIGHT) {
		return b4weight;
	}

	b8yuv.gb *= clamp(1. - b8weight * pDechromaStrength, 0., 1.);
	b8 = YUVAtoRGBAf(b8yuv, YUV_709_RGB);
	b8 *= b8weight * pStrength;
	if (pDebug == DEBUG_BLUR8_COLOR) {
		return b8;
	} else if (pDebug == DEBUG_BLUR8_WEIGHT) {
		return b8weight;
	}

	return dither(b1 + b2 + b4 + b8, uv, 255.);
}


//------------------------------------------------------------------------------
// Technique: Light Bloom
//------------------------------------------------------------------------------
/*float4 PSLightBloom(DefaultVertexData vtx) : TARGET {
	// Bloom blending is not that simple.
	float4 vo = SampleLayer(0, vtx.uv);
	float4 v = vo;
	for (uint i = 1; i < uint(Layers); i++) {
		float4 vl = SampleLayer(i, vtx.uv);
		float4 vl_hsv = RGBtoHSV(vl);

		float luminosity = realistic_brightness_curve(vl_hsv.z);
		vl_hsv.y *= (1. - luminosity);
		float4 vl_fin = HSVtoRGB(vl_hsv);

		v += vl_fin;
	}

	if (PreserveAlpha) {
		return float4(v.xyz, vo.a);
	} else {
		return v;
	}
}*/

//----------------------------------------------------------------------------//
// Technique
technique PAABloom <
	ui_label = "Realistic Bloom (by Xaymar)";
	ui_tooltip = "Tries to approximate 'real world' Bloom through fast methods.";
> {
	pass Bloom {
        VertexShader = PostProcessVS;
        PixelShader = Bloom;
	}
}
