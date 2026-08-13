import aperture;
import helpers.util;

import lib.ambientocclusion;

Texture2D flatNormal;

struct FragmentOutput {
    float4 ssaoInput;
}

static const float RADIUS = 0.5;

float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}

//// Main
[[shader("pixel")]]
FragmentOutput ambientOcclusion(float2 pos: SV_Position) {

    float2 texcoord = pos / ap.game.screenSize;
    float depth = ap.depth.sampleLinear(texcoord);

    float3 flatNormal = flatNormal[pos].rgb;

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 viewNormal = mul(ap.camera.view, float4(flatNormal, 1.0)).xyz;

    if (depth != 0) {
        
        float ssao = ssao(viewPos, viewNormal, RADIUS, pos);

        FragmentOutput output;

        output.ssaoInput = float4(float3(ssao), 1.0);

        return output;
    }

    FragmentOutput output;

    output.ssaoInput = float4(float3(1.0), 1.0);

    return output;
}