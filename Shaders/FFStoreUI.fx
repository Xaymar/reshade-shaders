// Attempts to hide the FFXIV UI from further processing.

uniform float detection_alpha_limit <
	ui_type = "slider";
	ui_label = "UI Detection Alpha";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
> = 0.2;
uniform float step_scale <
	ui_type = "slider";
	ui_label = "UI Mask Step Scale";
	ui_min = 1.0;
	ui_max = 512.0;
	ui_step = 1.0;
> = 4.0;

texture ColorStoreTex { 
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};
sampler ColorStore { 
	Texture = ColorStoreTex;
};

#include "ReShade.fxh"

float4 PS_StoreColor(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 bb = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
	if (bb.a >= detection_alpha_limit) {
		return bb;
	} else {
		return float4(bb.r,bb.g,bb.b,0);
	}
}
technique FFXIV_Store {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_StoreColor;
        RenderTarget = ColorStoreTex;
    }
}

float4 PS_MaskColor(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 cui = tex2Dlod(ColorStore, float4(texcoord, 0, 0));
	if (cui.a > 0.01) {
		int4 icoords = int4(texcoord * tex2Dsize(ColorStore, 0), 0, 0);
		for (int i = 0; i < 50; ++i) {
			// Do this test for each direction (+X, -X, +Y, -Y)
			{
				float4 hui = tex2Dfetch(ColorStore, icoords + int4(i * step_scale, 0, 0, 0));
				if (hui.a <= 0.01)
					return tex2Dfetch(ReShade::BackBuffer, icoords + int4(i * step_scale, 0, 0, 0));
			}
			{
				float4 hui = tex2Dfetch(ColorStore, icoords - int4(i * step_scale, 0, 0, 0));
				if (hui.a <= 0.01)
					return tex2Dfetch(ReShade::BackBuffer, icoords - int4(i * step_scale, 0, 0, 0));
			}
			{
				float4 hui = tex2Dfetch(ColorStore, icoords + int4(0, i * step_scale, 0, 0));
				if (hui.a <= 0.01)
					return tex2Dfetch(ReShade::BackBuffer, icoords + int4(0, i * step_scale, 0, 0));
			}
			{
				float4 hui = tex2Dfetch(ColorStore, icoords - int4(0, i * step_scale, 0, 0));
				if (hui.a <= 0.01)
					return tex2Dfetch(ReShade::BackBuffer, icoords - int4(0, i * step_scale, 0, 0));
			}
		}
	}
	return tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
}
technique FFXIV_Mask {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_MaskColor;
    }
}

float4 PS_LoadColor(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 cui = tex2Dlod(ColorStore, float4(texcoord, 0, 0));
	if (cui.a > 0)
		return cui;
	return tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
}
technique FFXIV_Load {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_LoadColor;
    }
}
