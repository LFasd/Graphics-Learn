Shader "Light/Oren-Nayar"
{
    Properties
    {
        _Color ("MainColor", Color) = (1,1,1,1)

        // 粗糙度
        _Roughness ("Roughness", Range(0, 1)) = 0.02
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;                
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            fixed3 _Color;
            float _Roughness;

            v2f vert (a2v v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.worldNormal);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                // 粗糙度平方
                float rough2 = _Roughness * _Roughness;

                float A = 1 - 0.5 * rough2 / (rough2 + 0.33);
                float B = 0.45 * rough2 / (rough2 + 0.09);

                // 分别计算灯光和视线方向在法线方向的边长，并用反三角函数计算出角度
                float normalDotView = dot(normal, viewDir);
                float normalDotLight = dot(normal, lightDir);
                float angleView = acos(normalDotView);
                float angleLight = acos(normalDotLight);

                float alpha = max(angleLight, angleView);
                float beta = min(angleLight, angleView);

                // 计算出灯光和视角方向在平面上的投影，标准化后用于计算纬线上的偏差
                float3 viewProject = normalize(viewDir - normalDotView * normal);
                float3 lightProject = normalize(lightDir - normalDotLight * normal);
                float lightPDotViewP = max(0, dot(viewProject, lightProject));

                fixed3 light = max(0, normalDotLight) * (A + (B * lightPDotViewP * sin(alpha) * tan(beta)));

                return fixed4(light * _Color.rgb, 1.0);
            }
            ENDCG
        }
    }
}
