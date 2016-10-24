#include "PostEffectsRS.hlsli"

/*// sizeof(CopyDest):sizeof(CopySrc) = 1:4
RWTexture2D<float3> CopyDest : register(u0);
Texture2D<float4> CopySrc : register(t0);

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 DTid : SV_DispatchThreadID)
{
	float4 color = CopySrc[DTid.xy];
	CopyDest[DTid.xy] = lerp(CopyDest[DTid.xy], color.rgb, color.a);
}*/

Texture2D<float4> LFBuf : register(t0);
SamplerState LinearBorder : register(s1);
RWTexture2D<float3> ColorBuf : register(u0);

cbuffer cb0 : register(b0)
{
	float2 g_inverseDimensions;
}

// The guassian blur weights (derived from Pascal's triangle)
static const float Weights5[3] = { 6.0f / 16.0f, 4.0f / 16.0f, 1.0f / 16.0f };
static const float Weights7[4] = { 20.0f / 64.0f, 15.0f / 64.0f, 6.0f / 64.0f, 1.0f / 64.0f };
static const float Weights9[5] = { 70.0f / 256.0f, 56.0f / 256.0f, 28.0f / 256.0f, 8.0f / 256.0f, 1.0f / 256.0f };

float4 Blur5(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h, float4 i)
{
	return Weights5[0] * e + Weights5[1] * (d + f) + Weights5[2] * (c + g);
}

float4 Blur7(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h, float4 i)
{
	return Weights7[0] * e + Weights7[1] * (d + f) + Weights7[2] * (c + g) + Weights7[3] * (b + h);
}

float4 Blur9(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h, float4 i)
{
	return Weights9[0] * e + Weights9[1] * (d + f) + Weights9[2] * (c + g) + Weights9[3] * (b + h) + Weights9[4] * (a + i);
}

#define BlurPixels Blur9

// 16x16 pixels with an 8x8 center that we will be blurring writing out.  Each uint is two color channels packed together
groupshared uint CacheR[128];
groupshared uint CacheG[128];
groupshared uint CacheB[128];
groupshared uint CacheA[128];

void Store2Pixels(uint index, float4 pixel1, float4 pixel2)
{
	CacheR[index] = f32tof16(pixel1.r) | f32tof16(pixel2.r) << 16;
	CacheG[index] = f32tof16(pixel1.g) | f32tof16(pixel2.g) << 16;
	CacheB[index] = f32tof16(pixel1.b) | f32tof16(pixel2.b) << 16;
	CacheA[index] = f32tof16(pixel1.a) | f32tof16(pixel2.a) << 16;
}

void Load2Pixels(uint index, out float4 pixel1, out float4 pixel2)
{
	uint4 RGBA = uint4(CacheR[index], CacheG[index], CacheB[index], CacheA[index]);
	pixel1 = f16tof32(RGBA);
	pixel2 = f16tof32(RGBA >> 16);
}

void Store1Pixel(uint index, float4 pixel)
{
	CacheR[index] = asuint(pixel.r);
	CacheG[index] = asuint(pixel.g);
	CacheB[index] = asuint(pixel.b);
	CacheA[index] = asuint(pixel.a);
}

void Load1Pixel(uint index, out float4 pixel)
{
	pixel = asfloat(uint4(CacheR[index], CacheG[index], CacheB[index], CacheA[index]));
}

// Blur two pixels horizontally.  This reduces LDS reads and pixel unpacking.
void BlurHorizontally(uint outIndex, uint leftMostIndex)
{
	float4 s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
	Load2Pixels(leftMostIndex + 0, s0, s1);
	Load2Pixels(leftMostIndex + 1, s2, s3);
	Load2Pixels(leftMostIndex + 2, s4, s5);
	Load2Pixels(leftMostIndex + 3, s6, s7);
	Load2Pixels(leftMostIndex + 4, s8, s9);

	Store1Pixel(outIndex, BlurPixels(s0, s1, s2, s3, s4, s5, s6, s7, s8));
	Store1Pixel(outIndex + 1, BlurPixels(s1, s2, s3, s4, s5, s6, s7, s8, s9));
}

void BlurVertically(uint2 pixelCoord, uint topMostIndex)
{
	float4 s0, s1, s2, s3, s4, s5, s6, s7, s8;
	Load1Pixel(topMostIndex, s0);
	Load1Pixel(topMostIndex + 8, s1);
	Load1Pixel(topMostIndex + 16, s2);
	Load1Pixel(topMostIndex + 24, s3);
	Load1Pixel(topMostIndex + 32, s4);
	Load1Pixel(topMostIndex + 40, s5);
	Load1Pixel(topMostIndex + 48, s6);
	Load1Pixel(topMostIndex + 56, s7);
	Load1Pixel(topMostIndex + 64, s8);

	float4 color = BlurPixels(s0, s1, s2, s3, s4, s5, s6, s7, s8);
	ColorBuf[pixelCoord] = lerp(ColorBuf[pixelCoord], color.rgb, color.a);
}

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint3 DTid : SV_DispatchThreadID)
{
	//
	// Load 4 pixels per thread into LDS
	//
	int2 GroupUL = (Gid.xy << 3) - 4;				// Upper-left pixel coordinate of group read location
	int2 ThreadUL = (GTid.xy << 1) + GroupUL;		// Upper-left pixel coordinate of quad that this thread will read

	//
	// Store 4 unblurred pixels in LDS
	//
	float2 uvUL = (float2(ThreadUL)+0.5) * g_inverseDimensions;
	float2 uvLR = uvUL + g_inverseDimensions;
	float2 uvUR = float2(uvLR.x, uvUL.y);
	float2 uvLL = float2(uvUL.x, uvLR.y);
	int destIdx = GTid.x + (GTid.y << 4);

	float4 pixel1a = LFBuf.SampleLevel(LinearBorder, uvUL, 0.0f);
	float4 pixel1b = LFBuf.SampleLevel(LinearBorder, uvUR, 0.0f);
	Store2Pixels(destIdx + 0, pixel1a, pixel1b);

	float4 pixel2a = LFBuf.SampleLevel(LinearBorder, uvLL, 0.0f);
	float4 pixel2b = LFBuf.SampleLevel(LinearBorder, uvLR, 0.0f);
	Store2Pixels(destIdx + 8, pixel2a, pixel2b);

	GroupMemoryBarrierWithGroupSync();

	//
	// Horizontally blur the pixels in Cache
	//
	uint row = GTid.y << 4;
	BlurHorizontally(row + (GTid.x << 1), row + GTid.x + (GTid.x & 4));

	GroupMemoryBarrierWithGroupSync();

	//
	// Vertically blur the pixels and write the result to memory
	//
	BlurVertically(DTid.xy, (GTid.y << 3) + GTid.x);
}
