Shader "Light/Phong Texture"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}
        _Color ("MainColor", Color) = (1,1,1,1)
        _Specular ("Specular Color", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(0, 256)) = 1

        [Toggle(_AMBIENT)] _Ambient ("Ambient", Float) = 0
        [Toggle(_DIFFUSE)] _Diffuse ("Diffuse", Float) = 0
        [Toggle(_NORMALMAP)] _NormalMap ("NormalMap", Float) = 0
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
                float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 lightDir : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            fixed4 _Color;
            fixed4 _Specular;
            float _Gloss;
            float _Ambient;
            float _Diffuse;
            float _NormalMap;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;  

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				// 计算副法线（在模型空间下）
				float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				// 或者使用 Unity 提供的宏，相当于上面两行代码
				// TANGENT_SPACE_ROTATION;

				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _Ambient;

				fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
				fixed3 tangentNormal;

                fixed3 normal = normalize(UnpackNormal(packedNormal));
                fixed3 lightDir = normalize(i.lightDir);
                float3 viewDir = normalize(i.viewDir);

                // 对法线，等光方向，视线方向进行插值（开启法线贴图为法线空间，不开启为世界空间）
                normal = lerp(normalize(i.worldNormal), normal, _NormalMap);
                lightDir = lerp(normalize(_WorldSpaceLightPos0.xyz), lightDir, _NormalMap);
                viewDir = lerp(normalize(_WorldSpaceCameraPos.xyz - i.worldPos), viewDir, _NormalMap);

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
