Shader "Light/Geometry"
{
    Properties
    {
        _Color("Base Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}

        _Roughness("Roughness",Range(0,1)) = 1
    }

    
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            float4 _Color;

            float _Roughness;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
                float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);

                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                return o;
            }


            fixed4 frag (v2f i) : COLOR
            {
                float3 viewDir = normalize(i.viewDir);
                float3 lightDir = normalize(i.lightDir);

                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 normal = normalize(UnpackNormal(packedNormal));

                float k = (_Roughness + 1) * (_Roughness + 1) / 8;

                float nv = saturate(dot(normal, viewDir));
                float g1 = nv / (nv * (1 - k) + k);
                
                float nl = saturate(dot(normal, lightDir));
                float g2 = nl / (nl * (1 - k) + k);
                
                float g = g1 * g2;

                // half a = _Roughness;
                // half lambdaV = nl * (nl * (1 - a) + a);
                // half lambdaL = nv * (nv * (1 - a) + a);
                // g =  0.5f / (lambdaV + lambdaL + 1e-5f);

                return float4(g * _Color.rgb * _LightColor0.rgb * nl,1);
            }
            ENDCG
        }
    }
}