// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
//zhangming20170524

#ifndef UNITY_STANDARD_META_VERTEX_COLOR_INCLUDED
#define UNITY_STANDARD_META_VERTEX_COLOR_INCLUDED

// Functionality for Standard shader "meta" pass
// (extracts albedo/emission for lightmapper etc.)

// define meta pass before including other files; they have conditions
// on that in some places
#define UNITY_PASS_META 1

#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "UnityMetaPass.cginc"
#include "UnityStandardCore.cginc"
#include "UnityStandardCoreVertexColor.cginc"

struct v2f_metaWithColor
{
    float4 uv       : TEXCOORD0;
    float4 pos      : SV_POSITION;

	//vertex color
	fixed4 color : COLOR;
};

v2f_metaWithColor vert_metaWithColor(VertexInputWithColor v)
{
    v2f_metaWithColor o;
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = TexCoordsWithColor(v);

	//vertex color
	o.color = v.color;

    return o;
}

// Albedo for lightmapping should basically be diffuse color.
// But rough metals (black diffuse) still scatter quite a lot of light around, so
// we want to take some of that into account too.
half3 UnityLightmappingAlbedo (half3 diffuse, half3 specular, half smoothness)
{
    half roughness = SmoothnessToRoughness(smoothness);
    half3 res = diffuse;
    res += specular * roughness * 0.5;
    return res;
}

float4 frag_metaWithColor(v2f_metaWithColor i) : SV_Target
{
    // we're interested in diffuse & specular colors,
    // and surface roughness to produce final albedo.
    FragmentCommonData data = UNITY_SETUP_BRDF_INPUT_VERTEX_COLOR(i.uv, i.color);

    UnityMetaInput o;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

#if defined(EDITOR_VISUALIZATION)
    o.Albedo = data.diffColor;
#else
    o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);
#endif
    o.SpecularColor = data.specColor;
    o.Emission = Emission(i.uv.xy);

    return UnityMetaFragment(o);
}

#endif // UNITY_STANDARD_META_VERTEX_COLOR_INCLUDED
