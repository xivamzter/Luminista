import aperture;
import helpers.util;

Texture2D flatNormal;

struct FragmentOutput {
    float4 ssaoInput;
}

static const float RADIUS = 0.5;
static const int SAMPLE_COUNT = 16;

static const float3 samples[SAMPLE_COUNT] = {
	float3(-0,-0.05,0.09),
    float3(0.06,-0.03,0.07),
    float3(-0.09,0.02,0.05),
	float3(0.1,-0.01,0.02),
    float3(0.06,-0.05,0.06),
    float3(-0.09,-0.02,0.06),
	float3(0.05,-0.09,0),
    float3(0.06,0.09,0.01),
    float3(0.06,0.05,0.08),
	float3(-0.09,-0.03,0.07),
    float3(0.05,-0.03,0.11),
    float3(0.1,-0.06,0.04),
	float3(0.12,0.05,0.01),
    float3(-0.08,-0.08,0.08),
    float3(0.06,0.11,0.06),
	float3(-0.02,0.14,0.04)
};

public float3x3 constructOrthonormalBasis(float3 normal) {
    float3 absNormal = abs(normal);

    return float3x3(
        float3(absNormal.y + normal.z, 0.0, -normal.x),
        float3(0.0, -absNormal.x - absNormal.z, absNormal.y),
        normal
    );
}

public float bayer2x2(float2 xy) {
    xy = floor(xy);

    return fract(dot(xy, float2(0.5, xy.y * 0.75)));
}

public float bayer4x4(float2 xy) {
    return fma(bayer2x2(xy * 0.5), 0.25, bayer2x2(xy));
}

public float ssao(float3 fragPos, float3 normalView, float radius, float2 pixelCoord) {
    float3 normal = normalize(normalView);
    // float3x3 tbn = constructOrthonormalBasis(normal);

    float ditherValue = bayer4x4(pixelCoord);
    float angle = ditherValue * 2.0 * PI;
    float3 randomVec = float3(cos(angle), sin(angle), 0.0);

    float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 tbn = float3x3(tangent, bitangent, normal);

    float occlusion = 0;

    for (int i = 0; i < SAMPLE_COUNT; i++) {
        float3 sampleOffset = mul(tbn, samples[i]);
        float3 samplePos = fragPos + sampleOffset;

        float3 offset = projectAndDivide(ap.camera.projection, samplePos);
        offset.xy = offset.xy * 0.5 + 0.5;

        float sampleDepth = ap.depth.sampleLinear(offset.xy);

        float3 sampleClip = float3(offset.xy * 2.0 - 1.0, sampleDepth);
        float3 sampleView = projectAndDivide(ap.camera.projectionInv, sampleClip);

        float3 dir = normalize(sampleView - fragPos);
        float NdotD = max(dot(normal, dir), 0.0);

        float rangeCheck = smoothstep(0.0, 1.0, radius / abs(fragPos.z - sampleView.z));

        float bias = 0.0;

        occlusion += (sampleView.z > samplePos.z + bias ? 1.0 : 0.0) * rangeCheck * NdotD;
    }

    occlusion /= float(SAMPLE_COUNT);
    float ao = 1.0 - occlusion;
    ao = pow(ao, 2.2);

	return ao;
}

//// Main
[[shader("pixel")]]
FragmentOutput ambientOcclusion(float2 pos: SV_Position) {

    FragmentOutput output;

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

        output.ssaoInput = float4(float3(ssao), 1.0);

        return output;
    }

    output.ssaoInput = float4(float3(1.0), 1.0);

    return output;
}