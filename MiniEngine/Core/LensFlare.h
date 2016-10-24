#pragma once

namespace Math { class Camera; }

namespace LensFlare
{
	void Initialize(void);
	void Shutdown(void);
	//void Render(GraphicsContext& Context, const float* ProjMat, float NearClipDist, float FarClipDist);
	void Render(GraphicsContext& Context, const Math::Camera& camera);


	extern BoolVar Res;
	//extern BoolVar DebugDraw;
	//extern BoolVar AsyncCompute;
	//extern BoolVar ComputeLinearZ;

}
