import aperture;
import helpers.util;

// Imports `helpers/shadows.slang`, since it is declared with `public module shadows`. See the Slang user guide for more info if confused.
import lib.shadows;
import lib.ambientocclusion;

Texture2D mainTexture;
Texture2D flatNormal;
Texture2D tangentTexture;
Texture2D skyScatteringTexture;
Texture2D skyTransmittanceTexture;
Texture2D ambientScatteringTexture;
Texture2D normalTexture;
Texture2D specularTexture;
Texture2D ssaoInput;

static const float PI = 3.14159265359;

static const float MOON_ILLUMINANCE = 0.25;
static const float SUN_ILLUMINANCE = 128000;
static const float3 blocklightColor = float3(1.0, 0.5, 0.08);

float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}

struct FragmentOutput {
    float4 color;
}

//// Main
[[shader("pixel")]]
FragmentOutput applyLighting(float2 pos: SV_Position) {

    FragmentOutput output;

    float2 texcoord = pos / ap.game.screenSize;
    float depth = ap.depth.sampleLinear(texcoord);

    float4 color = mainTexture[pos];

    uint2 texDim;
    ssaoInput.GetDimensions(texDim.x, texDim.y);

    float2 texelSize = 1.0 / float2(texDim);

    float result = 0.0;

    for (int x = -2; x < 2; ++x) {
        for (int y = -2; y < 2; ++y) {
            float2 offset = float2(float(x), float(y)) * texelSize;
            result += ssaoInput.sampleLinear(texcoord + offset).r;
        }
    }

    float ssao = result /= 16.0;

    color.rgb = decodeColorRgbm16F(color.rgba);

    float4 normal = flatNormal[pos];
    float4 tangent = tangentTexture[pos];

    float vanillaAO = normal.a;

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = playerSpacePos + float3(0.0, ap.camera.position.y, 0.0);
    float3 playerSpaceRayDirection = float3(0.0, 1.0, 0.0);

    float3 skyScattering = skyScatteringTexture.sampleLinear(texcoord).rgb;
    float3 skyLighting = ambientScatteringTexture.sampleLinear(texcoord).rgb;
    
    if (depth == 0.0) {

    float3 skyTransmittance = skyTransmittanceTexture.sampleLinear(texcoord).rgb;

    color.rgb = color.rgb * skyTransmittance + skyScattering;

    } else {

    // float3 blockLighting = (pow(lightMap.r, 2.2) * 10000) * blocklightColor;

    float4 texNormal = normalTexture[pos];
    float4 texSpecular = specularTexture[pos];

    float3 shadow = lerp(0.3, 1.0, getShadow(playerSpacePos, normal.rgb));

    // float3 sunLighting = shadow * SUN_ILLUMINANCE * max(0.0, dot(normalize(normal.rgb), normalize(ap.celestial.sunPosition))) / PI;
    // float3 moonLighting = shadow * MOON_ILLUMINANCE * max(0.0, dot(normalize(normal.rgb), normalize(ap.celestial.moonPosition))) / PI;

    // float3 dirLight = sunLighting + moonLighting;
    float3 indirectLight = skyLighting * (ssao * vanillaAO);

    color.rgb *= indirectLight;

    output.color = color;
    // output.color = float4(float3(vanillaAO * ssao), 1.0);

    return output;

    }

    color = encodeColorRgbm16F(color.rgb);

    output.color = color;

    return output;
}