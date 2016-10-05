#include "PostEffectsRS.hlsli"

Texture2D<float3> InputBuf : register(t0);
RWTexture2D<float3> Result : register(u0);

float2 projectedBrightSpot = float2(0.3, 0.7);
int flaresNo = 4;

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint3 DTid : SV_DispatchThreadID)
{
	float2 texCoords = float2(DTid.xy);
	float2 UV = float2(texCoords.x / 1920.0, texCoords.y / 1080.0);
	//float3 color = InputBuf[texCoords] + InputBuf[texCoords + float2(1,0)] + InputBuf[texCoords + float2(0,1)] + InputBuf[texCoords + float2(1,1)] / 4.0;
	float3 color = InputBuf[texCoords];
	//color.rgb = color.r*0.33 + color.g*0.56 + color.b*0.11;
	float2 reverseBrightSpot = float2(0.5, 0.5) - projectedBrightSpot;
	for (int i = 0; i < flaresNo; ++i)
	{
		float2 currentSpot = lerp(projectedBrightSpot, reverseBrightSpot, (i / flaresNo));
		float flareRadius = 0.05 * i;
		float currDistance = length(currentSpot - UV);
		if (currDistance < flareRadius)
		{
			color = (color + float3(1, 1, 1)) / 2.0;
		}
	}

	Result[texCoords] = color;
}