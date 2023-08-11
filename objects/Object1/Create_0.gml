BBMOD_SHADER_DEFAULT.add_variant(Shader1,  BBMOD_VFORMAT_DEFAULT);

z = 0;

renderer = new BBMOD_DefaultRenderer();
renderer.UseAppSurface = true;
renderer.EnableShadows = true;
renderer.EnableGBuffer = true;
renderer.EnableSSAO = true;
renderer.SSAORadius = 32.0;
renderer.SSAODepthRange = 5.0;
renderer.SSAOPower = 2.0;

postProcessor = new BBMOD_PostProcessor();
postProcessor.Vignette = 1.0;
postProcessor.ChromaticAberration = 3.0;
postProcessor.Antialiasing = BBMOD_EAntialiasing.FXAA;
renderer.PostProcessor = postProcessor;

camera = new BBMOD_Camera();
camera.FollowObject = self;
camera.MouseSensitivity = 0.5;

modSponza = BBMOD_RESOURCE_MANAGER.load("Data/Sponza/Sponza.bbmod", undefined, function (_err, _res) {
	if (_res)
	{
		_res.freeze();
	}
});

modSky = BBMOD_RESOURCE_MANAGER.load("Data/BBMOD/Models/Sphere.bbmod", undefined, function (_err, _res) {
	if (_res)
	{
		_res.freeze();
	}
});

matSky = BBMOD_MATERIAL_SKY.clone();
sprSky = sprite_add("Data/BBMOD/Skies/Sky+60.png", 1, false, true, 0, 0);
matSky.BaseOpacity = sprite_get_texture(sprSky, 0);

bbmod_light_ambient_set(BBMOD_C_BLACK);

sprIBL = sprite_add("Data/BBMOD/Skies/IBL+60.png", 1, false, true, 0, 0);
ibl = new BBMOD_ImageBasedLight(sprite_get_texture(sprIBL, 0));
bbmod_ibl_set(ibl);

sun = new BBMOD_DirectionalLight();
sun.CastShadows = true;
sun.ShadowmapResolution = 4096;
bbmod_light_directional_set(sun);

reflectionProbe = new BBMOD_ReflectionProbe(new BBMOD_Vec3(0, 0, 1));
reflectionProbe.set_size(new BBMOD_Vec3(1000));
bbmod_reflection_probe_add(reflectionProbe);
