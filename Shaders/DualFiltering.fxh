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

// Dual Filtering Blur for advanced effects.

texture2D tBlurDownUp2 <
	pooled = true;
> {
	Width = BUFFER_WIDTH / 2;
	Height = BUFFER_HEIGHT / 2;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlurDownUp2 {
	Texture = tBlurDownUp2;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D tBlurDownUp4 <
	pooled = true;
> {
	Width = BUFFER_WIDTH / 4;
	Height = BUFFER_HEIGHT / 4;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlurDownUp4 {
	Texture = tBlurDownUp4;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D tBlurDownUp8 <
	pooled = true;
> {
	Width = BUFFER_WIDTH / 8;
	Height = BUFFER_HEIGHT / 8;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlurDownUp8 {
	Texture = tBlurDownUp8;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D tBlur2px <
	pooled = true;
> {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlur2px {
	Texture = tBlur2px;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D tBlur4px <
	pooled = true;
> {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlur4px {
	Texture = tBlur4px;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

texture2D tBlur8px <
	pooled = true;
> {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlur8px {
	Texture = tBlur8px;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

#define DUALFILTERING_1 (float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT))
#define DUALFILTERING_2 (float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * 2)
#define DUALFILTERING_4 (float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * 4)
#define DUALFILTERING_8 (float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * 8)
#define DUALFILTERING_16 (float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * 16)

float4 DualFilteringDown(sampler2D tex, float2 uv, float2 halfTexel) {
	float4 pxCC = tex2D(tex, uv) * 4.0;
	float4 pxTL = tex2D(tex, uv - halfTexel);
	float4 pxTR = tex2D(tex, uv + halfTexel);
	float4 pxBL = tex2D(tex, uv + float2(halfTexel.x, -halfTexel.y));
	float4 pxBR = tex2D(tex, uv - float2(halfTexel.x, -halfTexel.y));
	float4 v = (pxCC + pxTL + pxTR + pxBL + pxBR) / 8.0;
	v.a = 1.0;
	return v;
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
	float4 v = (v0 + v1) / 12.;
	v.a = 1.0;
	return v;
}

float4 PassBlurDown2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringDown(ReShade::BackBuffer, uv, DUALFILTERING_1);
}

float4 PassBlurDown4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringDown(sBlurDownUp2, uv, DUALFILTERING_2);
}

float4 PassBlurDown8(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringDown(sBlurDownUp4, uv, DUALFILTERING_4);
}

float4 PassBlurUp8(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringUp(sBlurDownUp8, uv, DUALFILTERING_8);
}

float4 PassBlurUp4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringUp(sBlurDownUp4, uv, DUALFILTERING_4);
}

float4 PassBlurUp2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return DualFilteringUp(sBlurDownUp2, uv, DUALFILTERING_2);
}

float4 Blur2(float2 uv) {
	return tex2D(sBlur2px, uv);
}

float4 Blur4(float2 uv) {
	return tex2D(sBlur4px, uv);
}

float4 Blur8(float2 uv) {
	return tex2D(sBlur8px, uv);
}

technique DualFilteringBlur <
	enabled = true;
	hidden = true;
> {
	pass BlurDown2 {
		RenderTarget = tBlurDownUp2;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurDown2;
	}
	pass BlurDown4 {
		RenderTarget = tBlurDownUp4;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurDown4;
	}
	pass BlurDown8 {
		RenderTarget = tBlurDownUp8;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurDown8;
	}

	pass Blur2 {
		RenderTarget = tBlur2px;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp2;
	}
	pass Blur4_4To2 {
		RenderTarget = tBlurDownUp2;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp4;
	}
	pass Blur4 {
		RenderTarget = tBlur4px;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp2;
	}
	pass Blur8_8To4 {
		RenderTarget = tBlurDownUp4;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp8;
	}
	pass Blur8_4To2 {
		RenderTarget = tBlurDownUp2;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp4;
	}
	pass Blur8 {
		RenderTarget = tBlur8px;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;

        VertexShader = PostProcessVS;
        PixelShader = PassBlurUp2;
	}
}
