## fresnel
```
// vert
o.worldPos = TransformObjectToWorld(v.vertex.xyz);
o.worldNormal = TransformObjectToWorldNormal(v.normal);

// frag
float3 view = GetWorldSpaceNormalizeViewDir(i.worldPos);
i.worldNormal = normalize(i.worldNormal);
float fresnel = 1-dot(view, i.worldNormal);
fresnel = pow(fresnel, _FresnelPower);
```

## hlsl function
```
smoothstep(min, max, x)
clmap(x, min, max)
```

# point
## sample
TEXTURE2D(_BaseTex);
SAMPLER(sampler_BaseTex);
float4 baseColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex,
i.uv);

# misc
Material的判空只能通过重载的!=, 不能使用is not null

# hlsl template
## lit
```

```
## transparent
```
Shader "A/..."
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        [HDR] _Emission("Emission", Color) = (0,0,0,0)
        [NoScaleOffset]_BaseMap("Base Map", 2D) = "white" {}
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
            
            float4 _BaseColor;
            float4 _Emission;
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
                return _BaseColor + _Emission;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
```