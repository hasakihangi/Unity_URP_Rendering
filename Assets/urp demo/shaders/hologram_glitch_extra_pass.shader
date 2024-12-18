Shader "A/hologram_glitch_extra_pass"
{
    Properties
    {
        _BaseColor("Base Color(RGB) Alpha(A)", Color) = (1,1,1,1)
        [HDR]_FresnelColor("Fresnel Color(RGB)", Color) = (1,1,1,1)
        [NoScaleOffset][MainTexture]_AlbedoTexture("Albedo Texture(To Detail)", 2D) = "white" {}
        [NoScaleOffset]_NormalTexture("Normal Texture(To Detail)", 2D) = "white" {}
        _FlickingSpeed("Flicking Speed", Float) = 1
        // Edge1 <= Edge2
        _FlickingSmoothStep("Flicking SmoothStep(01 to Nonlinear, X: Edge1, Y: Edge2)", Vector) = (0,1,0,0)
        _FlickingIntensity("Flicking Intensity", Range(0,1)) = 0.8
        _FresnelPower1("Fresnel Power 1(To Color)", Float) = 10
        _FresnelPower2("Fresnel Power 2(To Alpha)", Float) = 1 
        [HDR]_ScanColor("Scan Color(RGB)", Color) = (1,1,1,1)
        _ScanTilling_Thick("Scan Tilling _Thick", Float) = 1
        _ScanSpeed_Thick("Scan Speed _Thick", Float) = 1
        _ScanTilling_Thin("Scan Tilling _Thin", Float) = 1
        _ScanSpeed_Thin("Scan Speed _Thin", Float) = 1
        _GlitchTilling("Glitch Tilling", Float) = 1
        _GlitchSpeed("Glitch Speed", Float) = 1
        _GlitchNoiseScale("Glitch Noise Scale", Float) = 50
        _GlitchViewVertexOffset("Glitch Vertex Offset", Float) = 5
    }
    SubShader
    {
        Tags { 
            "RenderType"="Transparent+5" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Transparent" 
        }
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "utility/A_tool.hlsl"
        #include "utility/A_noise.hlsl"
        float _GlitchTilling;
        float _GlitchSpeed;
        float _GlitchNoiseScale;
        float _GlitchViewVertexOffset;

        struct appdata
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float4 vertex : SV_POSITION;
            float3 worldPos : TEXCOORD0;
            float3 worldNormal: TEXCOORD1;
            float2 uv : TEXCOORD2;
            float test: TEXCOORD3;
        };
        
        v2f vert (appdata v)
        {
            v2f o;
            o.worldPos = TransformObjectToWorld(v.vertex.xyz);

            // glitch
            float glitchY = o.worldPos.y * _GlitchTilling + _Time.y * _GlitchSpeed;
            float2 glitchNoiseUV = float2(0.5, glitchY);
            float glitchNoise;
            Unity_SimpleNoise_float(glitchNoiseUV, _GlitchNoiseScale, 
            glitchNoise);
            glitchNoise = glitchNoise * 2 - 1;

            // glitch flicking
            float glitchFlicking;
            Unity_SimpleNoise_float(float2(_Time.y, 0),
            10, glitchFlicking);
            glitchFlicking = smoothstep(0.3, 0.8, glitchFlicking);

            float3 viewPos = TransformWorldToView(o.worldPos);
            viewPos += float3(_GlitchViewVertexOffset*0.01*glitchNoise*glitchFlicking, 0, 0);

            float3 objectPos = TransformWorldToObject(mul
            (UNITY_MATRIX_I_V, float4(viewPos, 1) ).xyz);
            
            o.test = glitchFlicking;
            o.vertex = TransformObjectToHClip(objectPos);
            o.worldNormal = TransformObjectToWorldNormal(v.normal);
            o.uv = v.uv;
            return o;
        }
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode"="SRPDefaultUnlit"
            }
            ColorMask 0
            ZWrite On
            Blend Off
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            float4 frag (v2f i) : SV_Target
            {
                return float4(0, 0, 0, 0); // 仅写入深度，无颜色输出
            }
            
            ENDHLSL
        }
        
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha 
            ZWrite Off
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "utility/A_tool.hlsl"
            #include "utility/A_noise.hlsl"
            
            float4 _BaseColor;
            float _FlickingSpeed;
            float2 _FlickingSmoothStep;
            float _FlickingIntensity;
            float _FresnelPower1;
            float _FresnelPower2;
            float _ScanTilling_Thick;
            float _ScanSpeed_Thick;
            float _ScanTilling_Thin;
            float _ScanSpeed_Thin;
            float3 _ScanColor;
            float3 _FresnelColor;

            TEXTURE2D(_AlbedoTexture);
            SAMPLER(sampler_AlbedoTexture);
            TEXTURE2D(_NormalTexture);
            SAMPLER(sampler_NormalTexture);
            
            static float flickingNoiseScale = 50;
            
            half4 frag (v2f i) : SV_Target
            {
                // Texture
                half4 albedoColor = SAMPLE_TEXTURE2D(_AlbedoTexture, 
                sampler_AlbedoTexture, i.uv);
                half4 detailColor = SAMPLE_TEXTURE2D(_NormalTexture, 
                sampler_NormalTexture, i.uv);
                half albedo = albedoColor.r;
                remap(albedo, float2(0,1), float2(0.6, 1), albedo);
                half detail = detailColor.a;
                // 提高对比度, smoothstep
                detail = smoothstep(0.45, 0.55, detail);
                remap(detail, float2(0,1), float2(0.3, 1), detail);
                // fresnel
                float3 view = GetWorldSpaceNormalizeViewDir(i.worldPos);
                i.worldNormal = normalize(i.worldNormal);
                float fresnel = saturate(1-dot(view, i.worldNormal));
                float fresnelPow1 = pow(fresnel, _FresnelPower1);
                float fresnelPow2 = pow(fresnel, _FresnelPower2);
                // flicking
                float2 flickingNoiseUv = float2(0.2 + _Time.y, 0.5);
                float flickingNoise;
                Unity_SimpleNoise_float(flickingNoiseUv, flickingNoiseScale, 
                flickingNoise); // ?
                // 为什么始终返回0? 因为shader不支持const
                flickingNoise = smoothstep(_FlickingSmoothStep.x, 
                _FlickingSmoothStep.y, flickingNoise);
                flickingNoise = lerp(1,flickingNoise,_FlickingIntensity);

                // scanline
                float yThick = i.worldPos.y * _ScanTilling_Thick + 
                _ScanSpeed_Thick * _Time.y;
                float yThin = i.worldPos.y * _ScanTilling_Thin + 
                _ScanSpeed_Thin * _Time.y;
                float scanlineThick = frac(yThick);
                float scanlineThin = max(sin(yThin), 0.6);
                // 这两个会作用在alpha值上, 考虑是+还是*, 应该是*
                // 提高最小阈值, 使用max
                scanlineThick = pow(scanlineThick, 6);
                scanlineThin = pow(scanlineThin, 0.5);

                // 似乎frenel作用在alpha值上效果并不是很好
                half4 finalColor;
                finalColor.rgb = (_BaseColor.rgb + _ScanColor * scanlineThick
                 * saturate(scanlineThick + 0.6) 
                + fresnelPow1 * _FresnelColor) * albedo;
                // finalColor.a = _BaseColor.a * fresnel * flickingNoise * 
                // scanlineThin;
                finalColor.a = _BaseColor.a * fresnelPow2 * scanlineThin * 
                detail * flickingNoise * saturate(scanlineThick + 0.6);
                return OutputTestColor(finalColor);
            }
            ENDHLSL
        }
    }
}