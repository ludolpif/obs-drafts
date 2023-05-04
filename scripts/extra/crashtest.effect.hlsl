// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture (from camera)
// Size of the source picture
uniform int width;
uniform int height;
// Data type of the input of the vertex shader
struct VertData {
    float4 pos : POSITION;  // Homogeneous space coordinates XYZW
    float2 uv  : TEXCOORD0; // UV coordinates in the source picture
};
// Vertex shader used to compute position of rendered pixels and pass UV
VertData VSDefault(VertData v_in) {
	VertData v_out;
	v_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
	v_out.uv  = v_in.uv;
	return v_out;
}
// Interpolation method and wrap mode for sampling a texture
SamplerState textureSampler {
    Filter    = Linear; // Anisotropy / Point / Linear
    AddressU  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
    AddressV  = Clamp;  // Wrap / Clamp / Mirror / Border / MirrorOnce
};
float4 PSNegative(VertData v_in) : TARGET {
    float4 texel = image.Sample(textureSampler, v_in.uv);
    texel.rgb = -texel.rgb;
    return texel;
}
technique Draw {
    pass {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSNegative(v_in);
    }
}
