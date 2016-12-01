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

#include "CompiledShaders/LensFlareCS.h"
#include "CompiledShaders/CopyLFtoBack.h"

namespace LensFlare
{
	RootSignature LensFlareRS;
	ComputePSO LensFlareCS;
	ComputePSO CopyBackCS;

	struct LensFlareCB
    {
		Math::Vector3 screenRes;
        Math::Vector4 projectedBrightSpot;
    };
}

void LensFlare::Initialize(void)
{
	LensFlareRS.Reset(4, 2);
	LensFlareRS.InitStaticSampler(0, Graphics::SamplerLinearClampDesc);
	LensFlareRS.InitStaticSampler(1, Graphics::SamplerLinearBorderDesc);
	LensFlareRS[0].InitAsConstants(0, 4);
	LensFlareRS[1].InitAsDescriptorRange(D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 0, 4);
	LensFlareRS[2].InitAsDescriptorRange(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 0, 4);
	LensFlareRS[3].InitAsConstantBuffer(1);
	LensFlareRS.Finalize(L"Lens Flare");

#define CreatePSO( ObjName, ShaderByteCode ) \
	ObjName.SetRootSignature(LensFlareRS); \
	ObjName.SetComputeShader(ShaderByteCode, sizeof(ShaderByteCode) ); \
	ObjName.Finalize();

	CreatePSO(LensFlareCS, g_pLensFlareCS);
	CreatePSO(CopyBackCS, g_pCopyLFtoBack);
}

void LensFlare::Shutdown(void)
{
}

void LensFlare::Render(GraphicsContext& Context, const Math::Camera& camera)
{
	ScopedTimer _prof(L"Lens Flare", Context);

	ComputeContext& CC = Context.GetComputeContext();
	CC.SetRootSignature(LensFlareRS);

    LensFlareCB lfCB;
	Math::Vector3 screen = Math::Vector3(Graphics::g_PingPongBuffer.GetWidth(), Graphics::g_PingPongBuffer.GetHeight(), 0);
	Math::Vector3 brightSpotWorldSpace = Math::Vector3(10.0, 1000.0, 500.0);
    Math::Vector4 projected = camera.GetViewProjMatrix() * Math::Vector4(brightSpotWorldSpace, 1.0);
    projected /= projected.GetW();
    projected.SetY(1.0f - projected.GetY());
	float dotProduct = Math::Dot(camera.GetForwardVec(), brightSpotWorldSpace - camera.GetPosition());

	// Render effect to half-resolution buffer
	if (// dotProduct >= 0 &&
		projected.GetX() > -0.2f && projected.GetX() < 1.2f && projected.GetY() > -0.2f && projected.GetY() < 1.2f)
    {

        //CC.TransitionResource(Graphics::g_SceneColorBuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        CC.TransitionResource(Graphics::g_PingPongBuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
		lfCB.projectedBrightSpot = projected;
		lfCB.screenRes = screen;
        CC.SetDynamicConstantBufferView(3, sizeof(LensFlareCB), &lfCB);
        CC.SetDynamicDescriptor(1, 0, Graphics::g_PingPongBuffer.GetUAV());
        //CC.SetDynamicDescriptor(2, 0, g_SceneColorBuffer.GetSRV());
        //CC.SetDynamicDescriptor(2, 0, g_PingPongBuffer.GetSRV());

        CC.SetPipelineState(LensFlareCS);
        CC.Dispatch2D(Graphics::g_PingPongBuffer.GetWidth(), Graphics::g_PingPongBuffer.GetHeight());

		// Quick buffer copy
		CC.TransitionResource(Graphics::g_SceneColorBuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
		CC.TransitionResource(Graphics::g_PingPongBuffer, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
		CC.SetConstants(0, 1.0f / Graphics::g_SceneColorBuffer.GetWidth(), 1.0f / Graphics::g_SceneColorBuffer.GetHeight());
		CC.SetDynamicDescriptor(1, 0, Graphics::g_SceneColorBuffer.GetUAV());
		CC.SetDynamicDescriptor(2, 0, Graphics::g_PingPongBuffer.GetSRV());
		CC.SetPipelineState(CopyBackCS);
		CC.Dispatch2D(Graphics::g_SceneColorBuffer.GetWidth(), Graphics::g_SceneColorBuffer.GetHeight());

    }
}