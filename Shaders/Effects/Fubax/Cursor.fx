/*
Cursor PS (c) 2018 Jacob Maximilian Fober

This work is licensed under the Creative Commons
Attribution-ShareAlike 4.0 International License.
To view a copy of this license, visit
http://creativecommons.org/licenses/by-sa/4.0/.
*/

// version 1.2.1


	  ////////////
	 /// MENU ///
	////////////

#include "ReShadeUI.fxh"

uniform float3 Color < __UNIFORM_COLOR_FLOAT3
> = float3(0.871, 0.871, 0.871);

uniform float Scale < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.1; ui_max = 1.0; ui_step = 0.001;
> = 0.2;

uniform float2 Offset < __UNIFORM_SLIDER_FLOAT2
	ui_min = 0f; ui_max = 1f; ui_step = 0.01;
> = 0f;


	  //////////////
	 /// SHADER ///
	//////////////

// Get mouse position
uniform float2 MousePoint < source = "mousepoint"; >;

texture CursorTex < source = "cursor.png"; > {Width = 108; Height = 108;};
sampler CursorSampler
{
	Texture = CursorTex;
	AddressU = BORDER;
	AddressV = BORDER;
	Format = R8;
};

#include "ReShade.fxh"

float3 CursorPS(float4 vois : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Get cursor texture size
	const float2 CursorTexSize = float2(tex2Dsize(CursorSampler, 0));
	// Get mouse position in UV space
	float2 Cursor = MousePoint * BUFFER_PIXEL_SIZE;
	// Get offset in UV space
	const float2 OffsetPos = Offset * CursorTexSize * BUFFER_PIXEL_SIZE * Scale;
	// Calculate Cursor size
	const float2 CursorSize = BUFFER_SCREEN_SIZE / CursorTexSize / Scale;

	// Sample display image
	float3 Display = tex2D(ReShade::BackBuffer, texcoord).rgb;
	// Sample cursor texture
	float CursorTexture = tex2D(CursorSampler, (OffsetPos - Cursor + texcoord) * CursorSize).r;

	return lerp(Display, Color, CursorTexture);
}


	  //////////////
	 /// OUTPUT ///
	//////////////

technique Cursor < ui_tooltip = "Display on-screen mouse cursor.\n"
"Can be placed before screen deformation techniques,\n"
"like Perfect Perspective,\n"
"that mouse would point at the right spot."; >
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = CursorPS;
	}
}
