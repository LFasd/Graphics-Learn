Shader "Light/Gradient Ambient"
{
    Properties
    {
        _Color ("MainColor", Color) = (1,1,1,1)
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.worldNormal);

                // 利用法向量计算渐变色权重
                float skyFactor = saturate(normal.y);
                float groundFactor = saturate(-normal.y);
                float equatorFactor = 1.0 - abs(normal.y);
                
                // 分别计算三个渐变色并合成环境光照
                fixed4 skyColor = unity_AmbientSky * skyFactor;
                fixed4 equatorColor = unity_AmbientEquator * equatorFactor;
                fixed4 groundColor = unity_AmbientGround * groundFactor;
                fixed3 ambient = skyColor.rgb + equatorColor.rgb + groundColor.rgb;


                return fixed4(ambient * _Color.rgb, 1.0);
            }
            ENDCG
        }
    }
}
