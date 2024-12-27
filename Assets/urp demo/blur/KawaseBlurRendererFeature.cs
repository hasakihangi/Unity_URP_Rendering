

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class KawaseBlurRendererFeature: ScriptableRendererFeature
{
	private KawaseBlurRenderPass pass;
	[SerializeField] private Material material;
	public bool enable = false;

	public RenderPassEvent renderPassEvent =
		RenderPassEvent.AfterRenderingOpaques;
	
	public override void Create()
	{
		if (enable)
		{
			pass = new KawaseBlurRenderPass(material);
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

public class KawaseBlurRenderPass : ScriptableRenderPass
{
	private Material material;
	private RTHandle cameraRT;
	private RTHandle rt1;
	private RTHandle rt2;
	private RenderTextureDescriptor rtd;
	private KawaseBlurVolume volume;
	private int blurExtraTimes;
	private float blurRange;

	private ProfilingSampler m_profilingSampler =
		new ProfilingSampler("Blur");

	private int _BlurRange;
	
	public KawaseBlurRenderPass(Material material)
	{
		this.material = material;
		rtd = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default, 0);
		rtd.msaaSamples = 1;
		_BlurRange = Shader.PropertyToID("_BlurRange");
	}

	public override void Configure(CommandBuffer cmd,
		RenderTextureDescriptor cameraTextureDescriptor)
	{
		volume = VolumeManager.instance.stack.GetComponent<KawaseBlurVolume>();
		if (volume.IsActive())
		{
			rtd.width = cameraTextureDescriptor.width / volume.downSample.value;
			rtd.height = cameraTextureDescriptor.height / volume.downSample.value;
			// 一般是写在这里, 可以提前安排?
			// RenderingUtils.ReAllocateIfNeeded(ref rt, rtd);
			RenderingUtils.ReAllocateIfNeeded(ref rt1, rtd);

			if (volume.blurExtraTimes.value > 0)
			{
				RenderingUtils.ReAllocateIfNeeded(ref rt2, rtd);
			}
		}
	}

	public override void Execute(ScriptableRenderContext context,
		ref RenderingData renderingData)
	{
		if (!volume.IsActive())
			return;
		// prepare
		UpdateShaderParameters();
		cameraRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
		
		CommandBuffer cmd = CommandBufferPool.Get();
		
		using (new ProfilingScope(cmd, m_profilingSampler))
		{
			float currentBlurRange = blurRange;
			material.SetFloat(_BlurRange, currentBlurRange);
			
			// 第一次是必要的, 降低采样生效
			Blit(cmd, cameraRT, rt1, material, 0);
			// // for (int i = 0; i < blurTimes; i++)
			// {
			// 	// material.SetFloat(_BlurRange, (i+1) * blurRange);
			// 	material.SetFloat(_BlurRange, blurRange);
			// 	Blit(cmd, rt1, rt2, material, 0);
			// 	// (rt1, rt2) = (rt2, rt1); 
			// 	// 仅仅只是交换引用? 可以进行引用交换吗? 引用交换是可以的
			// 	// Blit是操作的引用的实际内容
			// 	// 使用交换会报错
			// 	var tempRT = rt2;
			// 	rt2 = rt1;
			// 	rt1 = tempRT;
			// 	// rt1是摄像机的rt, rt2是申请的rt, 交换过后, rt2变成了摄像机的rt, 用这张rt去RenderingUtils.ReAllocateIfNeeded会出问题
			// }
			
			// rt1向rt1里面blur不就行了? 不行, 会变黑
			for (int i = 0; i < blurExtraTimes; i++)
			{
				currentBlurRange += blurRange;
				material.SetFloat(_BlurRange, currentBlurRange);Blit(cmd,
					rt1, rt2, material, 0);
				// 交换rt1和rt2, 将rt2里面的结果传到rt1
				(rt1, rt2) = (rt2, rt1);
			}
			
			
			currentBlurRange += blurRange;
			material.SetFloat(_BlurRange, currentBlurRange);
			
			// 最后一次也是必要的, 这里降低采样不会生效
			Blit(cmd, rt1, cameraRT, material, 0);
			// 不需要循环, 两次足够了, 循环是因为downSample
			// 应该是可以交换的, 只不过最后要换回来
		}
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}

	private void UpdateShaderParameters()
	{
		blurExtraTimes = volume.blurExtraTimes.value;
		blurRange = volume.blurRange.value / 1000;
	}

	public void Dispose()
	{
		rt1?.Release();
		rt2?.Release();
		rt1 = null;
		rt2 = null;
		cameraRT = null;
	}
}

public class KawaseBlurVolume : VolumeComponent, IPostProcessComponent
{
	public IntParameter blurExtraTimes =
		new ClampedIntParameter(0, 0, 4);

	public FloatParameter blurRange =
		new ClampedFloatParameter(0.0f, 0.0f, 10.0f);

	public IntParameter downSample = new ClampedIntParameter(1, 1, 8);
	
	// 至少有一次blur, 才表示启用, 否则在Execute中直接return
	public bool IsActive() => active &&  blurRange.value >
		0f;

	public bool IsTileCompatible()
	{
		throw new System.NotImplementedException();
	}
}