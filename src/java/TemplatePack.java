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
        var normalTexture = pipeline.texture2D("normalTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var lightmapTexture = pipeline.texture2D("lightmapTexture", TextureFormat.RGBA8_SNORM).renderSize().create();

        Buffer luminanceHistogramBuffer = pipeline.buffer("luminanceHistogramBuffer", Integer.BYTES * 256);
        Buffer exposureBuffer = pipeline.buffer("exposureBuffer", Integer.BYTES * 256);

        // if (pipeline.getSettings().getBoolValue("shadows"))
        pipeline.object(ProgramUsage.SHADOW, "object/shadow", "ShadowShader");
        pipeline.object(ProgramUsage.SKYBOX, "object/skybox", "BasicShader");
        pipeline.object(ProgramUsage.BASIC, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", normalTexture).writes("lightMap", lightmapTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);
        pipeline.object(ProgramUsage.TRANSLUCENT, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", normalTexture).writes("lightMap", lightmapTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);

        pipeline.stage(ProgramStage.PRE_RENDER).clearTo(new Vector4f(0.0f),mainTexture);

        pipeline.stage(ProgramStage.POST_RENDER).composite("sky", "post/sky", "applySky").writes("color", mainTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("lighting", "post/lighting", "applyLighting").writes("color", mainTexture).exportInt("CASCADE_COUNT", CASCADE_COUNT);
        pipeline.stage(ProgramStage.POST_RENDER).compute("histogram", "compute/histogram", "applyHistogram").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
        pipeline.stage(ProgramStage.POST_RENDER).compute("histogramAverage", "compute/histogramAverage", "applyHistogramAverage").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
        pipeline.stage(ProgramStage.POST_RENDER).compute("exposure", "compute/exposureBlend", "applyExposure").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
    }

    @Override
    public void configureRenderer(RendererConfig rendererConfig) {
        rendererConfig.setSunPathRotation(23.47f);
        rendererConfig.setShadowCascades(CASCADE_COUNT);
        rendererConfig.setShadowDistance(160.0f);
        rendererConfig.setShadowResolution(2048);
    }

}
