if (mouse_check_button_pressed(mb_left))
{
	camera.set_mouselook(true);
	window_set_cursor(cr_none);
}
else if (keyboard_check_pressed(vk_escape))
{
	camera.set_mouselook(false);
	window_set_cursor(cr_default);
}

if (camera.MouseLook)
{
	dof.AutoFocusPoint.Set(0.5, 0.5);
}
else if (mouse_check_button(mb_right))
{
	dof.AutoFocusPoint.Set(
		window_mouse_get_x() / window_get_width(),
		window_mouse_get_y() / window_get_height());
}

var _speed = keyboard_check(vk_shift) ? 2 : 0.5;
var _forward = (keyboard_check(ord("W")) - keyboard_check(ord("S"))) * _speed;
var _right = (keyboard_check(ord("D")) - keyboard_check(ord("A"))) * _speed;
var _up = (keyboard_check(ord("E")) - keyboard_check(ord("Q"))) * _speed;

x += lengthdir_x(_forward, camera.Direction) + lengthdir_x(_right, camera.Direction - 90);
y += lengthdir_y(_forward, camera.Direction) + lengthdir_y(_right, camera.Direction - 90);
z += _up;

camera.AspectRatio = bbmod_window_get_width() / bbmod_window_get_height();

var _directionPrev = camera.Direction;
var _directionUpPrev = camera.DirectionUp;

camera.update(delta_time);

var _scale = 5;
directionalBlur.Vector.Set(
	angle_difference(camera.Direction, _directionPrev) * _scale,
	angle_difference(camera.DirectionUp, _directionUpPrev) * _scale);
var _length = directionalBlur.Vector.Length();
_length = (_length > 0) ? _length : 1;
directionalBlur.Step = 2 / min(_length, 32);

if (keyboard_check(ord("F")))
{
	camera.get_forward().Copy(sun.Direction);
}

renderer.update(delta_time);

if (keyboard_check_pressed(vk_space))
{
	reflectionProbe.set_position(new BBMOD_Vec3(x, y, z));
	reflectionProbe.NeedsUpdate = true;
}
