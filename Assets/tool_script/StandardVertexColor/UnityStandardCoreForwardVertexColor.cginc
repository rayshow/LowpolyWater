// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
//zhangming20170522

#ifndef UNITY_STANDARD_CORE_FORWARD_VERTEX_COLOR_INCLUDED
#define UNITY_STANDARD_CORE_FORWARD_VERTEX_COLOR_INCLUDED

#if defined(UNITY_NO_FULL_STANDARD_SHADER)
#define UNITY_STANDARD_SIMPLE 1
#endif

#include "UnityStandardConfig.cginc"
#include "UnityStandardCore.cginc"
#include "UnityStandardCoreVertexColor.cginc"

#if UNITY_STANDARD_SIMPLE
    #include "UnityStandardCoreForwardSimpleVertexColor.cginc"
    VertexOutputBaseSimpleWithColor vertBase (VertexInputWithColor v) { return vertForwardBaseSimpleWithColor(v); }
    VertexOutputForwardAddSimpleWithColor vertAdd (VertexInputWithColor v) { return vertForwardAddSimpleWithColor(v); }
    half4 fragBase (VertexOutputBaseSimpleWithColor i) : SV_Target { return fragForwardBaseSimpleInternalWithColor(i); }
    half4 fragAdd (VertexOutputForwardAddSimpleWithColor i) : SV_Target { return fragForwardAddSimpleInternalWithColor(i); }
#else
    VertexOutputForwardBaseWithColor vertBase (VertexInputWithColor v) { return vertForwardBaseWithColor(v); }
    VertexOutputForwardAddWithColor vertAdd (VertexInputWithColor v) { return vertForwardAddWithColor(v); }
    half4 fragBase (VertexOutputForwardBaseWithColor i) : SV_Target { return fragForwardBaseInternalWithColor(i); }
    half4 fragAdd (VertexOutputForwardAddWithColor i) : SV_Target { return fragForwardAddInternalWithColor(i); }
#endif

#endif // UNITY_STANDARD_CORE_FORWARD_VERTEX_COLOR_INCLUDED
