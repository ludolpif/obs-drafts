// OBS-specific syntax adaptation to HLSL standard to avoid errors reported by the code editor
#define SamplerState sampler_state
#define Texture2D texture2d

// XXX voir dans GLSL vec4 texture2DLod(sampler2D) pour niveau de détail inférieur pour discard les mini zones ?
// http://developer.nvidia.com/GPUGems/gpugems_part01.html
// http://www.opengl.org/registry/doc/GLSLangSpec.4.30.8.pdf

// Uniform variables set by OBS (required)
uniform float4x4 ViewProj; // View-projection matrix used in the vertex shader
uniform Texture2D image;   // Texture containing the source picture (from camera)

// Extra uniform variables set by cam-png-compose OBS plugin
uniform Texture2D image2;  // Texture containing the picture to mix in (from png)
uniform bool draw_config_visuals_enable = true;
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
	vert_out.uv2  = v_in.uv; // TODO make pos/scale configurable
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
float4 PSDrawConfigVisuals(VertDataOut v_in, float2 k1_uv, float4 k1_s) {
    float4 rgba_red   = float4(1.0, 0.0, 0.0, 1.0);
    float4 rgba_black = float4(0.0, 0.0, 0.0, 1.0);
    float4 rgba_none  = float4(0.0, 0.0, 0.0, 0.0);

    float2 tmp = pow(v_in.uv - k1_uv, float2(2.0, 2.0));
    if ( tmp.x + tmp.y < 0.00001 ) return rgba_black;
    if ( tmp.x + tmp.y < 0.001   ) return float4(k1_s.rgb, 1.0);
    if ( tmp.x + tmp.y < 0.0012  ) return rgba_red;
    return rgba_none;
}

// Pixel shader used to ...
float4 PSColorKeyRGBA(VertDataOut v_in) : TARGET {
    float4x4 key_colors_config = float4x4(
//s      t      p      q    (similarity, smoothness, uv coords)
0.080, 0.050, 0.100, 0.100,
0.080, 0.050, 0.900, 0.100,
0.080, 0.050, 0.100, 0.900,
0.080, 0.050, 0.900, 0.900
);
    float2 k1_uv = key_colors_config[2].pq;
    float4 k1_s = image.Sample(textureSampler, k1_uv);
    float3 k1_nl = GetNonlinearColor(k1_s.rgb);

    if ( draw_config_visuals_enable ) {
        float4 cv = PSDrawConfigVisuals(v_in, k1_uv, k1_s);
        if ( cv.a > 0.0 ) return cv;
    }

    float4 texel = image.Sample(textureSampler, v_in.uv);
    texel.rgb = max(float3(0.0, 0.0, 0.0), texel.rgb / texel.a);

    float colorDist = distance(k1_nl, GetNonlinearColor(texel.rgb));
    float factor = saturate(max(colorDist - similarity, 0.0) / smoothness);
    texel.a *= factor;

    texel.rgb *= texel.a;

    // Debug outputs
    //texel.a = v_in.uv.x * v_in.uv.y;
    //texel.rgb = float3(colorDist, colorDist, colorDist);
    //texel.a = 1.0;
    return texel;
}

technique Draw {
    pass {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSColorKeyRGBA(v_in);
    }
}
