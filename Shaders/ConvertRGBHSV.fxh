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

// Convert RGB to HSV and back.
// - by Xaymar: https://xaymar.com/

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
