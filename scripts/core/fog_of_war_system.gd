extends Node
class_name FogOfWarSystem
## Fog of War System determines which contacts should be visible in external view
##
## Implements visibility rules: contacts are only visible if they are both
## detected AND identified. Terrain, ocean, atmosphere, and sealife are always visible.
## Requirements: 4.7, 4.8

## Reference to simulation state for contact tracking
var simulation_state: SimulationState


func _ready() -> void:
	# Find simulation state from parent (Main node)
	var main_node = get_parent()
	if main_node:
		simulation_state = main_node.get_node_or_null("SimulationState")
		if not simulation_state:
			push_error("FogOfWarSystem: SimulationState not found")
	
	print("FogOfWarSystem: Initialized")


## Determine if a contact should be visible in external view
## Requirement 4.7, 4.8: Contact is visible only if detected AND identified
## @param contact: The contact to check for visibility
## @return: true if contact should be rendered, false otherwise
func is_contact_visible(contact: Contact) -> bool:
	if not contact:
		return false
	
	# Contact must be both detected AND identified to be visible
	# This implements the fog-of-war rule: you can only see what you've
	# both detected (sensor contact) and identified (confirmed type)
	return contact.detected and contact.identified


## Update visibility flags for all contacts
## This can be called periodically to batch-update visibility
## @param contacts: Array of contacts to update
func update_visibility(contacts: Array[Contact]) -> void:
	# This method doesn't modify contacts, it just provides a way to
	# batch-check visibility if needed for optimization
	# The actual visibility check is done per-contact via is_contact_visible
	pass


## Get all visible contacts from simulation state
## Convenience method that filters contacts based on visibility rules
## @return: Array of contacts that should be rendered
func get_visible_contacts() -> Array[Contact]:
	if not simulation_state:
		return []
	
	var visible_contacts: Array[Contact] = []
	
	for contact in simulation_state.contacts:
		if is_contact_visible(contact):
			visible_contacts.append(contact)
	
	return visible_contacts


## Check if environmental elements should be visible
## Requirement 4.6: Terrain, ocean, atmosphere, and sealife are always visible
## @param element_type: Type of environmental element (not used, always returns true)
## @return: Always returns true for environmental elements
func is_environment_visible(_element_type: String = "") -> bool:
	# Environmental elements (terrain, ocean, atmosphere, sealife) are
	# always visible regardless of detection or identification status
	return true
