import aperture;
import helpers.util;

import lib.atmosphere;

struct FragmentOutput {
    float4 ambientScattering;
}

//// Main
[[shader("pixel")]]
FragmentOutput ambientSky(float2 pos: SV_Position) {
    FragmentOutput output;

    float2 texcoord = pos / (float2(ap.game.screenSize) / 2.0);
    float depth = ap.depth.sampleLinear(texcoord);

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = float3(0.0, ap.camera.position.y, 0.0);
    float3 playerSpaceRayDirection = normalize(playerSpacePos);

    if (depth != 0) {
        marchPrimaryRay ray = rayMarch(playerSpacePos + playerSpaceRayOrigin, float3(0.0, 1.0, 0.0));

        output.ambientScattering = float4(ray.scattering, 1.0);

        return output;
    }

    output.ambientScattering = float4(float3(0.0), 1.0);

    return output;
}