using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;


public class VolumetricLightFeature: ScriptableRendererFeature
{
	private VolumetricLightRenderPass pass;
	public Material volumetricLightMat;
	public Material blurMat;
	public Material blendMat;
	public bool enable = false;
	public RenderPassEvent renderPassEvent =
		RenderPassEvent.BeforeRenderingPostProcessing;
	
	public override void Create()
	{
		if (enable)
		{
			pass = new VolumetricLightRenderPass(volumetricLightMat, blurMat,
				blendMat);
		}
	}

	public override void AddRenderPasses(ScriptableRenderer renderer,
		ref RenderingData renderingData)
	{
		if (enable)
		{
			pass.renderPassEvent = renderPassEvent;
			renderer.EnqueuePass(pass);
		}
	}

	protected override void Dispose(bool disposing)
	{
		base.Dispose(disposing);
		pass?.Dispose();
		pass = null;
	}
}

public class VolumetricLightRenderPass : ScriptableRenderPass
{
	private Material volumetricLightMat;
	private Material blurMat;
	private Material blendMat;
	private RTHandle cameraRT;
	
	private RTHandle rt;
	private RenderTextureDescriptor rtd;

	private RTHandle rt1;
	private RenderTextureDescriptor rtd1;
	
	// 用作Blend
	private RTHandle rt2;
	private RenderTextureDescriptor rtd2;
	
	private VolumetricLightVolume volume;
	private ProfilingSampler m_profilingSampler =
		new ProfilingSampler("Volumetric Light");

	// private int _RandomNumber = Shader.PropertyToID("_RandomNumber");
	private int _Intensity = Shader.PropertyToID("_Intensity");
	private int _StepTime = Shader.PropertyToID("_StepTime");
	private int _BlurRange = Shader.PropertyToID("_BlurRange");
	private int _LightTex = Shader.PropertyToID("_LightTex");

	private float currentBlurRange;
	private float blurRange;
	
	public VolumetricLightRenderPass(Material volumetricLightMat, Material 
			blurMat, Material blendMat)
	{
		this.volumetricLightMat = volumetricLightMat;
		this.blurMat = blurMat;
		this.blendMat = blendMat;
		rtd = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default, 0);
		// rtd.msaaSamples = 1;
		
		rtd1 = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default, 0);
		rtd1.msaaSamples = 1;
		
		rtd2 = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default, 0);
		rtd2.msaaSamples = 1;
	}
	
	public override void Configure(CommandBuffer cmd,
		RenderTextureDescriptor cameraTextureDescriptor)
	{
		volume = VolumeManager.instance.stack.GetComponent<VolumetricLightVolume>();
		if (volume.IsActive())
		{
			// 用于pass0
			rtd.width = cameraTextureDescriptor.width;
			rtd.height = cameraTextureDescriptor.height;
			RenderingUtils.ReAllocateIfNeeded(ref rt, rtd);
			
			// 用于pass1, blur
			rtd1.width = cameraTextureDescriptor.width / volume
				.blurDownSample.value;
			rtd1.height = cameraTextureDescriptor.height / volume
				.blurDownSample.value;
			RenderingUtils.ReAllocateIfNeeded(ref rt1, rtd1);

			if (volume.blurExtraTimes.value > 0)
			{
				rtd2.width = cameraTextureDescriptor.width/ volume
					.blurDownSample.value;
				rtd2.height = cameraTextureDescriptor.height/ volume
					.blurDownSample.value;
				RenderingUtils.ReAllocateIfNeeded(ref rt2, rtd2);
			}
		}
		
		// 这里的清除倒是有用
		ConfigureTarget(rt);
		ConfigureClear(ClearFlag.Color, Color.black);
	}
	
	public override void Execute(ScriptableRenderContext context,
		ref RenderingData renderingData)
	{
		if (!renderingData.cameraData.postProcessEnabled)
			return;
		
		if (!volume.IsActive())
			return;
		
		cameraRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
		// ConfigureTarget(rt, cameraRT);

		CommandBuffer cmd = CommandBufferPool.Get();
		using (new ProfilingScope(cmd, m_profilingSampler))
		{
			volumetricLightMat.SetFloat(_Intensity, volume.intensity.value);
			volumetricLightMat.SetFloat(_StepTime, volume.stepTimes.value);
			
			cmd.Blit(cameraRT, rt, volumetricLightMat, 0);
			// 这里的cameraRT并没有使用到, 只用到了CameraDepthTexture
			
			// 除了Blit可以调用Pass以外, 还有其他方式吗?
			
			blurRange = volume.blurRange.value;
			currentBlurRange = blurRange;
			blurMat.SetFloat(_BlurRange, currentBlurRange);
			
			Blit(cmd, rt, rt1, blurMat, 0);
			for (int i = 0; i < volume.blurExtraTimes.value; i++)
			{
				currentBlurRange += blurRange;
				blurMat.SetFloat(_BlurRange, currentBlurRange);
				Blit(cmd, rt1, rt2, blurMat, 0);
				(rt1, rt2) = (rt2, rt1);
			}
			
			// 这里rt1是模糊后的lightTex
			blendMat.SetTexture(_LightTex, rt1);
			//
			Blit(cmd, cameraRT, rt, blendMat, 0);
			Blit(cmd, rt, cameraRT);
			
			// test, 模糊后的输入结果
			// Blit(cmd, rt1, cameraRT);

			// // test, 仅看volumetricLight的输出结果
			// volumetricLightMat.SetFloat(_Intensity, volume.intensity.value);
			// volumetricLightMat.SetFloat(_StepTime, volume.stepTimes.value);
			// // Blit(cmd, cameraRT, rt, volumetricLightMat, 0); // 这里反而不能使用Blit? 这是为什么? 
			// // Blitter.BlitTexture(cmd, cameraRT, rt, volumetricLightMat, 0);
			// // Blitter也不行
			// cmd.Blit(cameraRT, rt, volumetricLightMat, 0);
			// // 这一步导致了rt为黑, 为什么? 直接输出白色也为黑?
			// Blit(cmd, rt, cameraRT);
			// // 结果是什么都没有
		}
		// rt.Release();
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}
	
	public void Dispose()
	{
		rt?.Release();
		rt = null;
	}
}

public class VolumetricLightVolume : VolumeComponent, IPostProcessComponent
{
	public FloatParameter intensity = new ClampedFloatParameter(0f, 0f, 2f);
	public IntParameter stepTimes = new ClampedIntParameter(16, 1, 64);
	public IntParameter blurDownSample = new ClampedIntParameter(1, 1, 8);
	public IntParameter blurExtraTimes = new ClampedIntParameter(0, 0, 6);
	public FloatParameter blurRange = new ClampedFloatParameter(1f, 0.1f, 10f);
	
	public bool IsActive()
	{
		return active && intensity.value > 0f;
	}

	public bool IsTileCompatible()
	{
		return false;
	}
}