Shader "A/Blend"
{
    // 用于传回cameraRT, 没有downSample
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        ZTest Always ZWrite Off Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            TEXTURE2D(_LightTex); // 与cameraRT的分辨率是对应的? 不是对应的, 这个会downSample, 需要为_LightTex处理不同分辨率的情况, input.texcoord已经处理好了?

            half4 frag (Varyings input) : SV_Target
            {
                float3 blit = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;
                float3 lightTex = SAMPLE_TEXTURE2D(_LightTex, 
                sampler_LinearClamp, input.texcoord).rgb;
	    	    return float4(blit + lightTex, 1);
            }
            ENDHLSL
        }
    }
}