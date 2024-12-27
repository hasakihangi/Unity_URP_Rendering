Shader "A/Blur"
{
    HLSLINCLUDE
    
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // The Blit.hlsl file provides the vertex shader (Vert),
        // the input structure (Attributes), and the output structure (Varyings)
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        float _VerticalBlur;
        float _HorizontalBlur;
    
        float4 _BlitTexture_TexelSize;
    
        float4 BlurVertical (Varyings input) : SV_Target
        {
            // 8 或者 64 都没有什么区别
            const float BLUR_SAMPLES = 8;
            const float BLUR_SAMPLES_RANGE = BLUR_SAMPLES / 2;
            
            float3 color = 0;

            // 表示0.1个屏幕高的距离
            float blurPixels = _VerticalBlur * _ScreenParams.y;
            // _ScreenParams表示target的分辨率(输出)
            // _BlitTexture表示输入的分辨率
            // = _VerticalBlur * _ScreenParams.y / _BlitTexture_TexelSize.w
            // _BlitTexture's uv / _BliTexture's pixels = _Screen' uv / .. (比值式)
            //  =号同一边, a/b 形式下是对照物
            // =号两边, a和b相同位置上是对照物
            // 得到的是Screen'uv的sampleOffset? 对的, 因为要使用屏幕空间的uv来采样Texture的uv
            
            for(float i = -BLUR_SAMPLES_RANGE; i <= BLUR_SAMPLES_RANGE; i++)
            {
                float2 sampleOffset =
                    float2 (0, (blurPixels / _BlitTexture_TexelSize.w) *
                        (i / BLUR_SAMPLES_RANGE));
                color +=
                    SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
                        input.texcoord + sampleOffset).rgb;
                    // clamp会将超过1的部分钳制到1
                    // linear是线性过滤
            }
            
            return float4(color.rgb / (BLUR_SAMPLES + 1), 1);
        }

        float4 BlurHorizontal (Varyings input) : SV_Target
        {
            const float BLUR_SAMPLES = 64;
            const float BLUR_SAMPLES_RANGE = BLUR_SAMPLES / 2;
            
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float3 color = 0;
            float blurPixels = _HorizontalBlur * _ScreenParams.x;
            for(float i = -BLUR_SAMPLES_RANGE; i <= BLUR_SAMPLES_RANGE; i++)
            {
                float2 sampleOffset =
                    float2 ((blurPixels / _BlitTexture_TexelSize.z) *
                        (i / BLUR_SAMPLES_RANGE), 0);
                color +=
                    SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
                        input.texcoord + sampleOffset).rgb;
            }
            return float4(color / (BLUR_SAMPLES + 1), 1);
        }
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "BlurPassVertical"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment BlurVertical
            
            ENDHLSL
        }
        
        Pass
        {
            Name "BlurPassHorizontal"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment BlurHorizontal
            
            ENDHLSL
        }
    }
}