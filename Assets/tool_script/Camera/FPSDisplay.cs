using UnityEngine;
using System.Collections;

[AddComponentMenu("Debug/Camera/FPS")]
public class FPSDisplay : MonoBehaviour
{
	private float deltaTime = 0.0f;
	private int fontSize = Screen.height / 20;
	private bool exit = false;

	void Start()
	{
        Application.targetFrameRate = -1;
    }
	
	void Update()
	{
		deltaTime += (Time.deltaTime - deltaTime) * 0.1f;

		// 退出
		if ( exit )
		{ 
			Application.Quit();
		}
	}

	void OnGUI()
	{
		// 显示帧率
		float msec = deltaTime * 1000.0f;
		float fps = 1.0f / deltaTime;

		GUIStyle style = new GUIStyle();		
		Rect rect = new Rect(0, 0, Screen.width / 2, fontSize);
		style.alignment = TextAnchor.UpperLeft;
		style.fontSize = fontSize;
		if ( fps >= 40.0f )
			style.normal.textColor = Color.green;
		else if ( fps >= 20.0f && fps < 40.0f )
			style.normal.textColor = Color.yellow;
		else
			style.normal.textColor = Color.red;

		string text = string.Format("{0:0.0} ms ({1:0.} fps)", msec, fps);
		GUI.Label(rect, text, style);

		// 设置按钮
		// Create style for a button
		GUIStyle buttonStyle = new GUIStyle(GUI.skin.button);
		buttonStyle.fontSize = fontSize;
		
		// Load and set Font
		Font myFont = (Font)Resources.Load("Fonts/msyh", typeof(Font));
		buttonStyle.font = myFont;
		
		// Set color for selected and unselected buttons
		buttonStyle.normal.textColor = Color.white;
		buttonStyle.hover.textColor = Color.white;
		
		if (GUI.Button(new Rect(0, Screen.height-fontSize*2, fontSize*4, fontSize+6), "Exit", buttonStyle))
		{ 
			exit = true;
		}
	}
}