// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

Shader "Light/Ward"
{
    Properties 
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}//主纹理
        _Bump ("Bump", 2D) = "bump" {}//法线纹理
        _Specular ("Specular", Range(1.0, 10000.0)) = 250.0//高光指数
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)//高光颜色 
        _AlphaX("Alpha X",Range(0.001,1)) = 0.1//X方向的向异指数
        _AlphaY("Alpha Y",Range(0.001,1)) = 0.1//Y方向的向异指数
        _LightAtten("Light Atten",Float) = 1//高光强度
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
            #include "AutoLight.cginc"

            struct a2v
            {
                float4 vertex : POSITION; // 输入的模型顶点信息
                fixed3 normal : NORMAL; // 输入的法线信息
                fixed4 texcoord : TEXCOORD0; // 输入的坐标纹理集
                fixed4 tangent : TANGENT; // 切线信息
            };


            struct v2f
            {
                float4 pos : POSITION; // 输出的顶点信息
                fixed2 uv : TEXCOORD0; // 输出的UV信息
                fixed3 lightDir: TEXCOORD1; // 输出的光照方向
                fixed3 viewDir : TEXCOORD2; // 输出的摄像机方向
                fixed4 tangent : TANGENT;
                //LIGHTING_COORDS(3,4) // 封装了下面的写法
                // fixed3 _LightCoord : TEXCOORD3; // 光照坐标
                // fixed4 _ShadowCoord : TEXCOORD4; // 阴影坐标
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Bump;
            float4 _Bump_ST;
            float _Specular;
            fixed4 _SpecularColor;
            float _AlphaX;
            float _AlphaY;
            float _LightAtten;


            v2f vert(a2v v) 
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
                o.tangent = v.tangent;
                // 创建一个正切空间的旋转矩阵,TANGENT_SPACE_ROTATION由下面两行组成
                //TANGENT_SPACE_ROTATION;
                float3 binormal = cross( v.normal, v.tangent.xyz ) * v.tangent.w;
                float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal );

                // 将顶点的光方向，转到切线空间
                // 该顶点在对象坐标中的光方向向量,乘以切线空间旋转矩阵
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                // 该顶点在摄像机坐标中的方向向量,乘以切线空间旋转矩阵
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
                
                // 将照明信息给像素着色器，应该是用于下面片段中光衰弱atten的计算
                // TRANSFER_VERTEX_TO_FRAGMENT(o); // 由下面两行组成
                // 顶点转到世界坐标,再转到光坐标
                // o._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xyz;
                // // 顶点转到世界坐标，再从世界坐标转到阴影坐标
                // o._ShadowCoord = mul(unity_WorldToShadow[0], mul(unity_ObjectToWorld, v.vertex));
                // 注：把上面两行代码注释掉，也看不出上面效果，或许我使用的是平行光
                return o;
            }


            fixed4 frag(v2f i) : COLOR 
            {
                // 对主纹理进行采样
                fixed4 texColor = tex2D(_MainTex, i.uv);
                // 对法线图进行采样
                fixed3 norm = normalize(UnpackNormal(tex2D(_Bump, i.uv)));
                // 求漫反射
                // 公式：漫反射色 = 光颜色*N,L的余弦值(取大于0的)，所以夹角越小亮度越小
                fixed Diff=dot (norm,  normalize(i.lightDir));
                //半角向量
                fixed3 halfVector = normalize ( i.lightDir + i.viewDir);
                //切线方向
                fixed3 Tangent = normalize(i.tangent.rgb);
                //反射公式
                // 光衰弱
                fixed atten = LIGHT_ATTENUATION(i);
                // 环境光，Unity内置
                //fixed3 ambi = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //光线的反射向量
                fixed3 reflectVector = normalize(2 * dot(halfVector,-i.lightDir) * halfVector - i.lightDir); 
                fixed NdotH = dot (norm , halfVector);
                fixed Sigma = atan(NdotH);
                //fixed NdotL = max (0, Diff);
                fixed NdotL = Diff;
                //fixed NdotV = max (0,dot(norm  , normalize(i.viewDir)));
                fixed NdotV = dot(norm  , normalize(i.viewDir));
                //法向量与半角向量的夹角
                fixed angle = acos(NdotH);
                //法向量与半角向量的夹角的正切值
                fixed tanangle = tan(angle);
                //计算垂直于反射向量与半角向量的共有平面的向量
                fixed3 vertical1 = cross(reflectVector,norm);
                //fixed3 vertical1 = cross(norm,reflectVector);
                //vertical2垂直于vertical1与法线的共有平面的向量，即是反射向量投射在切线与副法线所共有的平面
                fixed3 vertical2 = normalize(cross(norm,vertical1));
                //vertical2的cos值
                fixed cosTheta = dot(Tangent,vertical2);
                fixed cos2Theta = cosTheta * cosTheta;
                fixed sin2Theta = 1 - cos2Theta;
                //计算高光公式的分子部分
                fixed Molecular = exp(-tanangle*tanangle*(cos2Theta/(_AlphaX * _AlphaX)+sin2Theta/(_AlphaY * _AlphaY)));
                //计算高光公式的分母部分
                fixed Denominator = 4 * 3.14159 * _AlphaX * _AlphaY * sqrt(NdotL * NdotV);
                fixed specularpower;
                specularpower = pow(saturate(Molecular/Denominator),_Specular);
                Diff = saturate (Diff);
                
                // 最终颜色
                // 公式： (漫反射 + 反射高光) * 光衰弱 ) * 材质主色
                fixed4 cfinal;
                cfinal.rgb = (texColor.rgb + (texColor.rgb * specularpower * _LightAtten)) * Diff *_LightColor0.rgb;
                cfinal.a = texColor.a;
                return cfinal;
            }
            ENDCG
        }
    }
}
