Shader "A_Cartoon/narmaya_cartoon"
{
    Properties
    {
        _BaseTex ("Base Texture", 2D) = "white" {}
        _DarkTex ("Dark Texture", 2D) = "grey" {}
        _ILMTex ("LIM Texture", 2D) = "white" {}
        _DecalTex ("Decal Texture", 2D) = "white" {}
        _DetailTex ("Detail Texture", 2D) = "white" {}
        
        _ToonEdge ("Toon Edge", Range(0,1)) = 0.5
        _ToonSoftness ("Toon Softness", Range(0,0.4)) = 0.1
        
        _DiffuseControlIntensity("Diffuse Control Intensity", Range(0,1)) = 0.8
        
        _SpecLightViewLerp("Spec Light View Lerp", Range(0,1)) = 0.5
        _SpecSize("Spec Size", Float) = 0.1
        _SpecColor("Spec Color(RGB) Intensity(A)", Color) = (1,1,1,1)
        _SpecColorLerp("Spec Color Lerp, 0:BaseColor, 1:SpecColor", Range(0,1)) = 1
        
        // another directional light
        _AnotherLightDirection("Another Light Direction(XYZ)", 
        Vector) = (1,1,1,1)
        // 因为不变的是相机空间(view)下的向量, 所以这个值要视为相机空间下的量, 然后转到世界坐标下
//        _AnotherLightEulerAngle("Another Light Euler Angel(XYZ) Intensity(A)", Vector) = (0,0,0,1)
        // 好做吗? 正确的方式应该是使用ShaderEditor脚本, 在编辑器下拖动编辑后, 传到对应的Material中
        _FillLightEdge("Fill Light Edge", Range(0,1)) = 0.5
        _FillLightSoftness("Fill Light Softness", Range(0, 0.3)) = 0.1
        [HDR]_FillLightColor("Fill Light Color(RGB) Intensity(A)", Color) = (1,1,1,1)
        _BaseToFillLightLerp("Base To Fill Light Lerp", Range(0,1)) = 0.5
        
        _OutlineWidth("Outline Width", Float) = 1.0
        _OutlineColor("Outline Color(RGB) LerpToBlack(A)", Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "RenderPipeline"="UniversalPipeline"
        }
        
        HLSLINCLUDE

         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../utility/A_tool.hlsl"

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_DarkTex);
            SAMPLER(sampler_DarkTex);
            TEXTURE2D(_ILMTex);
            SAMPLER(sampler_ILMTex);
            TEXTURE2D(_DecalTex);
            SAMPLER(sampler_DecalTex);
            TEXTURE2D(_DetailTex);
            SAMPLER(sampler_DetailTex);

            CBUFFER_START(UnityPerMaterial)
            // diffuse
            float _ToonEdge;
            float _ToonSoftness;
            float _DiffuseControlIntensity;

            // spec
            float _SpecLightViewLerp;
            float _SpecSize;
            half4 _SpecColor;
            float _SpecColorLerp;

            float3 _AnotherLightDirection;
            float4 _AnotherLightEulerAngle;

            float _FillLightEdge;
            float _FillLightSoftness;

            half3 _FillLightColor;
            float _BaseToFillLightLerp;
            // 范围计算都用float, 乘数因子用half
            
            CBUFFER_END
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertexColor : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 test : TEXCOORD3;
                float4 vertex : SV_POSITION;
                float4 vertexColor : TEXCOORD4;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.vertexColor = v.vertexColor;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // decal
                float4 decalColor = SAMPLE_TEXTURE2D(_DecalTex, sampler_DecalTex, i
                .uv);
                decalColor = saturate(decalColor - 0.5);
                
                // ILM
                half4 ILMColor = SAMPLE_TEXTURE2D(_ILMTex, sampler_ILMTex, i.uv);
                // .r -> specRange
                // .g -> diffusceControl
                // .b -> specSize
                // .a -> innerLine

                // DetailTex
                half4 detailColor = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, i
                .uv);

                float diffuseControl = ILMColor.g;
                diffuseControl = diffuseControl * 2 - 1;
                diffuseControl *= _DiffuseControlIntensity;
                
                // diffuse
                i.worldNormal = normalize(i.worldNormal);
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float diffuse = dot(lightDir, i.worldNormal);
                diffuse = (diffuse + 1.0) * 0.5;
                diffuse = i.vertexColor.r * diffuse; // 是在这个地方乘ao吗? 确实是
                // .r -> ao
                // .b -> face outline control
                
                diffuse += diffuseControl;
                float diffuseStep = smoothstep(_ToonEdge - _ToonSoftness/2, 
                _ToonEdge + _ToonSoftness/2, diffuse);
                
                float4 baseColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, 
                i.uv);
                float4 darkColor = SAMPLE_TEXTURE2D(_DarkTex, sampler_DarkTex, 
                i.uv);
                float4 diffuseToon = lerp(darkColor, baseColor, diffuseStep);
                
                
                // spec
                float3 viewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                float specView = dot(viewDir, i.worldNormal);
                specView = specView * 0.5 + 0.5;
                specView = specView * i.vertexColor.r + diffuseControl;
                float spec = lerp(diffuse, specView, _SpecLightViewLerp);
                // float specToon = saturate((spec - (1.0 - ILMColor.b * _SpecSize)) * 500);
                float specEdge = 1.0 - ILMColor.b * _SpecSize;
                // ILMColor.b 是没有高光的区域是黑色, 有高光的区域是白色
                // spec已经圈出来的高光区域, 以ILMColor.b作为分界线, 大于.b的地方显示高光, 小于.b的地方不显示高光
                // 所以.b的值越小表明是高光区域, 越大表明是非高光区域, 需要 1- 进行反向
                // 问题是_SpecSize的值我这里调到15左右才符合效果(极大地扩散了高光区域)
                
                float specStep = smoothstep(specEdge, specEdge, spec);
                float specToon = lerp(baseColor, _SpecColor.rgb, _SpecColorLerp) * 
                specStep * 
                _SpecColor.a * ILMColor.r;

                // 内描线
                half innerLine = ILMColor.a;
                half3 innerLineColor = lerp(baseColor.rgb * 0.2, half3(1,1,1)
                , innerLine);
                innerLine *= detailColor;

                // 边缘光, 在viewSpace进行, 设置的是相机空间的方向光
                float3 anotherLightDir = mul(UNITY_MATRIX_I_V, float4(_AnotherLightDirection.xyz, 1)).xyz;
                anotherLightDir = normalize(anotherLightDir);
                float fillLight = dot(anotherLightDir, i.worldNormal);
                fillLight = fillLight * 0.5 + 0.5;
                float fillLightStep = smoothstep(_FillLightEdge, 
                _FillLightEdge+_FillLightSoftness,
                 fillLight);
                half3 fillLightColor = fillLightStep * lerp(baseColor.rgb, 
                _FillLightColor, _BaseToFillLightLerp);
                fillLightColor = darkColor.a * fillLightColor * diffuseStep;
                
                half4 finalColor; 
                finalColor.rgb = (diffuseToon + specToon + fillLightColor) * innerLine;
                finalColor.rgb = sqrt(max(exp2(log2(max(finalColor.rgb, 0.0)) * 2.2), 0.0));
                finalColor.a = 1.0;
                return OutputTestColor(finalColor);
            }
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
           
            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode"="SRPDefaultUnlit"
            }
            Cull Front
            HLSLPROGRAM

            float _OutlineWidth;
            half4 _OutlineColor;
            
            #pragma vertex vert2
            #pragma fragment frag2

            struct appdata2
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 vertexColor : COLOR;
                float2 uv: TEXCOORD0;
            };

            struct v2f2
            {
                float3 test : TEXCOORD3;
                float4 vertex : SV_POSITION;
                float2 uv: TEXCOORD0;
            };

// float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                // float3 viewNormal =  TransformWorldToView(worldNormal);
                // viewNormal = normalize(viewNormal);
                // viewPos += viewNormal * _OutlineWidth * 0.001 * v.vertexColor.b;
             // o.vertex = TransformObjectToHClip(v.vertex);
            
            v2f2 vert2(appdata2 v)
            {
                v2f2 o;
                float4 viewPos = mul(UNITY_MATRIX_MV, v.vertex);

                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 viewNormal =  TransformWorldToView(worldNormal);
                viewNormal = normalize(viewNormal);
                viewPos.xyz += viewNormal * _OutlineWidth * 0.001 * v
                .vertexColor.b;
                
                o.vertex = mul(UNITY_MATRIX_P, viewPos);
                o.uv = v.uv;
                return o;
            }

            half4 frag2 (v2f2 i) : SV_Target
            {
                float4 baseColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, 
                i.uv);
                half maxComponent = max(max(baseColor.r, baseColor.g), baseColor.b) - 0.004;
                half3 saturatedColor = step(maxComponent.rrr, baseColor) * baseColor;
                saturatedColor = lerp(baseColor.rgb, saturatedColor, 0.6);
                // float3 outlineColor = lerp(baseColor.rgb, _OutlineColor, _OutlineColor.a);
                half3 outlineColor = 0.8 * saturatedColor * baseColor * _OutlineColor.xyz;
                float4 finalColor;
                finalColor.rgb = outlineColor;
                finalColor.a = 1;
                return finalColor;
            }
            
            ENDHLSL
        }
    }
}
