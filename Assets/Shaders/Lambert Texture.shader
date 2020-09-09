Shader "Light/Base Lambert Texture"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "white" {}
        _Color ("MainColor", Color) = (1,1,1,1)

        // 是否接收环境光
        [Toggle(_AMBIENT)] _Ambient ("Ambient", Float) = 0
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
            // make fog work


            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct a2v
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
            };

            fixed4 _Color;
            float _Ambient;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;                        

            v2f vert (a2v v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				// 计算副法线（在模型空间下）
				float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				// 或者使用 Unity 提供的宏，相当于上面两行代码
				//TANGENT_SPACE_ROTATION;

				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _Ambient;

				fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
				fixed3 tangentNormal;

                // 由于每一个片元传入的数据都是插值产生的，因此传入的法向量无法保证是单位向量，需要先归一成单位向量
                fixed3 normal = normalize(UnpackNormal(packedNormal));
                fixed3 lightDir = normalize(i.lightDir);

                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * saturate(dot(lightDir, normal));

                return fixed4(ambient + diffuse, 1.0);
            }
            ENDCG
        }
    }
}
