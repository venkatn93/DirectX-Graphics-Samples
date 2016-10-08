#include "PostEffectsRS.hlsli"

//Texture2D<float3> InputBuf : register(t0);
RWTexture2D<float3> ColorBuf : register(u0);

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint3 DTid : SV_DispatchThreadID)
{
	float2 texCoords = float2(DTid.xy);
	float2 UV = float2(texCoords.x / 1920.0, texCoords.y / 1080.0);
    float2 projectedBrightSpot = float2(0.3, 0.3);
    const int flaresNo = 4;
	// float3 color = ColorBuf[texCoords] + ColorBuf[texCoords + float2(1,0)] + ColorBuf[texCoords + float2(0,1)] + ColorBuf[texCoords + float2(1,1)] / 4.0;
	float3 color = ColorBuf[texCoords];
	//color.rgb = color.r*0.33 + color.g*0.56 + color.b*0.11;
	float2 reverseBrightSpot = (2*float2(0.5, 0.5)) - projectedBrightSpot;
	for (int i = 1; i < flaresNo + 1; ++i)
	{
		float2 currentSpot = lerp(projectedBrightSpot, reverseBrightSpot, ((float)i / (float)flaresNo));
		float flareRadius = 0.05;
		float currDistance = abs(length(currentSpot - UV));
		if (currDistance < flareRadius)
		{
            color = float3(1, 1, 1);
		}
	}
    /*float dist = abs(length(projectedBrightSpot - UV));
    if (dist < 0.1)
        color = float3(1, 0, 0);*/

    ColorBuf[texCoords] = color;
}