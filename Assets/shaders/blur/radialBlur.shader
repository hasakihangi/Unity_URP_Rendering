Shader "A/Radial Blur"
{
    HLSLINCLUDE
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    
    float4 _BlitTexture_TexelSize;
    float _BlurRange;
    int _LoopCount;
    float _X;
    float _Y;

    float4 RadialBlurFrag(Varyings input) : SV_Target
    {
        float3 col = 0;
        float2 dir = (float2(_X, _Y) - input.texcoord) * _BlurRange * 0.01;
        for (int t=0; t < _LoopCount; t++)
        {
            col += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
            input.texcoord += dir * _ScreenParams.xy / _BlitTexture_TexelSize.zw;
        }
        return float4(col/_LoopCount, 1);
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
            #pragma fragment RadialBlurFrag
            
            ENDHLSL
        }
    }
}