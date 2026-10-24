class_name KnockdownPose
extends RefCounted
## The body motion of a flying-back knockdown, shared by the player (HitStun)
## and enemies (Enemy): while airborne the body tips over backwards to
## air_pitch (enemies lean back, the player goes flat; with `spin` it keeps
## tumbling in backflips instead), it lands and settles flat on its back, lies there down_time seconds, then swings
## back up over rise_time. Visual only: update() returns the backward pitch
## (radians) for the caller to put on the model, turned about hip height and
## lowered onto the ground while down (apply()); done() once standing again.

enum Phase { FLYING, DOWN, RISING, DONE }

## Lying on the back.
const LYING := PI * 0.5
## Height (m) of the hips above the ground when lying on the back.
const LYING_HIP_HEIGHT := 0.15
## Still on the ground this long after the hit: it never left, so lie down anyway.
const TAKEOFF_GRACE := 0.12

var spin: bool = false
## Backward rotation speed while airborne (radians/s).
var flip_speed: float = deg_to_rad(540.0)
var down_time: float = 0.5
var rise_time: float = 0.3
## How far back (radians) the body tips while airborne, without spin.
var air_pitch: float = LYING

var _phase: Phase = Phase.FLYING
var _pitch: float = 0.0
## The lying angle the body settles onto once it's landed.
var _lying_pitch: float = LYING
var _timer: float = 0.0
var _air_time: float = 0.0
var _grounded_time: float = 0.0


func _init(spins: bool, flip_degrees_per_second: float, lie_time: float, get_up_time: float, air_pitch_degrees: float = 90.0) -> void:
	spin = spins
	air_pitch = deg_to_rad(air_pitch_degrees)
	flip_speed = deg_to_rad(flip_degrees_per_second)
	down_time = lie_time
	rise_time = get_up_time


## Hit again in the air: keep tumbling (a juggle) rather than starting over.
func refresh() -> void:
	if _phase != Phase.FLYING:
		_phase = Phase.FLYING
		_air_time = 0.0
		_grounded_time = 0.0


func done() -> bool:
	return _phase == Phase.DONE


## Still flying back through the air (not yet landed).
func is_flying() -> bool:
	return _phase == Phase.FLYING


## How far down onto the ground the body is (0 standing or airborne, 1 lying
## flat): full while down, easing off as it gets up.
func lying_amount() -> float:
	match _phase:
		Phase.DOWN:
			return clampf(1.0 - absf(_lying_pitch - _pitch) / LYING, 0.0, 1.0)
		Phase.RISING:
			return clampf(_pitch / LYING, 0.0, 1.0)
	return 0.0


## Advances by delta; airborne = off the ground. Returns the backward pitch.
func update(delta: float, airborne: bool) -> float:
	match _phase:
		Phase.FLYING:
			if airborne:
				_air_time += delta
				_pitch = _pitch + flip_speed * delta if spin else minf(_pitch + flip_speed * delta, air_pitch)
			else:
				_grounded_time += delta
				if _air_time > 0.0 or _grounded_time >= TAKEOFF_GRACE:
					_phase = Phase.DOWN
					_timer = down_time
					# Roll on (the way it was tumbling) onto the back.
					_lying_pitch = LYING + TAU * ceilf((_pitch - LYING) / TAU)
				else:
					_pitch = move_toward(_pitch, LYING * 0.3, flip_speed * delta)
		Phase.DOWN:
			_pitch = move_toward(_pitch, _lying_pitch, flip_speed * 1.5 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.RISING
				_timer = rise_time
				_pitch = LYING
		Phase.RISING:
			_timer -= delta
			var t := clampf(1.0 - _timer / maxf(rise_time, 0.01), 0.0, 1.0)
			_pitch = LYING * (1.0 - t * t * (3.0 - 2.0 * t))
			if _timer <= 0.0:
				_phase = Phase.DONE
				_pitch = 0.0
	return _pitch


## rest with pitch applied about its local X axis, turning about a point
## pivot_height up (the hips) so the body flips in place rather than about its
## feet, then lowered by `lying` (lying_amount()) so a body lying flat rests on
## the ground instead of floating at hip height.
static func apply(rest: Transform3D, pitch: float, pivot_height: float, lying: float = 0.0) -> Transform3D:
	var turn := Basis(Vector3.RIGHT, pitch)
	var pivot := Vector3.UP * pivot_height
	var drop := Vector3.DOWN * (pivot_height - LYING_HIP_HEIGHT) * lying
	return Transform3D(turn * rest.basis, rest.origin + pivot - turn * pivot + drop)
