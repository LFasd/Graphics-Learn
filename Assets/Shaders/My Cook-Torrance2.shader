// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Light/My Cook-Torrance2"
{
    Properties
    {
        _Color("Base Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}

        _Roughness("Roughness",Range(0,1)) = 1
        _Metallic("Metallic", Range(0, 1)) = 1
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
            float _FresnelBase;
            float _Metallic;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
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

            float G(float3 n, float3 v, float3 l)
            {
                float nv = saturate(dot(n, v));
                float nl = saturate(dot(n, l));

                float k = (_Roughness + 1) * (_Roughness + 1) / 8;

                float g1 = nv / (nv * (1 - k) + k);
                float g2 = nl / (nl * (1 - k) + k);
                
                float g = g1 * g2;
                return g;
            }

            float chiGGX(float v)
            {
                return v > 0 ? 1 : 0;
            }

            float D(float3 n, float3 h)
            {
                float nh = saturate(dot(n, h));
                float nh2 = nh*nh;
                float a = _Roughness;

                float a2 = a * a;
                float denom = (nh2 * (a2 - 1) + 1);
                float d = a2 * chiGGX(nh) / (3.14159*denom*denom + 0.00001);

                return d;
            }

            float F(float3 n, float3 v, float3 f0)
            {
                float f = f0 + (1 - f0) * pow((1 - (dot(n, v))), 5);
                return f;
            }

            fixed4 frag (v2f i) : COLOR
            {
                float3 viewDir = normalize(i.viewDir);
                float3 lightDir = normalize(i.lightDir);

                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 normal = normalize(UnpackNormal(packedNormal));

                fixed4 col = tex2D(_MainTex, i.uv);
                
                float3 h = normalize(viewDir + lightDir);
                float nl = saturate(dot(normal, lightDir));
                float nv = saturate(dot(normal, viewDir));

                float3 f0 = lerp(0.04, col.rgb, _Metallic);


                ///计算漫反射
                float3 diffuse = _Color.rgb * nl * col.rgb * _LightColor0.rgb;

                float denominator = 4 * nv * nl + 0.001;
                float specular = D(normal, h) * G(normal, viewDir, lightDir) * F(normal, viewDir, f0) / denominator;

                float3 ks = f0;
                float3 kd = (1 - ks) * (1 - _Metallic);
                
                float3 final = diffuse * kd + specular * col.rgb * _LightColor0.rgb;
                return float4(final,1);
            }
            ENDCG
        }
    }
}