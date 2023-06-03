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

// Helpful resources:
// - Lottes Tonemapper: https://github.com/KhronosGroup/glTF-Compressonator/blob/master/Compressonator/Applications/_Plugins/C3DModel_viewers/glTF_DX12_EX/DX12Util/shaders/Tonemapping.hlsl#L53
// - Karis Average: 
//    - https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//    - https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
//    - https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
//    - https://github.com/github/linguist/blob/master/samples/HLSL/bloom.cginc
// - Interleaved Gradient Noise: https://blog.demofox.org/2022/01/01/interleaved-gradient-noise-a-different-kind-of-low-discrepancy-sequence/
// - https://github.com/GarrettGunnell/AcerolaFX
// - https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/course-notes-moving-frostbite-to-pbr-v2.pdf
// - https://www.reedbeta.com/blog/artist-friendly-hdr-with-exposure-values/
// - https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
// - https://cdn.cloudflare.steamstatic.com/apps/valve/2008/GDC2008_PostProcessingInTheOrangeBox.pdf

#define XAYMAR_DIVIDE_ROUND_UP(n, d) uint(((n) + (d) - 1) / (d))
#define fmod(x, y) ((x) % (y))

namespace Xaymar {
	uniform uint FrameCount < source = "framecount"; >;
	uniform float DeltaTime < source = "frametime"; >;

	// -------------------------------------------------------------------------------- //
	// Basic HDR Support

	// HDR (16-bit) BackBuffers
	#define XAYMAR_COLOR_BIT_DEPTH 16
	#define XAYMAR_COLOR_VALUES (pow(2, XAYMAR_COLOR_BIT_DEPTH) - 1)
	#define XAYMAR_COLOR_FORMAT RGBA16F
	texture2D BackBufferTex <
		pooled = false;
	> {
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
		MipLevels = 1;
		Format = XAYMAR_COLOR_FORMAT;
	};
	sampler2D BackBuffer {
		Texture = BackBufferTex;
		MagFilter = LINEAR;
		MinFilter = LINEAR;
		MipFilter = LINEAR;
		MinLOD = 0.0f;
		MaxLOD = 0.0f;
		AddressU = CLAMP;
		AddressV = CLAMP;
		AddressW = CLAMP;
	};

	texture2D BackBufferTargetTex <
		pooled = false;
	> {
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
		MipLevels = 1;
		Format = XAYMAR_COLOR_FORMAT;
	};
	sampler2D BackBufferTarget {
		Texture = BackBufferTargetTex;
		MagFilter = LINEAR;
		MinFilter = LINEAR;
		MipFilter = LINEAR;
		MinLOD = 0.0f;
		MaxLOD = 0.0f;
		AddressU = CLAMP;
		AddressV = CLAMP;
		AddressW = CLAMP;
	};

	float4 FlipBackBuffer(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
		float4 col = tex2Dlod(Xaymar::BackBufferTarget, float4(texcoord, 0.0, 0.0));
		col.a = 1.;
		return col;
	}
	#define FlipBackBufferPass pass { \
		VertexShader = PostProcessVS; \
		PixelShader = Xaymar::FlipBackBuffer; \
		RenderTarget = Xaymar::BackBufferTex; \
		ClearRenderTargets = false; \
		BlendEnable = false; \
		StencilEnable = false; \
	}

	// -------------------------------------------------------------------------------- //
	// Dithering
	namespace Dither {
		float4 Dither(float4 color, float threshold) {
			// color: [0..Infinity) Decimal value in the expected output range.
			// threshold: The output of a thresholding function, like Bayer or IGN.

			/* Naive variant.
			float4 fcolor = frac(color);
			color = floor(color);
			color.r += fcolor.r > threshold ? 1. : 0.;
			color.g += fcolor.g > threshold ? 1. : 0.;
			color.b += fcolor.b > threshold ? 1. : 0.;
			color.a += fcolor.a > threshold ? 1. : 0.;
			return color; //*/
			
			/* Incorrect Variant (>= instead of >)
			return floor(color) + step(threshold, frac(color)); //*/
			
			//* Faked Variant (> emulated with a tiny offset)
			return floor(color) + step(threshold + 0.0001, frac(color)); //*/
		}
		float3 Dither(float3 color, float threshold) {
			// color: [0..Infinity) Decimal value in the expected output range.
			// threshold: The output of a thresholding function, like Bayer or IGN.

			/* Naive variant.
			float3 fcolor = frac(color);
			color = floor(color);
			color.r += fcolor.r > threshold ? 1. : 0.;
			color.g += fcolor.g > threshold ? 1. : 0.;
			color.b += fcolor.b > threshold ? 1. : 0.;
			return color; //*/
			
			/* Incorrect Variant (>= instead of >)
			return floor(color) + step(threshold, frac(color)); //*/
			
			//* Faked Variant (> emulated with a tiny offset)
			return floor(color) + step(threshold + 0.0001, frac(color)); //*/
		}
		float2 Dither(float2 color, float threshold) {
			// color: [0..Infinity) Decimal value in the expected output range.
			// threshold: The output of a thresholding function, like Bayer or IGN.

			/* Naive variant.
			float2 fcolor = frac(color);
			color = floor(color);
			color.r += fcolor.r > threshold ? 1. : 0.;
			color.g += fcolor.g > threshold ? 1. : 0.;
			return color; //*/
			
			/* Incorrect Variant (>= instead of >)
			return floor(color) + step(threshold, frac(color)); //*/
			
			//* Faked Variant (> emulated with a tiny offset)
			return floor(color) + step(threshold + 0.0001, frac(color)); //*/
		}
		float Dither(float color, float threshold) {
			// color: [0..Infinity) Decimal value in the expected output range.
			// threshold: The output of a thresholding function, like Bayer or IGN.

			/* Naive variant.
			float4 fcolor = frac(color);
			color = floor(color);
			color += fcolor > threshold ? 1. : 0.;
			return color; //*/
			
			/* Incorrect Variant (>= instead of >)
			return floor(color) + step(threshold, frac(color)); //*/
			
			//* Faked Variant (> emulated with a tiny offset)
			return floor(color) + step(threshold + 0.0001, frac(color)); //*/
		}
		float4 DitherQuantize(float4 color, float range, float threshold) {
			return Xaymar::Dither::Dither(color * range, threshold) / range;
		}
		float3 DitherQuantize(float3 color, float range, float threshold) {
			return Xaymar::Dither::Dither(color * range, threshold) / range;
		}
		float2 DitherQuantize(float2 color, float range, float threshold) {
			return Xaymar::Dither::Dither(color * range, threshold) / range;
		}
		float DitherQuantize(float color, float range, float threshold) {
			return Xaymar::Dither::Dither(color * range, threshold) / range;
		}

		float Bayer(uint2 xy, uint levels) {
			float val = 0.0;
			float div = 0.0;
			float mul = 1.0;

			[loop]
			for(uint level = levels; level >= 1; level--)
			{
				mul *= 4.0;

				float2 xy = floor(xy.xy * exp2(1 - level)) % 2;
				float x2 = xy.x*2.0;

				val += lerp(x2, 3.0 - x2, xy.y) / 3.0 * mul;
				div += mul;
			}

			return val / div;
		}

		float4 DitherBayer(float4 v, float range, uint2 xy) {
			if (true) {
				// Flicker the X and Y coordinates for better Dithering.
				xy.x += Xaymar::FrameCount % 4;
				xy.y += Xaymar::FrameCount % 4;
			}

			return Xaymar::Dither::DitherQuantize(v, range, Xaymar::Dither::Bayer(xy, 4));
		}

		float IGN(uint2 xy) {
			if (true) {
				xy.x += Xaymar::FrameCount % 64 * 5.588238f;
				xy.y += Xaymar::FrameCount % 64 * 5.588238f;
			}

			return fmod(52.9829189f * fmod(0.06711056f * float(xy.x) + 0.00583715f * float(xy.y), 1.f), 1.f);
		}

		float4 DitherIGN(float4 color, float range, uint2 xy) {
			// color = [0..1] Decimal value.
			// range = [0..Infinity] Decimal value of the expected range.
			// xy = Screen position of the pixel.
			return Xaymar::Dither::DitherQuantize(color, range, Xaymar::Dither::IGN(xy));
		}
	}

	// -------------------------------------------------------------------------------- //
	// Shapes
	namespace Shapes {
		bool Rectangle(float2 pos, float2 xy, float2 wh, float thickness) {
			if (
				(pos.x < xy.x) || 
				(pos.y < xy.y) || 
				(pos.x >= (xy.x + wh.x)) || 
				(pos.y >= (xy.y + wh.y))) {
				return false;
			} else if (
				(pos.x <= (xy.x + thickness)) || 
				(pos.y <= (xy.y + thickness)) ||
				(pos.x >= (xy.x + wh.x - thickness)) || 
				(pos.y >= (xy.y + wh.y - thickness))) {
				return true;
			} else {
				return false;
			}
		}

		bool Rectangle(float2 pos, float2 xy, float2 wh) {
			if (
				(pos.x < xy.x) || 
				(pos.y < xy.y) || 
				(pos.x >= (xy.x + wh.x)) || 
				(pos.y >= (xy.y + wh.y))) {
				return false;
			} else {
				return true;
			}
		}
	}

	// -------------------------------------------------------------------------------- //
	// Color Conversion
	namespace ColorConversion {
		// RGB to 709 (Full Range)
		#define XAYMAR_RGB_YUV_709 float3x3( 0.21260,  0.71520,  0.07220,\
											-0.11457, -0.38543,  0.50000,\
											 0.50000, -0.45415, -0.04585)
		#define XAYMAR_YUV_709_RGB float3x3( 1.00000,  0.00000,  1.57480,\
											 1.00000, -0.18732, -0.46812,\
											 1.00000,  1.85560,  0.00000)
		// RGB to 2020 (Full Range)
		#define XAYMAR_RGB_YUV_2020 float3x3( 0.262766,  0.677957,  0.0592771,\
											 -0.139665, -0.360347,  0.5000120,\
											  0.500159, -0.459944, -0.0402151)

		#define XAYMAR_YUV_2020_RGB float3x3( 1.0000,  0.0000,  1.4740,\
											  1.0000, -0.1645, -0.5713,\
											  1.0000,  1.8814,  0.0000)
		
		// lRGB to sRGB
		float3 sRGB_to_lRGB(float3 RGB) {
			return lerp(
				(RGB / 12.92),
				pow((RGB + 0.055) / 1.055, 2.4),
				step(1. - RGB, 1. - 0.04045) // This is <=
			);
			//return (ch <= 0.04045) ? (ch / 12.92) : pow((ch + 0.055) / 1.055, 2.4);
		}
		float3 lRGB_to_sRGB(float3 RGB) {
			return lerp(
				(RGB * 12.92),
				(pow(RGB, (1.0 / 2.4)) * 1.055 - 0.55),
				step(RGB, 0.0031308) // This is >=
			);
			//return (ch >= 0.0031308) ? (ch * 12.92) : (1.055 * pow(ch, 1.0 / 2.4) - 0.055);
		}

		// lRGB to (Hue, Saturation, Value)
		float4 RGBA_to_HSVA(float4 RGBA) {
			const float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			const float e = 1.0e-10;
			float4 p = lerp(float4(RGBA.bg, K.wz), float4(RGBA.gb, K.xy), step(RGBA.b, RGBA.g));
			float4 q = lerp(float4(p.xyw, RGBA.r), float4(RGBA.r, p.yzx), step(p.x, RGBA.r));
			float d = q.x - min(q.w, q.y);
			return float4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, RGBA.a);
		}
		float4 HSVA_to_RGBA(float4 HSVA) {
			const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			float4 v = float4(0,0,0,0);
			v.rgb = HSVA.z * lerp(K.xxx, clamp(abs(frac(HSVA.xxx + K.xyz) * 6.0 - K.www) - K.xxx, 0.0, 1.0), HSVA.y);
			v.a = HSVA.a;
			return v;
		}

		// lRGB to XYZ
		float3 RGB_to_XYZ(float3 rgb, float3x3 m) {
			return mul(m, rgb) + float3(0, .5, .5);
		}
		float3 RGB_to_XYZf(float3 rgb, float3x3 m) {
			return mul(m, rgb);
		}

		float RGB_to_X(float3 rgb, float3x3 m) {
			return dot(rgb, float3(m[0][0], m[1][0], m[2][0]));
		}

		float4 RGBA_to_XYZA(float4 rgba, float3x3 m) {
			return float4(RGB_to_XYZ(rgba.rgb, m), rgba.a);
		}
		float4 RGBA_to_XYZAf(float4 rgba, float3x3 m) {
			return float4(RGB_to_XYZf(rgba.rgb, m), rgba.a);
		}

		float3 XYZ_to_RGB(float3 yuv, float3x3 m) {
			return mul(m, yuv.rgb - float3(0, .5, .5));
		}
		float3 XYZ_to_RGBf(float3 yuv, float3x3 m) {
			return mul(m, yuv.rgb);
		}

		float4 XYZA_to_RGBA(float4 yuva, float3x3 m) {
			return float4(XYZ_to_RGB(yuva.rgb, m), yuva.a);
		}
		float4 XYZA_to_RGBAf(float4 yuva, float3x3 m) {
			return float4(XYZ_to_RGBf(yuva.rgb, m), yuva.a);
		}
	}
	
	// -------------------------------------------------------------------------------- //
	// Color Processing
	namespace Color {
		float Luminance(float3 x) {
			return Xaymar::ColorConversion::RGB_to_X(x, XAYMAR_RGB_YUV_2020);
		}

		float ComputeEV100(float aperture, float shutterTime, float ISO) {
			// aperture = Aperture (f-stops)
			// shutterTime = Shutter Time (seconds)
			// ISO = Sensor Sensitivity (ISO)
			return log2((aperture * aperture) / shutterTime * 100 / ISO);
		}

		float ComputeEV100FromLuminance(float luminance) {
			return log2(luminance * 100.f / 12.5f);
		}

		// From Acerola
		//https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/White-Balance-Node.html
		float3 WhiteBalance(float3 col, float temp, float tint) {
			float t1 = temp * 10.0f / 6.0f;
			float t2 = tint * 10.0f / 6.0f;

			float x = 0.31271 - t1 * (t1 < 0 ? 0.1 : 0.05);
			float standardIlluminantY = 2.87 * x - 3 * x * x - 0.27509507;
			float y = standardIlluminantY + t2 * 0.05;

			float3 w1 = float3(0.949237, 1.03542, 1.08728);

			float Y = 1;
			float X = Y * x / y;
			float Z = Y * (1 - x - y) / y;
			float L = 0.7328 * X + 0.4296 * Y - 0.1624 * Z;
			float M = -0.7036 * X + 1.6975 * Y + 0.0061 * Z;
			float S = 0.0030 * X + 0.0136 * Y + 0.9834 * Z;
			float3 w2 = float3(L, M, S);

			float3 balance = float3(w1.x / w2.x, w1.y / w2.y, w1.z / w2.z);

			float3x3 LIN_2_LMS_MAT = float3x3(
				float3(3.90405e-1, 5.49941e-1, 8.92632e-3),
				float3(7.08416e-2, 9.63172e-1, 1.35775e-3),
				float3(2.31082e-2, 1.28021e-1, 9.36245e-1)
			);

			float3x3 LMS_2_LIN_MAT = float3x3(
				float3(2.85847e+0, -1.62879e+0, -2.48910e-2),
				float3(-2.10182e-1,  1.15820e+0,  3.24281e-4),
				float3(-4.18120e-2, -1.18169e-1,  1.06867e+0)
			);

			float3 lms = mul(LIN_2_LMS_MAT, col);
			lms *= balance;

			return mul(LMS_2_LIN_MAT, lms);
		}
	}

	// -------------------------------------------------------------------------------- //
	// Tonemapping
	namespace Tonemapping {
		float3 Reinhard(float3 x) {
			// Reinhard: x / (1 + x)
			// Acerola: x / (1 + luminance(x))
			return x / (1 + Xaymar::Color::Luminance(x));
		}

		float3 ReinhardRCP(float3 x) {
			// Reinhard: x / (1 - x)
			// Acerola: x / (1 - luminance(x))
			return x / (1 - Xaymar::Color::Luminance(x));
		}
	}

	// -------------------------------------------------------------------------------- //
	// Math
	namespace Math {
		#define XAYMAR_PI 3.1415926535897932384626433832795		// PI = pi
		//const float Pi = 3.1415926535897932384626433832795;
		#define XAYMAR_TAU 6.283185307179586476925286766559		// 2PI = 2 * pi
		//const float Tau = 6.283185307179586476925286766559;
		#define XAYMAR_TAUSQROOT 2.506628274631000502415765284811	// sqrt(2 * pi)
		//const float TauSqRoot 2.506628274631000502415765284811
		
		// Convert Radians <-> Degrees
		#define XAYMAR_RAD 57.295779513082320876798154814105       // 180/pi
		#define XAYMAR_DEG 0.01745329251994329576923690768489      // pi/180
		#define XAYMAR_DEG_TO_RAD(x) (x * XAYMAR_DEG)
		#define XAYMAR_RAD_TO_DEG(x) (x * XAYMAR_RAD)

		// e and log(e(1)) / log(2)
		#define XAYMAR_E 2,7182818284590452353602874713527
		#define XAYMAR_LOG2_E 1.4426950408889634073599246810019 // Windows calculA_to_R: log(e(1)) / log(2)

		namespace Vector2D {
			float2 Rotate(float2 xy, float ang) {
				float2x2 mat = float2x2(
					cos(ang), -sin(ang),
					sin(ang), cos(ang)
				);
				return mul(mat, xy);
			}
		}
	}
}
