Shader "A/Kawase Blur"
{
    HLSLINCLUDE
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    
    float4 _BlitTexture_TexelSize;
    float _BlurRange;

    float4 KawaseBlurFrag(Varyings input) : SV_Target
    {
        _BlurRange /= 1000;
        float3 tex = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, 
        input.texcoord).rgb;
        tex += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
            input.texcoord +
            float2(-1,-1) * _BlurRange * _ScreenParams.xy / 
            _BlitTexture_TexelSize.zw
            );
        tex += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
            input.texcoord +
            float2(1,1) * _BlurRange * _ScreenParams.xy / 
            _BlitTexture_TexelSize.zw
            );
        tex += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
            input.texcoord +
            float2(1,-1) * _BlurRange * _ScreenParams.xy / 
            _BlitTexture_TexelSize.zw
            );
        tex += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,
            input.texcoord +
            float2(-1,1) * _BlurRange * _ScreenParams.xy / 
            _BlitTexture_TexelSize.zw
            );
        return float4(tex / 5, 1);
    }
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        ZWrite Off Cull Off
        Pass
        {
            Name "BlurPassVertical"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment KawaseBlurFrag
            
            ENDHLSL
        }
    }
}