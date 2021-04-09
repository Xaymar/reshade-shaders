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

// Professional Color Grading

#include "ReShade.fxh"
#include "Math.fxh"
#include "Dither.fxh"
#include "ConvertRGBYUV.fxh"
#include "ConvertRGBHSV.fxh"

#define TINT_VALUE_LINEAR 0
#define TINT_VALUE_EXP 1
#define TINT_VALUE_EXP2 2
#define TINT_VALUE_LOG 3
#define TINT_VALUE_LOG10 4

uniform float4 pLift <
	ui_category = "Grading";
	ui_type = "drag";
	ui_label = "Lift";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGamma <
	ui_category = "Grading";
	ui_type = "drag";
	ui_label = "Gamma";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGain <
	ui_category = "Grading";
	ui_type = "drag";
	ui_label = "Gain";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pOffset <
	ui_category = "Grading";
	ui_type = "drag";
	ui_label = "Offset";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pTintLow <
	ui_category = "Tint";
	ui_type = "drag";
	ui_label = "Shadows Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pTintMid <
	ui_category = "Tint";
	ui_type = "drag";
	ui_label = "Midtone Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pTintHig <
	ui_category = "Tint";
	ui_type = "drag";
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
	ui_type = "drag";
	ui_label = "Tint Value Exp Density";
	ui_min = 0.;
	ui_max = 10.;
> = 1.;

uniform float pHSVHue <
	ui_category = "HSV Correction";
	ui_type = "slider";
	ui_label = "Hue Shift";
	ui_min = -180.0; ui_max = 180.0;
	ui_step = 0.001;
> = 0.0;
uniform float pHSVSat <
	ui_category = "HSV Correction";
	ui_type = "slider";
	ui_label = "Saturation";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pHSVVal <
	ui_category = "HSV Correction";
	ui_type = "slider";
	ui_label = "Lightness";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float pYUVLuma <
	ui_category = "YUV Correction";
	ui_type = "slider";
	ui_label = "Luminosity";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pYUVChromaRotation <
	ui_category = "YUV Correction";
	ui_type = "slider";
	ui_label = "Rotate Chroma";
	ui_min = -180.0; ui_max = 180.0;
	ui_step = 0.001;
> = 0.0;
uniform float pYUVChromaMultiplier <
	ui_category = "YUV Correction";
	ui_type = "slider";
	ui_label = "Multply Chroma";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float pContrast <
	ui_category = "Correction";
	ui_type = "slider";
	ui_label = "Contrast";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform bool _dither <
    ui_label = "Dither";
> = false;

float get_corrected_gamma(float v) {
	if (v < 0.0) {
		return (-v + 1.0);
	} else {
		return (1.0 / (v + 1.0));
	}
}

float4 Lift(float4 v) {
	v.rgb = pLift.aaa + v.rgb;
	v.rgb = pLift.rgb + v.rgb;
	return v;
}

float4 Gamma(float4 v) {
	float4 gam = float4(
		get_corrected_gamma(pGamma.r),
		get_corrected_gamma(pGamma.g),
		get_corrected_gamma(pGamma.b),
		get_corrected_gamma(pGamma.a));
	v.rgb = pow(pow(v.rgb, gam.rgb), gam.aaa);
	return v;
}

float4 Gain(float4 v) {
	v.rgb *= pGain.rgb;
	v.rgb *= pGain.a;
	return v;
}

float4 Offset(float4 v) {
	v.rgb = pOffset.aaa + v.rgb;
	v.rgb = pOffset.rgb + v.rgb;
	return v;
}

float4 Tint(float4 v) {
	float value = RGBtoHSV(v).z;
	float4 tint = float4(0,0,0,1);

	if (pTintValueMode == TINT_VALUE_LINEAR) {
	} else if (pTintValueMode == TINT_VALUE_EXP) {
		value = 1.0 - exp2(value * pTintValueExp2Density * -_LOG2_E);
	} else if (pTintValueMode == TINT_VALUE_EXP2) {
		value = 1.0 - exp2(value * value * pTintValueExp2Density * pTintValueExp2Density * -_LOG2_E);
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

float4 HSVCorrection(float4 v) {
	float4 v1 = RGBtoHSV(v);
	v1.r += pHSVHue / 360.0;
	v1.g *= pHSVSat;
	v1.b *= pHSVVal;
	return HSVtoRGB(v1);
}

float4 YUVCorrection(float4 v) {
	v = YUVAtoRGBAf(v, RGB_YUV_709);
	v.r *= pYUVLuma;
	v.gb = rotate2D(v.gb, _DEG_TO_RAD(pYUVChromaRotation));
	v.gb *= pYUVChromaMultiplier;
	return RGBAtoYUVAf(v, YUV_709_RGB);
}

float4 Correction(float4 v) {
	v.rgb = ((v.rgb - 0.5) * max(pContrast, 0)) + 0.5;
	return v;
}

float4 PS_ColorGrade(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 v = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
	v = Lift(v);
	v = Gamma(v);
	v = Gain(v);
	v = Offset(v);
	v = Tint(v);
	v = HSVCorrection(v);
	v = YUVCorrection(v);
	v = Correction(v);

	if (_dither) {
		return dither(v, texcoord, 255);
	} else {
		return v;
	}
}

technique ColorGrade {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_ColorGrade;
    }
}
