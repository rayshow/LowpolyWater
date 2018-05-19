// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

using System;
using UnityEngine;
using UnityEditor;

class StandardLowpolyWaterGUI : ShaderGUI
{
    MaterialProperty WaterColor = null;
    MaterialProperty ReflColor = null;
    MaterialProperty Smoothness = null;
    MaterialProperty Metallic = null;
    MaterialProperty FoamTex = null;
    MaterialProperty DepthAODivider = null;
    MaterialProperty DepthAOOffset = null;
    MaterialProperty DepthAOStrength = null;
    MaterialProperty RadialGradientCenter = null;
    MaterialProperty RadialGradientDirection = null;
    MaterialProperty RadialGradientDistance = null;
    MaterialProperty RadialGradientOffset = null;
    MaterialProperty RadialGradientColor = null;
    MaterialProperty ReflectiveRatio = null;
    MaterialProperty ReflectiveDistort = null;
    MaterialProperty RefractiveRatio = null;
    MaterialProperty RefractiveDistort = null;
    MaterialProperty WaveAmplitude = null;
    MaterialProperty WaveFrequency = null;
    MaterialProperty WaveSteepness = null;
    MaterialProperty WaveSpeed = null;
    MaterialProperty WaveDirectionAB = null;
    MaterialProperty WaveDirectionCD = null;
    string WaterAOName = "_WATER_AO";
    string WaterRadialGradientName = "_WATER_RADIAL_GRADIENT";
    string WaterReflectionName = "_WATER_REFLECTION";
    string WaterRefractionName = "_WATER_REFRACTION";

    private enum WorkflowMode
    {
        Specular,
        Metallic,
        Dielectric
    }

    public void FindProperties(MaterialProperty[] props)
    {
        WaterColor = FindProperty("_WaterColor", props);
        Smoothness = FindProperty("_Glossiness", props);
        Metallic = FindProperty("_Metallic", props);
        FoamTex = FindProperty("_FoamTex", props);
        DepthAODivider = FindProperty("_DepthAODivider", props);
        DepthAOOffset = FindProperty("_DepthAOOffset", props);
        DepthAOStrength = FindProperty("_DepthAOStrength", props);
        RadialGradientCenter = FindProperty("_RadialGradientCenter", props);
        RadialGradientDirection = FindProperty("_RadialGradientDirection", props);
        RadialGradientDistance = FindProperty("_RadialGradientDistance", props);
        RadialGradientOffset = FindProperty("_RadialGradientOffset", props);
        RadialGradientColor = FindProperty("_RadialGradientColor", props);
        ReflectiveRatio = FindProperty("_ReflectiveRatio", props);
        ReflectiveDistort = FindProperty("_ReflectiveDistort", props);
        RefractiveRatio = FindProperty("_RefractiveRatio", props);
        RefractiveDistort = FindProperty("_RefractiveDistort", props);
        WaveAmplitude = FindProperty("_WaveAmplitude", props);
        WaveFrequency = FindProperty("_WaveFrequency", props);
        WaveSteepness = FindProperty("_WaveSteepness", props);
        WaveSpeed = FindProperty("_WaveSpeed", props);
        WaveDirectionAB = FindProperty("_WaveDirectionAB", props);
        WaveDirectionCD = FindProperty("_WaveDirectionCD", props);
    }

    bool firstApply = true;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        FindProperties(props);
        Material material = materialEditor.target as Material;
        string toggleTab = "       ";

        // Use default labelWidth
        EditorGUIUtility.labelWidth = 0f;

        // Detect any changes to the material
        EditorGUI.BeginChangeCheck();

        bool bWaterAO = Array.IndexOf(material.shaderKeywords, WaterAOName) != -1;
        bool bRadialGradient = Array.IndexOf(material.shaderKeywords, WaterRadialGradientName) != -1;
        bool bWaterReflection = Array.IndexOf(material.shaderKeywords, WaterReflectionName) != -1;
        bool bWaterRefraction = Array.IndexOf(material.shaderKeywords, WaterRefractionName) != -1;
        
        materialEditor.ColorProperty(WaterColor,"Water Color");
        materialEditor.RangeProperty(Smoothness, "smoothness");
        materialEditor.RangeProperty(Metallic, "metallic");
        materialEditor.TextureProperty(FoamTex, "FoamTex");

        bRadialGradient = EditorGUILayout.Toggle("Enable Radial Gradient:", bRadialGradient);
        if (bRadialGradient)
        {
            materialEditor.VectorProperty(RadialGradientCenter, toggleTab + "gradient center");
            materialEditor.FloatProperty(RadialGradientDistance, toggleTab + "gradient range");
            materialEditor.RangeProperty(RadialGradientOffset, toggleTab + "gradient offset");
            materialEditor.ColorProperty(RadialGradientColor, toggleTab + "gradient color");
        }

        bWaterReflection = EditorGUILayout.Toggle("Enable Water Reflection:", bWaterReflection);
        if(bWaterReflection)
        {
            materialEditor.RangeProperty(ReflectiveRatio, toggleTab + "water  reflective ratio");
            materialEditor.RangeProperty(ReflectiveDistort, toggleTab + "water  reflective distort");
        }
        
        bWaterRefraction = EditorGUILayout.Toggle("Enable Water Refraction:", bWaterRefraction);
        if (bWaterRefraction)
        {
            materialEditor.RangeProperty(RefractiveRatio, toggleTab + "water  refraction ratio");
            materialEditor.RangeProperty(RefractiveDistort, toggleTab + "water  refraction distort");
        }

        bWaterAO = EditorGUILayout.Toggle("Enable Water Depth AO:", bWaterAO);
        if (bWaterAO)
        {
            materialEditor.RangeProperty(DepthAODivider, toggleTab + "depth divider");
            materialEditor.RangeProperty(DepthAOOffset, toggleTab + "depth ao offset");
            materialEditor.RangeProperty(DepthAOStrength, toggleTab + "AO strength");
        }

        materialEditor.VectorProperty(WaveAmplitude, "wave amlitude");
        materialEditor.VectorProperty(WaveFrequency, "wave amlitude");
        materialEditor.VectorProperty(WaveSteepness, "wave amlitude");
        materialEditor.VectorProperty(WaveSpeed, "wave amlitude");
        materialEditor.VectorProperty(WaveDirectionAB, "wave amlitude");
        materialEditor.VectorProperty(WaveDirectionCD, "wave amlitude");

        EditorGUI.EndChangeCheck();
       
        SetKeyword(material, WaterAOName, bWaterAO);
        SetKeyword(material, WaterRadialGradientName, bRadialGradient);
        SetKeyword(material, WaterReflectionName, bWaterReflection);
        SetKeyword(material, WaterRefractionName, bWaterRefraction);
    }

    static void SetKeyword(Material m, string keyword, bool state)
    {
        if (state)
            m.EnableKeyword(keyword);
        else
            m.DisableKeyword(keyword);
    }


    static void SetMaterialKeywords(Material material)
    {
        // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
        // (MaterialProperty value might come from renderer material property block)
        SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap") || material.GetTexture("_DetailNormalMap"));
        SetKeyword(material, "_PARALLAXMAP", material.GetTexture("_ParallaxMap"));
        SetKeyword(material, "_DETAIL_MULX2", material.GetTexture("_DetailAlbedoMap") || material.GetTexture("_DetailNormalMap"));

        // A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
        // or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
        // The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
        MaterialEditor.FixupEmissiveFlag(material);
        bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
        SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);
    }
}

