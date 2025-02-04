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

// Debug Back or Depth Buffer

#include "ReShade.fxh"
#include "Xmr_Common.fxh"

uniform int _z_export <
    ui_type = "combo";
    ui_label = "Depth Export Type";
    ui_items =  "Grayscale=0\0"
                "RGB (R=Z, G=Z/256, B=Z/65535)=1\0"
                "YUV (Y=Z, U=Z/256, V=Z/65535)=2\0";
> = 0;
uniform bool _z_dither <
    ui_label = "Dither Depth";
> = false;

float limitAccuracyFloor(float a, float limit) {
    return floor(a * limit) / limit;
}

float4 Xaymar_DebugBackBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	return tex2Dlod(Xaymar::BackBuffer, float4(texcoord, 0, 0));
}
technique Xaymar_DebugBackBuffer <
    ui_label = "[Xaymar] Debug Back Buffer";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = Xaymar_DebugBackBuffer;
    }
}

float4 Xaymar_DebugAlphaBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	return float4(tex2Dlod(Xaymar::BackBuffer, float4(texcoord, 0, 0)).www, 1.);
}
technique Xaymar_DebugAlphaBuffer <
    ui_label = "[Xaymar] Debug Alpha Buffer";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = Xaymar_DebugAlphaBuffer;
    }
}

float4 Xaymar_DebugDepthBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float depth = ReShade::GetLinearizedDepth(texcoord);

    float4 output;
    if (_z_export == 0) {
	    output = float4(depth, depth, depth, 1.0);
    } else if (_z_export == 1) {
        float dR = depth;
        float dG = frac(dR * 255.);
        float dB = frac(dG * 255.);
        output = float4(dR, dG, dB, 1.0);
    } else if (_z_export == 2) {
        float dY = depth;
        float dU = frac(dY * 255.);
        float dV = frac(dU * 255.);
        output = Xaymar::ColorConversion::XYZA_to_RGBA(float4(dY, dU, dV, 1.0), XAYMAR_YUV_709_RGB);
    } else {
        output = float4(1.0, 0.0, 1.0, 1.0);
    }

    if (_z_dither) {
        output = Xaymar::Dither::DitherIGN(output, pow(2, XAYMAR_COLOR_BIT_DEPTH), pos);
    }

    return output;
}

technique Xaymar_DebugDepthBuffer <
    ui_label = "[Xaymar] Debug Depth Buffer";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = Xaymar_DebugDepthBuffer;
    }
}
