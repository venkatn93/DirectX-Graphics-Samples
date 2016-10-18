#include "PostEffectsRS.hlsli"

RWTexture2D<float4> LFBuf : register(u0);

cbuffer ConstantBuffer : register(b1)
{
	float4 projectedBrightSpot;
}

// ( 1.0 - x*x )^2
float Falloff_Xsq_C1(float xsq) { xsq = 0.0075 - xsq*xsq; return xsq; }

[RootSignature(PostEffects_RootSig)]
[numthreads(8, 8, 1)]
void main(uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint3 DTid : SV_DispatchThreadID)
{
	float2 texCoords = float2(DTid.xy);
	float2 UV = texCoords / float2(1920.0, 1080.0);
	//UV.x *= 1920.0 / 1080.0;
    float2 projected = projectedBrightSpot.xy;
	float2 reverseBrightSpot = (float2(1, 1)) - projected;
	float4 color = float4(1, 1, 1, 0);

	// Draw circular flares
	float flareRadius = 0.05;
	float2 currentSpot = lerp(projected, reverseBrightSpot, 0.6);
	float currDistance = abs(length(currentSpot - UV));
	float falloffFactor = 1.0 - clamp(currDistance / flareRadius, 0, 1.0);
	if (currDistance < flareRadius)
	{
		//color += float4(0.7f, 0.2f, 0.9f, 0.01);
		color = float4(float3(0.7f, 0.2f, 0.9f), color.a + 0.01);
	}

	flareRadius = 0.005;
	currentSpot = lerp(projected, reverseBrightSpot, 0.75);
	currDistance = abs(length(currentSpot - UV));
	falloffFactor = 1.0 - clamp(currDistance / flareRadius, 0, 1.0);
	//if (abs(currDistance - flareRadius) < 0.0006)
	if (falloffFactor)
	{
		color = float4(float3(0.8f, 0.4f, 0.2f), color.a + falloffFactor);
	}

	flareRadius = 0.025;
	currentSpot = lerp(projected, reverseBrightSpot, 1);
	currDistance = abs(length(currentSpot - UV));
	falloffFactor = 1.0 - clamp(currDistance / flareRadius, 0, 1.0);
	falloffFactor = clamp(falloffFactor*0.035, 0, 1.0);
	//color += float4(0.7f, 0.4f, 0.2f, falloffFactor);
	if (falloffFactor)
	{
		color = float4(float3(0.7f, 0.4f, 0.2f), color.a + falloffFactor);
	}

	// Draw ring
	currentSpot = float2(0.5, 0.5);
	currDistance = abs(length(currentSpot - UV));
	flareRadius = (length(projected - reverseBrightSpot)*0.6);
	float dotProd = dot(normalize(UV - currentSpot), normalize(reverseBrightSpot - currentSpot));
	if (abs(currDistance - flareRadius) < 0.006 && (dotProd > 0.995 || dotProd < -0.995))
	{
		//color += float4(0.7f, 0.2f, 0.9f, 0.01);
		color = float4(float3(0.9f, 0.9f, 0.9f), color.a + 0.01);
	}

	// Draw horizontal flare
	float falloffX = 1.0;
	float maxY = 0.025;
	float2 currDelta = projected - UV;
	if (abs(currDelta.x) < falloffX)
	{
		float limitY = Falloff_Xsq_C1(currDelta.x / falloffX);
		if (abs(currDelta.y) <= limitY)
			color = float4(float3(1, 1, 1), color.a + 0.35);
	}

	LFBuf[texCoords] = color;
}