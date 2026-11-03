class_name CombatRules
extends RefCounted
## The arithmetic of a fight: who gets hit, how much it hurts, what armor and
## blocking do. Plain functions so they are easy to test and to tune.

const BLOCK_REDUCTION := 0.8
## A block raised within this many seconds of the strike landing is a parry.
const PARRY_WINDOW := 0.18
## Armor/(armor+K) is the share of damage that gets through; K sets how fast armor stacks.
const ARMOR_K := 40.0
const MIN_DAMAGE := 1
## The guard covers a cone this wide (half angle, degrees) in the facing direction.
const GUARD_HALF_ANGLE := 70.0

const OUTCOME_HIT := "hit"
const OUTCOME_BLOCKED := "blocked"
const OUTCOME_PARRIED := "parried"


## Share of damage that gets through armor: 1.0 with none, never 0.
static func armor_multiplier(armor: float) -> float:
	return ARMOR_K / (ARMOR_K + maxf(armor, 0.0))


## Damage the player deals: the weapon plus a flat bonus per level.
static func player_damage(weapon_damage: int, level: int) -> int:
	return weapon_damage + ProgressionRules.damage_bonus(level)


## What happens when an enemy strike lands: {"outcome", "damage"}.
static func resolve_hit(raw_damage: float, armor: float, blocking: bool, guard_covers: bool, seconds_since_block: float, parry_window: float = PARRY_WINDOW) -> Dictionary:
	var through := raw_damage * armor_multiplier(armor)
	if blocking and guard_covers:
		if seconds_since_block <= parry_window:
			return {"outcome": OUTCOME_PARRIED, "damage": 0}
		return {"outcome": OUTCOME_BLOCKED, "damage": maxi(MIN_DAMAGE, roundi(through * (1.0 - BLOCK_REDUCTION)))}
	return {"outcome": OUTCOME_HIT, "damage": maxi(MIN_DAMAGE, roundi(through))}


## Is `target` inside the swing: close enough and within the cone in front?
static func in_arc(origin: Vector2, facing: Vector2, target: Vector2, reach: float, half_angle_degrees: float) -> bool:
	var offset := target - origin
	if offset.length() > reach:
		return false
	if offset.length() < 0.001 or facing == Vector2.ZERO:
		return true
	return rad_to_deg(absf(facing.normalized().angle_to(offset))) <= half_angle_degrees


## Does the player's guard face the attacker?
static func guard_covers(facing: Vector2, player_position: Vector2, attacker_position: Vector2) -> bool:
	return in_arc(player_position, facing, attacker_position, INF, GUARD_HALF_ANGLE)
