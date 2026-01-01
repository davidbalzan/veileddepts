class_name AppendageDragRegistry
extends RefCounted

## Manages dynamic drag contributions from extended equipment
##
## This registry tracks appendages (periscopes, masts, towed arrays, etc.) that
## contribute additional drag when deployed. Each appendage has a drag multiplier
## that increases the submarine's total drag coefficient.
##
## Requirements: 21.6, 21.7, 21.8, 21.9, 21.10

# Dictionary mapping appendage names to their drag multipliers
var appendages: Dictionary = {}

# Maximum total drag multiplier (2.0 = 100% increase)
var max_total_multiplier: float = 2.0


## Add an appendage with its drag contribution
##
## @param name: Unique identifier for the appendage (e.g., "periscope", "towed_array")
## @param multiplier: Drag multiplier (e.g., 0.05 = 5% increase, 0.25 = 25% increase)
func add_appendage(name: String, multiplier: float) -> void:
	appendages[name] = multiplier


## Remove an appendage from the registry
##
## @param name: Identifier of the appendage to remove
func remove_appendage(name: String) -> void:
	appendages.erase(name)


## Calculate total drag multiplier from all active appendages
##
## Sums all individual appendage multipliers and clamps to max_total_multiplier
## to prevent unrealistic drag values.
##
## @return: Total drag multiplier, clamped to [0.0, max_total_multiplier]
func get_total_drag_multiplier() -> float:
	var total: float = 0.0
	
	for multiplier in appendages.values():
		total += multiplier
	
	# Clamp to maximum allowed increase (100% = 2.0x base drag)
	return clamp(total, 0.0, max_total_multiplier)


## Remove all appendages from the registry
func clear_all() -> void:
	appendages.clear()


## Check if a specific appendage is currently registered
##
## @param name: Identifier of the appendage to check
## @return: true if the appendage exists in the registry
func has_appendage(name: String) -> bool:
	return appendages.has(name)
