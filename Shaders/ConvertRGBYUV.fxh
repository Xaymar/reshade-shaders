// Convert RGB to YUV and back.
// - by Xaymar: https://xaymar.com/

//----------------------------------------------------------------------------//
// RGB to 709

#define RGB_YUV_709 float3x3( 0.21260,  0.71520,  0.07220,\
                             -0.11457, -0.38543,  0.50000,\
                              0.50000, -0.45415, -0.04585)
#define YUV_709_RGB float3x3( 1.00000,  0.00000,  1.57480,\
                              1.00000, -0.18732, -0.46812,\
                              1.00000,  1.85560,  0.00000)

//----------------------------------------------------------------------------//
// RGB to YUV

float3 RGBtoYUV(float3 rgb, float3x3 m) {
	return mul(m, rgb) + float3(0, .5, .5);
}

float4 RGBAtoYUVA(float4 rgba, float3x3 m) {
	return float4(RGBtoYUV(rgba.rgb, m), rgba.a);
}

float3 YUVtoRGB(float3 yuv, float3x3 m) {
	return mul(m, yuv.rgb - float3(0, .5, .5));
}

float4 YUVAtoRGBA(float4 yuva, float3x3 m) {
	return float4(YUVtoRGB(yuva.rgb, m), yuva.a);
}
