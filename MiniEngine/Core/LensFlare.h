#pragma once

namespace Math { class Camera; }

namespace LensFlare
{
	void Initialize(void);
	void Shutdown(void);
	void Render(GraphicsContext& Context, const float* ProjMat, float NearClipDist, float FarClipDist);
	void Render(GraphicsContext& Context, const Math::Camera& camera);
	void MakeBox(GraphicsContext& CC);


	//extern BoolVar Enable;
	//extern BoolVar DebugDraw;
	//extern BoolVar AsyncCompute;
	//extern BoolVar ComputeLinearZ;

}
