if (mouse_check_button_pressed(mb_any))
{
	camera.set_mouselook(true);
	window_set_cursor(cr_none);
}
else if (keyboard_check_pressed(vk_escape))
{
	camera.set_mouselook(false);
	window_set_cursor(cr_default);
}

var _speed = keyboard_check(vk_shift) ? 2 : 0.5;
var _forward = (keyboard_check(ord("W")) - keyboard_check(ord("S"))) * _speed;
var _right = (keyboard_check(ord("D")) - keyboard_check(ord("A"))) * _speed;
var _up = (keyboard_check(ord("E")) - keyboard_check(ord("Q"))) * _speed;

x += lengthdir_x(_forward, camera.Direction) + lengthdir_x(_right, camera.Direction - 90);
y += lengthdir_y(_forward, camera.Direction) + lengthdir_y(_right, camera.Direction - 90);
z += _up;

camera.AspectRatio = window_get_width() / window_get_height();
camera.Exposure += (mouse_wheel_up() - mouse_wheel_down()) * 0.1;
camera.update(delta_time);

if (keyboard_check(ord("F")))
{
	sun.Direction = camera.get_forward();
}

renderer.update(delta_time);

if (keyboard_check_pressed(vk_space))
{
	reflectionProbe.set_position(new BBMOD_Vec3(x, y, z));
	reflectionProbe.NeedsUpdate = true;
}
