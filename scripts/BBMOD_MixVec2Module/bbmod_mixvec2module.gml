/// @module Particles

/// @func BBMOD_MixVec2Module([_property[, _from[, _to[, _separate]]]])
///
/// @extends BBMOD_ParticleModule
///
/// @desc A universal particle module that randomly mixes initial values of
/// particles' two consecutive properties between two values when they are
/// spawned.
///
/// @param {Real} [_property] The first of the two consecutive properties. Use
/// values from {@link BBMOD_EParticle}. Defaults to `undefined`.
/// @param {Struct.BBMOD_Vec2} [_from] The value to mix from. Defaults to
/// `(0, 0)`.
/// @param {Struct.BBMOD_Vec2} [_to] The value to mix to. Defaults to `_from`.
/// @param {Bool} [_separate] If `true`, then each component is mixed independently
/// on other components, otherwise all components are mixed using the same factor.
/// Defaults to `true`.
///
/// @see BBMOD_EParticle
function BBMOD_MixVec2Module(
	_property = undefined,
	_from = new BBMOD_Vec2(),
	_to = _from.Clone(),
	_separate = true
): BBMOD_ParticleModule() constructor
{
	/// @var {Real} The first of the two consecutive properties. Use values from
	/// {@link BBMOD_EParticle}. Default value is `undefined`.
	Property = _property;

	/// @var {Struct.BBMOD_Vec2} The initial value to mix from. Default value is
	/// `(0, 0)`.
	From = _from;

	/// @var {Struct.BBMOD_Vec2} The initial value to mix to. Default value is the
	/// same as {@link BBMOD_MixVec2Module.From}.
	To = _to;

	/// @var {Bool} If `true`, then each component is mixed independently on other
	/// components. Default value is `true`.
	Separate = _separate;

	static on_particle_start = function (_emitter, _particleIndex)
	{
		if (Property != undefined)
		{
			var _separate = Separate;
			var _factor = random(1.0);
			_emitter.Particles[# Property, _particleIndex] = lerp(From.X, To.X, _factor);
			_emitter.Particles[# Property + 1, _particleIndex] = lerp(From.Y, To.Y, _separate ? random(1.0)
				: _factor);
		}
	};
}
