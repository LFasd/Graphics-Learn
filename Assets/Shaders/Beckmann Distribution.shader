Shader "Light/Beckmann Distribution"
{
    Properties
    {
        _Color("Base Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}

        _Roughness("Roughness",Range(0,1)) = 1

        [Toggle(_GGX)] _GGX ("GGX", Float) = 0
        [Toggle(_BECKMANN)] _Beckmann ("Beckmann", Float) = 0
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

            float _GGX;
            float _Beckmann;

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

                // o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                // o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                // o.worldNormal = mul(v.normal,unity_WorldToObject);

                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                return o;
            }


            float chiGGX(float v)
            {
                return v > 0 ? 1 : 0;
            }

            fixed4 frag (v2f i) : COLOR
            {
                //将法线转到世界空间:乘以变换矩阵的逆的转置
                //float3 normalWorld  = mul(_Object2World,i.normal);
//                float3 normalWorld  = normalize(i.worldNormal);

                //观察者
                float3 eyeDir = normalize(i.viewDir);

                //光源
                float3 lightDir = normalize(i.lightDir);

                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 normal = normalize(UnpackNormal(packedNormal));

                float3 h = normalize(eyeDir+lightDir);
                float nh = saturate(dot(normal, h));          
                float nh2 = nh*nh;


                // Beckmann Distribution
                float m2 = _Roughness*_Roughness;
                float r1 = 1.0/(4.0 * m2 *pow(nh,4.0));
                float r2 = (nh2 -1.0)/(m2 * nh2);
                float beckmann = r1*exp(r2);
                
                // Trowbridge-Reitz GGX Distribution
                float a2 = _Roughness * _Roughness;
                float denom = (nh2 * (a2 - 1) + 1);
                float ggx = a2 * chiGGX(nh) / (3.14159*denom*denom);


                float d = beckmann * _Beckmann + ggx * _GGX;

                return float4(d * _Color.rgb * _LightColor0.rgb,1);
            }
            ENDCG
        }
    }
}