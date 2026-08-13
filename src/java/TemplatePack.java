import org.joml.Vector4f;

import dev.irisshaders.aperture.api.*;
import dev.irisshaders.aperture.api.objects.*;
import dev.irisshaders.aperture.api.pipeline.*;
import dev.irisshaders.aperture.api.renderer.*;

public class TemplatePack implements ShaderPack {
    private static final int CASCADE_COUNT = 4;

    @Override
    public void configurePipeline(Screen screen, PipelineConfig pipeline) {
        pipeline.combinationPass("post/combination");

        var mainTexture = pipeline.texture2D("mainTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var skyScatteringTexture = pipeline.texture2D("skyScatteringTexture", TextureFormat.RGBA16_SFLOAT).size(screen.renderWidth() / 2, screen.renderHeight() / 2).create();
        var skyTransmittanceTexture = pipeline.texture2D("skyTransmittanceTexture", TextureFormat.RGBA16_SFLOAT).size(screen.renderWidth() / 2, screen.renderHeight() / 2).create();
        var ambientScatteringTexture = pipeline.texture2D("ambientScatteringTexture", TextureFormat.RGBA16_SFLOAT).size(1, 1).create();
        var flatNormal = pipeline.texture2D("flatNormal", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var tangentTexture = pipeline.texture2D("tangentTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var normalTexture = pipeline.texture2D("normalTexture", TextureFormat.RGBA8_SNORM).renderSize().create();
        var specularTexture = pipeline.texture2D("specularTexture", TextureFormat.RGBA8_SNORM).renderSize().create();
        var ssaoInput = pipeline.texture2D("ssaoInput", TextureFormat.RGBA8_SNORM).renderSize().create();

        // Buffer luminanceHistogramBuffer = pipeline.buffer("luminanceHistogramBuffer", Integer.BYTES * 256);
        // Buffer exposureBuffer = pipeline.buffer("exposureBuffer", Integer.BYTES * 256);

        // if (pipeline.getSettings().getBoolValue("shadows"))
        pipeline.object(ProgramUsage.SHADOW, "object/shadow", "ShadowShader");
        pipeline.object(ProgramUsage.SKYBOX, "object/skybox", "BasicShader");
        pipeline.object(ProgramUsage.BASIC, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", flatNormal).writes("tangent", tangentTexture).writes("normalTexture", normalTexture).writes("specularTexture", specularTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);
        pipeline.object(ProgramUsage.TRANSLUCENT, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", flatNormal).writes("tangent", tangentTexture).writes("normalTexture", normalTexture).writes("specularTexture", specularTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);

        pipeline.stage(ProgramStage.PRE_RENDER).clearTo(new Vector4f(0.0f),mainTexture);

        pipeline.stage(ProgramStage.POST_RENDER).composite("sky", "post/sky", "raymarchSky").writes("scattering", skyScatteringTexture).writes("transmittance", skyTransmittanceTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("ssao", "post/ssao", "ambientOcclusion").writes("ssaoInput", ssaoInput);
        pipeline.stage(ProgramStage.POST_RENDER).composite("ambient", "post/ambient", "ambientSky").writes("ambientScattering", ambientScatteringTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("lighting", "post/lighting", "applyLighting").writes("color", mainTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);
        // pipeline.stage(ProgramStage.POST_RENDER).compute("histogram", "compute/histogram", "applyHistogram").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
        // pipeline.stage(ProgramStage.POST_RENDER).compute("histogramAverage", "compute/histogramAverage", "applyHistogramAverage").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
        // pipeline.stage(ProgramStage.POST_RENDER).compute("exposure", "compute/exposureBlend", "applyExposure").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
    }

    @Override
    public void configureRenderer(RendererConfig rendererConfig) {
        rendererConfig.setSunPathRotation(23.47f);
        rendererConfig.setShadowCascades(CASCADE_COUNT);
        rendererConfig.setShadowDistance(160.0f);
        rendererConfig.setShadowResolution(2048);
    }

}
