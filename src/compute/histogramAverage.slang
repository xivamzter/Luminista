import aperture;
import helpers.util;

static const float minLogLum = -4;
static const float maxLogLum = 24;
static const float logLumRange = maxLogLum - minLogLum;
static const float timeCoeff = 0.05;

RWTexture2D mainTexture;
RWStructuredBuffer<uint> luminanceHistogramBuffer;
RWStructuredBuffer<float2> exposureBuffer;

groupshared uint histogramShared[256];

[shader("compute")]
[numthreads(256, 1, 1)]
void applyHistogramAverage(uint3 globalThreadId: SV_DispatchThreadID, uint groupIndex: SV_GroupIndex) {

    float numPixels = (ap.game.renderSize.x * ap.game.renderSize.y);

    // Get the count from the histogram buffer
    uint countForThisBin = luminanceHistogramBuffer[groupIndex];
    histogramShared[groupIndex] = countForThisBin * groupIndex;

    GroupMemoryBarrierWithGroupSync();

    luminanceHistogramBuffer[groupIndex] = 0;

    for (uint cutoff = (256 >> 1); cutoff > 0; cutoff >>= 1) {

        if (uint(groupIndex) < cutoff) {

            histogramShared[groupIndex] += histogramShared[groupIndex + cutoff];
        }

        GroupMemoryBarrierWithGroupSync();
    }

    if (groupIndex == 0) {

        float weightedLogAverage = (histogramShared[0] / max(numPixels - float(countForThisBin), 1.0)) - 1.0;
        float weightedAvgLum = exp2(((weightedLogAverage / 254.0) * logLumRange) + minLogLum);
        // float lumLastFrame = exposureBuffer[0];
        // float adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeCoeff;

        // exposureBuffer[0] = float2(adaptedLum, exposure);

    }
}