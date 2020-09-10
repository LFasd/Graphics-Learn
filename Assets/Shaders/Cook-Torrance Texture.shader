// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Light/Cook-Torrance Texture"
{
    Properties
    {
        _Color("Base Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}

        _Roughness("Roughness",2D) = "white" {}
        _Fresnel("Fresnel",Range(0,1)) = 1
        _Metallic("Metallic", 2D) = "white" {}
        _K("K",Range(0,1)) = 1

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

            float4 _Color;


            float _Fresnel;
            float _K;
            samplerCUBE _Environment;

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

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            fixed4 frag (v2f i) : COLOR
            {
                //将法线转到世界空间:乘以变换矩阵的逆的转置
                //float3 normalWorld  = mul(_Object2World,i.normal);


                float3 viewDir = normalize(i.viewDir);
                float3 lightDir = normalize(i.lightDir);

                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 normal = normalize(UnpackNormal(packedNormal));

                float a = tex2D(_Roughness, i.uv2.xy);
                float metallic = (1- tex2D(_Metallic, i.uv2.zw));

                // float3 normalWorld  = mul(i.normal,unity_WorldToObject);

                //观察者
                // float3 eyeDir = normalize(_WorldSpaceCameraPos -i.posWorld).xyz;

                //光源
                // float3 lightDir = normalize(_WorldSpaceLightPos0).xyz;

                fixed4 col = tex2D(_MainTex, i.uv.xy);

                ///计算漫反射
                float3 diffuse = _Color * col.rgb;

                //计算天空盒
                // float3 r = reflect(-viewDir,normalWorld);
                // float4 reflectiveColor = texCUBE(_Environment,r);



                //计算高光
                //float3 h = (eyeDir+lightDir)/2;
                //float3 r = normalize(reflect(-lightDir,normalWorld));
                //float3 specular = saturate(dot(lightDir,normalWorld))* _SpecularColor * pow(saturate(dot(r,eyeDir)),_SpecularPower);

                //计算Cook-Torrance高光
                float s;
                float ln = saturate(dot(lightDir,normal));

                float3 h = normalize(viewDir+lightDir);
                float nh = saturate(dot(normal, h));
                float nv = saturate(dot(normal, viewDir));                
                float vh = saturate(dot(viewDir, h));
                
                //G项
                float nh2 = 2.0*nh;
                float g1 = (nh2*nv)/vh;
                float g2 = (nh2*ln)/vh;
                float g = min(1.0,min(g1,g2));

                //D项：beckmann distribution function
                float m2 = a*a;
                float r1 = 1.0/(4.0 * m2 *pow(nh,4.0));
                float r2 = (nh*nh -1.0)/(m2 * nh*nh);
                float roughness = r1*exp(r2);

                //F项
                float fresnel = pow(1.0 - vh,5.0);
                fresnel *= (1.0-_Fresnel);
                fresnel += _Fresnel;
                s = saturate((fresnel*g*roughness)/(nv*ln*3.14));

                //reflectiveColor *= fresnel;
                
                float3 final =_LightColor0*ln*(metallic*diffuse + s*(1-metallic));
                return float4(final,1);
            }
            ENDCG
        }
    }
}