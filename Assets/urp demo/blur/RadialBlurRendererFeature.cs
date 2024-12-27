

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RadialBlurRendererFeature: ScriptableRendererFeature
{
	private RadialBlurRenderPass pass;
	[SerializeField] private Material material;
	public bool enable = false;

	public RenderPassEvent renderPassEvent =
		RenderPassEvent.AfterRenderingOpaques;
	
	public override void Create()
	{
		if (enable)
		{
			pass = new RadialBlurRenderPass(material);
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

public class RadialBlurRenderPass : ScriptableRenderPass
{
	private Material material;
	private RTHandle cameraRT;
	private RTHandle rt;
	
	private RenderTextureDescriptor rtd;
	private RadialBlurVolume volume;
	
	private int loopCount;
	private float blurRange;
	private float x;
	private float y;

	private ProfilingSampler m_profilingSampler =
		new ProfilingSampler("Blur");

	private int _BlurRange;
	private int _LoopCount;
	private int _X;
	private int _Y;
	
	public RadialBlurRenderPass(Material material)
	{
		this.material = material;
		rtd = new RenderTextureDescriptor(
			Screen.width,
			Screen.height,
			RenderTextureFormat.Default, 0);
		rtd.msaaSamples = 1;
		_BlurRange = Shader.PropertyToID("_BlurRange");
		_LoopCount = Shader.PropertyToID("_LoopCount");
		_X = Shader.PropertyToID("_X");
		_Y = Shader.PropertyToID("_Y");
	}

	public override void Configure(CommandBuffer cmd,
		RenderTextureDescriptor cameraTextureDescriptor)
	{
		volume = VolumeManager.instance.stack.GetComponent<RadialBlurVolume>();
		if (volume.IsActive())
		{
			rtd.width = cameraTextureDescriptor.width / volume.downSample.value;
			rtd.height = cameraTextureDescriptor.height / volume.downSample.value;
			RenderingUtils.ReAllocateIfNeeded(ref rt, rtd);
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
			material.SetFloat(_X, x);
			material.SetFloat(_Y, y);
			material.SetInt(_LoopCount, loopCount);
			material.SetFloat(_BlurRange, blurRange);
			Blit(cmd, cameraRT, rt, material, 0); 
			Blit(cmd, rt, cameraRT);
		}
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}

	public void UpdateShaderParameters()
	{
		loopCount = volume.loopCount.value;
		blurRange = volume.blurRange.value;
		x = volume.x.value;
		y = volume.y.value;
	}

	public void Dispose()
	{
		rt?.Release();
		rt = null;
	}
}

public class RadialBlurVolume: VolumeComponent, IPostProcessComponent
{
	public FloatParameter blurRange = new ClampedFloatParameter(0f, 0f, 10f);
	public IntParameter loopCount = new ClampedIntParameter(1, 1, 8);
	public FloatParameter x = new ClampedFloatParameter(0.5f, 0f, 1f);
	public FloatParameter y = new ClampedFloatParameter(0.5f, 0f, 1f);
	public IntParameter downSample = new ClampedIntParameter(1, 1, 8);
	
	public bool IsActive()
	{
		return active && blurRange.value > 0f;
	}

	public bool IsTileCompatible()
	{
		return false;
	}
}