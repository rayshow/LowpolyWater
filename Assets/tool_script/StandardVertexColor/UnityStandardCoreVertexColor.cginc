// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
//zhangming20170522

#ifndef UNITY_STANDARD_CORE_VERTEX_COLOR_INCLUDED
#define UNITY_STANDARD_CORE_VERTEX_COLOR_INCLUDED

struct VertexInputWithColor
{
	float4 vertex   : POSITION;
	half3 normal    : NORMAL;
	float2 uv0      : TEXCOORD0;
	float2 uv1      : TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
	float2 uv2      : TEXCOORD2;
#endif
#ifdef _TANGENT_TO_WORLD
	half4 tangent   : TANGENT;
#endif

	//vertex color
	fixed4 color : COLOR;

	UNITY_VERTEX_INPUT_INSTANCE_ID
};

float4 TexCoordsWithColor(VertexInputWithColor v)
{
	float4 texcoord;
	texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
	texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
	return texcoord;
}

half3 AlbedoWithColor(float4 texcoords, fixed4 i_vertexColor)
{
	half3 albedo = _Color.rgb * tex2D(_MainTex, texcoords.xy).rgb * i_vertexColor.rgb;
#if _DETAIL
#if (SHADER_TARGET < 30)
	// SM20: instruction count limitation
	// SM20: no detail mask
	half mask = 1;
#else
	half mask = DetailMask(texcoords.xy);
#endif
	half3 detailAlbedo = tex2D(_DetailAlbedoMap, texcoords.zw).rgb;
#if _DETAIL_MULX2
	albedo *= LerpWhiteTo(detailAlbedo * unity_ColorSpaceDouble.rgb, mask);
#elif _DETAIL_MUL
	albedo *= LerpWhiteTo(detailAlbedo, mask);
#elif _DETAIL_ADD
	albedo += detailAlbedo * mask;
#elif _DETAIL_LERP
	albedo = lerp(albedo, detailAlbedo, mask);
#endif
#endif
	return albedo;
}

#ifndef UNITY_SETUP_BRDF_INPUT_VERTEX_COLOR
#define UNITY_SETUP_BRDF_INPUT_VERTEX_COLOR(tex,vertexColor) SpecularSetupWithColor(tex,vertexColor)
#endif

inline FragmentCommonData SpecularSetupWithColor(float4 i_tex, fixed4 i_vertexColor)
{
	half4 specGloss = SpecularGloss(i_tex.xy);
	half3 specColor = specGloss.rgb;
	half smoothness = specGloss.a;

	half oneMinusReflectivity;
	half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular(AlbedoWithColor(i_tex, i_vertexColor), specColor, /*out*/ oneMinusReflectivity);

	FragmentCommonData o = (FragmentCommonData)0;
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	return o;
}

inline FragmentCommonData MetallicSetupWithColor(float4 i_tex, fixed4 i_vertexColor)
{
	half2 metallicGloss = MetallicGloss(i_tex.xy);
	half metallic = metallicGloss.x;
	half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.

	half oneMinusReflectivity;
	half3 specColor;
	half3 diffColor = DiffuseAndSpecularFromMetallic(AlbedoWithColor(i_tex, i_vertexColor), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

	FragmentCommonData o = (FragmentCommonData)0;
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	return o;
}

#define FRAGMENT_SETUP_VERTEX_COLOR(x) FragmentCommonData x = \
    FragmentSetupWithColor(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i), i.color);
#define FRAGMENT_SETUP_FWDADD_VERTEX_COLOR(x) FragmentCommonData x = \
    FragmentSetupWithColor(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, IN_WORLDPOS_FWDADD(i), i.color);

half AlphaWithColor(float2 uv, fixed vertexAlpha)
{
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
	return _Color.a * vertexAlpha;
#else
	return tex2D(_MainTex, uv).a * _Color.a * vertexAlpha;
#endif
}

inline FragmentCommonData FragmentSetupWithColor(float4 i_tex, half3 i_eyeVec, half3 i_viewDirForParallax, half4 tangentToWorld[3], half3 i_posWorld, fixed4 i_vertexColor)
{
	i_tex = Parallax(i_tex, i_viewDirForParallax);

	half alpha = AlphaWithColor(i_tex.xy, i_vertexColor.a);
#if defined(_ALPHATEST_ON)
	clip(alpha - _Cutoff);
#endif

	FragmentCommonData o = UNITY_SETUP_BRDF_INPUT_VERTEX_COLOR(i_tex, i_vertexColor);
	o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
	o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
	o.posWorld = i_posWorld;

	// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	o.diffColor = PreMultiplyAlpha(o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
	return o;
}

// ------------------------------------------------------------------
//  Base forward pass (directional light, emission, lightmaps, ...)

inline half4 VertexGIForwardWithColor(VertexInputWithColor v, float3 posWorld, half3 normalWorld)
{
	half4 ambientOrLightmapUV = 0;
	// Static lightmaps
#ifdef LIGHTMAP_ON
	ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
	ambientOrLightmapUV.zw = 0;
	// Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
#elif UNITY_SHOULD_SAMPLE_SH
#ifdef VERTEXLIGHT_ON
	// Approximated illumination from non-important point lights
	ambientOrLightmapUV.rgb = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, posWorld, normalWorld);
#endif

	ambientOrLightmapUV.rgb = ShadeSHPerVertex(normalWorld, ambientOrLightmapUV.rgb);
#endif

#ifdef DYNAMICLIGHTMAP_ON
	ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

	return ambientOrLightmapUV;
}

struct VertexOutputForwardBaseWithColor
{
	float4 pos                          : SV_POSITION;
	float4 tex                          : TEXCOORD0;
	half3 eyeVec                        : TEXCOORD1;
	half3 normal                        : TEXCOORD9;
	float3 modelPos                     : TEXCOORD10;
	half4 tangentToWorldAndPackedData[3]    : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
	half4 ambientOrLightmapUV           : TEXCOORD5;    // SH or Lightmap UV
	UNITY_SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
	#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
		float3 posWorld                 : TEXCOORD8;
	#endif

	//vertex color
	fixed4 color : COLOR;

	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputForwardBaseWithColor vertForwardBaseWithColor(VertexInputWithColor v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputForwardBaseWithColor o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBaseWithColor, o);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);

#if UNITY_REQUIRE_FRAG_WORLDPOS
#if UNITY_PACK_WORLDPOS_WITH_TANGENT
	o.tangentToWorldAndPackedData[0].w = posWorld.x;
	o.tangentToWorldAndPackedData[1].w = posWorld.y;
	o.tangentToWorldAndPackedData[2].w = posWorld.z;
#else
	o.posWorld = posWorld.xyz;
#endif
#endif
	o.pos = UnityObjectToClipPos(v.vertex);

	o.tex = TexCoordsWithColor(v);
	o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
	float3 normalWorld = UnityObjectToWorldNormal(v.normal);
	

	o.normal = normalWorld;
	
#ifdef _TANGENT_TO_WORLD
	float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

	float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
	o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
	o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
	o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
#else
	o.tangentToWorldAndPackedData[0].xyz = 0;
	o.tangentToWorldAndPackedData[1].xyz = 0;
	o.tangentToWorldAndPackedData[2].xyz = normalWorld;
#endif

	//We need this for shadow receving
	UNITY_TRANSFER_SHADOW(o, v.uv1);

	o.ambientOrLightmapUV = VertexGIForwardWithColor(v, posWorld, normalWorld);

#ifdef _PARALLAXMAP
	TANGENT_SPACE_ROTATION;
	half3 viewDirForParallax = mul(rotation, ObjSpaceViewDir(v.vertex));
	o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
	o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
	o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
#endif

	//vertex color
	o.color = v.color;

	UNITY_TRANSFER_FOG(o, o.pos);
	return o;
}

#if _ALPHABORDER_ON
half _AlphaPow;
#endif

half4 fragForwardBaseInternalWithColor(VertexOutputForwardBaseWithColor i)
{
	FRAGMENT_SETUP_VERTEX_COLOR(s)

	UNITY_SETUP_INSTANCE_ID(i);
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

	UnityLight mainLight = MainLight();
	UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

	half occlusion = Occlusion(i.tex.xy);
	UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

	

	half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
	c.rgb += Emission(i.tex.xy);
	
	UNITY_APPLY_FOG(i.fogCoord, c.rgb);
	half4 output = OutputForward(c, s.alpha);

#if _ALPHABORDER_ON
	//float3 outDirection = i.modelPos.xz;
	half NdotV = pow(max(0.0, dot(normalize(i.normal.xz), normalize(-i.eyeVec.xz))), _AlphaPow);
	output.a *= NdotV;
#endif

	//return float4(s.diffColor, 1);
	//return s.alpha;
	//return 0.5f;
	return output;
}

// ------------------------------------------------------------------
//  Additive forward pass (one light per pass)

struct VertexOutputForwardAddWithColor
{
	float4 pos                          : SV_POSITION;
	float4 tex                          : TEXCOORD0;
	half3 eyeVec                        : TEXCOORD1;
	half4 tangentToWorldAndLightDir[3]  : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:lightDir]
	float3 posWorld                     : TEXCOORD5;
	UNITY_SHADOW_COORDS(6)
		UNITY_FOG_COORDS(7)

		// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
#if defined(_PARALLAXMAP)
		half3 viewDirForParallax            : TEXCOORD8;
#endif

	//vertex color
	fixed4 color : COLOR;

	UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputForwardAddWithColor vertForwardAddWithColor(VertexInputWithColor v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputForwardAddWithColor o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAddWithColor, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.pos = UnityObjectToClipPos(v.vertex);

	o.tex = TexCoordsWithColor(v);
	o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
	o.posWorld = posWorld.xyz;
	float3 normalWorld = UnityObjectToWorldNormal(v.normal);
#ifdef _TANGENT_TO_WORLD
	float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

	float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
	o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0];
	o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1];
	o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2];
#else
	o.tangentToWorldAndLightDir[0].xyz = 0;
	o.tangentToWorldAndLightDir[1].xyz = 0;
	o.tangentToWorldAndLightDir[2].xyz = normalWorld;
#endif
	//We need this for shadow receiving
	UNITY_TRANSFER_SHADOW(o, v.uv1);

	float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
#ifndef USING_DIRECTIONAL_LIGHT
	lightDir = NormalizePerVertexNormal(lightDir);
#endif
	o.tangentToWorldAndLightDir[0].w = lightDir.x;
	o.tangentToWorldAndLightDir[1].w = lightDir.y;
	o.tangentToWorldAndLightDir[2].w = lightDir.z;

#ifdef _PARALLAXMAP
	TANGENT_SPACE_ROTATION;
	o.viewDirForParallax = mul(rotation, ObjSpaceViewDir(v.vertex));
#endif

	//vertex color
	o.color = v.color;

	UNITY_TRANSFER_FOG(o, o.pos);
	return o;
}

half4 fragForwardAddInternalWithColor(VertexOutputForwardAddWithColor i)
{
	FRAGMENT_SETUP_FWDADD_VERTEX_COLOR(s)

	UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
	UnityLight light = AdditiveLight(IN_LIGHTDIR_FWDADD(i), atten);
	UnityIndirect noIndirect = ZeroIndirect();

	half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

	UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0, 0, 0, 0)); // fog towards black in additive pass
	return OutputForward(c, s.alpha);
}

// ------------------------------------------------------------------
//  Deferred pass

struct VertexOutputDeferredWithColor
{
	float4 pos                          : SV_POSITION;
	float4 tex                          : TEXCOORD0;
	half3 eyeVec                        : TEXCOORD1;
	half4 tangentToWorldAndPackedData[3]: TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
	half4 ambientOrLightmapUV           : TEXCOORD5;    // SH or Lightmap UVs

#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
	float3 posWorld                     : TEXCOORD6;
#endif

	//vertex color
	fixed4 color : COLOR;

	UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputDeferredWithColor vertDeferredWithColor(VertexInputWithColor v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputDeferredWithColor o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputDeferredWithColor, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
#if UNITY_REQUIRE_FRAG_WORLDPOS
#if UNITY_PACK_WORLDPOS_WITH_TANGENT
	o.tangentToWorldAndPackedData[0].w = posWorld.x;
	o.tangentToWorldAndPackedData[1].w = posWorld.y;
	o.tangentToWorldAndPackedData[2].w = posWorld.z;
#else
	o.posWorld = posWorld.xyz;
#endif
#endif
	o.pos = UnityObjectToClipPos(v.vertex);

	o.tex = TexCoordsWithColor(v);
	o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
	float3 normalWorld = UnityObjectToWorldNormal(v.normal);
#ifdef _TANGENT_TO_WORLD
	float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

	float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
	o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
	o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
	o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
#else
	o.tangentToWorldAndPackedData[0].xyz = 0;
	o.tangentToWorldAndPackedData[1].xyz = 0;
	o.tangentToWorldAndPackedData[2].xyz = normalWorld;
#endif

	o.ambientOrLightmapUV = 0;
#ifdef LIGHTMAP_ON
	o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#elif UNITY_SHOULD_SAMPLE_SH
	o.ambientOrLightmapUV.rgb = ShadeSHPerVertex(normalWorld, o.ambientOrLightmapUV.rgb);
#endif
#ifdef DYNAMICLIGHTMAP_ON
	o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

#ifdef _PARALLAXMAP
	TANGENT_SPACE_ROTATION;
	half3 viewDirForParallax = mul(rotation, ObjSpaceViewDir(v.vertex));
	o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
	o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
	o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
#endif

	//vertex color
	o.color = v.color;

	return o;
}

void fragDeferredWithColor(
	VertexOutputDeferredWithColor i,
	out half4 outGBuffer0 : SV_Target0,
	out half4 outGBuffer1 : SV_Target1,
	out half4 outGBuffer2 : SV_Target2,
	out half4 outEmission : SV_Target3          // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
	, out half4 outShadowMask : SV_Target4       // RT4: shadowmask (rgba)
#endif
	)
{
#if (SHADER_TARGET < 30)
	outGBuffer0 = 1;
	outGBuffer1 = 1;
	outGBuffer2 = 0;
	outEmission = 0;
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
	outShadowMask = 1;
#endif
	return;
#endif

	FRAGMENT_SETUP_VERTEX_COLOR(s)

	// no analytic lights in this pass
	UnityLight dummyLight = DummyLight();
	half atten = 1;

	// only GI
	half occlusion = Occlusion(i.tex.xy);
#if UNITY_ENABLE_REFLECTION_BUFFERS
	bool sampleReflectionsInDeferred = false;
#else
	bool sampleReflectionsInDeferred = true;
#endif

	UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);

	half3 emissiveColor = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

#ifdef _EMISSION
	emissiveColor += Emission(i.tex.xy);
#endif

#ifndef UNITY_HDR_ON
	emissiveColor.rgb = exp2(-emissiveColor.rgb);
#endif

	UnityStandardData data;
	data.diffuseColor = s.diffColor;
	data.occlusion = occlusion;
	data.specularColor = s.specColor;
	data.smoothness = s.smoothness;
	data.normalWorld = s.normalWorld;

	UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

	// Emissive lighting buffer
	outEmission = half4(emissiveColor, 1);

	// Baked direct lighting occlusion if any
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
	outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
#endif
}

#endif // UNITY_STANDARD_CORE_VERTEX_COLOR_INCLUDED
