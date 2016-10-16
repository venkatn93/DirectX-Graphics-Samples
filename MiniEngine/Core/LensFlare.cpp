#include "pch.h"

#include "LensFlare.h"
#include "PostEffects.h"
#include "GameCore.h"
#include "CommandContext.h"
#include "RootSignature.h"
#include "PipelineState.h"
#include "GraphicsCore.h"
#include "BufferManager.h"
#include "MotionBlur.h"
#include "DepthOfField.h"
#include "FXAA.h"
#include "Camera.h"

#include "CompiledShaders/MyEffectCS.h"

namespace LensFlare
{
	RootSignature LensFlareRS;
	ComputePSO LensFlareCS;

    struct LensFlareCB
    {
        Math::Vector4 projectedBrightSpot;
    };
}

void LensFlare::Initialize(void)
{
	LensFlareRS.Reset(4, 0);
	//LensFlareRS.InitStaticSampler(0, SamplerLinearClampDesc);
	//LensFlareRS.InitStaticSampler(1, SamplerLinearBorderDesc);
	LensFlareRS[0].InitAsConstants(0, 4);
	LensFlareRS[1].InitAsDescriptorRange(D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 0, 4);
	LensFlareRS[2].InitAsDescriptorRange(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 0, 4);
	LensFlareRS[3].InitAsConstantBuffer(1);
	LensFlareRS.Finalize(L"Lens Flare");

#define CreatePSO( ObjName, ShaderByteCode ) \
	ObjName.SetRootSignature(LensFlareRS); \
	ObjName.SetComputeShader(ShaderByteCode, sizeof(ShaderByteCode) ); \
	ObjName.Finalize();

	CreatePSO(LensFlareCS, g_pMyEffectCS);
}

void LensFlare::Shutdown(void)
{
}

void LensFlare::Render(GraphicsContext& Context, const float* ProjMat, float NearClipDist, float FarClipDist)
{
}

void LensFlare::Render(GraphicsContext& Context, const Math::Camera& camera)
{
	ScopedTimer _prof(L"Lens Flare", Context);

	ComputeContext& CC = Context.GetComputeContext();
	CC.SetRootSignature(LensFlareRS);

    LensFlareCB lfCB;
	Math::Vector3 brightSpotWorldSpace = Math::Vector3(10, 1000, -50);
    Math::Vector4 projected = camera.GetViewProjMatrix() * Math::Vector4(brightSpotWorldSpace, 1.0);
    //projected.SetX(projected.GetX() / -projected.GetZ());
    //projected.SetY(projected.GetY() / -projected.GetZ());
    projected /= projected.GetW();
    projected.SetY(1.0f - projected.GetY());
	float dotProduct = Math::Dot(camera.GetForwardVec(), brightSpotWorldSpace - camera.GetPosition());
	if (// dotProduct >= 0 &&
		projected.GetX() > -0.2f && projected.GetX() < 1.2f && projected.GetY() > -0.2f && projected.GetY() < 1.2f)
    {

        CC.TransitionResource(Graphics::g_SceneColorBuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        //CC.TransitionResource(Graphics::g_PingPongBuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        //const float* viewProjMat = reinterpret_cast<const float*>(&camera.GetViewProjMatrix());
		lfCB.projectedBrightSpot = projected;
        CC.SetDynamicConstantBufferView(3, sizeof(LensFlareCB), &lfCB);
        CC.SetDynamicDescriptor(1, 0, Graphics::g_SceneColorBuffer.GetUAV());
        //CC.SetDynamicDescriptor(2, 0, g_SceneColorBuffer.GetSRV());
        //CC.SetDynamicDescriptor(2, 0, g_PingPongBuffer.GetSRV());

        CC.SetPipelineState(LensFlareCS);
        CC.Dispatch2D(Graphics::g_SceneColorBuffer.GetWidth(), Graphics::g_SceneColorBuffer.GetHeight(), 8, 8);
    }
}