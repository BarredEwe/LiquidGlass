#include <metal_stdlib>
using namespace metal;

// ──────────────────────────────────────────
// Vertex → Fragment interface
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// ──────────────────────────────────────────
// Constant buffer (buffer(0)) – 16-byte aligned
struct Uniforms {
    float2 resolution;
    float time;
    float blurScale;
    float2 boxSize;
    float cornerRadius;
    float3 tintColor;
    float tintAlpha;
};

float boxSDF(float2 uv, float2 boxSize, float cornerRadius) {
    float2 q = abs(uv) - boxSize * 0.5 + cornerRadius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - cornerRadius;
}

// ──────────────────────────────────────────
// Noise-based jitter for cheap blur
float2 randomVec2(float2 co) {
    float2 seed = fract(co * 0.12345 + float2(4.44, 7.77));
    return fract(sin(seed * float2(127.1, 311.7)) * 43758.5453);
}

float3 stableSample(float2 uv, float timeOffset, float mipLevel,
                    texture2d<float> tex, sampler samp,
                    constant Uniforms &u) {
    float2 jitter = randomVec2(uv + float2(u.time + timeOffset)) * 0.5;
    float lod = clamp(mipLevel - 1.0, 0.0, 10.0);
    return tex.sample(samp, uv + jitter / u.resolution.x, level(lod)).rgb;
}

// Colour helpers
float3 saturateColor(float3 color, float factor) {
    float gray = dot(color, float3(0.299, 0.587, 0.114));
    return mix(float3(gray), color, factor);
}

// Gaussian-ish blur
float3 getBlurredColor(float2 uv, float mipLevel,
                       texture2d<float> tex, sampler samp,
                       constant Uniforms &u) {
    const float offsets[9] = {0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0};
    float3 sum = float3(0.0);
    for (uint i = 0; i < 9; ++i) {
        sum += stableSample(uv, offsets[i], mipLevel, tex, samp, u);
    }
    float3 avg = sum * 0.1;

    // Сатурация + гамма
    avg = saturateColor(avg, 2.0);
    avg = mix(avg, avg * avg, 0.5);

    return avg;
}

// Refraction offset based on SDF
float2 computeRefractOffset(float sdf) {
    if (sdf < 0.1) return float2(0.0);

    float2 grad = normalize(float2(dfdx(sdf), dfdy(sdf)));
    float offsetAmount = pow(abs(sdf), 12.0) * -0.1;
    return grad * offsetAmount;
}

// Edge highlight for glossy rim
float highlight(float sdf) {
    if (sdf < 0.1) return 0.0;

    float2 grad = normalize(float2(dfdx(sdf), dfdy(sdf)));
    return 1.0 - clamp(pow(1.0 - abs(dot(grad, float2(-1.0, 1.0))), 0.5), 0.0, 1.0);
}

// ──────────────────────────────────────────
// Fragment shader
fragment float4 liquidGlassFragment(VertexOut in               [[stage_in]],
                                    constant Uniforms &u       [[buffer(0)]],
                                    texture2d<float> iChannel0 [[texture(0)]],
                                    sampler iChannel0Sampler   [[sampler(0)]]) {
    // Y-flip so snapshot matches UIKit orientation
    float2 uvTex = float2(in.uv.x, 1.0 - in.uv.y);
    float2 fragCoord = uvTex * u.resolution;
    float2 centeredUV = fragCoord - u.resolution * 0.5;
    float sdf = boxSDF(centeredUV, u.boxSize, u.cornerRadius);

    float normalizedInside = (sdf / u.boxSize.y) + 1.0;
    float edgeBlendFactor = pow(normalizedInside, 12.0);

    // Sharp background
    float3 baseTex = iChannel0.sample(iChannel0Sampler, uvTex).rgb;

    // Blur strength via blurScale
    float s = u.blurScale;
    float mipLevel = mix(0.0, 6.0, pow(s, 1.8));
    float weight = pow(s, 1.5);

    float2 sampleUV = uvTex + computeRefractOffset(normalizedInside);
    float3 blurred = getBlurredColor(sampleUV, mipLevel, iChannel0, iChannel0Sampler, u);

    // Mix sharp/blurred by blurScale
    float3 mixed = mix(baseTex, blurred, weight);

    // Rim-light
    mixed += clamp(highlight(normalizedInside) * pow(edgeBlendFactor, 5.0), 0.0, 1.0) * 0.5;

    // Glass tint
    mixed = mix(mixed, u.tintColor, u.tintAlpha * weight);

    // Subtle veil + noise
    float3 veilTint = float3(0.96, 0.98, 1.0);
    mixed = mix(mixed, veilTint, 0.1 * weight);

    float n = randomVec2(uvTex + u.time).x - 0.5;
    mixed += n * 0.03 * weight;

    // Inside mask
    float boxMask = 1.0 - clamp(sdf, 0.0, 1.0);
    float3 final = mix(baseTex, mixed, boxMask);

    return float4(final, 1.0);
}

// ──────────────────────────────────────────
// Pass-through vertex
vertex VertexOut vertexPassthrough(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2(-1.0,  1.0), float2( 1.0, -1.0), float2( 1.0,  1.0)
    };
    VertexOut v;
    v.position = float4(positions[vertexID], 0.0, 1.0);
    v.uv = positions[vertexID] * 0.5 + 0.5;
    return v;
}
