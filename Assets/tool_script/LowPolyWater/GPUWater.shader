Shader "FX/Water/GPUWater"
{
	Properties
	{
		_WaterColor("Water Color", Color) = (1,0,1,1)
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
		//alpha blend
		_RadialGradientCenter("gradient center",Vector) = (0,0,0,0)
		_RadialGradientDistance("gradient distance",float) = 100
		_RadialGradientOffset("gradient offset ", range(0,1)) = 0
		_RadialGradientColor("gradient border color",Color) = (1,1,1,1)
		//reflective effect
		_ReflectiveRatio("Water Reflective Ratio", Range(0,1)) = 1
		_ReflectiveDistort("Water Reflective Distort", Range(0,10)) = 1
		//refractive effect
		_RefractiveRatio("Water Refractive Ratio", Range(0,1)) = 1
		_RefractiveDistort("Water Refractive Distort", Range(0,10)) = 1
		//depth AO Effect
		_DepthAODivider("Depth AO DepthAODivider", Range(0,100)) = 1
		_DepthAOOffset("Depth AO Offset", Range(0,1)) = 0
		_DepthAOStrength("Depth AO Strength", Range(1,5)) = 1
		//Wave Parameter
		_WaveAmplitude("Wave Amplitude", Vector) = (0.3 ,0.35, 0.25, 0.25)
		_WaveFrequency("Wave Frequency", Vector) = (1.3, 1.35, 1.25, 1.25)
		_WaveSteepness("Wave Steepness", Vector) = (1.0, 1.0, 1.0, 1.0)
		_WaveSpeed("Wave Speed", Vector) = (1.2, 1.375, 1.1, 1.5)
		_WaveDirectionAB("Wave Direction", Vector) = (0.3 ,0.85, 0.85, 0.25)
		_WaveDirectionCD("Wave Direction", Vector) = (0.1 ,0.9, 0.5, 0.5)
		[HideInInspector] _RadialGradientDirection("gradient direction",Vector) = (0,0,0,0)
		[HideInInspector] _ReflectionTex("Internal Reflection", 2D) = "" {}
		[HideInInspector] _RefractionTex("Internal Refraction", 2D) = "" {}
	}

	CGINCLUDE
	#include "UnityStandardCore.cginc"
	half3 GerstnerOffset3(half2 xz, half4 steepness, half4 amp, half4 freq, half4 speed, half4 dirAB, half4 dirCD)
	{
		half3 offsets;

		half4 AB = steepness.xxyy * amp.xxyy * dirAB.xyzw;
		half4 CD = steepness.zzww * amp.zzww * dirCD.xyzw;

		half4 dotABCD = freq.xyzw * half4(dot(dirAB.xy, xz), dot(dirAB.zw, xz), dot(dirCD.xy, xz), dot(dirCD.zw, xz));
		half4 TIME = _Time.yyyy * speed;

		half4 COS = cos(dotABCD + TIME);
		half4 SIN = sin(dotABCD + TIME);

		offsets.x = dot(COS, half4(AB.xz, CD.xz));
		offsets.z = dot(COS, half4(AB.yw, CD.yw));
		offsets.y = dot(SIN, amp);

		return offsets;
	}

	half3 GerstnerNormal3(half2 xz, half4 amp, half4 freq, half4 speed, half4 dirAB, half4 dirCD)
	{
		half3 nrml = half3(0, 2.0, 0);

		half4 AB = freq.xxyy * amp.xxyy * dirAB.xyzw;
		half4 CD = freq.zzww * amp.zzww * dirCD.xyzw;

		half4 dotABCD = freq.xyzw * half4(dot(dirAB.xy, xz), dot(dirAB.zw, xz), dot(dirCD.xy, xz), dot(dirCD.zw, xz));
		half4 TIME = _Time.yyyy * speed;

		half4 COS = cos(dotABCD + TIME);

		nrml.x -= dot(COS, half4(AB.xz, CD.xz));
		nrml.z -= dot(COS, half4(AB.yw, CD.yw));

		nrml = normalize(nrml);

		return nrml;
	}

	inline half4 VertexLightAndAmbient(float3 posWorld, half3 normalWorld)
	{
		half4 ambient = 0;
#ifdef VERTEXLIGHT_ON
		// Approximated illumination from non-important point lights
		ambient.rgb = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, posWorld, normalWorld);
#endif
		ambient.rgb = ShadeSHPerVertex(normalWorld, ambient.rgb);
		return ambient;
	}

	struct appdata
	{
		float4 vertex : POSITION;
		float3  normal : NORMAL;
		float2 texCoord : TEXCOORD0;
		float2 shadowCoord: TEXCOORD1;
		float4 tangent   : TANGENT;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f
	{
		float4 vertex : SV_POSITION;
		float2 texCoord : TEXCOORD0;
		half3  normal: TEXCOORD1;
		half3  eyeVec : TEXCOORD2;
		float3 worldPos: TEXCOORD3;
		float4  screenUV : TEXCOORD4;
		float4  screenDistort: TEXCOORD5;
		half4  ambient : TEXCOORD6;    
		float4 geometryInfo: TEXCOORD7;
		UNITY_FOG_COORDS(8)
		UNITY_SHADOW_COORDS(9)
		
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	ENDCG

	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent"}
		LOD 100

		Pass
		{
			Name "Forward"
			Tags{ "LightMode" = "ForwardBase"}
			
			//ZWrite Off
			ZTest LEqual
			Blend SrcAlpha OneMinusSrcAlpha
			
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex VertWaterLighting
			#pragma fragment FragWaterLighting
			// make fog work
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma multi_compile_instancing
			#pragma shader_feature _ _WATER_AO
			#pragma shader_feature _ _WATER_RADIAL_GRADIENT
			#pragma shader_feature _ _WATER_REFLECTION
			#pragma shader_feature _ _WATER_REFRACTION
			
			//Wave 
			float4 _WaveAmplitude;
			float4 _WaveFrequency;
			float4 _WaveSteepness;
			float4 _WaveSpeed;
			float4 _WaveDirectionAB;
			float4 _WaveDirectionCD;
			half _ReflectiveDistort;
			half _RefractiveDistort;

			v2f VertWaterLighting(appdata v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float4 originalWorldA = mul(UNITY_MATRIX_M, float4(v.vertex.xyz,1));
				float4 originalWorldB = mul(UNITY_MATRIX_M, float4(v.tangent.xyz,1));
				float4 originalWorldC = mul(UNITY_MATRIX_M, float4(v.normal, 1));
				
				float3 forward = normalize(v.vertex.xyz - v.normal);
				float3 right = cross(normalize(v.normal), forward);

				float3 AOffset = GerstnerOffset3(originalWorldA.xz, _WaveSteepness, _WaveAmplitude, _WaveFrequency, _WaveSpeed, _WaveDirectionAB, _WaveDirectionCD);
				float3 BOffset = GerstnerOffset3(originalWorldB.xz, _WaveSteepness, _WaveAmplitude, _WaveFrequency, _WaveSpeed, _WaveDirectionAB, _WaveDirectionCD);
				float3 COffset = GerstnerOffset3(originalWorldC.xz, _WaveSteepness, _WaveAmplitude, _WaveFrequency, _WaveSpeed, _WaveDirectionAB, _WaveDirectionCD);
				
				float3 PointA = v.vertex.xyz + AOffset;
				v.vertex.xyz = PointA;
				float3 PointB = v.tangent.xyz + BOffset;
				float3 PointC = v.normal + COffset;

				float3 dir1 = normalize(PointA - PointC);
				float3 dir2 = normalize(PointB - PointC);
				float3 meshNormal = cross(dir1,dir2);

				float4 worldPos = mul(UNITY_MATRIX_M, v.vertex);
				float4 viewPos = mul(UNITY_MATRIX_V, worldPos);
				half3 worldNormal =  mul(normalize(meshNormal), (float3x3)unity_WorldToObject);
				o.vertex =   mul(UNITY_MATRIX_P, viewPos);
				o.worldPos = worldPos.xyz;
				o.eyeVec = NormalizePerVertexNormal(o.worldPos - _WorldSpaceCameraPos);
				o.ambient = VertexLightAndAmbient(o.worldPos, worldNormal);
				o.normal = worldNormal;

				//model space xz and liner view space z
				o.geometryInfo.xy = v.vertex.xz;
				o.geometryInfo.zw = float2(-viewPos.z, 0);

				//texture space uv and screen uv and offset
				o.texCoord = v.texCoord;
				o.screenUV = ComputeNonStereoScreenPos(o.vertex);
				o.screenDistort.xy = worldNormal.xz*_ReflectiveDistort;
				o.screenDistort.zw = worldNormal.xz*_RefractiveDistort;
#if defined (SHADOWS_DEPTH)
				o._ShadowCoord = o.screenUV;
#endif
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			
			inline half3 MetallicDiffuseAndSpecular(half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
			{
				const half4 DielectricSpec = half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301);
				specColor = lerp(DielectricSpec.rgb, albedo, metallic);
				oneMinusReflectivity = DielectricSpec.a*(1 - metallic);
				return albedo * oneMinusReflectivity;
			}

			inline FragmentCommonData
				FragmentSetup(
				half4 waterColor,
				half3 normal,
				half3 eyeVec,
				float3 posWorld)
			{
				half3 realtimeRefl = 0;

				half oneMinusReflectivity;
				half3 specColor;
				half3 diffColor = MetallicDiffuseAndSpecular(waterColor.rgb, _Metallic, specColor, oneMinusReflectivity);

				FragmentCommonData o = (FragmentCommonData)0;
				o.alpha = waterColor.a;
				o.diffColor = diffColor;
				o.specColor = specColor;
				o.oneMinusReflectivity = oneMinusReflectivity;
				o.smoothness = _Glossiness;
				o.normalWorld = normalize(normal);
				
				o.eyeVec = normalize(eyeVec);
				o.posWorld = posWorld;
				return o;
			}

			inline half3 IndirectGlossnessSpecular(
				FragmentCommonData s,
				half atten,
				half4 ambient,
				UnityLight light)
			{
				Unity_GlossyEnvironmentData g;
				g.roughness = SmoothnessToPerceptualRoughness(s.smoothness);
				g.reflUVW = reflect(s.eyeVec, s.normalWorld);
				g.reflUVW.y = max(0,g.reflUVW.y);
				
					return Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, g);
			}

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			sampler2D _ReflectionTex;
			sampler2D _RefractionTex;
			half _ReflectiveRatio;
			half _RefractiveRatio;
			half4 _ReflColor;
			half4 _WaterColor;
			half _DepthAODivider;
			half _DepthAOOffset;
			half _DepthAOStrength;
			float3 _RadialGradientCenter;
			half2  _RadialGradientDirection;
			half _RadialGradientDistance;
			half _RadialGradientOffset;
			half3 _RadialGradientColor;

			fixed4 FragWaterLighting(v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				half4 waterColor = _WaterColor;
				half alpha = _WaterColor.a;

			/*	half2 dir = IN.GeometryInfo.xy - _GradientStartPos;
				half distance = _GradientDistance - sqrt(dot(dir, dir));
				half cosAngle = dot(normalize(dir), _GradientDirection);
				half stepPart = step(0, cosAngle);
				alpha = (1 - stepPart) + saturate(_GradientOffset*(1 - cosAngle) + distance / _GradientDistance)* stepPart;
				Color.rgb = lerp(_RadialGradientColor, _Color, alpha).rgb;
*/
#ifdef _WATER_RADIAL_GRADIENT //gradient
				half2 dir = i.geometryInfo.xy - _RadialGradientCenter.xy;
				half distance = _RadialGradientDistance - sqrt(dot(dir, dir));
				half cosAngle = dot(normalize(dir), _RadialGradientDirection);
				half stepPart = step(0, cosAngle);
				alpha = (1 - stepPart) + saturate(_RadialGradientOffset*(1 - cosAngle) + distance / _RadialGradientDistance)* stepPart;
				waterColor.rgb = lerp(_RadialGradientColor, waterColor, alpha).rgb;
#endif
				half4 refl = 0;

				half4 depthColor = 0;
#ifdef _WATER_AO //depth effect
				half depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, i.screenUV + float4(i.screenDistort.zw, 0, 0));
				half currentDepth = i.geometryInfo.z;
				depth = LinearEyeDepth(depth);

				half depthDistance = saturate(saturate((depth - currentDepth) / _DepthAODivider) + _DepthAOOffset);
				depthColor  = lerp(waterColor, waterColor*0.5, depthDistance*_DepthAOStrength);
				waterColor = lerp(_WaterColor, _WaterColor*0.5, depthDistance);
#endif

#ifdef _WATER_REFRACTION //refraction
				half4 realtimeRefr = tex2Dproj(_RefractionTex, i.screenUV + float4(i.screenDistort.zw, 0, 0));
				waterColor = lerp(waterColor, waterColor*realtimeRefr*1.5, _RefractiveRatio);
#endif

				FragmentCommonData s = FragmentSetup(waterColor, i.normal, i.eyeVec,  i.worldPos);
				half atten = UnityComputeForwardShadows(0, i.worldPos, i.screenUV);
				UnityLight directLight;
				directLight.color = _LightColor0.rgb*atten;
				directLight.dir = _WorldSpaceLightPos0.xyz;

				//ambient and skybox
				UnityIndirect indirectLight;
				indirectLight.specular = IndirectGlossnessSpecular(s, atten, i.ambient, directLight);
#ifdef _WATER_REFLECTION //reflection
				half4 realtimeRefl = tex2Dproj(_ReflectionTex, i.screenUV + float4(i.screenDistort.xy, 0, 0));
				const half3 complement = half3(2.6, 2.0745, 1.6);
				indirectLight.specular = lerp(indirectLight.specular, indirectLight.specular*complement*realtimeRefl, _ReflectiveRatio);
				//indirectLight.specular = _ReflectiveRatio* realtimeRefl;
				refl = realtimeRefl;
#endif
				indirectLight.diffuse =  ShadeSHPerPixel(i.normal, i.ambient, i.worldPos);

				half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, directLight, indirectLight);
				UNITY_APPLY_FOG(i.fogCoord, c.rgb);
				
				//return float4(i.normal*0.5+0.5,1);
				//return float4(indirectLight.specular, 1);
			  /*	half3 reflUVW = reflect(i.eyeVec, i.normal);
				half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflUVW, 0);
				DecodeHDR(rgbm, unity_SpecCube0_HDR);
				return float4(rgbm.rgb,1);*/
				return float4(c.rgb, alpha);
			}
			ENDCG
		}
	}
		CustomEditor "StandardLowpolyWaterGUI"
		FallBack "VertexLit"
}
