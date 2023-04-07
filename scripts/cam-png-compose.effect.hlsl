// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture

// General properties
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

// Data type of the input and output of the vertex shader
struct VertData {
    float4 pos : POSITION;  // Homogeneous space coordinates XYZW
    float2 uv  : TEXCOORD0; // UV coordinates in the source picture
};

// Vertex shader used to compute position of rendered pixels and pass UV
VertData VSDefault(VertData v_in)
{
	VertData vert_out;
	vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
	vert_out.uv  = v_in.uv;
	return vert_out;
}

// Computation functions used in the pixel shader (must be declared before the pixel shader)
float GetNonlinearChannel(float u) {
	return (u <= 0.0031308) ? (12.92 * u) : ((1.055 * pow(u, 1.0 / 2.4)) - 0.055);
}

float3 GetNonlinearColor(float3 rgb) {
	return float3(GetNonlinearChannel(rgb.r), GetNonlinearChannel(rgb.g), GetNonlinearChannel(rgb.b));
}

// Interpolation method and wrap mode for sampling a texture
SamplerState textureSampler {
    Filter    = Linear; // Anisotropy / Point / Linear
    AddressU  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
    BorderColor = 00000000; // Used only with Border edges (optional)
};

// Pixel shader used to ...
float4 PSColorKeyRGBA(VertData v_in) : TARGET
{
    float4 k1 = image.Sample(textureSampler, float2(0.10, 0.10));
    float3 k1_nl = GetNonlinearColor(k1.rgb);

    float4 s;
    if ( (v_in.uv.x > 0.09) && (v_in.uv.x < 0.11) && (v_in.uv.y > 0.09) && (v_in.uv.y < 0.11) ) {
        s.rgb = k1.rgb;
        s.a = 1.0;
        return s;
    }

    s = image.Sample(textureSampler, v_in.uv);

    s.rgb = max(float3(0.0, 0.0, 0.0), s.rgb / s.a);

    float colorDist = distance(k1_nl, GetNonlinearColor(s.rgb));
    float factor = saturate(max(colorDist - similarity, 0.0) / smoothness);
    s.a *= factor;

    s.rgb *= s.a;

    // Debug outputs
    //s.a = v_in.uv.x * v_in.uv.y;
    //s.rgb = float3(colorDist, colorDist, colorDist);
    //s.a = 1.0;
    return s;
}

technique Draw
{
    pass
    {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSColorKeyRGBA(v_in);
    }
}
