import aperture;
import helpers.util;
import settings;
import lib.shadows;
import lib.brdf;

struct FragmentOutput {
    float4 color;
}

Texture2D mainTexture;
Texture2D flatNormalTexture;
Texture2D lightmapTexture;
Texture2D labPBRNormalTexture;
Texture2D labPBRSpecularTexture;

Texture2D skyScatteringTexture;
Texture2D skyTransmittanceTexture;
Texture2D ambientScatteringTexture;

static const float MOON_ILLUMINANCE = 0.25;
static const float SUN_ILLUMINANCE = 128000;
static const float3 blocklightColor = float3(1.0, 0.5, 0.08);

public static const float EARTH_RADIUS_KM = 6400.0;
public static const float CAMERA_ALTITUDE_KM = -100.0 / 1000.0;
public static const float3 CAMERA_OFFSET_KM = float3(0.0, EARTH_RADIUS_KM + CAMERA_ALTITUDE_KM, 0.0);
static const float3 CENTER_OF_EARTH = float3(0.0, 0.0, 0.0);

public float3 playerToAtmosphere(float3 playerPos) {
    return fma(playerPos, rcp(1000.0), CAMERA_OFFSET_KM);
}

float2 sphIntersect( in float3 ro, in float3 rd, in float3 ce, float ra )
{
    float3 oc = ro - ce;
    float b = dot( oc, rd );
    float3 qc = oc - b*rd;
    float h = ra*ra - dot( qc, qc );
    if( h<0.0 ) return float2(-1.0); // no intersection
    h = sqrt( h );
    return float2( -b-h, -b+h );
}

public float earthShadow(float3 rayPos, float3 lightDir) {
    float3 localUpVec = normalize(rayPos) * 0.01;
    float2 earthShadowIntersection = sphIntersect(rayPos + localUpVec, lightDir, CENTER_OF_EARTH, EARTH_RADIUS_KM + CAMERA_ALTITUDE_KM);
    return earthShadowIntersection.y < 0.0 ? 1.0 : 0.0;
}

//// Main
[[shader("pixel")]]
FragmentOutput applyLighting(float2 pos: SV_Position) {

    FragmentOutput output;

    // Sample depth
    float2 texcoord = pos / ap.game.screenSize;
    float depth = ap.depth.sampleLinear(texcoord);

    // Sample mainScene
    float4 color = mainTexture[pos];
    color.rgb = decodeColorRgbm16F(color.rgba);

    // Space conversions
    float3 ndcPos = float3(texcoord * 2.0 - 1.0, depth);
    float3 viewPos = projectAndDivide(ap.camera.projectionInv, ndcPos);
    float3 playerSpacePos = mul(ap.camera.viewInv, float4(viewPos, 1.0)).xyz;

    float3 playerSpaceRayOrigin = float3(0.0, ap.camera.position.y, 0.0);
    float3 rayOrigin = playerToAtmosphere(playerSpacePos + playerSpaceRayOrigin);

    float3 viewDir = normalize(-playerSpacePos);

    float3 sunDir = normalize(ap.celestial.sunPosition);
    float3 moonDir = normalize(ap.celestial.moonPosition);

    float3 skyLighting = ambientScatteringTexture.sampleLinear(texcoord).rgb;

    // Sample flatNormal
    float3 normals = flatNormalTexture[pos].rgb;

    // Sample lightmap
    float4 lightmap = lightmapTexture[pos];

    float vanillaBlockLight = lightmap.r;
    float vanillaSkyLight = lightmap.g;
    float vanillaAO = lightmap.b;

    // Sample LabPBR normal map
    float4 labNormal = labPBRNormalTexture.sampleLinear(texcoord);
    float labAO = labNormal.a;

    // Sample LabPBR specular map
    float4 specularTex = labPBRSpecularTexture[pos];

    float roughness = max(specularTex.r, 0.04);
    float reflectance = specularTex.g;
    float porositySSS = specularTex.b;
    float labEmissive = specularTex.a;

    if (depth == 0.0) {
        
    float3 skyScattering = skyScatteringTexture.sampleLinear(texcoord).rgb;
    float3 skyTransmittance = skyTransmittanceTexture.sampleLinear(texcoord).rgb;

    color.rgb = color.rgb * skyTransmittance + skyScattering;
    
    } else {

    ////////// SSAO blur //////////

    uint2 texDim;
    mainTexture.GetDimensions(texDim.x, texDim.y);

    float2 texelSize = 1.0 / float2(texDim);

    float result = 0.0;

    for (int x = -2; x < 2; ++x) {
        for (int y = -2; y < 2; ++y) {
            float2 offset = float2(float(x), float(y)) * texelSize;
            result += lightmapTexture.sampleLinear(texcoord + offset).a;
        }
    }

    float ssao = result /= 16.0;

    ////////////////////

    float3 shadow = getShadow(playerSpacePos, normals);

    float earthShadowSun = earthShadow(rayOrigin, sunDir);
    float earthShadowMoon = earthShadow(rayOrigin, moonDir);

    if (userSettings.NORMAL_MAPPING) {
        normals = labNormal.rgb;
    }

    float debugBRDF = 0.0;

    float3 sunLighting = earthShadowSun * brdf(sunDir, viewDir, color.rgb, reflectance, normals, roughness, SUN_ILLUMINANCE, debugBRDF);
    float3 moonLighting = earthShadowMoon * brdf(moonDir, viewDir, color.rgb, reflectance, normals, roughness, MOON_ILLUMINANCE, debugBRDF);

    float3 directLight = shadow * (sunLighting + moonLighting);

    float3 indirectLight = (skyLighting) * (ssao * vanillaAO * labAO);

    color.rgb *= indirectLight + directLight;

    output.color = encodeColorRgbm16F(color.rgb);
    // output.color = float4(labNormal.rgb, 1.0);
    // output.color = float4(float3(ssao * vanillaAO * labAO), 1.0);
    // output.color = encodeColorRgbm16F(float3(labEmissive));
    
    return output;
    }

    output.color = encodeColorRgbm16F(color.rgb);

    return output;
}