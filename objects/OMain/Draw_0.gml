new BBMOD_Matrix()
	.Scale(1000, 1000, 1000)
	.Translate(x, y, z)
	.ApplyWorld();
modSky.render([matSky]);

new BBMOD_Matrix().Scale(0.1, 0.1, 0.1).ApplyWorld();
modSponza.render();

new BBMOD_Matrix().ApplyWorld();

draw_clear(c_black);
camera.apply();
renderer.render();
