Shader "A/DecalCube"
{
    Properties
    {
        [MainTexture] _DecalTex("Decal Texture", 2D) = "white" {} 
    }
    SubShader
    {
        Tags { 
            "RenderType"="Transparent" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Transparent" 
        }
        
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            TEXTURE2D(_DecalTex);
            SamplerState sampler_LinearClamp;
            
            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.vertex.xy / _ScaledScreenParams.xy;
                    // 0 to 1 在屏幕的uv
                // 重建的是已经存在的像素在世界坐标的位置, 并不是这个物体的坐标

                // real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
                // UNITY_NEAR_CLIP_VALUE在d3d11是1
                // 在opengl是-1
                
                #if UNITY_REVERSED_Z 
                    real depth = SampleSceneDepth(uv); // 使用CameraDepthTexture
                #else
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, 
                    SampleSceneDepth(uv));
                #endif
                // 需要转到的是clipPos, clipPos在D3D11的表现是1~0, 在opengl表现是-1~1
                float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP); // 其中考虑了UNITY_UV_STARTS_AT_TOP

                 float3 objectPos = mul(UNITY_MATRIX_I_M, float4(worldPos, 1));

                float4 tex = SAMPLE_TEXTURE2D(_DecalTex, 
                sampler_LinearClamp, objectPos.xy + 0.5);

                float alpha = step(float3(-0.5,-0.5,-0.5), objectPos) - step
                (float3(0.5,0.5,0.5), objectPos);
                
                float4 finalColor;
                finalColor.rgb = tex.rgb;
                finalColor.a = alpha * tex.a;
                return finalColor;
            }
            ENDHLSL
        }
    }
    Fallback Off
}