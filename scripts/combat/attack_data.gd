class_name AttackData
extends Resource
## Numbers for a single attack. Shared by the player and enemies; fields only
## enemies read are grouped under "Enemy".

@export var display_name: String = ""
@export var damage: int = 10
## Horizontal push applied to whoever gets hit (m/s).
@export var knockback: float = 3.0
## Forward speed of the attacker while the attack is winding up and active (m/s).
@export var lunge_speed: float = 0.0

@export_group("Timing")
## Wind-up before the hitbox goes live (player attacks; enemies use telegraph_time).
@export var startup_time: float = 0.1
## How long the hitbox is live.
@export var active_time: float = 0.12
## Player: the combo window to chain the next attack. Enemy: the punish window.
@export var recovery_time: float = 0.25

@export_group("Enemy")
## Visible wind-up before the attack lands. Long enough for the player to react.
@export var telegraph_time: float = 0.5
## The enemy approaches until it is at least this close before telegraphing (m).
@export var max_range: float = 2.0
## Relative chance of picking this attack.
@export var weight: float = 1.0
@export var telegraph_color: Color = Color(1.0, 0.85, 0.2)
## Peak extra scale of the mesh while telegraphing (0.1 = +10%).
@export var telegraph_pulse_amount: float = 0.1
## Pulses per second while telegraphing.
@export var telegraph_pulse_rate: float = 4.0
