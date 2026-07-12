import aperture;
import helpers.util;

import lib.atmosphere;

Texture2D mainTexture;

struct FragmentOutput {
    float4 color;
}


float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}

//// Main
[[shader("pixel")]]
FragmentOutput applySky(float2 pos: SV_Position) {

    float2 texcoord = pos / ap.game.screenSize;
    float depth = ap.depth.sampleLinear(texcoord);

    float4 color = mainTexture[pos];
    color.rgb = decodeColorRgbm16F(color.rgba);

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = float3(0.0, ap.camera.position.y, 0.0);
    float3 playerSpaceRayDirection = normalize(playerSpacePos);

    marchPrimaryRay ray = rayMarch(playerSpaceRayOrigin, playerSpaceRayDirection);

    if (depth == 0) {
        color.rgb = color.rgb * ray.transmittance + ray.scattering;
    }

    color = encodeColorRgbm16F(color.rgb);

    FragmentOutput output;

    output.color = color;

    return output;
}