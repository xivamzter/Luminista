import aperture;
import helpers.util;

static const float minLogLum = -4;
static const float maxLogLum = 24;
static const float logLumRange = maxLogLum - minLogLum;
static const float timeCoeff = 0.05;

float computeEV100FromAvgLuminance(float avgLuminance) {
// We later use the middle gray at 12.7% in order to have
// a middle gray at 18% with a sqrt (2) room for specular highlights
// But here we deal with the spot meter measuring the middle gray
// which is fixed at 12.5 for matching standard camera
// constructor settings (i.e. calibration constant K = 12.5)
// Reference : http :// en. wikipedia . org / wiki / Film_speed
return log2 ( avgLuminance * 100.0f / 12.5f) ;
}

float convertEV100ToExposure(float EV100) {
// Compute the maximum luminance possible with H_sbs sensitivity
// maxLum = 78 / ( S * q ) * N^2 / t
// = 78 / ( S * q ) * 2^ EV_100
// = 78 / (100 * 0.65) * 2^ EV_100
// = 1.2 * 2^ EV
// Reference : http :// en. wikipedia . org / wiki / Film_speed
float maxLuminance = 1.2f * pow (2.0f, EV100);
return maxLuminance;
}

RWTexture2D mainTexture;
RWStructuredBuffer<uint> luminanceHistogramBuffer;
RWStructuredBuffer<float2> exposureBuffer;

groupshared uint histogramShared[256];

[shader("compute")]
[numthreads(256, 1, 1)]
void applyHistogramAverage(uint3 globalThreadId: SV_DispatchThreadID, uint localIndex: SV_GroupIndex) {

    

    // Get the count from the histogram buffer
    uint countForThisBin = luminanceHistogramBuffer[localIndex];
    histogramShared[localIndex] = countForThisBin * localIndex;

    GroupMemoryBarrierWithGroupSync();

    luminanceHistogramBuffer[localIndex] = 0;

    [unroll]
    for (uint cutoff = (256 >> 1); cutoff > 0; cutoff >>= 1) {

        if (uint(localIndex) < cutoff) {

            histogramShared[localIndex] += histogramShared[localIndex + cutoff];
        }

        GroupMemoryBarrierWithGroupSync();
    }

    if (localIndex == 0) {
        
        float numPixels = (ap.game.renderSize.x * ap.game.renderSize.y);

        float weightedLogAverage = (histogramShared[0] / max(numPixels - float(countForThisBin), 1.0)) - 1.0;

        float weightedAvgLum = exp2(((weightedLogAverage / 254.0) * logLumRange) + minLogLum);

        float lumLastFrame = mainTexture[int2(0, 0)].x;
        float adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeCoeff;

        float computeEV100 = computeEV100FromAvgLuminance(adaptedLum);
        float exposure = convertEV100ToExposure(computeEV100);

        mainTexture.Store(int2(0, 0), float4(adaptedLum, 0.0, 0.0, 0.0));

        exposureBuffer[0] = float2(adaptedLum, exposure);
    }
}