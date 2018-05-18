using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[AddComponentMenu("Debug/Camera/EnableDepth")]
public class EnableDepth : MonoBehaviour {

	// Use this for initialization
	void Start () {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
	}
	
	// Update is called once per frame
	void Update () {
		
	}
}
