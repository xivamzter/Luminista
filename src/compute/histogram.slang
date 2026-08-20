import aperture;
import helpers.util;

RWTexture2D mainTexture;
RWStructuredBuffer<uint> luminanceHistogramBuffer;

groupshared uint histogramShared[256];

static const float EPSILON = 0.005;
static const float3 RGB_TO_LUM = float3(0.2125, 0.7154, 0.0721);

static const float minLogLum = -4;
static const float2 u_params = float2(minLogLum, 1.0 / 28.0);

// For a given color and luminance range, return the histogram bin index
uint colorToBin(float3 hdrColor, float minLogLum, float inverseLogLumRange) {

    // Convert our RGB value to Luminance
    float lum = dot(hdrColor, RGB_TO_LUM);

    // Avoid taking the log of zero
    if (lum < EPSILON) {

    return 0;
    }

    // Calculate the log_2 luminance and express it as a value in [0.0, 1.0]
    // where 0.0 represents the minimum luminance, and 1.0 represents the max.
    float logLum = clamp((log2(lum) - minLogLum) * inverseLogLumRange, 0.0, 1.0);

    // Map [0, 1] to [1, 255]. The zeroth bin is handled by the epsilon check above.
    return uint(logLum * 254.0 + 1.0);
}

[shader("compute")]
[numthreads(16, 16, 1)]
void applyHistogram(uint3 globalThreadId: SV_DispatchThreadID, uint groupIndex: SV_GroupIndex) {

    histogramShared[groupIndex] = 0;

    GroupMemoryBarrierWithGroupSync();

    if (all(globalThreadId.xy < ap.game.renderSize)) {

        float4 hdrColor = mainTexture[int2(globalThreadId.xy)];
        hdrColor.rgb = decodeColorRgbm16F(hdrColor);
        uint binIndex = colorToBin(hdrColor.rgb, u_params.x, u_params.y);

        InterlockedAdd(histogramShared[binIndex], 1);
    }

    GroupMemoryBarrierWithGroupSync();

    InterlockedAdd(luminanceHistogramBuffer[groupIndex], histogramShared[groupIndex]);
}