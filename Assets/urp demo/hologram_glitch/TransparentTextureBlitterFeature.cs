using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TransparentTextureBlitterFeature : ScriptableRendererFeature
{
	[SerializeField] private Material mat;
	public Settings settings = new Settings();

	[SerializeField] private bool enable = false;
	
	[System.Serializable]
	public class Settings // 用于传递结构体和string类型的变量, 因为string表现得像结构体
	{
		public int downSample = 1;
		public string textureName = "_TransparentTexture";
	}

	private TransparentTextureBlitterPass pass;
		
	public override void Create()
	{
		if (enable)
		{
			pass = new TransparentTextureBlitterPass(RenderPassEvent
				.AfterRenderingTransparents, mat, settings);
		}
	}

	public override void SetupRenderPasses(ScriptableRenderer renderer,
		in RenderingData renderingData)
	{
		if (enable)
		{
			pass.SetInput(renderer.cameraColorTargetHandle);
		}
	}
	
	public override void AddRenderPasses(ScriptableRenderer renderer,
		ref RenderingData renderingData)
	{
		if (enable)
		{
			renderer.EnqueuePass(pass);
		}
			
	}
	
	protected override void Dispose(bool disposing)
	{
		pass?.Dispose();
		pass = null;
	}
}

public class TransparentTextureBlitterPass : ScriptableRenderPass
{
	private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("BlitToTexture _TransparentTexture");
	private RTHandle cameraRT;
	private RTHandle outputRT;
	private Material mat;
	private TransparentTextureBlitterFeature.Settings settings;

	public TransparentTextureBlitterPass(RenderPassEvent evt, Material mat,
		TransparentTextureBlitterFeature.Settings settings)
	{
		this.renderPassEvent = evt;
		this.mat = mat;
		this.settings = settings;
	}
	
	public void SetInput(RTHandle cameraRT)
	{
		this.cameraRT = cameraRT;
	}

	public override void Configure(CommandBuffer cmd,
		RenderTextureDescriptor cameraTextureDescriptor)
	{
		var descriptor = cameraTextureDescriptor;
		descriptor.depthBufferBits = 0;
		descriptor.msaaSamples = 1;
		descriptor.height /= settings.downSample;
		descriptor.width /= settings.downSample;
		RenderingUtils.ReAllocateIfNeeded(ref outputRT, descriptor,
			FilterMode.Bilinear, TextureWrapMode.Clamp);
	}
	
	public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
	{
		CommandBuffer cmd = CommandBufferPool.Get();
		using (new ProfilingScope(cmd, m_ProfilingSampler))
		{
			Blitter.BlitCameraTexture(cmd, cameraRT, outputRT, mat, 0);
			cmd.SetGlobalTexture(settings.textureName, outputRT);
		}
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}
	
	public void Dispose()
	{
		cameraRT?.Release();
		outputRT?.Release();
	}
}