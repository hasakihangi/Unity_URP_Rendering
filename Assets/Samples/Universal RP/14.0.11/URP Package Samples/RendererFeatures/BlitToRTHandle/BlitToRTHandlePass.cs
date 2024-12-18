using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// This pass creates an RTHandle and blits the camera color to it.
// The RTHandle is then set as a global texture, which is available to shaders in the scene.
public class BlitToRTHandlePass : ScriptableRenderPass
{
	private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("BlitToRTHandle_CopyColor");
	private RTHandle m_InputHandle;
	private RTHandle m_OutputHandle;
	private const string k_OutputName = "_CopyColorTexture";
	private int m_OutputId = Shader.PropertyToID(k_OutputName);
	private Material m_Material;

	public BlitToRTHandlePass(RenderPassEvent evt, Material mat)
	{
		renderPassEvent = evt;
		m_Material = mat;
	}

	public void SetInput(RTHandle src)
	{
		// The Renderer Feature uses this variable to set the input RTHandle.
		m_InputHandle = src;
	}

	public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
	{
		// Debug.Log("Configure: " + renderPassEvent);
		// Configure the custom RTHandle
		var desc = cameraTextureDescriptor;
		// Debug.Log(desc.msaaSamples);
		desc.depthBufferBits = 0;
		desc.msaaSamples = 1;
		desc.height /= 2;
		desc.width /= 2;
		RenderingUtils.ReAllocateIfNeeded(ref m_OutputHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: k_OutputName);

		// Set the RTHandle as the output target
		// ConfigureTarget(m_OutputHandle);
		// ConfigureTarget(m_InputHandle); // 这东西直接代指的camera的texture, 所以不能直接用这个,
		// ConfigureClear(ClearFlag.All, Color.red);
	}

	public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
	{
		// Debug.Log("Execute: " + renderPassEvent);
		CommandBuffer cmd = CommandBufferPool.Get();
		using (new ProfilingScope(cmd, m_ProfilingSampler))
		{
			// Blit the input RTHandle to the output one
			Blitter.BlitCameraTexture(cmd, m_InputHandle, m_OutputHandle, m_Material, 0);
			// 如果直接设置呢?
			// 直接设置也能起作用, 但是阶段会失效


			// Make the output texture available for the shaders in the scene
			cmd.SetGlobalTexture(m_OutputId, m_OutputHandle.nameID);
			//cmd.SetGlobalTexture(m_OutputId, m_InputHandle);
		}
		context.ExecuteCommandBuffer(cmd);
		cmd.Clear();
		CommandBufferPool.Release(cmd);
	}

	public void Dispose()
	{
		m_InputHandle?.Release();
		m_OutputHandle?.Release();
	}
}