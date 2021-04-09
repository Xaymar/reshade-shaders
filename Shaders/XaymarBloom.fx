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
> = 0.9;

#if DUALFILTERING_ENABLE_2PX == 1
uniform float pLayer1Strength <
	ui_category = "Layers";
	ui_type = "slider";
	ui_label = "Layer 1 Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;
#if DUALFILTERING_ENABLE_4PX == 1
uniform float pLayer2Strength <
	ui_category = "Layers";
	ui_type = "slider";
	ui_label = "Layer 2 Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;
#if DUALFILTERING_ENABLE_8PX == 1
uniform float pLayer3Strength <
	ui_category = "Layers";
	ui_type = "slider";
	ui_label = "Layer 3 Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;
#if DUALFILTERING_ENABLE_16PX == 1
uniform float pLayer4Strength <
	ui_category = "Layers";
	ui_type = "slider";
	ui_label = "Layer 4 Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;
#endif
#endif
#endif
#endif

#if DUALFILTERING_ENABLE_2PX == 1
#define DEBUG_BLUR2_RGB 1
#define DEBUG_BLUR2_YUV 2
#define DEBUG_BLUR2_WEIGHT 3
#if DUALFILTERING_ENABLE_4PX == 1
#define DEBUG_BLUR4_RGB 4
#define DEBUG_BLUR4_YUV 5
#define DEBUG_BLUR4_WEIGHT 6
#if DUALFILTERING_ENABLE_8PX == 1
#define DEBUG_BLUR8_RGB 7
#define DEBUG_BLUR8_YUV 8
#define DEBUG_BLUR8_WEIGHT 9
#if DUALFILTERING_ENABLE_16PX == 1
#define DEBUG_BLUR16_RGB 10
#define DEBUG_BLUR16_YUV 11
#define DEBUG_BLUR16_WEIGHT 12
#endif
#endif
#endif
#endif

uniform int pDebug <
	__UNIFORM_COMBO_INT1
	ui_items =
		"None\0"
#if DUALFILTERING_ENABLE_2PX == 1
		"Blur 2 RGB\0"
		"Blur 2 YUV\0"
		"Blur 2 Weight\0"
#if DUALFILTERING_ENABLE_4PX == 1
		"Blur 4 RGB\0"
		"Blur 4 YUV\0"
		"Blur 4 Weight\0"
#if DUALFILTERING_ENABLE_8PX == 1
		"Blur 8 RGB\0"
		"Blur 8 YUV\0"
		"Blur 8 Weight\0"
#if DUALFILTERING_ENABLE_16PX == 1
		"Blur 16 RGB\0"
		"Blur 16 YUV\0"
		"Blur 16 Weight\0"
#endif
#endif
#endif
#endif
		;
	ui_label = "Debug Output";
> = 0;

float realistic_brightness_curve(float v) {
	// Apply Threshold
	v = clamp(v - pThreshold, 0., 1.) / max(1. - pThreshold, .000001);

	// Create an inverse curve that is initially weak, but then picks up fast.
	v *= v;
	v *= v;

	return v;
}

float4 ApplyBloom(inout float4 rgba, out float4 yuva, inout float weight) {
	yuva = RGBAtoYUVAf(rgba, RGB_YUV_709);
	weight = realistic_brightness_curve(yuva.r) * weight;

	yuva.gb *= clamp(1. - weight * pDechromaStrength, 0., 1.);
	rgba = YUVAtoRGBAf(yuva, YUV_709_RGB);
	return rgba * weight * pStrength;
}

float4 Bloom(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float4 v = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));

#if DUALFILTERING_ENABLE_2PX == 1
	{
		float weight = pLayer1Strength;
		float4 rgba = Blur2(uv);
		float4 yuva;
		float4 final = ApplyBloom(rgba, yuva, weight);
		v += final;
		if (pDebug == DEBUG_BLUR2_RGB) {
			return final;
		} else if (pDebug == DEBUG_BLUR2_YUV) {
			return yuva;
		} else if (pDebug == DEBUG_BLUR2_WEIGHT) {
			return weight;
		}
	}
#endif
#if DUALFILTERING_ENABLE_4PX == 1
	{
		float weight = pLayer2Strength;
		float4 rgba = Blur4(uv);
		float4 yuva;
		float4 final = ApplyBloom(rgba, yuva, weight);
		v += final;
		if (pDebug == DEBUG_BLUR4_RGB) {
			return final;
		} else if (pDebug == DEBUG_BLUR4_YUV) {
			return yuva;
		} else if (pDebug == DEBUG_BLUR4_WEIGHT) {
			return weight;
		}
	}
#endif
#if DUALFILTERING_ENABLE_8PX == 1
	{
		float weight = pLayer3Strength;
		float4 rgba = Blur8(uv);
		float4 yuva;
		float4 final = ApplyBloom(rgba, yuva, weight);
		v += final;
		if (pDebug == DEBUG_BLUR8_RGB) {
			return final;
		} else if (pDebug == DEBUG_BLUR8_YUV) {
			return yuva;
		} else if (pDebug == DEBUG_BLUR8_WEIGHT) {
			return weight;
		}
	}
#endif
#if DUALFILTERING_ENABLE_16PX == 1
	{
		float weight = pLayer4Strength;
		float4 rgba = Blur16(uv);
		float4 yuva;
		float4 final = ApplyBloom(rgba, yuva, weight);
		v += final;
		if (pDebug == DEBUG_BLUR16_RGB) {
			return final;
		} else if (pDebug == DEBUG_BLUR16_YUV) {
			return yuva;
		} else if (pDebug == DEBUG_BLUR16_WEIGHT) {
			return weight;
		}
	}
#endif

	return dither(v, uv, 255.);
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
