// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture (from camera)
// Extra uniform variables set by cam-png-compose OBS plugin
uniform Texture2D image2;  // Texture containing the picture to mix in (from png)
uniform int mode = 1;
uniform int bg_key_color = 0;
uniform float bg_saturation = 1.0;
uniform float bg_blur = 1.0;
uniform int bg_mul_enable = 0;
uniform int bg_mul_color = 0x2b2a32;
uniform float similarity = 0.080;
uniform float smoothness = 0.050;

/* Size of the source picture
uniform int width;
uniform int height;
*/

// Data type of the input of the vertex shader
struct VertDataIn {
    float4 pos : POSITION;  // Homogeneous space coordinates XYZW
    float2 uv  : TEXCOORD0; // UV coordinates in the source picture
};
// Data type of the output of the vertex shader
struct VertDataOut {
        float4 pos : POSITION;
        float2 uv  : TEXCOORD0;
        float2 uv2 : TEXCOORD1;
};
// Vertex shader used to compute position of rendered pixels and pass UV
VertDataOut VSDefault(VertDataIn v_in) {
	VertDataOut vert_out;
	vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
	vert_out.uv  = v_in.uv;
	vert_out.uv2  = v_in.uv/1.8+float2(0.1,0.1); // TODO make pos/scale configurable
	return vert_out;
}

// Interpolation method and wrap mode for sampling a texture
SamplerState textureSampler {
    Filter    = Linear; // Anisotropy / Point / Linear
    AddressU  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
    BorderColor = 00000000; // Used only with Border edges (optional)
};


// Pixel shader used to ...
float4 PSMixThreeRGBATextures(VertDataOut v_in) : TARGET {
    float4 back,middle,front;
    float4 front_and_middle;
    float4 front_and_middle_and_back;

    front    = image.Sample(textureSampler, v_in.uv);
    middle   = image.Sample(textureSampler, v_in.uv2); //XXX image2
    back     = float4(v_in.uv, 0.3, 1.0);

    front_and_middle = middle.rgba * (1.0-front.a) + front.rgba * front.a;
    front_and_middle_and_back =  back.rgba * (1.0-front_and_middle.a) + front_and_middle.rgba * front_and_middle.a;

    return front_and_middle_and_back;

    // s.rgb = max(float3(0.0, 0.0, 0.0), s.rgb / s.a);
    // s.rgb *= s.a;
    // return s;
}

technique Draw {
    pass {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSMixThreeRGBATextures(v_in);
    }
}
