#include "PostEffectsRS.hlsli"

// sizeof(CopyDest):sizeof(CopySrc) = 1:4
RWTexture2D<float3> CopyDest : register(u0);
Texture2D<float3> CopySrc : register(t0);

groupshared float3 mipColors[4];

[RootSignature(PostEffects_RootSig)]
[numthreads(2, 2, 1)]
void main(uint3 Gid : SV_GroupID, uint3 DTid : SV_DispatchThreadID)
{
	// STUB
	/*float3 average = (CopySrc[DTid.xy]
		+ CopySrc[DTid.xy + float2(1, 0)]
		+ CopySrc[DTid.xy + float2(0, 1)]
		+ CopySrc[DTid.xy + float2(1, 1)]) * 0.25;*/
	//CopyDest[Gid.xy] = average;
}
