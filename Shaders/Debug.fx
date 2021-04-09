// Debug Back or Depth Buffer

#include "ReShade.fxh"
#include "Dither.fxh"
#include "ConvertRGBYUV.fxh"

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

//----------------------------------------------------------------------------//
// things
float limitAccuracyFloor(float a, float limit) {
    return floor(a * limit) / limit;
}

//----------------------------------------------------------------------------//
// Debug Back Buffer
float4 DebugBackBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	return tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
}

float4 DebugDepthBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float depth = ReShade::GetLinearizedDepth(texcoord);;

    float4 output;
    if (_z_export == 0) {
	    output = float4(depth, depth, depth, 1.0);
    } else if (_z_export == 1) {
        float dR = (depth * 255.) / 255.;
        float dG = (dR * 255.) % 1.;
        float dB = (dG * 255.) % 1.;
        output = float4(dR, dG, dB, 1.0);
    } else if (_z_export == 2) {
        float dY = (depth * 255.) / 255.;
        float dU = (dY * 255.) % 1.;
        float dV = (dU * 255.) % 1.;
        output = YUVAtoRGBA(float4(dY, dU, dV, 1.0), YUV_709_RGB);
    } else {
        output = float4(1.0, 0.0, 1.0, 1.0);
    }

    if (_z_dither) {
        output = dither(output, texcoord, 255);
    }

    return output;
}

technique DebugBackBuffer {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = DebugBackBuffer;
    }
}
technique DebugDepthBuffer {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = DebugDepthBuffer;
    }
}
