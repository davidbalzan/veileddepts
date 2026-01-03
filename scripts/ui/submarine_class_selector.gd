extends OptionButton
## UI component for selecting submarine class


func _ready() -> void:
	# Populate dropdown with available classes
	var main = get_node("/root/Main")
	if main and main.has_method("get_available_submarine_classes"):
		var classes = main.get_available_submarine_classes()
		for submarine_class_name in classes:
			add_item(submarine_class_name)

	# Connect selection signal
	item_selected.connect(_on_class_selected)


func _on_class_selected(index: int) -> void:
	var class_name = get_item_text(index)
	var main = get_node("/root/Main")
	if main and main.has_method("change_submarine_class"):
		main.change_submarine_class(class_name)
