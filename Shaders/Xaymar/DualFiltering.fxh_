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
#ifndef DUALFILTERING_ENABLE_2PX
	#define DUALFILTERING_ENABLE_2PX 1
#endif
#if DUALFILTERING_ENABLE_2PX == 1
texture2D tBlur2px {
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

float4 Blur2(float2 uv) {
	return tex2D(sBlur2px, uv);
}

#ifndef DUALFILTERING_ENABLE_4PX
	#define DUALFILTERING_ENABLE_4PX 1
#endif
#if DUALFILTERING_ENABLE_4PX == 1
texture2D tBlur4px {
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

float4 Blur4(float2 uv) {
	return tex2D(sBlur4px, uv);
}

#ifndef DUALFILTERING_ENABLE_8PX
	#define DUALFILTERING_ENABLE_8PX 1
#endif
#if DUALFILTERING_ENABLE_8PX == 1
texture2D tBlur8px {
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

float4 Blur8(float2 uv) {
	return tex2D(sBlur8px, uv);
}

#ifndef DUALFILTERING_ENABLE_16PX
	#define DUALFILTERING_ENABLE_16PX 1
#endif
#if DUALFILTERING_ENABLE_16PX == 1
texture2D tBlur16px {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlur16px {
	Texture = tBlur16px;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

float4 Blur16(float2 uv) {
	return tex2D(sBlur16px, uv);
}

#ifndef DUALFILTERING_ENABLE_32PX
	#define DUALFILTERING_ENABLE_32PX 1
#endif
#if DUALFILTERING_ENABLE_32PX == 1
texture2D tBlur32px {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	MipLevels = 1;
	Format = RGB10A2;
};
sampler2D sBlur32px {
	Texture = tBlur32px;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MinLOD = 0.0f;
	MaxLOD = 0.0f;
	AddressU = CLAMP;
	AddressV = CLAMP;
	AddressW = CLAMP;
};

float4 Blur32(float2 uv) {
	return tex2D(sBlur32px, uv);
}
#endif
#endif
#endif
#endif
#endif
