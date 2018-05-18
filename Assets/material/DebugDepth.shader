Shader "Unlit/DebugDepth"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 screenUV : TEXCOORD1;
				float4 screenUV2 : TEXCOORD2;
				UNITY_FOG_COORDS(3)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenUV = o.vertex.xyzw;// ComputeNonStereoScreenPos(o.vertex);
				o.screenUV2 = ComputeNonStereoScreenPos(o.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				//o.uv.zw = o.vertex.xy;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 screen = i.screenUV.xy / i.screenUV.w *0.5+0.5;
				screen.y = 1 - screen.y;
				float2 screen2 = i.screenUV2.xy / i.screenUV2.w;
				// sample the texture
				fixed4 col = tex2D(_MainTex, screen2);
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screen).r;
				//float shadowMap = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, float3(screen,0));

				depth = Linear01Depth(depth);
				//shadowMap = Linear01Depth(shadowMap);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return depth;
			}
			ENDCG
		}
	}
}
