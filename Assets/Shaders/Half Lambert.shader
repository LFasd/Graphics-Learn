Shader "Light/Half Lambert"
{
    Properties
    {
        _Color ("MainColor", Color) = (1,1,1,1)
		_Factor ("Factor", Range(0.5, 1)) = 0.5
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
            };

            fixed4 _Color;
			float _Factor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 由于每一个片元传入的数据都是插值产生的，因此传入的法向量无法保证是单位向量，需要先归一成单位向量
                fixed3 normal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * saturate(dot(worldLightDir, normal));

                fixed3 half_lambert = diffuse * _Factor + 1 - _Factor;

				// fixed3 half_lambert = diffuse * 0.5 + 0.5;

                return fixed4(half_lambert, 1.0);
            }
            ENDCG
        }
    }
}
