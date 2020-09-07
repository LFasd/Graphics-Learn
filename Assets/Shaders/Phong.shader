Shader "Light/Phong"
{
    Properties
    {
        _Color ("MainColor", Color) = (1,1,1,1)
        _Specular ("Specular Color", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(0, 256)) = 1

        [Toggle(_AMBIENT)] _Ambient ("Ambient", Float) = 0
        [Toggle(_DIFFUSE)] _Diffuse ("Diffuse", Float) = 0
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
            #include "Lighting.cginc"

            struct appdata
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

            fixed4 _Color;
            fixed4 _Specular;
            float _Gloss;
            float _Ambient;
            float _Diffuse;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _Ambient;

                float3 normal = normalize(i.worldNormal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

                fixed3 diffuse = _Color.rgb * _LightColor0.rgb * saturate(dot(normal, lightDir)) * _Diffuse;

                // 计算镜面反射光方向
                float3 reflectionDir = 2 * normal * dot(normal, lightDir) - lightDir;
                // float3 reflectionDir = reflect(-lightDir, normal);

                // 根据镜面反射光方向与视角方向的接近程度决定镜面反射强度
                fixed3 specular = _Specular.rgb * _LightColor0.rgb * pow(saturate(dot(reflectionDir, viewDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }
}
