import aperture;
import helpers.util;

Texture2D mainTexture;

struct FragmentOutput {
    float4 color;
}

static const float3 ATMOSPHERE_RAYLEIGH_SCATTERING_COEFFICIENT = float3(0.005802, 0.013558, 0.033100);
static const float3 ATMOSPHERE_RAYLEIGH_ABSORPTION_COEFFICIENT = float3(0.0);
static const float3 ATMOSPHERE_RAYLEIGH_EXTINCTION_COEFFICIENT = ATMOSPHERE_RAYLEIGH_SCATTERING_COEFFICIENT + ATMOSPHERE_RAYLEIGH_ABSORPTION_COEFFICIENT;
static const float ATMOSPHERE_RAYLEIGH_SCALE_HEIGHT = 8.0;
static const float ATMOSPHERE_RAYLEIGH_DENSITY_EXP_SCALE = -1.0 / ATMOSPHERE_RAYLEIGH_SCALE_HEIGHT;

static const float3 ATMOSPHERE_MIE_SCATTERING_COEFFICIENT = float3(0.003996);
static const float3 ATMOSPHERE_MIE_EXTINCTION_COEFFICIENT = float3(0.004440);
static const float ATMOSPHERE_MIE_SCALE_HEIGHT = 1.2;
static const float ATMOSPHERE_MIE_DENSITY_EXP_SCALE = -1.0 / ATMOSPHERE_MIE_SCALE_HEIGHT;

static const float3 ATMOSPHERE_OZONE_SCATTERING_COEFFICIENT = float3(0.0);
static const float3 ATMOSPHERE_OZONE_EXTINCTION_COEFFICIENT = float3(0.000650, 0.001881, 0.000085);
static const float ATMOSPHERE_OZONE_SCALE_HEIGHT = 15.0;
static const float ATMOSPHERE_OZONE_LAYER0_WIDTH = 25.0;
static const float ATMOSPHERE_OZONE_LAYER0_CONSTANT_TERM = -2.0 / 3.0;
static const float ATMOSPHERE_OZONE_LAYER0_LINEAR_TERM = 1.0 / ATMOSPHERE_OZONE_SCALE_HEIGHT;
static const float ATMOSPHERE_OZONE_LAYER1_CONSTANT_TERM =  8.0 / 3.0;
static const float ATMOSPHERE_OZONE_LAYER1_LINEAR_TERM = -1.0 / ATMOSPHERE_OZONE_SCALE_HEIGHT;

public static const float EARTH_RADIUS_KM = 6400.0;
public static const float CAMERA_ALTITUDE_KM = -100.0 / 1000.0;
public static const float3 CAMERA_OFFSET_KM = float3(0.0, EARTH_RADIUS_KM + CAMERA_ALTITUDE_KM, 0.0);

static const float PI = 3.14159265359;
static const int NUM_STEPS = 32;

static const float3 CENTER_OF_EARTH = float3(0.0, 0.0, 0.0);
static const float ATMOSPHERE_THICKNESS_KM = 100.0;
static const float ATMOSHPHERE_BOTTOM_SPHERE_RADIUS_KM = EARTH_RADIUS_KM;
static const float ATMOSPHERE_TOP_SPHERE_RADIUS_KM = ATMOSHPHERE_BOTTOM_SPHERE_RADIUS_KM + ATMOSPHERE_THICKNESS_KM;

static const float LIGHT_ILLUMINANCE = 128000;
static const float MOON_ILLUMINANCE = 0.25;
static const float SUN_ILLUMINANCE = 128000;

public float3 playerToAtmosphere(float3 playerPos) {
    return fma(playerPos, rcp(1000.0), CAMERA_OFFSET_KM);
}

// public float3 atmoshphereToPlayer(float3 atmoshpherePos) {
//     return fma(atmoshpherePos, 1000.0, -CAMERA_OFFSET_KM);
// }

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

public struct MediumSample {
    float3 rayleighScattering;
    float3 rayleighExtinction;

    float3 mieScattering;
    float3 mieExtinction;

    float3 ozoneExtinction;

    float3 totalScattering;
    float3 totalExtinction;
}

public MediumSample sampleMedium(float sampleAltitude) {
    sampleAltitude = max(sampleAltitude - ATMOSHPHERE_BOTTOM_SPHERE_RADIUS_KM, 0.0);

    float rayleighDensity = exp(ATMOSPHERE_RAYLEIGH_DENSITY_EXP_SCALE * sampleAltitude);
    float mieDensity = exp(ATMOSPHERE_MIE_DENSITY_EXP_SCALE * sampleAltitude);
    float ozoneDensity = saturate(select(
        sampleAltitude < ATMOSPHERE_OZONE_LAYER0_WIDTH,
        fma(ATMOSPHERE_OZONE_LAYER0_LINEAR_TERM, sampleAltitude, ATMOSPHERE_OZONE_LAYER0_CONSTANT_TERM),
        fma(ATMOSPHERE_OZONE_LAYER1_LINEAR_TERM, sampleAltitude, ATMOSPHERE_OZONE_LAYER1_CONSTANT_TERM)
    ));

    MediumSample sample;

    sample.rayleighScattering = ATMOSPHERE_RAYLEIGH_SCATTERING_COEFFICIENT * rayleighDensity;
    sample.rayleighExtinction = ATMOSPHERE_RAYLEIGH_EXTINCTION_COEFFICIENT * rayleighDensity;

    sample.mieScattering = ATMOSPHERE_MIE_SCATTERING_COEFFICIENT * mieDensity;
    sample.mieExtinction = ATMOSPHERE_MIE_EXTINCTION_COEFFICIENT * mieDensity;

    sample.ozoneExtinction = ATMOSPHERE_OZONE_EXTINCTION_COEFFICIENT * ozoneDensity;

    sample.totalScattering = sample.rayleighScattering + sample.mieScattering;
    sample.totalExtinction = sample.rayleighExtinction + sample.mieExtinction + sample.ozoneExtinction;

    return sample;
}

public float miePhaseCornetteShanks(float cosTheta, float g) {
    float gSqr = g * g;
    float k = 3.0 / (8.0 * PI) * (1.0 - gSqr) / (2.0 + gSqr);
    return k * (1.0 + cosTheta * cosTheta) / pow(1.0 + gSqr - 2.0 * g * -cosTheta, 1.5);
}

public float rayleighPhase(float cosTheta) {
    const static float factor = 3.0 / (16.0 * PI);

    return factor * (1.0 + cosTheta * cosTheta);
}

float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}


//// Second raymarch for sky
bool getDistancesForSecondRay(in float2 atmosLayerTop, in float2 atmosLayerBottom, out float furthestDistance) {

    // ray existed the top sphere but didn't enter, its origin is inside of the atmosphere
    if (atmosLayerTop.x < 0.0) {

    furthestDistance = atmosLayerBottom.x >= 0.0 ? min(atmosLayerTop.y, atmosLayerBottom.x) : atmosLayerTop.y;

    return true;
    }

    return false;
}


public float3 rayMarchSecondary(in float3 playerSpaceRayOrigin) {
    
    float3 transmittance = float3(1.0);

    float3 rayOrigin = playerSpaceRayOrigin;
    
    float3 lightPos = mul(float3x3(ap.camera.viewInv), ap.celestial.sunPosition);
    float3 lightDir = normalize(lightPos);

    float2 atmosLayerBottom = sphIntersect(rayOrigin, lightDir, CENTER_OF_EARTH, ATMOSHPHERE_BOTTOM_SPHERE_RADIUS_KM);
    float2 atmosLayerTop = sphIntersect(rayOrigin, lightDir, CENTER_OF_EARTH, ATMOSPHERE_TOP_SPHERE_RADIUS_KM);

    ////
    float closestDistance = 0.0;
    float furthestDistance;

    // Check if need to raymarch
    bool needToRayMarch = getDistancesForSecondRay(atmosLayerTop, atmosLayerBottom, furthestDistance);

    if (!needToRayMarch) {
        return transmittance;
    }

    float3 entryPointPosition = playerSpaceRayOrigin + lightDir * closestDistance;
    float3 exitPointPosition = playerSpaceRayOrigin + lightDir * furthestDistance;

    // from entry to exit point in defined number of steps
    float3 rayStep = (exitPointPosition - entryPointPosition) / float(NUM_STEPS);

    // Distance between each step;
    float rayStepLength = length(rayStep);

    for (int i = 0; i < NUM_STEPS; i++) {
        float3 rayPos = lerp(entryPointPosition, exitPointPosition, (float(i) + 0.5) / float(NUM_STEPS));

        float sampleAltitude = length(rayPos);

        MediumSample mediumSample = sampleMedium(sampleAltitude);
        float3 sampleTransmittance = exp(-mediumSample.totalExtinction * rayStepLength);

        transmittance *= sampleTransmittance;
    }

    return transmittance;
}

//// First raymarch for sky
bool getDistances(in float2 atmosLayerTop, in float2 atmosLayerBottom, out float closestDistance, out float furthestDistance) {

    // ray didn't exist the top sphere, it missed the atmosphere entirely
    if (atmosLayerTop.y < 0.0) {
        return false;
    } 

    // ray existed the top sphere but didn't enter, its origin is inside of the atmosphere
    else if (atmosLayerTop.x < 0.0) {

    closestDistance = 0.0;
    furthestDistance = atmosLayerBottom.x >= 0.0 ? min(atmosLayerTop.y, atmosLayerBottom.x) : atmosLayerTop.y;

    return true;
    }

    // ray entered and existed the top, it's origin is outside of the atmosphere
    else {

    closestDistance = atmosLayerTop.x;
    furthestDistance = atmosLayerBottom.x >= 0.0 ? min(atmosLayerTop.y, atmosLayerBottom.x) : atmosLayerTop.y;
    
    return false;
    }

    return true;
}

public struct marchPrimaryRay {
    float3 scattering;
    float3 transmittance;
}

public marchPrimaryRay rayMarch(in float3 playerSpaceRayOrigin, in float3 playerSpaceRayDirection) {

    marchPrimaryRay ray;

    float3 rayOrigin = playerToAtmosphere(playerSpaceRayOrigin);

    float2 atmosLayerBottom = sphIntersect(rayOrigin, playerSpaceRayDirection, CENTER_OF_EARTH, ATMOSHPHERE_BOTTOM_SPHERE_RADIUS_KM);
    float2 atmosLayerTop = sphIntersect(rayOrigin, playerSpaceRayDirection, CENTER_OF_EARTH, ATMOSPHERE_TOP_SPHERE_RADIUS_KM);

    float3 lightPos = mul(float3x3(ap.camera.viewInv), ap.celestial.sunPosition);
    float3 lightDir = normalize(lightPos);

    float cosTheta = clamp(dot(-playerSpaceRayDirection, normalize(lightDir)), 0.0, 1.0);

    // prerequisites
    float lightRayleighPhase = rayleighPhase(cosTheta);
    float lightMiePhase = miePhaseCornetteShanks(cosTheta, 0.8);

    ////
    float closestDistance;
    float furthestDistance;

    // Check if need to raymarch
    bool needToRayMarch = getDistances(atmosLayerTop, atmosLayerBottom, closestDistance, furthestDistance);

    if (!needToRayMarch) {
        return ray;
    }

    // main function
    ray.scattering = float3(0.0);
    ray.transmittance = float3(1.0);

    float3 entryPointPosition = playerToAtmosphere(playerSpaceRayOrigin) + playerSpaceRayDirection * closestDistance;
    float3 exitPointPosition = playerToAtmosphere(playerSpaceRayOrigin) + playerSpaceRayDirection * furthestDistance;

    // from entry to exit point in defined number of steps
    float3 rayStep = (exitPointPosition - entryPointPosition) / float(NUM_STEPS);

    // Distance between each step;
    float rayStepLength = length(rayStep);

    for (int i = 0; i < NUM_STEPS; i++) {
        float3 rayPos = lerp(entryPointPosition, exitPointPosition, (float(i) + 0.5) / float(NUM_STEPS));

        float sampleAltitude = length(rayPos);

        MediumSample mediumSample = sampleMedium(sampleAltitude);
        float3 sampleTransmittance = exp(-mediumSample.totalExtinction * rayStepLength);

        float3 phaseTimesMediumScattering = mediumSample.rayleighScattering * lightRayleighPhase + mediumSample.mieScattering * lightMiePhase;

        float3 localUpVec = normalize(rayPos) * 0.01;
        float2 earthShadowIntersection = sphIntersect(rayPos + localUpVec, lightDir, CENTER_OF_EARTH, EARTH_RADIUS_KM);
        float earthShadow = earthShadowIntersection.y < 0.0 ? 1.0 : 0.0;
        
        float3 sampleToLightTransmittance = rayMarchSecondary(rayPos);

        float3 singleScattering = LIGHT_ILLUMINANCE * phaseTimesMediumScattering * sampleToLightTransmittance * earthShadow;

        float3 integratedSingleScattering = (singleScattering - singleScattering * sampleTransmittance) / mediumSample.totalExtinction;

        ray.scattering += integratedSingleScattering * ray.transmittance;
        ray.transmittance *= sampleTransmittance;
    }

    return ray;
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