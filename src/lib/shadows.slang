public module shadows;

import aperture;

extern static const int CASCADE_COUNT;

static bool projectShadow(float3 playerPos, float3 normal, out int cascadeIndex, out float2 uv, out float depth) {

    uint cascadeCount = min(CASCADE_COUNT, max(1u, ap.celestial.cascadeCount));

    float3 shadowViewPos = mul(ap.celestial.view, float4(playerPos, 1.0)).xyz;
    float4 shadowClipPos;

    int cascade;

    for (cascade = 0; cascade < cascadeCount; cascade++) {

    shadowClipPos = mul(ap.celestial.projection[cascade], float4(shadowViewPos, 1.0));

    if (!isfinite(shadowClipPos.w) || abs(shadowClipPos.w) < 0.00001) {
    continue;
    }

    if (all(clamp(shadowClipPos.xy, float2(-1.0), float2(1.0)) == shadowClipPos.xy))
    break;
    
    }

    cascadeIndex = cascade;

    float3 shadowViewNormal = mul(float3x3(ap.celestial.view), normal);
    float3 shadowClipNormal = mul(float3x3(ap.celestial.projection[cascade]), shadowViewNormal);

    shadowClipPos.xyz += shadowClipNormal * 0.02 * pow(2.0, cascade);

    float3 ndc = shadowClipPos.xyz / shadowClipPos.w;
    uv = ndc.xy * 0.5 + 0.5;
    depth = ndc.z;

    float3 shadowPos = float3(uv, depth);
    return all(shadowPos >= 0.0 && shadowPos <= 1.0);
}

static float3 getShadow(float3 playerPos, float3 normal) {

    int cascade;
    float2 uv;
    float depth;

    float3 shadowScreenPos = projectShadow(playerPos, normal, cascade, uv, depth);

    // float3 shadowCoord = float3(shadowScreenPos.xy, cascade);
    // float4 shadowColor = texShadowColor.Sample(shadowCoord);

    float transparentShadow = ap.shadow.compare(uv, cascade, depth);
    float opaqueShadow = ap.opaqueShadow.compare(uv, cascade, depth);

    // float transparentShadow = shadowMapFiltered.SampleCmp(shadowCoord, shadowScreenPos.z);
    // float opaqueShadow = solidShadowMapFiltered.SampleCmp(shadowCoord, shadowScreenPos.z);

    // if (transparentShadow == 1.0) {
    //     shadow = float3(1.0);
    // }
    // else {
    //     shadow = transparentShadow + shadowColor.rgb * (1.0 - shadowColor.a); 
    // }

    float3 shadow = transparentShadow;
    
    if (opaqueShadow == 0.0) {
        shadow = float3(0.0);
    } 

    return shadow;
}