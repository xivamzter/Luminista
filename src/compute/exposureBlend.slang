import aperture;
import helpers.util;

RWTexture2D mainTexture;
RWStructuredBuffer<uint> luminanceHistogramBuffer;

groupshared uint histogramShared[256];

[shader("compute")]
[numthreads(16, 16, 1)]
void applyExposure(uint3 globalThreadId: SV_DispatchThreadID, uint groupIndex: SV_GroupIndex) {

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
        // float weightedAvgLum = exp2(((weightedLogAverage / 254.0) * logLumRange) + minLogLum);
        // float lumLastFrame = mainTexture[int2(0, 0)].x;
        // float adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeCoeff;

        // mainTexture.Store(int2(0, 0), float4(adaptedLum, 0.0, 0.0, 0.0));
    }
}