#include "PostEffectsRS.hlsli"

// sizeof(CopyDest):sizeof(CopySrc) = 1:4
RWTexture2D<float3> CopyDest : register(u0);
Texture2D<float4> CopySrc : register(t0);

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 DTid : SV_DispatchThreadID)
{
	float4 color = CopySrc[DTid.xy];
	CopyDest[DTid.xy] = lerp(CopyDest[DTid.xy], color.rgb, color.a);
}
