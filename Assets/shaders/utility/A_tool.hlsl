#if !defined(A_Tool_Include)
#define A_Tool_Include

float4 OutputTestColor(float parameter)  
{  
    return float4(parameter, parameter, parameter, 1);  
}  
  
float4 OutputTestColor(float3 color)  
{  
    return float4(color, 1);  
}  
  
float4 OutputTestColor(float4 outputColor)  
{  
    return outputColor;  
}

float4 OutputTestColor(half3 color)
{
    return float4(color, 1);
}

void remap(float In, float2 inMinMax, float2 outMinMax, out float Out)
{
    Out = outMinMax.x + (In - inMinMax.x) * (outMinMax.y - outMinMax.x) / 
    (inMinMax.y - inMinMax.x);
}

#endif