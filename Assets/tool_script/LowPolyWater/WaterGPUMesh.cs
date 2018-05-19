using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[AddComponentMenu("FX/Water/Lowpoly Mesh")]
public class WaterGPUMesh : MonoBehaviour {

    public GameObject waterTilePrefab = null;
    
    public uint xMeshCount = 5;
    public uint zMeshCount = 4;
    public int meshResolution = 40;
    public float unitWidth = 2.0f;

    private Material waterMaterial = null;
    private float meshWidth = 80.0f;
    private Mesh waterMesh;
    private int pointResolution = 0;
    private int indexCount = 0;
    private int sharePointCount = 0;
    private float uvUnit = 0.0f;
    private Material firstTilebMaterial = null;
    private Vector3[] shareVertices;
    private Vector3[] aloneVertices;
    private Vector3[] aloneNormals;
    private Vector4[] aloneTangants;
    private Vector2[] aloneUVs;
    private int[] aloneTriangleIndices;

    void Awake()
    {
        if (!waterTilePrefab)
        {
            Debug.LogError("need a water file prefab.");
            return;
        }
        waterMaterial = waterTilePrefab.GetComponent<Renderer>().sharedMaterial;
        if (!waterMaterial)
        {
            Debug.LogError("prefab need set material.");
            return;
        }


        if (xMeshCount == 0 || zMeshCount == 0)
        {
            Debug.LogError("x or z MeshCount can't be 0.");
            return;
        }

        meshWidth = unitWidth * meshResolution;
        int xhalf = (int)xMeshCount / 2;
        int zhalf = (int)zMeshCount / 2;

        Vector3 forward = Camera.main.transform.forward.normalized;
        forward = transform.InverseTransformDirection(forward);
        Vector2 GradientForward = new Vector2();
        GradientForward.x = forward.x;
        GradientForward.y = forward.z;
        waterMaterial.SetVector("_RadialGradientDirection", GradientForward);
        
        for (int x = 0; x < xMeshCount; ++x)
        {
            for (int z = 0; z < zMeshCount; ++z)
            {
                Vector3 pos =  new Vector3(meshWidth * (x - xhalf), transform.position.y, meshWidth * (z - zhalf));
                GameObject obj = Instantiate(waterTilePrefab, pos, Quaternion.identity, transform);
            } 
        }
    }


    void Start()
    {
        ReAllocateVerticesMemory();   
    }

    private void ReAllocateVerticesMemory()
    {
        if(waterMesh)
        {
            DestroyImmediate(waterMesh);
            waterMesh = null;
        }
        waterMesh = new Mesh();
        pointResolution = meshResolution + 1;
        indexCount = 6 * meshResolution * meshResolution;
        sharePointCount = pointResolution * pointResolution;
        uvUnit = 1.0f / meshResolution;

        aloneTriangleIndices = new int[indexCount];
        shareVertices = new Vector3[sharePointCount];
        aloneVertices = new Vector3[indexCount];
        aloneNormals = new Vector3[indexCount];
        aloneTangants = new Vector4[indexCount];
        aloneUVs = new Vector2[indexCount];

        for (int i = 0; i < meshResolution; ++i)
        {
            for (int j = 0; j < meshResolution; ++j)
            {
                int trianglePointIndex = 6 * (i * meshResolution + j);

                //indices
                aloneTriangleIndices[trianglePointIndex] = trianglePointIndex;
                aloneTriangleIndices[trianglePointIndex + 1] = trianglePointIndex + 1;
                aloneTriangleIndices[trianglePointIndex + 2] = trianglePointIndex + 2;
                aloneTriangleIndices[trianglePointIndex + 3] = trianglePointIndex + 3;
                aloneTriangleIndices[trianglePointIndex + 4] = trianglePointIndex + 4;
                aloneTriangleIndices[trianglePointIndex + 5] = trianglePointIndex + 5;

                //UVs
                aloneUVs[trianglePointIndex] = new Vector2(i * uvUnit, j * uvUnit);
                aloneUVs[trianglePointIndex + 1] = new Vector2(i * uvUnit, (j + 1) * uvUnit);
                aloneUVs[trianglePointIndex + 2] = new Vector2((i + 1) * uvUnit, j * uvUnit);
                aloneUVs[trianglePointIndex + 3] = new Vector2(i * uvUnit, (j + 1) * uvUnit);
                aloneUVs[trianglePointIndex + 4] = new Vector2((i + 1) * uvUnit, (j + 1) * uvUnit);
                aloneUVs[trianglePointIndex + 5] = new Vector2((i + 1) * uvUnit, j * uvUnit);
            }
        }

        //generate share vertex
        for (int i = 0; i < pointResolution; ++i)
        {
            for (int j = 0; j < pointResolution; ++j)
            {
                shareVertices[i * pointResolution + j] = new Vector3((i - pointResolution / 2) * unitWidth, 0.0f, (j - pointResolution / 2) * unitWidth);
            }
        }
        
        //use share vertex to generate alone vertex
        for (int i = 0; i < meshResolution; ++i)
        {
            for (int j = 0; j < meshResolution; ++j)
            {
                int baseVerIndex = i * pointResolution + j;
                int trianglePointIndex = 6 * (i * meshResolution + j);

                //alone vertex
                aloneVertices[trianglePointIndex] = shareVertices[baseVerIndex];
                aloneVertices[trianglePointIndex + 1] = shareVertices[baseVerIndex + 1];
                aloneVertices[trianglePointIndex + 2] = shareVertices[baseVerIndex + pointResolution];
                aloneVertices[trianglePointIndex + 3] = shareVertices[baseVerIndex + 1];
                aloneVertices[trianglePointIndex + 4] = shareVertices[baseVerIndex + 1 + pointResolution];
                aloneVertices[trianglePointIndex + 5] = shareVertices[baseVerIndex + pointResolution];

                //normal
                ComputerCenter(trianglePointIndex, trianglePointIndex + 1, trianglePointIndex + 2);
                ComputerCenter(trianglePointIndex + 3, trianglePointIndex + 4, trianglePointIndex + 5);
            }
        }
        
        waterMesh.vertices = aloneVertices;
        waterMesh.triangles = aloneTriangleIndices;
        waterMesh.normals = aloneNormals;
        waterMesh.tangents = aloneTangants;
        waterMesh.uv = aloneUVs;
        

        MeshFilter[] childFilters = GetComponentsInChildren<MeshFilter>();
        if (childFilters.Length != 0)
        {
            for (int i = 0; i < childFilters.Length; ++i)
            {
                childFilters[i].sharedMesh = waterMesh;
            }
        }
    }

    private void ComputerCenter(int x, int y, int z)
    {
        Vector3 center = (aloneVertices[x] + aloneVertices[y] + aloneVertices[z])/3;
        //aloneNormals[x] = Vector3.up;
        //aloneNormals[y] = Vector3.up;
        //aloneNormals[z] = Vector3.up;
        aloneTangants[x] = aloneVertices[y];
        aloneNormals[x] = aloneVertices[z];
        aloneTangants[y] = aloneVertices[z];
        aloneNormals[y] = aloneVertices[x];
        aloneTangants[z] = aloneVertices[x];
        aloneNormals[z] = aloneVertices[y];
    }


    void OnDrawGizmos()
    {
        Vector3 lGradientForward = Camera.main.transform.forward.normalized;
       
        if (waterMaterial &&waterMaterial.IsKeywordEnabled("_WATER_RADIAL_GRADIENT"))
        {
            Vector2 center = waterMaterial.GetVector("_RadialGradientCenter");
            float range = waterMaterial.GetFloat("_RadialGradientDistance");
            Vector2 direction = waterMaterial.GetVector("_RadialGradientDirection");

            lGradientForward.y = 0;
            Vector3 lGradientStartPos = new Vector3(center.x, 10, center.y);
            lGradientStartPos = transform.TransformPoint(lGradientStartPos);
            Gizmos.color = Color.red;
            Gizmos.DrawLine(lGradientStartPos, lGradientStartPos + lGradientForward * range);
            Gizmos.DrawSphere(lGradientStartPos, 1);

        }
    }



    void Update()
    {

#if UNITY_EDITOR
        if (pointResolution!=meshResolution+1)
        {
            Debug.Log("editor update");
            ReAllocateVerticesMemory();
        }
#endif
    }


}
