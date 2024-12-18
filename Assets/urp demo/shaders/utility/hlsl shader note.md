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

# misc
Material的判空只能通过重载的!=, 不能使用is not null