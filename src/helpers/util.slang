public float4 encodeColorRgbm16F(float3 color) {
    float magnitude = clamp(max3(color.r, color.g, color.b), 0.0, float16_t::maxValue);

    return float4(select(magnitude > 1e-6, color / magnitude, 0.0), magnitude);
}

public float3 decodeColorRgbm16F(float4 colorAndMagnitude) {
    return colorAndMagnitude.rgb * colorAndMagnitude.a;
}