Shader "A/VolumetricLight"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline"}
        ZWrite Off Cull Off
        
        Pass
        {
            // 没有使用BlitTexture, 有使用CameraDepthTexture
            HLSLPROGRAM
            
            
            #define MAIN_LIGHT_CALCULATE_SHADOWS
            #define _MAIN_LIGHT_SHADOWS_CASCADE 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../utility/A_tool.hlsl"

            #define random(seed) sin(seed * 641.5467987313875 + 1.943856175)
            #define MAX_RAY_LENGTH 20

            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float3 positionOS : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                // float3 viewVec : TEXCOORD1; // 用于还原世界坐标
            };

            // float _RandomNumber; 不需要
            float _Intensity;
            float _StepTime;

            float GetLightAttenuation(float3 position)
            {
                float4 shadowPos = TransformWorldToShadowCoord(position);
                float intensity = MainLightRealtimeShadow(shadowPos);
                return intensity;
            }

            v2f vert(appdata i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS);
                return o;
            }

            float4 frag(v2f i): SV_Target
            {
                float2 uv = i.positionCS.xy / _ScaledScreenParams.xy;
                
                #if UNITY_REVERSED_Z 
                real d = SampleSceneDepth(uv); 
                #else
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, 
                SampleSceneDepth(uv));
                #endif
                
                float3 worldPos = ComputeWorldSpacePosition(uv, d, UNITY_MATRIX_I_VP);
                
                float depth = Linear01Depth(d, _ZBufferParams);
                // float eyeDepth = LinearEyeDepth(d,_ZBufferParams);
                
                float3 startPos = _WorldSpaceCameraPos;
                float3 dir = normalize(worldPos - startPos);
                float rayLength = length(worldPos - startPos);
                rayLength = min(rayLength, MAX_RAY_LENGTH);
                
                float3 finalPos = startPos + dir * rayLength;
                float2 step = 1.0 / _StepTime;
                step.y *= 0.4; // 每次扰动的最大值占步长的0.4
                float noise = random(worldPos.x * _ScreenParams.x * 
                _ScreenParams.y); // 可以保证每一个frag都不同
                float intensity = 0;
                for (float currentStep=step.x; currentStep<1; currentStep+=step.x)
                {
                    // 需要每一次循环都不同吗? 不需要, 只需要保证每一个像素点的不同, 使用noise函数效果更好
                    // 每次循环都不同可以形成起雾的效果
                    float3 currentPos = lerp(startPos, finalPos, currentStep + noise * 
                    step.y);
                    float atten = GetLightAttenuation(currentPos);
                    intensity += atten;
                }
                
                intensity /= _StepTime;
                
                Light light = GetMainLight();
                if (depth > 0.3)
                {
                    intensity = 0;
                }
                
                float4 finalColor;
                finalColor.rgb = float3(light.color * intensity * _Intensity);
                finalColor.a = 1;
                
                return OutputTestColor(finalColor);
            }
            ENDHLSL
        }
    }
    Fallback Off
}