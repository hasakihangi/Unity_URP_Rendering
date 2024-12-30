Shader "A/VolumetricCloud"
{
    Properties
    {
        _VolumeTex("Volume Texture", 3D) = "white" {}
        _NumSteps("Number of Steps", Integer) = 32
        _StepSize("Step Size", Float) = 0.02
        _DensityScale("Density Scale", Float) = 0.2
        _OffsetScale("Offset Scale(XYZ)", Vector) = (0.5, 0.5, 0.5, 0)
        _NumLightSteps("Number of Light Steps", Integer) = 16
        _LightStepSize("Light Step Size", Float) = 0.06
        _LightAbsorb("Light Absorb", Float) = 2.0
        _DarknessThreshold("Darkness Threshold", Float) = 0.15
        _Transmittance("Transmittance", Float) = 0.9
        _CloudColor("Cloud Color(RGB)", Color) = (1,1,1,1)
        _ShadowColor("Shadow Color(RGB)", Color) = (0.5, 0.6, 0.7, 1)
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
            
            // _VolumeTex
            // _NumSteps
            // _StepSize
            // _DensityScale
            // _OffsetScale
            // _NumLightSteps
            // _LightStepSize
            
            
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