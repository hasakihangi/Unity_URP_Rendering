using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EasyBlurRendererFeature : ScriptableRendererFeature
{
	private EasyBlurRenderPass pass;
	public RenderPassEvent renderPassEvent =
		RenderPassEvent.AfterRenderingSkybox;

	public Settings settings;
	
	// 每当面板序列化时会调用一次, 不太适合用于创建什么东西
	public override void Create()
	{
		// Debug.Log(0);
		pass = new EasyBlurRenderPass(settings)
		{
			renderPassEvent = renderPassEvent
		};
	}

	// 当Feature启用时每帧调用一次
	public override void SetupRenderPasses(ScriptableRenderer renderer,
		in RenderingData renderingData)
	{
		// Debug.Log(2);
	}

	// 当Feature启用时每帧调用一次
	public override void AddRenderPasses(ScriptableRenderer renderer,
		ref RenderingData renderingData)
	{
		// Debug.Log(1);
		pass.renderPassEvent = renderPassEvent;
		renderer.EnqueuePass(pass);
	}

	[System.Serializable]
	public class Settings
	{
		public int verticalDownSampling = 1;
		public int horizontalDownSampling = 1;
	}

	protected override void Dispose(bool disposing)
	{
		base.Dispose(disposing);
	}
}

public class EasyBlurRenderPass: ScriptableRenderPass
{
	private EasyBlurRendererFeature.Settings settings;
	private RTHandle blurRT;
	private RenderTextureDescriptor blurRTDes;

	private ProfilingSampler
		m_profilingSampler = new ProfilingSampler("EasyBlur");
	public EasyBlurRenderPass(EasyBlurRendererFeature.Settings settings)
	{
		this.settings = settings;
		blurRTDes = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default,
			0
		);
		blurRTDes.msaaSamples = 1;
	}
	
	public override void Configure(CommandBuffer cmd,
		RenderTextureDescriptor cameraTextureDescriptor)
	{
		// 根据cameraTextureDescriptor修改blurRTDes
		blurRTDes.width = cameraTextureDescriptor.width/settings.verticalDownSampling;
		blurRTDes.height = cameraTextureDescriptor.height/settings.horizontalDownSampling;
		// 申请rtHandle
		RenderingUtils.ReAllocateIfNeeded(ref blurRT, blurRTDes);
			// 如果在内部new, 需要使用ref将new的结果传递出来
		ConfigureTarget(blurRT);
	}

	public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
	{
		RTHandle cameraRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
		CommandBuffer cmd = CommandBufferPool.Get();
		using (new ProfilingScope(cmd, m_profilingSampler))
		{
			Blit(cmd, cameraRT, blurRT);
			//  两种写法: 1 Blitter.BlitCameraTexture
			//  2 Blit: 对Blitter.BlitCameraTexture的封装
			Blit(cmd, blurRT, cameraRT);
		}
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}

	public void Dispose()
	{
		if (blurRT != null) 
			blurRT.Release();
	}
}
