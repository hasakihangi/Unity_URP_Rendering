using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditor;

public class BlurRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private BlurSettings settings;
    [SerializeField] private Shader shader;
    private Material material;
    private BlurRenderPass blurRenderPass;

    // 仅在初始化时调用
    public override void Create()
    {
        if (shader == null)
        {
            return;
        }
        material = new Material(shader);
        blurRenderPass = new BlurRenderPass(material, settings);

        blurRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    // 每帧调用
    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType == CameraType.Game)
        {
            renderer.EnqueuePass(blurRenderPass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        blurRenderPass.Dispose();
#if UNITY_EDITOR
            if (EditorApplication.isPlaying)
            {
                Destroy(material);
            }
            else
            {
                DestroyImmediate(material);
            }
#else
        Destroy(material);
#endif
    }

    [System.Serializable]
    public class BlurSettings
    {
        [Range(0, 0.4f)] public float horizontalBlur;
        [Range(0, 0.4f)] public float verticalBlur;
    }

    public class BlurRenderPass : ScriptableRenderPass
    {
        private static readonly int horizontalBlurId = Shader.PropertyToID("_HorizontalBlur");
        private static readonly int verticalBlurId = Shader.PropertyToID("_VerticalBlur");

        private BlurSettings defaultSettings;
        private Material material;

        private RenderTextureDescriptor blurTextureDescriptor;
        private RTHandle blurTextureHandle;

        public BlurRenderPass(Material material, BlurSettings defaultSettings)
        {
            this.material = material;
            this.defaultSettings = defaultSettings;
            blurTextureDescriptor = new RenderTextureDescriptor(
            Screen.width,
            Screen.height,
            RenderTextureFormat.Default, 0
        );
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            blurTextureDescriptor.width = cameraTextureDescriptor.width;
            blurTextureDescriptor.height = cameraTextureDescriptor.height;
            RenderingUtils.ReAllocateIfNeeded(ref blurTextureHandle, blurTextureDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            RTHandle cameraTargetHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;
            UpdateBlurSettings();
            // 为什么是两次? 因为横向一次, 纵向一次
            Blit(cmd, cameraTargetHandle, blurTextureHandle, material, 0);
            Blit(cmd, blurTextureHandle, cameraTargetHandle, material, 1);
            // 设置到了shader中的_BlitTexture上
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void UpdateBlurSettings()
        {
            if (material == null) return;
            material.SetFloat(horizontalBlurId, defaultSettings.horizontalBlur);
            material.SetFloat(verticalBlurId, defaultSettings.verticalBlur);
        }

        public void Dispose()
        {
#if UNITY_EDITOR
                if (EditorApplication.isPlaying)
                {
                    Object.Destroy(material);
                }
                else
                {
                    Object.DestroyImmediate(material);
                }
#else
            Object.Destroy(material);
#endif

            if (blurTextureHandle != null) blurTextureHandle.Release();
        }
    }
}