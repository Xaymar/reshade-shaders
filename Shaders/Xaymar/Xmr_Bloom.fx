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

#include "ReShade.fxh"
#include "Xmr_Common.fxh"

//----------------------------------------------------------------------------//
// Bloom

#ifndef XAYMAR_BLOOM_RESOLUTION
#define XAYMAR_BLOOM_RESOLUTION 1
#endif

uniform float pThreshold <
	ui_category = "Threshold";
	ui_type = "slider";
	ui_label = "Threshold";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pThresholdRange <
	ui_category = "Threshold";
	ui_type = "slider";
	ui_label = "Threshold Range";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float pDesaturate <
	ui_category = "Threshold";
	ui_type = "slider";
	ui_label = "Desaturate";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float pStrength <
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float pSmallStrength <
	ui_category = "Small Bloom";
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float4 pSmallGain <
	ui_category = "Small Bloom";
	ui_type = "slider";
	ui_label = "Gain (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);
uniform float3 pSmallTint <
	ui_category = "Small Bloom";
	ui_type = "slider";
	ui_label = "Tint (R, G, B)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1.0, 1.0, 1.0);

uniform float pMediumStrength <
	ui_category = "Medium Bloom";
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float4 pMediumGain <
	ui_category = "Medium Bloom";
	ui_type = "slider";
	ui_label = "Gain (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);
uniform float3 pMediumTint <
	ui_category = "Medium Bloom";
	ui_type = "slider";
	ui_label = "Tint (R, G, B)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1.0, 1.0, 1.0);

uniform float pLargeStrength <
	ui_category = "Large Bloom";
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;
uniform float4 pLargeGain <
	ui_category = "Large Bloom";
	ui_type = "slider";
	ui_label = "Gain (Y, U, V, All)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float4(1.0, 1.0, 1.0, 1.0);
uniform float3 pLargeTint <
	ui_category = "Large Bloom";
	ui_type = "slider";
	ui_label = "Tint (R, G, B)";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = float3(1.0, 1.0, 1.0);

#define DEBUG_NONE 0
#define DEBUG_THRESHOLD 1
#define DEBUG_SMALL_BLUR 2
#define DEBUG_MEDIUM_BLUR 3
#define DEBUG_LARGE_BLUR 4
#define DEBUG_COMBINED 5
uniform uint pDebug <
	ui_category = "Debug";
	ui_type = "combo";
	ui_label = "Debug";
	ui_items = "None\0"
		"Threshold\0"
		"Small Blur\0"
		"Medium Blur\0"
		"Large Blur\0"
		"Combined Blur\0";
	ui_tooltip = "";
> = 2;

#if XAYMAR_BLOOM_RESOLUTION == 0
#define _WHDIV 1
#define _HMUL 2
#define _QMUL 4
#define _EMUL 8
#elif XAYMAR_BLOOM_RESOLUTION == 1
#define _WHDIV 2
#define _HMUL 4
#define _QMUL 8
#define _EMUL 16
#elif XAYMAR_BLOOM_RESOLUTION == 2
#define _WHDIV 4
#define _HMUL 8
#define _QMUL 16
#define _EMUL 32
#else
#define _WHDIV 8
#define _HMUL 16
#define _QMUL 32
#define _EMUL 64
#endif

texture2D BloomThresholdTex <
	pooled = false;
> {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
} ;
sampler2D BloomThreshold {
	Texture = BloomThresholdTex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D Bloom2Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / _WHDIV;
	Height = BUFFER_HEIGHT / _WHDIV;
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
} ;
sampler2D Bloom2 {
	Texture = Bloom2Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D Bloom4Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / _WHDIV;
	Height = BUFFER_HEIGHT / _WHDIV;
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
} ;
sampler2D Bloom4 {
	Texture = Bloom4Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D Bloom8Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / _WHDIV;
	Height = BUFFER_HEIGHT / _WHDIV;
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
};
sampler2D Bloom8 {
	Texture = Bloom8Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D BloomDown2Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / (_WHDIV + 2);
	Height = BUFFER_HEIGHT / (_WHDIV + 2);
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
};
sampler2D BloomDown2 {
	Texture = BloomDown2Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D BloomDown4Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / (_WHDIV + 4);
	Height = BUFFER_HEIGHT / (_WHDIV + 4);
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
};
sampler2D BloomDown4 {
	Texture = BloomDown4Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D BloomDown8Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / (_WHDIV + 8);
	Height = BUFFER_HEIGHT / (_WHDIV + 8);
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
} ;
sampler2D BloomDown8 {
	Texture = BloomDown8Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D BloomUp4Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / (_WHDIV + 4);
	Height = BUFFER_HEIGHT / (_WHDIV + 4);
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
};
sampler2D BloomUp4 {
	Texture = BloomUp4Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D BloomUp2Tex <
	pooled = false;
> {
	Width = BUFFER_WIDTH / (_WHDIV + 2);
	Height = BUFFER_HEIGHT / (_WHDIV + 2);
	MipLevels = 1;
	Format = XAYMAR_COLOR_FORMAT;
} ;
sampler2D BloomUp2 {
	Texture = BloomUp2Tex;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

float4 DualFilteringDown(sampler2D tex, float2 uv, float2 halfTexel) {
	float4 pxCC = tex2D(tex, uv) * 4.0;
	float4 pxTL = tex2D(tex, uv - halfTexel);
	float4 pxTR = tex2D(tex, uv + halfTexel);
	float4 pxBL = tex2D(tex, uv + float2(halfTexel.x, -halfTexel.y));
	float4 pxBR = tex2D(tex, uv - float2(halfTexel.x, -halfTexel.y));
	return (pxCC + pxTL + pxTR + pxBL + pxBR) / 8.0;
}

float4 DualFilteringUp(sampler2D tex, float2 uv, float2 halfTexel) {
	float4 pxL = tex2D(tex, uv - float2(halfTexel.x * 2., 0));
	float4 pxR = tex2D(tex, uv + float2(halfTexel.x * 2., 0));

	float4 pxT = tex2D(tex, uv - float2(0, halfTexel.y * 2.));
	float4 pxB = tex2D(tex, uv + float2(0, halfTexel.y * 2.));

	float4 pxTR = tex2D(tex, uv + float2(halfTexel.x, -halfTexel.y));
	float4 pxBL = tex2D(tex, uv - float2(halfTexel.x, -halfTexel.y));

	float4 pxTL = tex2D(tex, uv - halfTexel);
	float4 pxBR = tex2D(tex, uv + halfTexel);

	float4 v0 = (pxTL + pxTR + pxBL + pxBR) * 2.;
	float4 v1 = (pxL + pxR + pxT + pxB);
	return (v0 + v1) / 12.;
}

float4 PS_Threshold(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float4 color = tex2D(Xaymar::BackBuffer, uv);
	float luminance = Xaymar::Color::Luminance(color.rgb);

	luminance -= pThreshold;
	luminance /= pThresholdRange;
	luminance = saturate(luminance);

	color = Xaymar::ColorConversion::RGBA_to_XYZAf(color, XAYMAR_RGB_YUV_2020);
	color.gb *= 1. - (luminance * pDesaturate);
	color = Xaymar::ColorConversion::XYZA_to_RGBAf(color, XAYMAR_YUV_2020_RGB);
	color.rgb *= luminance;

	return color;
}

// 2px
float4 PS_Bloom2_Down2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Full -> Half
	return DualFilteringDown(BloomThreshold, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT));
}

float4 PS_Bloom2_Up2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Half -> Full
	return DualFilteringUp(BloomDown2, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT));
}

// 4px
float4 PS_Bloom4_Down4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Half -> Quarter
	return DualFilteringDown(BloomDown2, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * _HMUL);
}

float4 PS_Bloom4_Up4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Quarter -> Half
	return DualFilteringUp(BloomDown4, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * _HMUL);
}

float4 PS_Bloom4_Up2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Half -> Full
	return DualFilteringUp(BloomUp2, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT));
}

// 8px
float4 PS_Bloom8_Down8(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Quarter -> Eigth
	return DualFilteringDown(BloomDown4, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * _QMUL);
}

float4 PS_Bloom8_Up8(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Eigth -> Quarter
	return DualFilteringUp(BloomDown8, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * _QMUL);
}

float4 PS_Bloom8_Up4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Quarter -> Half
	return DualFilteringUp(BloomUp4, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * _HMUL);
}

float4 PS_Bloom8_Up2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	// Half -> Full
	return DualFilteringUp(BloomUp2, uv, float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT));
}

float4 PS_Merge(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {	
	float4 color = tex2D(Xaymar::BackBuffer, uv);

	// Small Bloom
	float4 small = tex2D(Bloom2, uv);
	small.rgb *= pSmallStrength;
	small = Xaymar::ColorConversion::RGBA_to_XYZAf(small, XAYMAR_RGB_YUV_2020);
	small.rgb *= pSmallGain.rgb;
	small.rgb *= pSmallGain.aaa;
	small = Xaymar::ColorConversion::XYZA_to_RGBAf(small, XAYMAR_YUV_2020_RGB);
	small.rgb *= pSmallTint.rgb;

	// Medium Bloom
	float4 medium = tex2D(Bloom4, uv);
	medium.rgb *= pMediumStrength;
	medium = Xaymar::ColorConversion::RGBA_to_XYZAf(medium, XAYMAR_RGB_YUV_2020);
	medium.rgb *= pMediumGain.rgb;
	medium.rgb *= pMediumGain.aaa;
	medium = Xaymar::ColorConversion::XYZA_to_RGBAf(medium, XAYMAR_YUV_2020_RGB);
	medium.rgb *= pMediumTint.rgb;

	// Large Bloom
	float4 large = tex2D(Bloom8, uv);
	large.rgb *= pLargeStrength;
	large = Xaymar::ColorConversion::RGBA_to_XYZAf(large, XAYMAR_RGB_YUV_2020);
	large.rgb *= pLargeGain.rgb;
	large.rgb *= pLargeGain.aaa;
	large = Xaymar::ColorConversion::XYZA_to_RGBAf(large, XAYMAR_YUV_2020_RGB);
	large.rgb *= pLargeTint.rgb;

	// Combine the three
	float4 combined = small + medium + large;
	combined *= pStrength;

	// Combine with color
	color += combined;

	if (pDebug == DEBUG_THRESHOLD) {
		return tex2D(BloomThreshold, uv);
	} else if (pDebug == DEBUG_SMALL_BLUR) {
		return small;
	} else if (pDebug == DEBUG_MEDIUM_BLUR) {
		return medium;
	} else if (pDebug == DEBUG_LARGE_BLUR) {
		return large;
	} else if (pDebug == DEBUG_COMBINED) {
		return combined;
	} else {
		return color;
	}	
}

technique Xaymar_Bloom <
	ui_label = "[Xaymar] Bloom";
> {
	pass Threshold { // Threshold
        VertexShader = PostProcessVS;
        PixelShader = PS_Threshold;
        RenderTarget = BloomThresholdTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}

	pass Down2 { // Full -> Half
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom2_Down2;
        RenderTarget = BloomDown2Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up2 { // Half -> Full
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom2_Up2;
        RenderTarget = Bloom2Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}

	pass Down4 { // Half -> Quarter
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom4_Down4;
        RenderTarget = BloomDown4Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up4 { // Quarter -> Half
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom4_Up4;
        RenderTarget = BloomUp2Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up2 { // Half -> Full
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom4_Up2;
        RenderTarget = Bloom4Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}

	pass Down4 { // Quarter -> Eigth
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom8_Down8;
        RenderTarget = BloomDown8Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up8 { // Eigth -> Quarter
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom8_Up8;
        RenderTarget = BloomUp4Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up4 { // Quarter -> Half
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom8_Up4;
        RenderTarget = BloomUp2Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
	pass Up2 { // Half -> Full
        VertexShader = PostProcessVS;
        PixelShader = PS_Bloom8_Up2;
        RenderTarget = Bloom8Tex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}

	pass Merge {
        VertexShader = PostProcessVS;
        PixelShader = PS_Merge;
        RenderTarget = Xaymar::BackBufferTargetTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
    FlipBackBufferPass
}
