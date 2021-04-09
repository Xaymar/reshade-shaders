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
#include "dither.fxh"

#define TINT_VALUE_LINEAR 0
#define TINT_VALUE_EXP 1
#define TINT_VALUE_EXP2 2
#define TINT_VALUE_LOG 3
#define TINT_VALUE_LOG10 4

#define C_e 2,7182818284590452353602874713527
#define C_log2_e 1.4426950408889634073599246810019 // Windows calculator: log(e(1)) / log(2)

uniform float4 pLift <
	ui_type = "drag";
	ui_label = "Lift";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGamma <
	ui_type = "drag";
	ui_label = "Gamma";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform float4 pGain <
	ui_type = "drag";
	ui_label = "Gain";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1., 1., 1., 1.);
uniform float4 pOffset <
	ui_type = "drag";
	ui_label = "Offset";
	ui_min = -10.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(0., 0., 0., 0.);
uniform int pTintValueMode <
	ui_type = "combo";
	ui_label = "Tint Value Mode";
	ui_items = "LINEAR=0\0EXP=1\0EXP2=2\0LOG=3\0LOG10=4\0";
	ui_tooltip = "";
> = 0;
uniform float pTintValueExp2Density <
	ui_type = "drag";
	ui_label = "Tint Value Exp Density";
	ui_min = 0.;
	ui_max = 10.;
> = 1.;
uniform float3 pTintLow <
	ui_type = "drag";
	ui_label = "Shadows Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1., 1., 1.);
uniform float3 pTintMid <
	ui_type = "drag";
	ui_label = "Midtone Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1., 1., 1.);
uniform float3 pTintHig <
	ui_type = "drag";
	ui_label = "Highlight Tint";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1., 1., 1.);
uniform float pHue <
	ui_type = "slider";
	ui_label = "Hue Shift";
	ui_min = -180.0; ui_max = 180.0;
	ui_step = 0.001;
> = 0.0;
uniform float pSaturation <
	ui_type = "slider";
	ui_label = "Saturation";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pLightness <
	ui_type = "slider";
	ui_label = "Lightness";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pContrast <
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

float4 Lift(float4 v)
{
	v.rgb = pLift.aaa + v.rgb;
	v.rgb = pLift.rgb + v.rgb;
	return v;
}

float4 Gamma(float4 v)
{
	float4 gam = float4(
		get_corrected_gamma(pGamma.r),
		get_corrected_gamma(pGamma.g),
		get_corrected_gamma(pGamma.b),
		get_corrected_gamma(pGamma.a));
	v.rgb = pow(pow(v.rgb, gam.rgb), gam.aaa);
	return v;
}

float4 Gain(float4 v)
{
	v.rgb *= pGain.rgb;
	v.rgb *= pGain.a;
	return v;
}

float4 Offset(float4 v)
{
	v.rgb = pOffset.aaa + v.rgb;
	v.rgb = pOffset.rgb + v.rgb;
	return v;
}

float4 RGBtoHSV(float4 RGBA) {
	const float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	const float e = 1.0e-10;
	float4 p = lerp(float4(RGBA.bg, K.wz), float4(RGBA.gb, K.xy), step(RGBA.b, RGBA.g));
	float4 q = lerp(float4(p.xyw, RGBA.r), float4(RGBA.r, p.yzx), step(p.x, RGBA.r));
	float d = q.x - min(q.w, q.y);
	return float4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, RGBA.a);
}

float4 HSVtoRGB(float4 HSVA) {
	const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float4 v = float4(0,0,0,0);
	v.rgb = HSVA.z * lerp(K.xxx, clamp(abs(frac(HSVA.xxx + K.xyz) * 6.0 - K.www) - K.xxx, 0.0, 1.0), HSVA.y);
	v.a = HSVA.a;
	return v;
}

float4 Tint(float4 v)
{
	float value = RGBtoHSV(v).z;
	float3 tint = float3(0,0,0);

	if (pTintValueMode == TINT_VALUE_LINEAR) {
	} else if (pTintValueMode == TINT_VALUE_EXP) {
		value = 1.0 - exp2(value * pTintValueExp2Density * -C_log2_e);
	} else if (pTintValueMode == TINT_VALUE_EXP2) {
		value = 1.0 - exp2(value * value * pTintValueExp2Density * pTintValueExp2Density * -C_log2_e);
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
	v.rgb *= tint;
	return v;
}

float4 Correction(float4 v)
{
	float4 v1 = RGBtoHSV(v);
	v1.r += pHue / 360.0;
	v1.g *= pSaturation;
	v1.b *= pLightness;
	float4 v2 = HSVtoRGB(v1);
	v2.rgb = ((v2.rgb - 0.5) * max(pContrast, 0)) + 0.5;
	return v2;
}

float4 PS_ColorGrade(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 v = Correction(Tint(Offset(Gain(Gamma(Lift(tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0))))))));
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
