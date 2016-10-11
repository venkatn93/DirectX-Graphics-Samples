#include "PostEffectsRS.hlsli"

RWTexture2D<float3> ColorBuf : register(u0);

cbuffer ConstantBuffer : register(b1)
{
	float4x4 viewProjMat;
}

// ( 1.0 - x*x )^2
float Falloff_Xsq_C1(float xsq) { xsq = 1.0 - xsq; return xsq*xsq; }

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint3 DTid : SV_DispatchThreadID)
{
	float2 texCoords = float2(DTid.xy);
	float2 UV = texCoords / float2(1920.0, 1080.0);
	UV.x *= 1920.0 / 1080.0;
    float3 brightSpotWorldSpace = float3(10, 100, 10);
	float2 projectedBrightSpot = mul(viewProjMat, float4(brightSpotWorldSpace, 1.0)).xy;
    const int flaresNo = 4;
	float3 color = ColorBuf[texCoords];

	// Draw horizontal flare
	float falloffX = 0.2;
	float maxY = 0.025;
	float2 currDelta = projectedBrightSpot - UV;
	if (abs(currDelta.x) < falloffX)
	{
		float limitY = Falloff_Xsq_C1(currDelta.x);
		if (abs(currDelta.y) < limitY)
			color = float3(0, 1, 0);
	}

	// Draw circular flares
	float2 reverseBrightSpot = (float2(1, 1)) - projectedBrightSpot;
	for (int i = 1; i <= flaresNo; ++i)
	{
		float2 currentSpot = lerp(projectedBrightSpot, reverseBrightSpot, ((float)i / (float)flaresNo));
		float flareRadius = 0.025;
		float currDistance = abs(length(currentSpot - UV));
		float falloffFactor = 1.0 - clamp(currDistance/flareRadius, 0, 1.0);
		falloffFactor = clamp(falloffFactor*0.5, 0, 1.0);
        color = lerp(color, float3(1, 1, 1), falloffFactor);
		// Draw borderline around flare
		//if (abs(currDistance - flareRadius) < 0.0006)
		//{
			//color = float3(1, 1, 1);
		//}
	}

	ColorBuf[texCoords] = color;
}