class_name EnemyStats
extends Resource
## Tunable enemy numbers. Edit res://resources/enemies/*.tres in the inspector.

@export var max_health: int = 80
## Shown on the level badge over the health number, coloured against the
## player's level. An Enemy's level_override replaces it per instance.
@export_range(1, 99) var level: int = 1
## The enemy's name, e.g. for its gun-mode queue slot's tooltip.
@export var display_name: String = ""
## Face shown in gun mode's target queue slots: a 64x64 icon in
## res://textures/ui/icons/ made by scripts/tools/build_portrait_icons.gd
## (rules: docs/enemy_portraits.md). Defaults to a generic placeholder.
@export var portrait: Texture2D = preload("res://textures/ui/icons/placeholder_portrait.png")

@export_group("Level Scaling")
## One hit's damage at the same level as the player, as a share of a same-level,
## ungeared player's max health; then scaled by the level gap (CombatTuning).
## 0 = use each attack's own damage, still scaled by the gap.
@export_range(0.0, 1.0, 0.01) var damage_percent: float = 0.0
## Max health at the same level as the player, in basic melee-swing hits; then
## scaled by the level gap. 0 = use max_health, still scaled by the gap.
@export var health_in_melee_hits: float = 0.0

@export_group("Movement")
@export var move_speed: float = 3.5
@export var strafe_speed: float = 2.2
@export var acceleration: float = 20.0
@export var turn_speed: float = 8.0

@export_group("Awareness")
## Training dummy: never engages the player, and goes back to standing still
## after a stagger.
@export var passive: bool = false
@export var detection_radius: float = 12.0
## Gives up and returns to idle beyond this distance.
@export var lose_interest_radius: float = 22.0
## Length of the "spotted you" beat before engaging.
@export var aware_time: float = 0.6

@export_group("Patrol")
## Shambling speed while wandering its patrol area (Enemy.patrol_area).
@export var patrol_speed: float = 0.65
## Pause at each patrol point (s).
@export var patrol_pause_min: float = 0.2
@export var patrol_pause_max: float = 1.2

@export_group("Reposition")
## Circling distance while waiting for a turn to attack (m).
@export var preferred_distance: float = 4.5
## Distance error that produces full-speed correction toward/away from the player.
@export var distance_tolerance: float = 1.5
## Chance, each time he starts circling, that he backs away when the player comes
## closer than preferred_distance. Otherwise he holds his ground and only
## circles (he still closes in when too far). 1 = always back off.
@export_range(0.0, 1.0, 0.01) var back_off_chance: float = 0.15
@export var reposition_time_min: float = 1.2
@export var reposition_time_max: float = 2.8
@export var strafe_flip_time_min: float = 1.5
@export var strafe_flip_time_max: float = 3.5
## When another enemy has the attack turn, retry after this long.
@export var token_retry_interval: float = 0.4
## Gives up the attack turn if it can't close to range in time.
@export var approach_timeout: float = 2.5

@export_group("Combat")
@export var attacks: Array[AttackData] = []
## Stops tracking the player this long before a telegraph ends, so side-dodges work.
@export var telegraph_commit_time: float = 0.15
## After an attack, no enemy may take the next turn for this long.
@export var attack_token_cooldown: float = 0.9
@export var stagger_time: float = 0.4
@export var stagger_friction: float = 18.0
## Launchers (AttackData.launch_speed) knock it into the air for air combos.
@export var launchable: bool = true

@export_group("Combo")
## The Mincer's one attack: a telegraph, then five alternating claw sweeps (two
## slow, three rapid), then an overextended recovery that's open to punishment.
## Damage of every swing, all five the same (before level scaling; while
## damage_percent above is set, that decides the base instead).
@export var attack_damage: int = 25
## Length of each slow swing (1 and 2), split like the player's first melee
## swings: 17% windup, 21% strike (hitbox live), 62% recovery.
@export var slow_swing_time: float = 0.9
## Length of each rapid swing (3 to 5): 25% windup, 55% strike, 20% recovery.
@export var rapid_swing_time: float = 0.3
## The tell before the combo: rears up, claws spread, trembling (s).
@export var telegraph_time: float = 0.7
## After swing 5: the stumble, step back and straightening up, during which he
## can't attack and takes vulnerable_damage_multiplier damage (s).
@export var vulnerable_time: float = 1.2
@export var vulnerable_damage_multiplier: float = 1.0
## Wait after the recovery before the next combo can start (s).
@export var combo_cooldown: float = 1.5
## Chance, each time he's about to start a combo, that he steps back ~1.5 m to
## reset the spacing instead. 0 = never.
@export_range(0.0, 1.0, 0.01) var random_step_back_chance: float = 0.05
## Hits don't cancel the rapid swings (3 to 5), only the telegraph, slow swings
## and recovery.
@export var combo_stagger_immune: bool = false
