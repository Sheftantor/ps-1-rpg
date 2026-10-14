extends Node
## Combat feedback (autoload "Feel"): hit stop, camera shake, enemy hit flash and
## push, floating damage numbers, kill puff and "+XP", and sound hooks. Every value
## comes from `settings` (res://settings/feel_settings.tres); F9 opens a live
## tuning panel (FeelPanel). Feedback only: never changes damage or timing.
##
## Entry points, each called from one place:
##   on_hit(attacker, target, damage, is_heavy)  - Hurtbox.receive_hit()
##   on_kill(target, xp)                         - Enemy._award_xp()
##   on_swing(attacker)                          - Hitbox.activate()
## Characters ask is_frozen(self) at the top of _physics_process, so hit stop
## freezes only them (their animation players are disabled meanwhile);
## Engine.time_scale and the tree pause are left to gun mode.

const SETTINGS_PATH := "res://settings/feel_settings.tres"
const FONT: Font = preload("res://Import/MGS1 HUD.ttf")
const POOL_SIZE := 8
## Where numbers and puffs appear on a body without a better point (m above its feet).
const BODY_HEIGHT := 1.4

var settings: FeelSettings

## Frozen node -> {until: usec, mixers: {AnimationMixer: original process mode}}
var _frozen: Dictionary = {}
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shaken_camera: Camera3D = null
var _noise := FastNoiseLite.new()
var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _last_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = load(SETTINGS_PATH) as FeelSettings
	if settings == null:
		settings = FeelSettings.new()
	_noise.frequency = 1.0
	# One octave: the full -1..1 range, so shake_max_offset is the real peak.
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)
	var panel := FeelPanel.new()
	panel.name = &"FeelPanel"
	add_child(panel)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Real time throughout: hit stop and shake ignore Engine.time_scale.
	var now := Time.get_ticks_usec()
	var real_delta := minf((now - _last_usec) / 1_000_000.0, 0.1)
	_last_usec = now
	_update_freezes(now)
	_update_shake(real_delta)


# --- Entry points ---------------------------------------------------------------

## A hit landed: damage is what the target actually took.
func on_hit(attacker: Node, target: Node, damage: int, is_heavy := false) -> void:
	if not settings.enabled or not is_instance_valid(target):
		return
	var heavy := is_heavy or _is_heavy(target, damage)
	var player_hurt := target is Player
	var gun := attacker is Player and (attacker as Player).state_machine.current_name() == PlayerState.GUN_AIM
	if settings.hit_stop_enabled and (not gun or settings.hit_stop_on_gun):
		var time := settings.hit_stop_heavy if heavy else settings.hit_stop_light
		freeze(target, time)
		if is_instance_valid(attacker):
			freeze(attacker, time)
	if settings.shake_enabled and (player_hurt or attacker is Player):
		var amount := settings.shake_heavy if heavy else settings.shake_light
		add_trauma(amount * (settings.shake_player_hurt_multiplier if player_hurt else 1.0))
	if settings.hit_reaction_enabled and target is Enemy:
		var enemy := target as Enemy
		enemy.flash(settings.flash_color, settings.flash_time)
		if is_instance_valid(attacker) and attacker is Node3D and settings.knockback_distance > 0.0:
			var away := enemy.global_position - (attacker as Node3D).global_position
			away.y = 0.0
			if away.length_squared() > 0.0001:
				enemy.push(away.normalized() * settings.knockback_distance / settings.knockback_time, settings.knockback_time)
	if settings.damage_numbers_enabled and damage > 0 and target is Node3D:
		var color := settings.color_player_hurt if player_hurt else (settings.color_heavy if heavy else settings.color_normal)
		float_text(str(damage), _top_of(target as Node3D), color)
	if player_hurt:
		play(settings.snd_player_hurt, settings.snd_player_hurt_db)
	elif heavy:
		play(settings.snd_hit_heavy, settings.snd_hit_heavy_db)
	else:
		play(settings.snd_hit_light, settings.snd_hit_light_db)


## An enemy died, giving the player xp.
func on_kill(target: Node, xp: int) -> void:
	if not settings.enabled or not settings.kill_feedback_enabled or not is_instance_valid(target):
		return
	var body := target as Node3D
	if target is Enemy:
		(target as Enemy).flash(settings.kill_flash_color, settings.kill_flash_time)
	if body != null:
		_puff(body.global_position + Vector3.UP * BODY_HEIGHT * 0.6)
		if xp > 0:
			float_text("+%d XP" % xp, _top_of(body) + Vector3.UP * 0.3, settings.color_xp)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and settings.xp_bar_pulse_time > 0.0:
		player.hud.pulse_xp_bar(settings.xp_bar_pulse_time)
	play(settings.snd_kill, settings.snd_kill_db)


## A swing started (its hitbox went live).
func on_swing(_attacker: Node) -> void:
	if settings.enabled:
		play(settings.snd_swing, settings.snd_swing_db)


# --- Hit stop -------------------------------------------------------------------

## Freezes node (a Player or Enemy) for seconds of real time: its physics step
## and every AnimationMixer under it stop. Overlapping freezes extend it.
func freeze(node: Node, seconds: float) -> void:
	if seconds <= 0.0 or not (node is Player or node is Enemy):
		return
	var until := Time.get_ticks_usec() + int(seconds * 1_000_000.0)
	if _frozen.has(node):
		_frozen[node].until = maxi(_frozen[node].until, until)
		return
	var mixers := {}
	for mixer: Node in node.find_children("*", "AnimationMixer", true, false):
		# Disabling the node pauses it in place; switching callback_mode_process
		# to manual and back instead restarts the AnimationTree's one-shot clips.
		mixers[mixer] = mixer.process_mode
		mixer.process_mode = Node.PROCESS_MODE_DISABLED
	_frozen[node] = {until = until, mixers = mixers}


func is_frozen(node: Node) -> bool:
	return _frozen.has(node)


func _update_freezes(now: int) -> void:
	for node: Node in _frozen.keys():
		if is_instance_valid(node) and now < _frozen[node].until:
			continue
		for mixer: Node in _frozen[node].mixers:
			if is_instance_valid(mixer):
				mixer.process_mode = _frozen[node].mixers[mixer]
		_frozen.erase(node)


# --- Camera shake -----------------------------------------------------------------

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Shakes the current camera's h/v offset only, so its real position (spring
## arm, lock-on framing) is never touched.
func _update_shake(real_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != _shaken_camera:
		if is_instance_valid(_shaken_camera):
			_shaken_camera.h_offset = 0.0
			_shaken_camera.v_offset = 0.0
		_shaken_camera = camera
	_trauma = maxf(_trauma - settings.shake_decay * real_delta, 0.0)
	if camera == null:
		return
	_shake_time += real_delta * settings.shake_frequency
	var strength := pow(_trauma, settings.shake_exponent) * settings.shake_max_offset
	camera.h_offset = _noise.get_noise_2d(_shake_time, 0.0) * strength
	camera.v_offset = _noise.get_noise_2d(0.0, _shake_time + 100.0) * strength


# --- Numbers and puffs -------------------------------------------------------------

## A billboard number (or word) rising and fading at position, readable through walls.
func float_text(text: String, position: Vector3, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = settings.damage_number_font_size
	label.pixel_size = settings.damage_number_pixel_size
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, color.a)
	label.outline_size = maxi(4, settings.damage_number_font_size / 6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.render_priority = 20
	label.outline_render_priority = 19
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(label)
	var spread := settings.damage_number_spread
	label.global_position = position + Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread) * 0.5)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, ^"global_position:y", label.global_position.y + settings.damage_number_rise,
			settings.damage_number_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"modulate:a", 0.0, settings.damage_number_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(label, ^"outline_modulate:a", 0.0, settings.damage_number_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _puff(position: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null or settings.death_puff_count <= 0:
		return
	var puff := CPUParticles3D.new()
	puff.process_mode = Node.PROCESS_MODE_ALWAYS
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = settings.death_puff_count
	puff.lifetime = settings.death_puff_time
	puff.direction = Vector3.UP
	puff.spread = 180.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.4
	puff.gravity = Vector3(0, -1.5, 0)
	puff.damping_min = 2.0
	puff.damping_max = 4.0
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = settings.death_puff_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	puff.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, settings.death_puff_color)
	fade.set_color(1, Color(settings.death_puff_color, 0.0))
	puff.color_ramp = fade
	scene.add_child(puff)
	puff.global_position = position
	puff.emitting = true
	puff.finished.connect(puff.queue_free)


## Just above the body: the top of its collision shape, or BODY_HEIGHT.
func _top_of(body: Node3D) -> Vector3:
	var height := BODY_HEIGHT
	var shape := body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		height = shape.position.y + (shape.shape as CapsuleShape3D).height * 0.5
	return body.global_position + Vector3.UP * (height + 0.2)


func _is_heavy(target: Node, damage: int) -> bool:
	var health := target.get_node_or_null(^"Health") as Health
	return health != null and health.max_health > 0 \
			and damage >= settings.heavy_damage_threshold * health.max_health


# --- Sound -----------------------------------------------------------------------

## Plays stream on the next free pool player (or the oldest); empty slots are skipped.
func play(stream: AudioStream, volume_db: float) -> void:
	if stream == null or not settings.enabled or not settings.sound_enabled:
		return
	var player: AudioStreamPlayer = null
	for i in POOL_SIZE:
		var candidate := _pool[(_next_player + i) % POOL_SIZE]
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _pool[_next_player]
	_next_player = (_pool.find(player) + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-settings.pitch_variation, settings.pitch_variation)
	player.play()


## Puts every value back to the script defaults (the F9 panel's Reset).
func reset_settings() -> void:
	var defaults := FeelSettings.new()
	for property in settings.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			settings.set(property.name, defaults.get(property.name))


func save_settings() -> Error:
	return ResourceSaver.save(settings, SETTINGS_PATH)
