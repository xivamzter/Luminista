import aperture;
import helpers.util;

// Imports `helpers/shadows.slang`, since it is declared with `public module shadows`. See the Slang user guide for more info if confused.
import lib.shadows;
import lib.atmosphere;

Texture2D mainTexture;
Texture2D normalTexture;
Texture2D lightmapTexture;

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

    color.rgb = decodeColorRgbm16F(color.rgba);

    float4 normal = normalTexture[pos];
    float vanillaAO = normal.a;

    float4 lightMap = lightmapTexture[pos];
    lightMap.rgb = decodeColorRgbm16F(lightMap.rgba);
    
    if (depth == 0.0) {
        discard;
    }

    // space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = playerSpacePos + float3(0.0, ap.camera.position.y, 0.0);
    float3 playerSpaceRayDirection = float3(0.0, 1.0, 0.0);

    marchPrimaryRay ray = rayMarch(playerSpaceRayOrigin, playerSpaceRayDirection);

    float3 blockLighting = (pow(lightMap.r, 2.2) * 10000) * blocklightColor;
    float3 skyLighting = ray.scattering;

    // float3 shadow = lerp(0.3, 1.0, shadowVisibility(playerSpacePos));
    float3 shadow = lerp(0.3, 1.0, getShadow(playerSpacePos, normal.rgb));
    // float3 shadow = getShadow(playerSpacePos, normal.rgb);

    float3 sunLighting = shadow * SUN_ILLUMINANCE * max(0.0, dot(normalize(normal.rgb), normalize(ap.celestial.sunPosition))) / PI;
    float3 moonLighting = shadow * MOON_ILLUMINANCE * max(0.0, dot(normalize(normal.rgb), normalize(ap.celestial.moonPosition))) / PI;
    
    float3 dirLight = sunLighting + moonLighting;
    float3 indirectLight = skyLighting;

    color.rgb *= dirLight + indirectLight;

    color = encodeColorRgbm16F(color.rgb);

    output.color = color;

    return output;
}