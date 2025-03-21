/// @module Core

/// @var {Struct.BBMOD_BaseCamera} The last used camera. Can be `undefined`.
/// @private
global.__bbmodCameraCurrent = undefined;

/// @var {Struct.BBMOD_Vec3}
/// @private
global.__bbmodCameraPosition = new BBMOD_Vec3();

/// @var {Real} Distance to the far clipping plane.
/// @private
global.__bbmodZFar = 1.0;

/// @var {Real}
/// @private
global.__bbmodCameraExposure = 1.0;

/// @var {Real}
/// @private
global.__bbmodCameraFovFlip = -1.0;

/// @var {Real}
/// @private
global.__bbmodCameraAspectFlip = -1.0;

/// @func BBMOD_BaseCamera()
///
/// @implements {BBMOD_IDestructible}
///
/// @desc A camera with support for both orthographic and perspective
/// projection.
function BBMOD_BaseCamera() constructor
{
	static __isBrowser = bbmod_is_browser();

	/// @var {camera} An underlying GameMaker camera.
	/// @readonly
	Raw = camera_create();

	/// @var {Real} The camera's exposure value. Defaults to `1`.
	Exposure = 1.0;

	/// @var {Struct.BBMOD_Vec3} The camera's position. Defaults to `(0, 0, 0)`.
	Position = new BBMOD_Vec3(0.0);

	/// @var {Struct.BBMOD_Vec3} A position where the camera is looking at.
	Target = BBMOD_VEC3_FORWARD;

	/// @var {Struct.BBMOD_Vec3} The up vector.
	Up = BBMOD_VEC3_UP;

	/// @var {Real} The camera's field of view. Defaults to `60`.
	/// @note This does not have any effect when {@link BBMOD_BaseCamera.Orthographic}
	/// is enabled.
	Fov = 60.0;

	/// @var {Real} The camera's aspect ratio. Defaults to
	/// `bbmod_window_get_width() / bbmod_window_get_height()`.
	AspectRatio = bbmod_window_get_width() / bbmod_window_get_height();

	/// @var {Real} Distance to the near clipping plane. Anything closer to the
	/// camera than this will not be visible. Defaults to `0.1`.
	/// @note This can be a negative value if {@link BBMOD_BaseCamera.Orthographic}
	/// is enabled.
	ZNear = 0.1;

	/// @var {Real} Distance to the far clipping plane. Anything farther from
	/// the camera than this will not be visible. Defaults to `32768`.
	ZFar = 32768.0;

	/// @var {Bool} Use `true` to enable orthographic projection. Defaults to
	/// `false` (perspective projection).
	Orthographic = false;

	/// @var {Real} The width of the orthographic projection. If `undefined`,
	/// then it is computed from {@link BBMOD_BaseCamera.Height} using
	/// {@link BBMOD_BaseCamera.AspectRatio}. Defaults to the window's width.
	/// @see BBMOD_BaseCamera.Orthographic
	Width = bbmod_window_get_width();

	/// @var {Real} The height of the orthographic projection. If `undefined`,
	/// then it is computed from {@link BBMOD_BaseCamera.Width} using
	/// {@link BBMOD_BaseCamera.AspectRatio}. Defaults to `undefined`.
	/// @see BBMOD_BaseCamera.Orthographic
	Height = undefined;

	/// @var {Bool} If `true` then the camera updates position and orientation
	/// of the 3D audio listener in the {@link BBMOD_BaseCamera.update_matrices}
	/// method. Defaults to `true`.
	AudioListener = true;

	/// @var {Array<Real>} The `view * projection` matrix.
	/// @note This is updated each time {@link BBMOD_BaseCamera.update_matrices}
	/// is called.
	/// @readonly
	ViewProjectionMatrix = matrix_build_identity();

	/// @var {Bool} If `true` then projection matrix is flipped vertically by
	/// `camera_set_proj_mat`.
	/// @private
	__projFlipped = false;

	/// @func __build_proj_mat()
	///
	/// @desc Builds a projection matrix based on the camera's properties.
	///
	/// @return {Array<Real>} The projection matrix.
	///
	/// @private
	static __build_proj_mat = function ()
	{
		var _proj;
		if (Orthographic)
		{
			var _width = (Width != undefined) ? Width : (Height * AspectRatio);
			var _height = (Height != undefined) ? Height : (Width / AspectRatio);
			_proj = matrix_build_projection_ortho(_width, _height * global.__bbmodCameraAspectFlip, ZNear, ZFar);
		}
		else
		{
			_proj = matrix_build_projection_perspective_fov(
				Fov * global.__bbmodCameraFovFlip, AspectRatio * global.__bbmodCameraAspectFlip, ZNear, ZFar);
		}
		return _proj;
	};

	/// @func update_matrices()
	///
	/// @desc Recomputes camera's view and projection matrices.
	///
	/// @return {Struct.BBMOD_BaseCamera} Returns `self`.
	///
	/// @note This is called automatically in the {@link BBMOD_BaseCamera.update}
	/// method, so you do not need to call this unless you modify
	/// {@link BBMOD_BaseCamera.Position} or {@link BBMOD_BaseCamera.Target}
	/// after the `update` method.
	///
	/// @example
	/// ```gml
	/// /// @desc Step event
	/// camera.set_mouselook(true);
	/// camera.update(delta_time);
	/// if (camera.Position.Z < 0.0)
	/// {
	///     camera.Position.Z = 0.0;
	/// }
	/// camera.update_matrices();
	/// ```
	static update_matrices = function ()
	{
		gml_pragma("forceinline");

		var _view = matrix_build_lookat(
			Position.X, Position.Y, Position.Z,
			Target.X, Target.Y, Target.Z,
			Up.X, Up.Y, Up.Z);
		camera_set_view_mat(Raw, _view);

		var _proj = __build_proj_mat();
		camera_set_proj_mat(Raw, _proj);
		var _projRaw = camera_get_proj_mat(Raw);
		__projFlipped = (_projRaw[5] == -_proj[5]);

		// Note: Using _view and _proj mat straight away leads into a weird result...
		ViewProjectionMatrix = matrix_multiply(
			get_view_mat(),
			get_proj_mat());

		if (AudioListener)
		{
			audio_listener_position(Position.X, Position.Y, Position.Z);
			audio_listener_orientation(
				Target.X, Target.Y, Target.Z,
				Up.X, Up.Y, Up.Z);
		}

		return self;
	}

	/// @func update(_deltaTime)
	///
	/// @desc Updates camera's matrices.
	///
	/// @param {Real} _deltaTime How much time has passed since the last frame
	/// (in microseconds).
	///
	/// @return {Struct.BBMOD_BaseCamera} Returns `self`.
	static update = function (_deltaTime)
	{
		update_matrices();
		return self;
	};

	/// @func get_view_mat()
	///
	/// @desc Retrieves camera's view matrix.
	///
	/// @return {Array<Real>} The view matrix.
	static get_view_mat = function ()
	{
		gml_pragma("forceinline");

		if (__isBrowser)
		{
			// This returns a struct in HTML5 for some reason...
			return camera_get_view_mat(Raw);
		}

		var _view = matrix_get(matrix_view);
		var _proj = matrix_get(matrix_projection);
		camera_apply(Raw);
		var _retval = matrix_get(matrix_view);
		matrix_set(matrix_view, _view);
		matrix_set(matrix_projection, _proj);
		return _retval;
	};

	/// @func get_proj_mat()
	///
	/// @desc Retrieves camera's projection matrix.
	///
	/// @return {Array<Real>} The projection matrix.
	static get_proj_mat = function ()
	{
		gml_pragma("forceinline");

		if (__isBrowser)
		{
			// This returns a struct in HTML5 for some reason...
			return camera_get_proj_mat(Raw);
		}

		var _view = matrix_get(matrix_view);
		var _proj = matrix_get(matrix_projection);
		camera_apply(Raw);
		var _retval = matrix_get(matrix_projection);
		matrix_set(matrix_view, _view);
		matrix_set(matrix_projection, _proj);
		return _retval;
	};

	/// @func get_right()
	///
	/// @desc Retrieves a vector pointing right relative to the camera's
	/// direction.
	///
	/// @return {Struct.BBMOD_Vec3} The right vector.
	static get_right = function ()
	{
		gml_pragma("forceinline");
		var _view = get_view_mat();
		return new BBMOD_Vec3(
			_view[0],
			_view[4],
			_view[8]
		);
	};

	/// @func get_up()
	///
	/// @desc Retrieves a vector pointing up relative to the camera's
	/// direction.
	///
	/// @return {Struct.BBMOD_Vec3} The up vector.
	static get_up = function ()
	{
		gml_pragma("forceinline");
		var _view = get_view_mat();
		return new BBMOD_Vec3(
			_view[1],
			_view[5],
			_view[9]
		);
	};

	/// @func get_forward()
	///
	/// @desc Retrieves a vector pointing forward in the camera's direction.
	///
	/// @return {Struct.BBMOD_Vec3} The forward vector.
	static get_forward = function ()
	{
		gml_pragma("forceinline");
		var _view = get_view_mat();
		return new BBMOD_Vec3(
			_view[2],
			_view[6],
			_view[10]
		);
	};

	/// @func world_to_screen(_vector[, _screenWidth[, _screenHeight]])
	///
	/// @desc Computes screen-space position from a vector in world-space.
	///
	/// @param {Struct.BBMOD_Vec3, Struct.BBMOD_Vec4} _vector The vector in
	/// world-space.
	/// @param {Real} [_screenWidth] The width of the screen. If `undefined`, it
	/// is retrieved using {@link bbmod_window_get_width}.
	/// @param {Real} [_screenHeight] The height of the screen. If `undefined`,
	/// it is retrieved using {@link bbmod_window_get_height}.
	///
	/// @return {Struct.BBMOD_Vec4} The screen-space position or `undefined` if
	/// the point is outside of the screen.
	///
	/// @note This requires {@link BBMOD_BaseCamera.ViewProjectionMatrix}, so you
	/// should use this *after* {@link BBMOD_BaseCamera.update_matrices} (or
	/// {@link BBMOD_BaseCamera.update}) is called!
	static world_to_screen = function (_vector, _screenWidth = undefined, _screenHeight = undefined)
	{
		gml_pragma("forceinline");
		_screenWidth ??= bbmod_window_get_width();
		_screenHeight ??= bbmod_window_get_height();
		var _screenPos = new BBMOD_Vec4(_vector.X, _vector.Y, _vector.Z, _vector[$ "W"] ?? 1.0)
			.Transform(ViewProjectionMatrix);
		if (_screenPos.Z < 0.0)
		{
			return undefined;
		}
		_screenPos.X /= _screenPos.W;
		_screenPos.Y /= _screenPos.W;
		_screenPos.X = ((_screenPos.X * 0.5) + 0.5) * _screenWidth;
		_screenPos.Y = ((_screenPos.Y * 0.5) + 0.5) * _screenHeight;
		if (__projFlipped)
		{
			_screenPos.Y = _screenHeight - _screenPos.Y;
		}
		return _screenPos;
	};

	/// @func screen_point_to_vec3(_vector[, _renderer])
	///
	/// @desc Unprojects a position on the screen into a direction in world-space.
	///
	/// @param {Struct.BBMOD_Vector2} _vector The position on the screen.
	/// @param {Struct.BBMOD_Renderer} [_renderer] A renderer or `undefined`.
	///
	/// @return {Struct.BBMOD_Vec3} The world-space direction.
	static screen_point_to_vec3 = function (_vector, _renderer = undefined)
	{
		var _forward = get_forward();
		var _up = get_up();
		var _right = get_right();
		var _tFov = dtan(Fov * 0.5);
		_up = _up.Scale(_tFov);
		_right = _right.Scale(_tFov * AspectRatio);
		var _screenWidth = _renderer ? _renderer.get_width() : bbmod_window_get_width();
		var _screenHeight = _renderer ? _renderer.get_height() : bbmod_window_get_height();
		var _screenX = _vector.X - (_renderer ? _renderer.X : 0);
		var _screenY = _vector.Y - (_renderer ? _renderer.Y : 0);
		var _scaleUp = (_screenY / _screenHeight) * 2.0 - 1.0;
		if (__projFlipped)
		{
			_scaleUp = -_scaleUp;
		}
		var _ray = _forward.Add(_up.Scale(_scaleUp).Add(
			_right.Scale((_screenX / _screenWidth) * 2.0 - 1.0)));
		return _ray;
	};

	/// @func apply()
	///
	/// @desc Applies the camera.
	///
	/// @return {Struct.BBMOD_BaseCamera} Returns `self`.
	///
	/// @example
	/// Following code renders a model from the camera's view.
	/// ```gml
	/// camera.apply();
	/// model.submit();
	/// bbmod_material_reset();
	/// ```
	///
	/// @note This also overrides the camera position and exposure passed to
	/// shaders using {@link bbmod_camera_set_position} and
	/// {@link bbmod_camera_set_exposure} respectively!
	static apply = function ()
	{
		gml_pragma("forceinline");
		global.__bbmodCameraCurrent = self;
		camera_apply(Raw);
		bbmod_camera_set_position(Position.Clone());
		bbmod_camera_set_zfar(ZFar);
		bbmod_camera_set_exposure(Exposure);
		return self;
	};

	static destroy = function ()
	{
		camera_destroy(Raw);
		if (global.__bbmodCameraCurrent == self)
		{
			global.__bbmodCameraCurrent = undefined;
		}
		return undefined;
	};
}

/// @func bbmod_camera_get_position()
///
/// @desc Retrieves the position of the camera that is passed to shaders.
///
/// @return {Struct.BBMOD_Vec3} The camera position.
///
/// @see bbmod_camera_set_position
function bbmod_camera_get_position()
{
	gml_pragma("forceinline");
	return global.__bbmodCameraPosition;
}

/// @func bbmod_camera_set_position(_position)
///
/// @desc Defines position of the camera passed to shaders.
///
/// @param {Struct.BBMOD_Vec3} _position The new camera position.
///
/// @see bbmod_camera_get_position
function bbmod_camera_set_position(_position)
{
	gml_pragma("forceinline");
	global.__bbmodCameraPosition = _position;
}

/// @func bbmod_camera_get_zfar()
///
/// @desc Retrieves distance to the far clipping plane passed to shaders.
///
/// @return {Real} The distance to the far clipping plane.
///
/// @see bbmod_camera_set_zfar
function bbmod_camera_get_zfar()
{
	gml_pragma("forceinline");
	return global.__bbmodZFar;
}

/// @func bbmod_camera_set_zfar(_value)
///
/// @desc Defines distance to the far clipping plane passed to shaders.
///
/// @param {Real} _value The new distance to the far clipping plane.
///
/// @see bbmod_camera_get_zfar
function bbmod_camera_set_zfar(_value)
{
	gml_pragma("forceinline");
	global.__bbmodZFar = _value;
}

/// @func bbmod_camera_get_exposure()
///
/// @desc Retrieves camera exposure value passed to shaders.
///
/// @return {Real} The camera exposure value.
///
/// @see bbmod_camera_set_exposure
function bbmod_camera_get_exposure()
{
	gml_pragma("forceinline");
	return global.__bbmodCameraExposure;
}

/// @func bbmod_camera_set_exposure(_exposure)
///
/// @desc Defines camera exposure value passed to shaders.
///
/// @param {Real} _exposure The new camera exposure value.
///
/// @see bbmod_camera_get_exposure
function bbmod_camera_set_exposure(_exposure)
{
	gml_pragma("forceinline");
	global.__bbmodCameraExposure = _exposure;
}

/// @func bbmod_camera_get_fov_flip()
///
/// @desc Returns whether {@link BBMOD_BaseCamera} uses a flipped field of view.
///
/// @return {Bool} Returns `true` (default) if flipped field of view is used.
///
/// @see bbmod_camera_set_fov_flip
function bbmod_camera_get_fov_flip()
{
	gml_pragma("forceinline");
	return (global.__bbmodCameraFovFlip == -1.0);
}

/// @func bbmod_camera_set_fov_flip(_flip)
///
/// @desc Changes whether {@link BBMOD_BaseCamera} should use a flipped field of
/// view.
///
/// @param {Bool} _flip Use `true` (default) to enable flipped field of view.
///
/// @see bbmod_camera_get_fov_flip
function bbmod_camera_set_fov_flip(_flip)
{
	gml_pragma("forceinline");
	global.__bbmodCameraFovFlip = _flip ? -1.0 : 1.0;
}

/// @func bbmod_camera_get_aspect_flip()
///
/// @desc Returns whether {@link BBMOD_BaseCamera} uses a flipped aspect ratio.
///
/// @return {Bool} Returns `true` (default) if flipped aspect ratio is used.
///
/// @see bbmod_camera_set_aspect_flip
function bbmod_camera_get_aspect_flip()
{
	gml_pragma("forceinline");
	return (global.__bbmodCameraAspectFlip == -1.0);
}

/// @func bbmod_camera_set_aspect_flip(_flip)
///
/// @desc Changes whether {@link BBMOD_BaseCamera} should use a flipped aspect
/// ratio.
///
/// @param {Bool} _flip Use `true` (default) to enable flipped aspect ratio.
///
/// @see bbmod_camera_get_aspect_flip
function bbmod_camera_set_aspect_flip(_flip)
{
	gml_pragma("forceinline");
	global.__bbmodCameraAspectFlip = _flip ? -1.0 : 1.0;
}
