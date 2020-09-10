// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Light/PBR"
{
    Properties
    {
        _Color("Base Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}

        _Roughness("Roughness",2D) = "white" {}
        _Metallic("Metallic", 2D) = "white" {}
        _FresnelBase("FresnelBase", Range(0, 1)) = 1
        _Environment ("Environment", Cube) = "white"
        
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
            #include "UnityPBSLighting.cginc"

            float4 _Color;

            float _FresnelBase;

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
                float4 uv2 : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            sampler2D _Roughness;
            float4 _Roughness_ST;
            sampler2D _Metallic;
            float4 _Metallic_ST;

            samplerCUBE _Environment;
        

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                o.uv2.xy = v.texcoord.xy * _Roughness_ST.xy + _Roughness_ST.zw;
                o.uv2.zw = v.texcoord.xy * _Metallic_ST.xy + _Metallic_ST.zw;

                float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
                float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);

                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            float G(float3 n, float3 v, float3 l, float a)
            {
                float nv = saturate(dot(n, v));
                float nl = saturate(dot(n, l));

                float k = (a + 1) * (a + 1) / 8;

                float g1 = nv / (nv * (1 - k) + k);
                float g2 = nl / (nl * (1 - k) + k);
                
                float g = g1 * g2;

                
                // half lambdaV = nl * (nl * (1 - a) + a);
                // half lambdaL = nv * (nv * (1 - a) + a);
                // g =  (0.5f / (lambdaV + lambdaL + 1e-5f)) * nl;

                return g;
            }

            float D(float3 n, float3 h, float a)
            {
                float nh = saturate(dot(n, h));
                float nh2 = nh*nh;

                // float nh2 = nh * nh;
                // float a2 = a*a;
                // float r1 = 1.0/(4.0 * a2 *pow(nh,4.0));
                // float r2 = (nh2 -1.0)/(a2 * nh2);
                // float d = r1*exp(r2);

                float a2 = a * a;
                float denom = nh2 * (a2 - 1) + 1;
                float d = a2  / (3.14159 * denom*denom + 0.00001);

                return d;
            }

            float3 F(float3 n, float3 v, float3 f0)
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

                float a = tex2D(_Roughness, i.uv2.xy);
                // a = 0.1;
                float metallic = tex2D(_Metallic, i.uv2.zw);

                fixed4 col = tex2D(_MainTex, i.uv.xy);
                
                float3 h = normalize(viewDir + lightDir);
                float nl = saturate(dot(normal, lightDir));
                float nv = saturate(dot(normal, viewDir));
                float hl = saturate(dot(h, lightDir));
                float hv = saturate(dot(h, viewDir));

                float3 f0 = 0.04;
                f0 = f0 * (1 - metallic) + col.rgb * metallic;

                float d = D(normal, h, a);
                float3 f = F(normal, viewDir, f0);
                float g = G(normal, viewDir, lightDir, a);
                // f = FresnelTerm(f0, hv);

                ///计算漫反射
                float3 diffuse = _Color.rgb * nl * col.rgb * _LightColor0.rgb;

                float denominator = 4 * nv * nl + 0.001;
                float specular = d * g * f / denominator;

                float3 ks = f;
                float3 kd = (1 - ks) * (1 - metallic);
                
                float3 final = diffuse * kd + specular * hl;
                return float4(kd * diffuse + d * f * g * _LightColor0.rgb,1);
            }
            ENDCG
        }
    }
}