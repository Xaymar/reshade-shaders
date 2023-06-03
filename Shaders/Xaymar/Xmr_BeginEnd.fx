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

#include "ReShade.fxh"
#include "Xmr_Common.fxh"

uniform uint Tonemapper <
	ui_type = "combo";
	ui_label = "Tonemapper";
	ui_items = "None\0"
        "Reinhard\0";
	ui_tooltip = "";
> = 1;

uniform uint Debander <
	ui_category = "Debanding";
	ui_type = "combo";
	ui_label = "Debanding Method";
	ui_items = "None\0"
		"ReShade\0";
	ui_tooltip = "";
> = 2;

uniform float DebandingRadius <
	ui_category = "Debanding";
	ui_type = "slider";
	ui_label = "";
	ui_tooltip = "Search radius for appropriate pixels to deband with.\n"
		"- qUINT: Range is scaled to 0.0 to 1.0.\n"
		"- ReShade: The radius increases linearly for each iteration. A higher radius will find more gradients, but a lower radius will smooth more aggressively.";
	ui_min = 0.0;
	ui_max = 32.0;
	ui_step = 0.001;
> = 24.0;

uniform int ReShadeDebandIterations <
	ui_category = "Debanding";
    ui_label = "Iterations";
    ui_max = 4;
    ui_min = 1;
    ui_tooltip = "The number of debanding steps to perform per sample. Each step reduces a bit more banding, but takes time to compute.";
    ui_type = "slider";
> = 1;

uniform bool ReShadeDebandEnableWeber <
	ui_category = "Debanding";
    ui_label = "Weber ratio";
    ui_tooltip = "Weber ratio analysis that calculates the ratio of the each local pixel's intensity to average background intensity of all the local pixels.";
    ui_type = "radio";
> = true;

uniform float ReShadeDebandStdDevThreshold <
	ui_category = "Debanding";
    ui_label = "Standard deviation threshold";
    ui_max = 0.5;
    ui_min = 0.0;
    ui_step = 0.001;
    ui_tooltip = "Standard deviations lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.007;

uniform bool ReShadeDebandEnableStdDev <
	ui_category = "Debanding";
    ui_label = "Standard deviation";
    ui_tooltip = "Modified standard deviation analysis that calculates nearby pixels' intensity deviation from the current pixel instead of the mean.";
    ui_type = "radio";
> = true;

uniform float ReShadeDebandWeberThreshold <
	ui_category = "Debanding";
    ui_label = "Weber ratio threshold";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_step = 0.01;
    ui_tooltip = "Weber ratios lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.04;

// Reshade uses C ReShadeDebandRand for random, max cannot be larger than 2^15-1
uniform int drandom < source = "random"; min = 0; max = 32767; >;

float ReShadeDebandRand(float x)
{
    return frac(x / 41.0);
}

float ReShadeDebandPermute(float x)
{
    return ((34.0 * x + 1.0) * x) % 289.0;
}

float4 Xaymar_BeginProcessing(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
	float depth = ReShade::GetLinearizedDepth(texcoord.xy);

	if (Debander == 1) { // ReShade
		float3 ori = color.rgb; //tex2Dlod(Xaymar::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb;

		// Initialize the PRNG by hashing the position + a random uniform
		float3 m = float3(texcoord + 1.0, (drandom / 32767.0) + 1.0);
		float h = ReShadeDebandPermute(ReShadeDebandPermute(ReShadeDebandPermute(m.x) + m.y) + m.z);

		// Compute a random angle
		float dir  = ReShadeDebandRand(ReShadeDebandPermute(h)) * 6.2831853;
		float2 o;
		sincos(dir, o.y, o.x);
		
		// Distance calculations
		float2 pt;
		float dist;

		for (int i = 1; i <= ReShadeDebandIterations; ++i) {
			dist = ReShadeDebandRand(h) * DebandingRadius * i;
			pt = dist * BUFFER_PIXEL_SIZE;
		
			h = ReShadeDebandPermute(h);
		}
		
		// Sample at quarter-turn intervals around the source pixel
		float3 ref[4] = {
			tex2Dlod(ReShade::BackBuffer, float4(mad(pt,                  o, texcoord), 0.0, 0.0)).rgb, // SE
			tex2Dlod(ReShade::BackBuffer, float4(mad(pt,                 -o, texcoord), 0.0, 0.0)).rgb, // NW
			tex2Dlod(ReShade::BackBuffer, float4(mad(pt, float2(-o.y,  o.x), texcoord), 0.0, 0.0)).rgb, // NE
			tex2Dlod(ReShade::BackBuffer, float4(mad(pt, float2( o.y, -o.x), texcoord), 0.0, 0.0)).rgb  // SW
		};

		// Calculate weber ratio
		float3 mean = (ori + ref[0] + ref[1] + ref[2] + ref[3]) * 0.2;
		float3 k = abs(ori - mean);
		[unroll]
		for (int j = 0; j < 4; ++j) {
			k += abs(ref[j] - mean);
		}

		k = k * 0.2 / mean;

		// Calculate std. deviation
		float3 sd = 0.0;
		[unroll]
		for (int j = 0; j < 4; ++j) {
			sd += pow(ref[j] - ori, 2);
		}

		sd = sqrt(sd * 0.25);

		// Generate final output
		float3 output;

		output = (ref[0] + ref[1] + ref[2] + ref[3]) * 0.25;

		// Generate a binary banding map
		bool3 banding_map = true;

		if (ReShadeDebandEnableWeber)
			banding_map = banding_map && k <= ReShadeDebandWeberThreshold * ReShadeDebandIterations;

		if (ReShadeDebandEnableStdDev)
			banding_map = banding_map && sd <= ReShadeDebandStdDevThreshold * ReShadeDebandIterations;

		/*------------------------.
		| :: Ordered Dithering :: |
		'------------------------*/
		//Calculate grid position
		float grid_position = frac(dot(texcoord, (BUFFER_SCREEN_SIZE * float2(1.0 / 16.0, 10.0 / 36.0)) + 0.25));

		//Calculate how big the shift should be
		float dither_shift = 0.25 * (1.0 / (exp2(XAYMAR_COLOR_BIT_DEPTH) - 1.0));

		//Shift the individual colors differently, thus making it even harder to see the dithering pattern
		float3 dither_shift_RGB = float3(dither_shift, -dither_shift, dither_shift); //subpixel dithering

		//modify shift acording to grid position.
		dither_shift_RGB = lerp(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position); //shift acording to grid position.
		
		color.rgb = banding_map ? output + dither_shift_RGB : ori;
	}

	// Inverse Tonemapping
	if (Tonemapper == 0) {
		color = color;
	} else if (Tonemapper == 1) { // Reinhard
		color.rgb = Xaymar::Tonemapping::ReinhardRCP(color.rgb);
	}

	// Ensure Alpha is 1.0
	color.a = 1.;

	return color;
}
technique Xaymar_BeginProcessing <
	ui_label = "[Xaymar] Begin Processing";
	ui_tooltip = "Begin any processing with Xaymar's HDR compatible pipeline. Must be before any Xaymar shaders.";
> {
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = Xaymar_BeginProcessing;
		RenderTarget = Xaymar::BackBufferTex;
		ClearRenderTargets = false;
		BlendEnable = false;
		StencilEnable = false;
	}
}

float4 Xaymar_EndProcessing(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float4 color = tex2Dlod(Xaymar::BackBuffer, float4(texcoord, 0.0, 0.0));

	// Tonemapping
	if (Tonemapper == 0) {
		color = color;
	} else if (Tonemapper == 1) { // Reinhard
		color.rgb = Xaymar::Tonemapping::Reinhard(color.rgb);
	}

	// Ensure Alpha is 1.0
	color.a = 1.;

	// Dithering
	return Xaymar::Dither::DitherBayer(color, pow(2, BUFFER_COLOR_BIT_DEPTH), vpos);
}
technique Xaymar_EndProcessing <
	ui_label = "[Xaymar] End Processing";
	ui_tooltip = "End processing with Xaymar's HDR compatible pipeline. Must be after any Xaymar shaders.";
> {
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = Xaymar_EndProcessing;
	}
}