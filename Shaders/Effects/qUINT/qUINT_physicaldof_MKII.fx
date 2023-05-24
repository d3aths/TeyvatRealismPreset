/*=============================================================================

   Copyright (c) Pascal Gilcher. All rights reserved.

	ReShade effect file
    github.com/martymcmodding

	Support me:
   		patreon.com/mcflypg

    Physically based depth of field effect 

    * Unauthorized copying of this file, via any medium is strictly prohibited
 	* Proprietary and confidential
    * See accompanying license document for terms and conditions

=============================================================================*/

/*
    todo:    
 
    bokeh scatter  
*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/

#ifndef FULL_RESOLUTION
 #define FULL_RESOLUTION            0   //[0 or 1]      If enabled, the DOF will render its effects in fullscreen, otherwise half res (default)
#endif

#ifndef ADVANCED_BOKEH_EFFECTS
 #define ADVANCED_BOKEH_EFFECTS     1   //[0 or 1]      If enabled, more features for bokeh shapes become available, at a performance cost
#endif


//no touchy >:(
#define MIN_F_STOPS 		0.95		
#define MAX_F_STOPS 		8.0
#define COC_CLAMP			0.009

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform int FOCUS_MODE <
	ui_type = "combo";
    ui_label = "Focusing Mode";
	ui_items = "Manual Focus\0Autofocus\0Autofocus (Point and Click with MMB)\0";
    ui_category = "Focusing"; 
> = 0;

uniform float RAW_FOCUS_PLANE_DEPTH <
    ui_type = "drag";
    ui_min = 0.002;
    ui_max = 1.0;
    ui_label = "Manual Focal Plane Depth";
    ui_tooltip = "Distance to the focal plane. 0 means camera itself, 1 means infinity.\nThis value is internally converted to actual distance parameters.\nFor easier adjustment, this parameter reacts more sensitive to close areas.";  
    ui_category = "Focusing"; 
> = 0.1;

//#define FOCUS_PLANE_DEPTH (RAW_FOCUS_PLANE_DEPTH * RAW_FOCUS_PLANE_DEPTH) //Squared for more fine grained control

uniform float2 AUTOFOCUS_CENTER <
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_label = "Autofocus Center";
    ui_tooltip = "X and Y coordinates of autofocus center. Negative values move left/up";
    ui_category = "Focusing";
> = float2(0.0, 0.0);

uniform float AUTOFOCUS_RANGE <
    ui_type = "drag";
    ui_min = 0.05;
    ui_max = 1.0;
    ui_label = "Autofocus Detection Range";
    ui_tooltip = "Area size around focus center to analyze";
    ui_category = "Focusing";
> = 0.35;

uniform float AUTOFOCUS_SPEED <
    ui_type = "drag";
    ui_min = 0.05;
    ui_max = 1.0;
    ui_label = "Autofocus Adjustment Speed";
    ui_tooltip = "Adjustment speed of autofocus on focus change";
    ui_category = "Focusing";
> = 0.1;

uniform float FOCAL_LENGTH <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 350.0;
    ui_label = "Focal Length";
    ui_tooltip = "Focal length of the virtual camera. As with real cameras,\na higher focal length means smaller depth of field and more blur.";  
    ui_category = "Lens Parameters - Simple"; 
> = 50.0;

uniform float FSTOPS <
    ui_type = "drag";
    ui_min = MIN_F_STOPS;
    ui_max = MAX_F_STOPS;
    ui_label = "Aperture F-Stops";
    ui_tooltip = "Aperture size of the virtual camera (4 means f/4). The aperture opening directly influences\nthe bokeh shape curvature and the blur radius.";  
    ui_category = "Lens Parameters - Simple"; 
> = 2.8;

uniform int VERTEX_COUNT <
    ui_type = "slider";
    ui_min = 3;
    ui_max = 9;
    ui_label = "Aperture Blade Count";
    ui_tooltip = "Number of blades of the aperture. For small aperture, e.g. 6 results in hexagonal bokeh.";  
    ui_category = "Lens Parameters - Simple";   
> = 6;

uniform float APERTURE_ROUNDNESS <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Aperture Roundness";
    ui_tooltip = "A value of 0.0 produces polygonal bokeh, a value of 1.0 produces circular bokeh.";  
    ui_category = "Lens Parameters - Simple"; 
> = 1.0;

uniform float BOKEH_ANGLE <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Bokeh Rotation";
    ui_tooltip = "Rotation angle of bokeh shape. Only rotates the polygon shape, scaling is applied after.";
    ui_category = "Lens Parameters - Advanced";  
> = 0.25;

#if ADVANCED_BOKEH_EFFECTS != 0
uniform float BOKEH_RATIO_TANGENTIAL <
    ui_type = "drag";
    ui_min = -3.0;
    ui_max = 3.0;
    ui_label = "Tangential Bokeh Scale";
    ui_tooltip = "Scales bokeh shape tangentially. Allows to simulate astigmatism, petzval bokeh effect and more.";  
    ui_category = "Lens Parameters - Advanced"; 
> = 0.0;

uniform float BOKEH_RATIO_SAGITTAL <
    ui_type = "drag";
    ui_min = -3.0;
    ui_max = 3.0;
    ui_label = "Sagittal Bokeh Scale";
    ui_tooltip = "Scales bokeh shape sagittally. Allows to simulate astigmatism, petzval bokeh effect and more.";
    ui_category = "Lens Parameters - Advanced";  
> = 0.0;

uniform float BOKEH_ANAMORPH_RATIO <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 3.0;
    ui_label = "Anamorph Bokeh Ratio";
    ui_tooltip = "Squeezes Bokeh horizontally to simulate the usage of anamorphic lenses.\nTechnically, bokeh should increase vertically and not decrease horizontally,\nbut the usage of an anamorphic lens alters the FoV, which this shader cannot modify.\nMatching the FoV using a different focal length results yields the results here.";
    ui_category = "Lens Parameters - Advanced";  
> = 1.0;

uniform float BOKEH_SPHERICAL_ABB <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Spherical Abberation"; 
    ui_category = "Lens Parameters - Advanced"; 
> = 0.0;
#endif

uniform int RING_COUNT_MAX <
    ui_type = "slider";
    ui_min = 3;
    ui_max = 25;
    ui_label = "Bokeh Quality";
    ui_tooltip = "Number of sample rings. Higher values produce smoother and more defined bokeh discs, but cost more performance.\nShader might occasionally sample more than this to prevent undersampling in certain areas.";  
    ui_category = "Blur Parameters"; 
> = 7;

uniform float BOKEH_INTENSITY <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Bokeh Highlight Intensity";
    ui_tooltip = "Higher values produce more pronounced bokeh discs.";  
    ui_category = "Blur Parameters"; 
> = 0.5;

uniform float BOKEH_SMOOTHNESS <
    ui_type = "drag";
    ui_min = -1.0;
    ui_max = 1.0;
    ui_label = "Bokeh Smoothness";
    ui_tooltip = "Further out of focus smoothing to soften bokeh discs and close sample gaps.\nThis is relative to bokeh disc size, and will not blur all out of focus areas the same way.";  
    ui_category = "Blur Parameters"; 
> = 0.0;

uniform bool USE_PREFILTER <
    ui_label = "Enable Prefiltering";
    ui_category = "Blur Parameters";
> = true;

uniform bool USE_UNDERSAMPLE_PROTECTION <
    ui_label = "Enable Undersampling Protection";
    ui_category = "Blur Parameters";
> = false;

uniform int BOKEH_SHAPE_DEBUG <
	ui_type = "combo";
    ui_label = "Bokeh Shape Helper";
	ui_items = "OFF\0Point Grid w/ Scene\0Point Grid\0";
	ui_tooltip = "Helps fine tuning bokeh appearance in case bokeh shapes are badly visible.";
    ui_category = "Internal Parameters"; 
> = 0;
/*
uniform float4 tempF1 <
    ui_type = "drag";
    ui_min = -100.0;
    ui_max = 100.0;
    ui_category = "Internal Parameters"; 
> = float4(1,1,1,1);

uniform float4 tempF2 <
    ui_type = "drag";
    ui_min = -100.0;
    ui_max = 100.0;
    ui_category = "Internal Parameters"; 
> = float4(1,1,1,1);

uniform float4 tempF3 <
    ui_type = "drag";
    ui_min = -100.0;
    ui_max = 100.0;
    ui_category = "Internal Parameters"; 
> = float4(1,1,1,1);
*/
/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

uniform float2 MOUSE_POINT < source = "mousepoint"; >;
uniform bool OVERLAY_OPEN < source = "overlay_open"; >;
uniform float FRAME_TIME < source = "frametime"; >;

#define DILATED_COC_TILE_SIZE   ((BUFFER_WIDTH >> 9) + 2)   //((((4 * BUFFER_WIDTH) / 2048)/2)*2 + 8) 
#define PI                      3.1415927

#if FULL_RESOLUTION != 0
 #define LAYER_PIXEL_SIZE_SCALE  1.0
#else 
 #define LAYER_PIXEL_SIZE_SCALE  2.0
#endif

//=============================================================================

texture ColorInputTex : COLOR;
texture DepthInputTex : DEPTH;
sampler ColorInput 	        { Texture = ColorInputTex; };
sampler DepthInput          { Texture = DepthInputTex; };

texture2D FocusTex1			        { Width = 1;   Height = 1;                Format = R16F;  	};
sampler2D sFocusTex1			    { Texture = FocusTex1;  };
texture2D FocusTex16			    { Width = 16;   Height = 16;              Format = R16F;  	};
sampler2D sFocusTex16			    { Texture = FocusTex16;  };
texture2D LastMousePt			    { Width = 1;   Height = 1;                Format = RG16F;  	};
sampler2D sLastMousePt			    { Texture = LastMousePt;  };

texture2D TileCoC 					{ Width = BUFFER_WIDTH/DILATED_COC_TILE_SIZE;   Height = BUFFER_HEIGHT/DILATED_COC_TILE_SIZE;   Format = RGBA16F; };
texture2D DilatedTileCoC 			{ Width = BUFFER_WIDTH/DILATED_COC_TILE_SIZE;   Height = BUFFER_HEIGHT/DILATED_COC_TILE_SIZE;   Format = RGBA16F; };
sampler2D sTileCoC					{ Texture = TileCoC;	    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;		};
sampler2D sDilatedTileCoC			{ Texture = DilatedTileCoC;	};

//TODO: can't be compressed to SDR somehow... find out why
texture2D ForegroundTex 			{ Width = BUFFER_WIDTH/LAYER_PIXEL_SIZE_SCALE;   Height = BUFFER_HEIGHT/LAYER_PIXEL_SIZE_SCALE;   Format = RGBA16F; };
sampler2D sForegroundTex			{ Texture = ForegroundTex; };
texture2D BackgroundTex 			{ Width = BUFFER_WIDTH/LAYER_PIXEL_SIZE_SCALE;   Height = BUFFER_HEIGHT/LAYER_PIXEL_SIZE_SCALE;   Format = RGBA16F; };
sampler2D sBackgroundTex			{ Texture = BackgroundTex; };

texture2D ColorAndDepthTex 			{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA16F;};
sampler2D sColorAndDepthTex			{ Texture = ColorAndDepthTex; AddressU = MIRROR; AddressV = MIRROR; };
texture2D ColorAndDepthTexLo 		{ Width = BUFFER_WIDTH/LAYER_PIXEL_SIZE_SCALE;   Height = BUFFER_HEIGHT/LAYER_PIXEL_SIZE_SCALE;   Format = RGBA16F;};
sampler2D sColorAndDepthTexLo		{ Texture = ColorAndDepthTexLo;	AddressU = MIRROR; AddressV = MIRROR;};
texture2D DepthTexLo 			    { Width = BUFFER_WIDTH/LAYER_PIXEL_SIZE_SCALE;   Height = BUFFER_HEIGHT/LAYER_PIXEL_SIZE_SCALE;   Format = R16F; };
sampler2D sDepthTexLo			    { Texture = DepthTexLo;	AddressU = MIRROR; AddressV = MIRROR;};

#include "qUINT\Global.fxh"
#include "qUINT\Depth.fxh"

struct VSOUT
{
	float4 vpos 		: SV_Position;
    float2 uv   		: TEXCOORD0;
    float2 camera       : TEXCOORD1;
};

struct TileData
{
    float min_coc;
    float max_coc;
    float min_depth;
    float max_depth;
};

struct BokehKernelData 
{
    float2x2 vertexmat;
    float2x2 scalemat;
    float2 vertex_curr;
    float2 vertex_next;
};

/*=============================================================================
	Functions
=============================================================================*/

//https://github.com/EpicGames/UnrealEngine/blob/bf95c2cbc703123e08ab54e3ceccdd47e48d224a/Engine/Source/Runtime/Renderer/Private/PostProcess/DiaphragmDOFUtils.cpp

//@return distance in m
float depth_to_z(in float depth)
{
	//z in m
    return depth * RESHADE_DEPTH_LINEARIZATION_FAR_PLANE + 1;
}

//@return focal dist in m
float get_focal_distance() //
{
    return depth_to_z(tex2Dfetch(sFocusTex1, int2(0,0)).x);
	//return depth_to_z(FOCUS_PLANE_DEPTH);
}

float get_coc(VSOUT i, float depth)
{
    float focal_dist = i.camera.y; //unit doesn't matter, since it's cancelled anyways
    float coc_radius_inf = i.camera.x;
    float scene_depth = depth_to_z(depth); //unit doesn't matter, must only be same as focal_dist

    //                     s - d        d: focal distance
    // coc = coc_inf * -----------      s: object distance
    //                       s

    float coc_radius = ((scene_depth - focal_dist) / scene_depth) * coc_radius_inf;
    return sign(coc_radius) * clamp(abs(coc_radius), 0, COC_CLAMP);
    //return clamp(coc_radius, -COC_CLAMP, 0);
}

float2 get_max_abs_coc(VSOUT i)
{
    return float2(COC_CLAMP, min(COC_CLAMP, i.camera.x)); //foreground CoC will always exceed COC_CLAMP, but far field CoC goes up to radius at infinity
}

float sample_intersect(float coc, float n, float i, float max_radius)
{    
    return saturate(abs(coc) * n / max_radius - i + 0.5); //centered on ring, feather 0.5 both sides
    //return saturate(abs(coc) * n / max_radius - i + 1.0); //this is 1 when coc >= ring radius and 0 when coc <= ring radius - 1, best compromise even though it makes for super small in focus areas...
}

float sample_alpha(float coc)
{
    float coc_pixels = BUFFER_WIDTH/LAYER_PIXEL_SIZE_SCALE * coc;
    return rcp(PI * max(coc_pixels * coc_pixels, 1));
}

float get_fg_weight(float depth, float coc, TileData Tile, float center_depth)
{
    //#define LAYER_RANGE (0.09)
    //float weight = coc <= 0 ? linearstep(LAYER_RANGE * LAYER_RANGE, 0, depth - Tile.min_depth) : 0;
    float weight = linearstep(abs(center_depth - Tile.min_depth), 0, depth - Tile.min_depth); //automatic range adjustment, works super well!
    return weight;
}

float bokeh_int()
{
   return 1 + exp2(-BOKEH_INTENSITY * 8.0);
}

void unpack_hdr(inout float3 color)
{
    color = color * sqrt(1e-6 + dot(color, color)) / 1.733; 
    float a = bokeh_int();  
    color = color / (a - color);
}

void pack_hdr(inout float3 color)
{
    color= bokeh_int() * color * rcp(1 + color);
    color *= 1.733;
    color = color * rsqrt(sqrt(dot(color, color))+0.0001);
}

float4 tex2Dbicub(sampler tex, float2 iuv, float2 texsize)
{
	float4 uv = 0.0;
	uv.xy = iuv * texsize;

	float2 center = floor(uv.xy - 0.5) + 0.5;
	float4 d = float4(uv.xy - center, 1 + center - uv.xy);
	float4 d2 = d * d;
	float4 d3 = d2 * d;
	float4 sd = d2 * (3 - 2 * d);	

	float4 o = lerp(d2, d3, 0.3594) * 0.2; //approx |err|*255 < 0.2 < bilinear precision
	uv.xy = center - o.zw;
	uv.zw = center + 1 + o.xy;
	uv /= texsize.xyxy;	

	float4 w = (1.0/6.0) + d * 0.5 + sd * (1.0/6.0);
	w = w.wwyy * w.zxzx;

	return w.x * tex2D(tex, uv.xy)
	     + w.y * tex2D(tex, uv.zy)
		 + w.z * tex2D(tex, uv.xw)
		 + w.w * tex2D(tex, uv.zw);
}


TileData init_tile(in VSOUT i)
{
    float4 tile_data = tex2Dbicub(sDilatedTileCoC, i.uv, tex2Dsize(sDilatedTileCoC));
    TileData Tile;
    Tile.min_coc = tile_data.x;
    Tile.max_coc = tile_data.y;
    Tile.min_depth = tile_data.z;
    Tile.max_depth = tile_data.w;
    return Tile;
}

BokehKernelData init_kernel(in VSOUT i)
{
    BokehKernelData BokehKernel;
    sincos(radians(360.0 / VERTEX_COUNT), BokehKernel.vertexmat._21, BokehKernel.vertexmat._11);
    BokehKernel.vertexmat._12 = -BokehKernel.vertexmat._21;
    BokehKernel.vertexmat._22 = BokehKernel.vertexmat._11;

    sincos(radians(360.0 / VERTEX_COUNT) * BOKEH_ANGLE, BokehKernel.vertex_curr.y, BokehKernel.vertex_curr.x);
    BokehKernel.vertex_next = mul(BokehKernel.vertex_curr, BokehKernel.vertexmat);

    float2 v = i.uv * (2.0 * BUFFER_ASPECT_RATIO.yx) - BUFFER_ASPECT_RATIO.yx;
    //v.y = -v.y; //fix handedness so v.xy = cos, sin of angle to center
    v.xy /= length(BUFFER_ASPECT_RATIO); //normalize so |v| = 1 in corners
    float r = length(v); v/= r;

#if ADVANCED_BOKEH_EFFECTS != 0
    float scale_tangential = r * BOKEH_RATIO_TANGENTIAL;
    float scale_sagittal   = r * BOKEH_RATIO_SAGITTAL;
    float scale_horizontal = rcp(BOKEH_ANAMORPH_RATIO);
    float scale_vertical   = 1.0;

    float2 k = 1.0 + float2(scale_tangential, scale_sagittal);
    float d = (k.x - k.y) * v.x * v.y;

    //rotate * scale A * rotate back * scale B
    BokehKernel.scalemat = float2x2(
        dot(k, v * v) * scale_horizontal,      d,
        d * scale_horizontal,                  dot(k.yx, v * v)
    );
#else 
    BokehKernel.scalemat = float2x2(1,0,0,1);
#endif
    return BokehKernel;
}

float4 get_af_aabb()
{
    float2 focus_uv = AUTOFOCUS_CENTER * 0.5 + 0.5;
    float4 focus_aabb; //sample square window around focal point
    focus_aabb.xy = focus_uv - AUTOFOCUS_RANGE * BUFFER_ASPECT_RATIO * 0.5;
    focus_aabb.zw = focus_uv + AUTOFOCUS_RANGE * BUFFER_ASPECT_RATIO * 0.5;
    focus_aabb = saturate(focus_aabb); //clamp to screen
    return focus_aabb;
}

/*=============================================================================
	Shader Entry Points
=============================================================================*/

uniform bool MMB_DOWN < source = "mousebutton"; keycode = 2; mode = ""; >;

float4 VS_SaveMouse(in uint id : SV_VertexID) : SV_Position
{    
    return float4(!MMB_DOWN, !MMB_DOWN, 0, 1); //faster than discard because this kills the write in the geometry stage
}

void PS_SaveMouse(in float4 vpos : SV_Position, out float2 o : SV_Target0)
{ 
    o = MOUSE_POINT;
}

float4 VS_Focus(in uint id : SV_VertexID) : SV_Position
{ 
	//return float4(id.xx == uint2(2, 1) ? float2(3, -3) : float2(-1, 1), 0, 1);
    float2 uv; float4 vpos;
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
	vpos = float4(uv.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return vpos;
}

void PS_FocusReduce16(in float4 vpos : SV_Position, out float o : SV_Target0)
{ 
    if(FOCUS_MODE != 1)
        discard;
   
    float4 focus_aabb = get_af_aabb();
    float2 aabb_span = focus_aabb.zw - focus_aabb.xy;

    int2 samples = ceil(aabb_span * 16 * BUFFER_ASPECT_RATIO); //sample at most 5 samples vertically = 80 because it's 16 threads doing it

    float2 grid_shift = (floor(vpos.xy) + 0.5) / 16.0;
    float2 focus = 0;

    for(int x = 0; x < samples.x; x++)
    for(int y = 0; y < samples.y; y++)
    {
        float2 grid_uv_norm = (float2(x, y) + grid_shift) / samples;
        float2 grid_uv_screen = lerp(focus_aabb.xy, focus_aabb.zw, grid_uv_norm);

        float z = tex2Dlod(sDepthTexLo, grid_uv_screen, 0).x; //this is lagging 1 frame behind, consider swapping order of shaders?

        //real cameras measure contrast, which is inversely proportional to "how much out of focus is it"
        //as such, avg of depth doesn't work, because far depths can be hugely out of focus (30m vs infinity focus) and still be sharp
        //but for close areas, the tiniest focal change results in a big blur. So the weighting must be proportional to the influence
        //changes to the focus plane have on this pixel. Which is the steepness of the CoC curve, which is proportional to 1/(depth^2).
        float w = rcp(z * z + 1e-6); 

        w *= exp2(-dot(grid_uv_norm * 2 - 1, grid_uv_norm * 2 - 1) * 4.0); //weight samples outside from center less
        focus += float2(z, 1) * w;
    }

    o = focus.x / focus.y;
}

void PS_FocusReduce1(in float4 vpos : SV_Position, out float4 o : SV_Target0)
{ 
    if(FOCUS_MODE == 0)
    {
        o.xyz = RAW_FOCUS_PLANE_DEPTH * RAW_FOCUS_PLANE_DEPTH;
        o.w = 1;
        return;
    }

    if(FOCUS_MODE == 2)
    {
        o.xyz = tex2Dfetch(sColorAndDepthTex, tex2Dfetch(sLastMousePt, int2(0,0)).xy).w;
        o.w = 1;
        return;
    }

    float focus = 0;
    float minfocus = 10000;

    for(uint x = 0; x < 16; x++)
    for(uint y = 0; y < 16; y++)
    {
        float f = tex2Dfetch(sFocusTex16, int2(x, y)).x; //tex2Dgather!
        focus += f;
        minfocus = min(f, minfocus);
    }

    o = focus / 256.0;
    o = lerp(o, minfocus, 0.15); //bias towards min a bit
    o.w = saturate(AUTOFOCUS_SPEED * max(FRAME_TIME, 1.0)/50.0);
}

VSOUT VS_DOF(in uint id : SV_VertexID)
{
    VSOUT o;
    o.uv.x = (id == 2) ? 2.0 : 0.0;
    o.uv.y = (id == 1) ? 2.0 : 0.0;
	o.vpos = float4(o.uv.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    //set up camera parameters
    const float sensor_diag_mm  = 43.3; //mm
    float focal_dist            = get_focal_distance(); //depth -> m
    float focal_dist_mm         = focal_dist * 1000.0; //m -> mm
	float focal_length_mm       = FOCAL_LENGTH; //alternatively: 0.5 * SENSOR_SIZE * rcp(tan(radians(fov_degrees) * 0.5)) //FOV must be diagonal!

	float coc_inf_diameter_mm = focal_length_mm * focal_length_mm * rcp(FSTOPS * (focal_dist_mm - focal_length_mm));	
	float max_coc = 0.5 * coc_inf_diameter_mm / sensor_diag_mm; //unitless screen space % maximum coc radius (at infinity)

    o.camera.x = max_coc;
    o.camera.y = focal_dist;
    
    return o;
}

void PS_MakeInputs(in VSOUT i, out float4 o : SV_Target0)
{
    o.rgb = tex2D(ColorInput, i.uv).rgb;unpack_hdr(o.rgb);
	o.a = Depth::get_linear_depth(i.uv);   

    if(BOKEH_SHAPE_DEBUG)
    {
        float num_img = 10.0;
        float2 uv = (frac((i.uv - 0.5) * num_img * BUFFER_ASPECT_RATIO.yx + 0.5) - 0.5) / num_img;
        o.rgb = length(uv * BUFFER_SCREEN_SIZE.x) < 3.5 ? 32.0 : BOKEH_SHAPE_DEBUG == 1 ? o.rgb : 0.0;
    } 
}

void PS_DownsampleInputs(in VSOUT i, out float4 o1 : SV_Target0, out float o2 : SV_Target1)
{
    float4 colordepth = tex2D(sColorAndDepthTex, i.uv);
    float depth = colordepth.w;
    
    //wz
    //xy

#if FULL_RESOLUTION != 0
    float max_abs_coc = get_coc(i, depth);
#else
    float4 depths = tex2DgatherA(sColorAndDepthTex, i.uv);

    float4 cocs;
    cocs.x = get_coc(i, depths.x);
    cocs.y = get_coc(i, depths.y);
    cocs.z = get_coc(i, depths.z);
    cocs.w = get_coc(i, depths.w);

    float max_abs_coc = cocs.x;
    max_abs_coc = lerp(max_abs_coc, cocs.y, abs(cocs.y) > abs(max_abs_coc));
    max_abs_coc = lerp(max_abs_coc, cocs.z, abs(cocs.z) > abs(max_abs_coc));
    max_abs_coc = lerp(max_abs_coc, cocs.w, abs(cocs.w) > abs(max_abs_coc));
#endif  
    if(USE_PREFILTER)
    {

        float4 prefilter = float4(colordepth.rgb, 1);

        float ring_spacing = COC_CLAMP / RING_COUNT_MAX;
        float ramp = saturate(abs(max_abs_coc) / COC_CLAMP * RING_COUNT_MAX);

        float pixel_radius = ramp * ring_spacing * BUFFER_WIDTH * 0.3; 

        for(int x = -pixel_radius; x <= pixel_radius; x++)
        for(int y = -pixel_radius; y <= pixel_radius; y++)
        {
            float2 offs = float2(x, y);
            float w = smoothstep(1.2, 0.8, length(offs) / pixel_radius);
            offs *= BUFFER_PIXEL_SIZE * LAYER_PIXEL_SIZE_SCALE;

            float4 tap = tex2Dlod(sColorAndDepthTex, i.uv + offs, 0);     
            float tap_coc = get_coc(i, tap.w);
            prefilter += float4(tap.rgb, 1) * (abs(tap_coc) >= abs(max_abs_coc)*0.5) * w;
        }

        prefilter.rgb /= prefilter.w;
        colordepth.rgb = (prefilter.rgb);
    }    

    o1 = colordepth;
    o2 = depth;
}


void PS_TileCoC(in VSOUT i, out float4 o : SV_Target0)
{
	o = float4(1000000, -1000000, 1.0, 0.0);
	float2 srcsize = BUFFER_SCREEN_SIZE; //tex2Dsize(sColorAndDepthTex);

    int2 grid_start = i.vpos.xy * DILATED_COC_TILE_SIZE;

	for(int x = 0; x < DILATED_COC_TILE_SIZE; x++)
	for(int y = 0; y < DILATED_COC_TILE_SIZE; y++)
	{
		float depth = Depth::get_linear_depth(float2(grid_start.x + x, grid_start.y + y) / srcsize.xy);        
        float coc = get_coc(i, depth);

		o.x = min(o.x, coc); 
        o.y = max(o.y, coc);
       
        o.z = min(o.z, depth);
        o.w = max(o.w, depth);
	}
}

void PS_TileDilate(in VSOUT i, out float4 o : SV_Target0)
{
    float4 tile_data = tex2Dfetch(sTileCoC, i.vpos.xy);

    //we need to search (gather) the entire maximum CoC radius
    //however, we only need to store the biggest CoC that would be able to scatter onto this one
    float dilate_radius = COC_CLAMP;
    float tile_scale = tex2Dsize(sTileCoC).x;
    int dilate_window_tiles = ceil(dilate_radius * tex2Dsize(sTileCoC).x); //.x because CoC is in % of screen width as per convention
    dilate_window_tiles++; //some padding
    float4 dilated_tile_data = tile_data;

    for(int x = -dilate_window_tiles; x <= dilate_window_tiles; x++)
    for(int y = -dilate_window_tiles; y <= dilate_window_tiles; y++)
    {
        int2 tpos = i.vpos.xy + int2(x, y);
        float4 t = tex2Dfetch(sTileCoC, tpos);
        float curr_abs_coc = max(abs(t.x), abs(t.y));
        float dilate_distance = length(float2(x, y)) / tile_scale; //% of screen width, same as CoC

        //if the coc of the currently sampled tile would be able to scatter onto the current "pixel", take it
        //theoretically, this could be done with max coc for background, and min coc for foreground separately
        if(dilate_distance < curr_abs_coc * 1.5) //padding so the maximum intersectable coc spreads father than it should, to make 100% sure we don't get artifacts
        {
            tile_data.xz = min(tile_data.xz, t.xz); 
            tile_data.yw = max(tile_data.yw, t.yw);
        }
    }

    o = tile_data;
}

float spherical_abberation(float ring_idx, float num_rings, float kernel_radius, float tap_coc, float amount)
{
    float radius_percent = ring_idx / num_rings;
    float w = saturate(kernel_radius * radius_percent/abs(tap_coc) - 0.5);
    w = amount > 0 ? w : 1-w;
    w = lerp(1, w + 1e-3, abs(amount));
    w *= w;
    w *= w; 
    return w;
}

float chebyshev_occlusion(float3 moment_data, float x)
{
    float2 moments = moment_data.yz / (moment_data.x + 1e-5);

    float var = abs(moments.x * moments.x - moments.y);
    float d = max(0, x - moments.x);
    float chebyshev = saturate(var / (var + d * d));   
    float falloff = moments.x / COC_CLAMP;
    return lerp(chebyshev, 1, falloff * falloff);
}

void PS_BokehBG(in VSOUT i, out float4 o : SV_Target0)
{
    BokehKernelData BokehKernel = init_kernel(i);
    TileData        Tile        = init_tile(i);

    float scatter_radius_max = Tile.max_coc;
    float scatter_radius_min = min(abs(Tile.max_coc), abs(Tile.min_coc)); 
    float scatter_radius_highestpossible = get_max_abs_coc(i).y;
    int ring_count = ceil(scatter_radius_max / scatter_radius_highestpossible * RING_COUNT_MAX);
    float kernel_radius = float(ring_count) / RING_COUNT_MAX * scatter_radius_highestpossible;  
    ring_count = max(ring_count, 3);

    [branch]
    if(USE_UNDERSAMPLE_PROTECTION)
        ring_count = min(25, ceil(RING_COUNT_MAX * abs(scatter_radius_max) / max(scatter_radius_min, 0.25 * scatter_radius_max)));

    int density_scale = max(1, 6 - VERTEX_COUNT);  

    float4 center = tex2Dlod(sColorAndDepthTexLo, i.uv, 0);
    float center_coc = get_coc(i, center.w); 

    if(center_coc < 0)
    {
        o = center;
        return;
    }

    float4 bokehsum = 0;
    float3 coc_m1m2 = float3(1, center_coc, center_coc * center_coc) * sample_alpha(center_coc); //1, m1, m2  

/*
    float2 center_vec = i.uv * 2.0 - 1.0;
    float vig = dot(center_vec, center_vec);
    vig = rcp(1 + vig); vig *= vig; vig = 1-vig;
    center_vec = normalize(center_vec);
*/
    for(float r = 1; r <= ring_count; r++)
    {
        //accumulate central moments per ring, so we don't get different weighting across the rings
        float3 coc_m1m2_ring = 0;
        for(int v = 0; v < VERTEX_COUNT; v++)
        {            
            for(float s = 0; s < r * density_scale; s++)
            {                
                //aperture roundness
                float h = s / (r * density_scale);
                float a = h * h * (3.0 - 2.0 * h);
                float l = 2.55 * rcp(VERTEX_COUNT * VERTEX_COUNT * 0.4 - 1.0);
                h = lerp(h, (1.0 + l) * h - a * l, APERTURE_ROUNDNESS);

                float2 tap_location = lerp(BokehKernel.vertex_curr, BokehKernel.vertex_next, h);
                tap_location *= (1.0 - APERTURE_ROUNDNESS) + rsqrt(dot(tap_location, tap_location)) * APERTURE_ROUNDNESS; //lerp normalize
#if ADVANCED_BOKEH_EFFECTS != 0
                tap_location = mul(tap_location, BokehKernel.scalemat);
#endif
                //float ring_radius = (kernel_radius * r) / ring_count; 
                float ring_radius = (kernel_radius * r) / (ring_count + 0.5);   
                
                float4 tap = tex2Dlod(sColorAndDepthTexLo, i.uv + tap_location * ring_radius * BUFFER_ASPECT_RATIO, 0);     

                //float vigfactor = sqrt(saturate(dot(center_vec, tap_location) * BOKEH_OPTICAL_VIG * vig)) * ring_count;      

                float tap_coc       = get_coc(i, tap.w); 
                float alpha         = sample_alpha(tap_coc);
                float intersect     = sample_intersect(tap_coc, ring_count, r, kernel_radius); //TODO unhappy with this, this uses different intersect than the other ._.

                float tap_weight = alpha * intersect; // * saturate(tap_coc / COC_CLAMP * 4.0);

                tap_weight *= chebyshev_occlusion(coc_m1m2, tap_coc);
#if ADVANCED_BOKEH_EFFECTS != 0               
                tap_weight *= spherical_abberation(r, ring_count, kernel_radius, tap_coc, BOKEH_SPHERICAL_ABB);    
#endif
                bokehsum += float4(tap.rgb, 1) * tap_weight;
                coc_m1m2_ring += float3(1, tap_coc, tap_coc * tap_coc) * tap_weight;
            }

            BokehKernel.vertex_curr = BokehKernel.vertex_next;
            BokehKernel.vertex_next = mul(BokehKernel.vertex_curr, BokehKernel.vertexmat);
        }
        coc_m1m2 += coc_m1m2_ring;
    }
    float4 tap = center;
    float tap_coc = center_coc;    
    float alpha = sample_alpha(tap_coc);
    float intersect = 1;

    float tap_weight = alpha * intersect;
#if ADVANCED_BOKEH_EFFECTS != 0
    tap_weight *= spherical_abberation(0, ring_count, kernel_radius, tap_coc, BOKEH_SPHERICAL_ABB);          
#endif
    bokehsum += float4(tap.rgb, 1) * tap_weight;
        
    o.rgb  = bokehsum.rgb/bokehsum.w;
    o.w = 1;
}

void PS_BokehFG(in VSOUT i, out float4 o : SV_Target0)
{
    BokehKernelData BokehKernel = init_kernel(i);  
    TileData       Tile         = init_tile(i);

    float scatter_radius_max = abs(Tile.min_coc);
    float scatter_radius_min = min(abs(Tile.max_coc), abs(Tile.min_coc)); //technically only max coc but the presence of some super big background coc might ruin this    

    float scatter_radius_highestpossible = get_max_abs_coc(i).x;
    uint ring_count = ceil(scatter_radius_max / scatter_radius_highestpossible * RING_COUNT_MAX);
    float kernel_radius = float(ring_count) / RING_COUNT_MAX * scatter_radius_highestpossible;  
    ring_count = max(ring_count, 3);

    [branch]
    if(USE_UNDERSAMPLE_PROTECTION)
        ring_count = min(25, ceil(RING_COUNT_MAX * abs(scatter_radius_max) / max(scatter_radius_min, 0.25 * scatter_radius_max)));

    int density_scale = max(1, 6 - VERTEX_COUNT);

    float4 sum_fg       = 0;
    float4 sum_bg       = 0;
    float4 sum_all      = 0;

    float max_foreground_coc = 0;

    float4 center = tex2Dlod(sColorAndDepthTexLo, i.uv, 0);
    float center_depth = center.w;
    float center_coc = get_coc(i, center.w);

    if(scatter_radius_max < 0.0001)
    {
        o = float4(center.rgb, 0);
        return;
    }  
/*
    float2 center_vec = i.uv * 2.0 - 1.0;
    float vig = dot(center_vec, center_vec);
    vig = rcp(1 + vig); vig *= vig; vig = 1-vig;
    center_vec = normalize(center_vec);
*/
    for(int v = 0; v < VERTEX_COUNT; v++)
    {
        for(float r = 1; r <= ring_count; r++)
        for(float s = 0; s < r * density_scale; s++)
        {
            //aperture roundness
            float h = s / (r * density_scale);
            float a = h * h * (3.0 - 2.0 * h);
            float l = 2.55 * rcp(VERTEX_COUNT * VERTEX_COUNT * 0.4 - 1.0);
            h = lerp(h, (1.0 + l) * h - a * l, APERTURE_ROUNDNESS);
            float2 tap_location = lerp(BokehKernel.vertex_curr, BokehKernel.vertex_next, h);
            tap_location *= (1.0 - APERTURE_ROUNDNESS) + rsqrt(dot(tap_location, tap_location)) * APERTURE_ROUNDNESS; 
#if ADVANCED_BOKEH_EFFECTS != 0
            tap_location = mul(tap_location, BokehKernel.scalemat);
#endif
            //float ring_radius = (kernel_radius * (r)) / ring_count;     
            float ring_radius = (kernel_radius * r) / (ring_count + 0.5);     

            float4 tap = tex2Dlod(sColorAndDepthTexLo, i.uv - tap_location * ring_radius * BUFFER_ASPECT_RATIO, 0); //- for foreground shape inversion
            float mirror_depth = tex2Dlod(sDepthTexLo, i.uv + tap_location * ring_radius * BUFFER_ASPECT_RATIO, 0).x;
            tap.w = min(tap.w, mirror_depth);

            //float vigfactor = sqrt(saturate(dot(-center_vec, tap_location) * BOKEH_OPTICAL_VIG * vig)) * ring_count; //- for inverted in foreground     

            float tap_coc       = get_coc(i, tap.w); 
            float alpha         = sample_alpha(tap_coc);
            float intersect     = sample_intersect(tap_coc, ring_count, r, kernel_radius); //TODO unhappy with this, this uses different intersect than the other ._.

            float is_foreground = tap_coc < 0 ? 1 : 0;

            float fg_weight = get_fg_weight(tap.w, tap_coc, Tile, center_depth);
            float bg_weight = 1 - fg_weight;
#if ADVANCED_BOKEH_EFFECTS != 0
            alpha *= spherical_abberation(r, ring_count, kernel_radius, tap_coc, -BOKEH_SPHERICAL_ABB);
#endif
            sum_fg  += float4(tap.rgb, 1) * alpha * intersect * fg_weight * is_foreground;
            sum_bg  += float4(tap.rgb, 1) * alpha * intersect * bg_weight * is_foreground;
            sum_all += float4(tap.rgb, 1) * alpha; // * !is_foreground;

            max_foreground_coc = max(max_foreground_coc, -tap_coc * intersect);

        }
        BokehKernel.vertex_curr = BokehKernel.vertex_next;
		BokehKernel.vertex_next = mul(BokehKernel.vertex_curr, BokehKernel.vertexmat);
    }

    //center
    float4 orig = tex2Dlod(sColorAndDepthTexLo, i.uv, 0);
    float4 tap = orig;
    float tap_coc   = get_coc(i, tap.w);     
   
    float alpha         = sample_alpha(tap_coc);
    float intersect     = 1.0;
    float is_foreground = tap_coc < 0 ? 1 : 0;

    float fg_weight = get_fg_weight(tap.a, tap_coc, Tile, center_depth);
    float bg_weight = 1 - fg_weight;  
#if ADVANCED_BOKEH_EFFECTS != 0
    alpha *= spherical_abberation(0, ring_count, kernel_radius, tap_coc, -BOKEH_SPHERICAL_ABB);    
#endif
    sum_fg  += float4(tap.rgb, 1) * alpha * intersect * fg_weight * is_foreground;
    sum_bg  += float4(tap.rgb, 1) * alpha * intersect * bg_weight * is_foreground;
    sum_all += float4(tap.rgb, 1) * alpha; // * !is_foreground;  

    max_foreground_coc = max(max_foreground_coc, -tap_coc * intersect);   

    float num_samples = density_scale * VERTEX_COUNT * ring_count * (ring_count + 1) / 2 + 1; //+1 -> center

    if(sum_fg.w != 0)  sum_fg.rgb  /= sum_fg.w;
    if(sum_bg.w != 0)  sum_bg.rgb  /= sum_bg.w;
    if(sum_all.w != 0) sum_all.rgb  /= sum_all.w;

    float covered_area = kernel_radius * (ring_count + 0.5) / ring_count;
    float foreground_opacity = saturate((sum_bg.w == 0 ? 1 : 0) + 1.0/num_samples / sample_alpha(covered_area) * sum_fg.w);    

    float4 blurry_foreground = lerp(sum_bg, sum_fg, foreground_opacity);  
    float foreground_coc_radius = saturate(-tap_coc * BUFFER_WIDTH / LAYER_PIXEL_SIZE_SCALE);

    float foreground_alpha = saturate((sum_fg.w + sum_bg.w) / sample_alpha(covered_area) / num_samples); //ratio of accumulated intersected alphas with alpha of kernel
    blurry_foreground = lerp(blurry_foreground, sum_all, saturate(saturate(1 - foreground_alpha) * foreground_coc_radius));
    
    foreground_alpha = max(foreground_alpha, saturate(-tap_coc * BUFFER_WIDTH / LAYER_PIXEL_SIZE_SCALE)); //if center pixel is in fg, then the fg layer shall be taken
    foreground_alpha *= saturate(max_foreground_coc * BUFFER_WIDTH * 0.125); //dynamic fadeout to fullres

    blurry_foreground = lerp(blurry_foreground, orig, (sum_fg.w + sum_bg.w) < 1e-6); //fig black border bug

    o = blurry_foreground;
    o.w = foreground_alpha;
}

void PS_MergeLayers(in VSOUT i, out float4 o : SV_Target0)
{
    float4 orig = tex2D(sColorAndDepthTex, i.uv);

    float4 fg = tex2D(sForegroundTex, i.uv);
    float4 bg = tex2D(sBackgroundTex, i.uv);

    float highres_coc  = get_coc(i, orig.w); 

    float2 transition_fgbg = saturate(float2(-highres_coc, highres_coc) * BUFFER_WIDTH / LAYER_PIXEL_SIZE_SCALE);
    transition_fgbg.x = max(fg.w, transition_fgbg.x); //fixes some artifacts 

    o = lerp(orig, bg, transition_fgbg.y);      
    o = lerp(o, fg, transition_fgbg.x);

    pack_hdr(o.rgb); 
    o.w = max(transition_fgbg.x, transition_fgbg.y);
}

void PS_PostPass(in VSOUT i, out float4 o : SV_Target0)
{
    o = tex2D(ColorInput, i.uv); 

    if(abs(BOKEH_SMOOTHNESS) < 1e-3) return;  

    float ww = o.w;
    float4 maxfilter = float4(o.rgb * o.rgb, 1);
    float3 mintap = 10000; 
    float3 maxtap = 0;
    for(int r = 1; r <= 3; r++)
    for(int s = 0; s < r * 4; s++)
    {
        float2 dir; sincos(s * rcp(r * 4.0) * PI * 2.0, dir.y, dir.x);
        dir *= BUFFER_PIXEL_SIZE * ww;
        dir *= abs(BOKEH_SMOOTHNESS) * 4.0;
        dir *= r / 3.0;
        float4 tap = tex2Dlod(ColorInput, i.uv + dir, 0); 

        float tapw = saturate(tap.w * 10.0); 
        tapw *= BOKEH_SMOOTHNESS < 0 ? cos(r / 4.0 * 1.57) : 1;
        maxfilter +=float4(tap.rgb * tap.rgb, 1) * tapw;

        mintap = lerp(mintap, min(mintap, tap.rgb), tapw);
        maxtap = lerp(maxtap, max(maxtap, tap.rgb), tapw);
    }
    maxfilter.rgb /= maxfilter.w;
    maxfilter.rgb = sqrt(maxfilter.rgb);

    [branch]
    if(BOKEH_SMOOTHNESS < 0)
    {
        //sharpen mode
        maxfilter.rgb = lerp(o.rgb, maxfilter.rgb, -1.415);
        maxfilter.rgb = lerp(mintap,        maxfilter.rgb, smoothstep(mintap,        maxfilter.rgb, o.rgb));
        maxfilter.rgb = lerp(maxfilter.rgb, maxtap,        smoothstep(maxfilter.rgb, maxtap,        o.rgb));
    }
  
    o.rgb = maxfilter.rgb; 



/*
    float4 focus_aabb = get_af_aabb();
    float2 aabb_span = focus_aabb.zw - focus_aabb.xy;

    float z = Depth::get_linear_depth(i.uv);  
    float coc = get_coc(i, z); 

    if(coc > 0)
    o.r *= 0.6;

    float2 normuv = linearstep(focus_aabb.xy, focus_aabb.zw, i.uv);

    if(all(saturate(normuv - normuv * normuv)))
        o.rgb *= 0.9;    
*/
}


/*=============================================================================
	Techniques
=============================================================================*/

technique PhysicalDOF_MKII
{
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_MakeInputs;
        RenderTarget = ColorAndDepthTex;
    }
    pass
	{
		VertexShader = VS_SaveMouse;
		PixelShader = PS_SaveMouse;
		RenderTarget = LastMousePt;
		PrimitiveTopology = POINTLIST;
		VertexCount = 1;
    }
    pass
	{
		VertexShader = VS_Focus;
		PixelShader  = PS_FocusReduce16;
        RenderTarget = FocusTex16;
    } 
    pass
	{
		VertexShader = VS_Focus;
		PixelShader  = PS_FocusReduce1;
        RenderTarget = FocusTex1;
        BlendEnable = true;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
    }  
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_DownsampleInputs;
        RenderTarget0 = ColorAndDepthTexLo;
        RenderTarget1 = DepthTexLo;
	}

    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_TileCoC;
        RenderTarget = TileCoC;
	}
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_TileDilate;
        RenderTarget = DilatedTileCoC;
	}    
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_BokehFG;
        RenderTarget = ForegroundTex;
	}
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_BokehBG;
        RenderTarget = BackgroundTex;
	}    
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_MergeLayers;
	} 
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_PostPass;
	}    
}