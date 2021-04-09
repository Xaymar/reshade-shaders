// Dither Shader Header
// - by Xaymar: https://xaymar.com/

// Enable Pseudo-Temporal Dithering
#ifndef DITHER_ENABLE_PIXEL_FLICKER
	#define DITHER_ENABLE_PIXEL_FLICKER 0
#endif

#if DITHER_ENABLE_PIXEL_FLICKER == 1
uniform float _dither_flicker <
    source = "random";
    min = 0;
    max = 4;
>;
#endif

float _dither_bayer(float2 vpos, int max_level)
{
	float finalBayer   = 0.0;
	float finalDivisor = 0.0;
    float layerMult	   = 1.0;

  	for(float bayerLevel = max_level; bayerLevel >= 1.0; bayerLevel--)
	{
		layerMult 		   *= 4.0;

		float2 bayercoord 	= floor(vpos.xy * exp2(1 - bayerLevel)) % 2;
		float line0202 = bayercoord.x*2.0;

		finalBayer += lerp(line0202, 3.0 - line0202, bayercoord.y) / 3.0 * layerMult;
		finalDivisor += layerMult;
	}

	return finalBayer / finalDivisor;
}

float4 dither(float4 v, float2 uv, float range) {
    float2 xy = uv * float2(BUFFER_WIDTH, BUFFER_HEIGHT);

#if DITHER_ENABLE_PIXEL_FLICKER == 1
    // Flicker the X and Y coordinates for better dithering.
    xy.x += _dither_flicker % 2;
    xy.y += _dither_flicker / 2;
#endif

    // Apply Bayer ditherimg.
    // - Retrieve the "step".
    float d = _dither_bayer(xy, 3);
    // - Convert the input to an pseudo-integer.
    float4 vI = v * range;
    // - Grab the fraction which tells us how close we are to the higher value.
    float4 vF = frac(vI);
    // - Move the floor of vI down for dithering.
    vI = floor(vI);
    // - Apply the actual dithering.
    vI.r = vF.r > d ? vI.r + 1 : vI.r;
    vI.g = vF.g > d ? vI.g + 1 : vI.g;
    vI.b = vF.b > d ? vI.b + 1 : vI.b;
    vI.a = vF.a > d ? vI.a + 1 : vI.a;
    // - Scale vI back to float range.
    vI /= range;

	return vI;
}
