import aperture;
import helpers.util;

import lib.atmosphere;

struct FragmentOutput {
    float4 ambientScattering;
}


float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}

//// Main
[[shader("pixel")]]
FragmentOutput ambientSky(float2 pos: SV_Position) {

    float2 halfRes = float2(ap.game.screenSize) / 2.0;

    float2 texcoord = pos / halfRes;
    float depth = ap.depth.sampleLinear(texcoord);

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = float3(0.0, ap.camera.position.y, 0.0);
    float3 playerSpaceRayDirection = normalize(playerSpacePos);

    if (depth != 0) {
        marchPrimaryRay ray = rayMarch(playerSpacePos + playerSpaceRayOrigin, float3(0.0, 1.0, 0.0));

        FragmentOutput output;

        output.ambientScattering = float4(ray.scattering, 1.0);

        return output;
    }

    FragmentOutput output;

    output.ambientScattering = float4(float3(0.0), 1.0);

    return output;
}