// Copyright 2017 - 2023 Michael Fabian Dirks <info@xaymar.com>
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

// Professional Color Grading

#include "ReShade.fxh"
#include "Xmr_Common.fxh"

//----------------------------------------------------------------------------//
// Lift
float4 Lift(float4 v, float4 pLift) {
	v.rgb = pLift.aaa + v.rgb;
	v.rgb = pLift.rgb + v.rgb;
	return v;
}

//----------------------------------------------------------------------------//
// Gamma
float fix_gamma(float v) {
	if (v < 0.0) {
		return (-v + 1.0);
	} else {
		return (1.0 / (v + 1.0));
	}
}

float4 Gamma(float4 v, float4 pGamma) {
	float4 gam = float4(
		fix_gamma(pGamma.r),
		fix_gamma(pGamma.g),
		fix_gamma(pGamma.b),
		fix_gamma(pGamma.a));
	v.rgb = pow(pow(abs(v.rgb), gam.rgb), gam.aaa) * sign(v.rgb);
	return v;
}

//----------------------------------------------------------------------------//
// Gain
float4 Gain(float4 v, float4 pGain) {
	v.rgb *= pGain.rgb;
	v.rgb *= pGain.a;
	return v;
}

//----------------------------------------------------------------------------//
// Offset
float4 Offset(float4 v, float4 pOffset) {
	v.rgb = pOffset.aaa + v.rgb;
	v.rgb = pOffset.rgb + v.rgb;
	return v;
}

//----------------------------------------------------------------------------//
// Tint
#define TINT_VALUE_LINEAR 0
#define TINT_VALUE_EXP 1
#define TINT_VALUE_EXP2 2
#define TINT_VALUE_LOG 3
#define TINT_VALUE_LOG10 4

float4 Tint(float4 v, float4 pTintLow, float4 pTintMid, float4 pTintHig, int pTintValueMode, float pTintValueExp2Density) {
	float value = Xaymar::Color::Luminance(v.rgb);
	float4 tint = float4(0,0,0,1);

	if (pTintValueMode == TINT_VALUE_LINEAR) {
	} else if (pTintValueMode == TINT_VALUE_EXP) {
		value = 1.0 - exp2(value * pTintValueExp2Density * -XAYMAR_LOG2_E);
	} else if (pTintValueMode == TINT_VALUE_EXP2) {
		value = 1.0 - exp2(value * value * pTintValueExp2Density * pTintValueExp2Density * -XAYMAR_LOG2_E);
	} else if (pTintValueMode == TINT_VALUE_LOG) {
		value = (log2(value) + 2.) / 2.333333;
	} else if (pTintValueMode == TINT_VALUE_LOG10) {
		value = (log10(value) + 1.) / 2.;
	}
	value = clamp(value, 0.0, 1.0);

	if (value > 0.5) {
		tint = lerp(pTintMid, pTintHig, value * 2.0 - 1.0);
	} else {
		tint = lerp(pTintLow, pTintMid, value * 2.0);
	}
	v.rgb *= tint.rgb;
	v.rgb *= tint.aaa;
	return v;
}

//----------------------------------------------------------------------------//
// Correction
float4 Contrast(float4 v, float4 pContrast) {
	//v.rgb -= float3(.5, 0, 0);
	//v.rgb *= max(pYUVContrast.rgb, 0);
	//v.rgb *= max(pYUVContrast.a, 0);
	//v.rgb += float3(.5, 0, 0);
	v.r = ((v.r - 0.5) * max(pContrast.r, 0)) + 0.5;
	v.g = ((v.g - 0.5) * max(pContrast.g, 0)) + 0.5;
	v.b = ((v.b - 0.5) * max(pContrast.b, 0)) + 0.5;
	v.rgb = ((v.rgb - 0.5) * max(pContrast.a, 0)) + 0.5;
	return v;
}

//----------------------------------------------------------------------------//
// YUV Correction
float4 YUVCorrection(float4 v, float3x3 From, float3x3 To, float4 pGain, float pChromaRotation, float3 pChromaGain, float4 pGamma, float4 pContrast) {
	v = Xaymar::ColorConversion::XYZA_to_RGBAf(v, From);
	
	// Gain
	v = Gain(v, pGain);

	// UV Rotation (Could be considered Hue)
	v.gb = Xaymar::Math::Vector2D::Rotate(v.gb, XAYMAR_DEG_TO_RAD(pChromaRotation));
	// ToDo: This rotates a square, but we need to rotate a circle, then convert back into a square.

	// UV Multiplier (Could be considered Saturation)
	v.gb *= pChromaGain.rg;
	v.gb *= pChromaGain.b;

	// YUV Gamma
	v = Gamma(v, pGamma);

	// YUV Contrast
	v = Contrast(v, pContrast);

	return Xaymar::ColorConversion::RGBA_to_XYZAf(v, To);
}

//----------------------------------------------------------------------------//
// Default Functionality
uniform float4 pLift <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Lift";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGamma <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Gamma";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGain <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Gain";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pOffset <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Offset";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pContrast <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Contrast";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 pTintLow <
	ui_category = "Tint";
	ui_type = "slider";
	ui_label = "Shadows Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pTintMid <
	ui_category = "Tint";
	ui_type = "slider";
	ui_label = "Midtone Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pTintHig <
	ui_category = "Tint";
	ui_type = "slider";
	ui_label = "Highlight Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform int pTintValueMode <
	ui_category = "Tint";
	ui_type = "combo";
	ui_label = "Tint Value Mode";
	ui_items = "LINEAR=0\0EXP=1\0EXP2=2\0LOG=3\0LOG10=4\0";
	ui_tooltip = "";
> = 0;
uniform float pTintValueExp2Density <
	ui_category = "Tint";
	ui_type = "slider";
	ui_label = "Tint Value Exp Density";
	ui_min = 0.;
	ui_max = 10.;
> = 1.;

uniform float4 pYUV709Gain <
	ui_category = "YUV709";
	ui_type = "slider";
	ui_label = "Gain (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);
uniform float pYUV709ChromaRotation <
	ui_category = "YUV709";
	ui_type = "slider";
	ui_label = "UV Rotation";
	ui_min = -180.0; ui_max = 180.0;
	ui_step = 0.001;
> = 0.0;
uniform float3 pYUV709ChromaGain <
	ui_category = "YUV709";
	ui_type = "slider";
	ui_label = "UV Post-Gain (U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1.0, 1.0, 1.0);
uniform float4 pYUV709Gamma <
	ui_category = "YUV709";
	ui_type = "slider";
	ui_label = "Gamma (Y, U, V, All)";
	ui_min = -1.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pYUV709Contrast <
	ui_category = "YUV709";
	ui_type = "slider";
	ui_label = "Contrast (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 pYUV2020Gain <
	ui_category = "YUV2020";
	ui_type = "slider";
	ui_label = "Gain (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);
uniform float pYUV2020ChromaRotation <
	ui_category = "YUV2020";
	ui_type = "slider";
	ui_label = "UV Rotation";
	ui_min = -180.0; ui_max = 180.0;
	ui_step = 0.001;
> = 0.0;
uniform float3 pYUV2020ChromaGain <
	ui_category = "YUV2020";
	ui_type = "slider";
	ui_label = "UV Post-Gain (U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1.0, 1.0, 1.0);
uniform float4 pYUV2020Gamma <
	ui_category = "YUV2020";
	ui_type = "slider";
	ui_label = "Gamma (Y, U, V, All)";
	ui_min = -1.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pYUV2020Contrast <
	ui_category = "YUV2020";
	ui_type = "slider";
	ui_label = "Contrast (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float2 pWhiteBalance <
	ui_category = "White Balance";
	ui_type = "slider";
	ui_label = "Whitebalance (Temp, Tint)";
	ui_min = -1.0; ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.0, 0.0);

float4 Grade(float4 v) {
	v = Lift(v, pLift);
	v = Gamma(v, pGamma);
	v = Gain(v, pGain);
	v = Offset(v, pOffset); 
	v = Contrast(v, pContrast);
	v = Tint(v, pTintLow, pTintMid, pTintHig, pTintValueMode, pTintValueExp2Density);
	v = YUVCorrection(v, XAYMAR_RGB_YUV_709, XAYMAR_YUV_709_RGB, pYUV709Gain, pYUV709ChromaRotation, pYUV709ChromaGain, pYUV709Gamma, pYUV709Contrast);
	v = YUVCorrection(v, XAYMAR_RGB_YUV_2020, XAYMAR_YUV_2020_RGB, pYUV2020Gain, pYUV2020ChromaRotation, pYUV2020ChromaGain, pYUV2020Gamma, pYUV2020Contrast);
	v = Xaymar::Color::WhiteBalance(v, pWhiteBalance.r , pWhiteBalance.g);

	return v;
}

float4 PS_ColorGrade(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 output = tex2D(Xaymar::BackBuffer, float4(texcoord, 0, 0));
	output = Grade(output);
    return Xaymar::Dither::DitherIGN(output, XAYMAR_COLOR_VALUES, pos);
}

technique Xaymar_ColorGrade <
    ui_label = "[Xaymar] Color Grading";
>{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_ColorGrade;
        RenderTarget = Xaymar::BackBufferTargetTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
    }
    FlipBackBufferPass
}
